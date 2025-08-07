#!/bin/bash

# Enable debug mode
set -x

AUDIO_FILE="/tmp/whisper_audio.wav"
PID_FILE="/tmp/whisper_recorder.pid"
LIVE_AUDIO_DIR="/tmp/whisper_live"
MODEL_PATH="/home/unwn/models/ggml-medium.bin"
FAST_MODEL_PATH="/home/unwn/models/ggml-base.bin"  # Faster but less accurate
LOG_FILE="/tmp/whisper_debug.log"
LIVE_OUTPUT_FILE="/tmp/whisper_live_output.txt"
CHUNK_DURATION=3  # seconds per audio chunk for live transcription

# Function to log debug info
debug_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to paste text based on window type
paste_text() {
    # Get active window info
    ACTIVE_WINDOW=$(hyprctl activewindow -j)
    IS_XWAYLAND=$(echo "$ACTIVE_WINDOW" | jq -r .xwayland)
    WINDOW_CLASS=$(echo "$ACTIVE_WINDOW" | jq -r .class)
    WINDOW_TITLE=$(echo "$ACTIVE_WINDOW" | jq -r .title)
    
    debug_log "Active window info: $ACTIVE_WINDOW"
    debug_log "Is XWayland: $IS_XWAYLAND"
    debug_log "Window class: $WINDOW_CLASS"
    debug_log "Window title: $WINDOW_TITLE"
    
    # Check if it's a terminal or has terminal-like behavior
    IS_TERMINAL=false
    
    # Check for standalone terminals
    case "$WINDOW_CLASS" in
        *terminal*|*Terminal*|kitty|alacritty|wezterm|foot|gnome-terminal|konsole|xterm|st|urxvt)
            IS_TERMINAL=true
            debug_log "Detected standalone terminal: $WINDOW_CLASS"
            ;;
    esac
    
    # Check for integrated terminals in editors
    case "$WINDOW_CLASS" in
        *code*|*Code*|Cursor|cursor)
            # More specific check for terminal focus in editors
            if echo "$WINDOW_TITLE" | grep -qi "terminal\|bash\|zsh\|fish\|powershell\|cmd" || 
               echo "$WINDOW_TITLE" | grep -q "~\|>\|$"; then
                IS_TERMINAL=true
                debug_log "Detected integrated terminal in $WINDOW_CLASS"
            else
                debug_log "Editor detected but no terminal focus in $WINDOW_CLASS"
            fi
            ;;
    esac
    
    # Apply appropriate paste method
    if [ "$IS_TERMINAL" = "true" ]; then
        debug_log "Using terminal paste method (Ctrl+Shift+V)"
        if [ "$IS_XWAYLAND" = "true" ]; then
            xdotool key ctrl+shift+v
        else
            wtype -M ctrl -M shift v -m shift -m ctrl
        fi
    else
        debug_log "Using standard paste method (Ctrl+V)"
        if [ "$IS_XWAYLAND" = "true" ]; then
            xdotool key ctrl+v
        else
            wtype -M ctrl v -m ctrl
        fi
    fi
}

# Function to type text directly (bypassing clipboard)
type_text() {
    local text="$1"
    ACTIVE_WINDOW=$(hyprctl activewindow -j)
    IS_XWAYLAND=$(echo "$ACTIVE_WINDOW" | jq -r .xwayland)
    
    debug_log "Typing text directly: ${text:0:50}..."
    
    if [ "$IS_XWAYLAND" = "true" ]; then
        # Use xdotool for XWayland
        echo "$text" | xargs -0 xdotool type --
    else
        # Use wtype for native Wayland
        wtype "$text"
    fi
}

# Function to select and replace current line/text
select_and_replace_text() {
    local new_text="$1"
    ACTIVE_WINDOW=$(hyprctl activewindow -j)
    IS_XWAYLAND=$(echo "$ACTIVE_WINDOW" | jq -r .xwayland)
    
    debug_log "Selecting and replacing text with: ${new_text:0:50}..."
    
    if [ "$IS_XWAYLAND" = "true" ]; then
        # Select current line and replace
        xdotool key Home
        xdotool key shift+End
        sleep 0.1
        echo "$new_text" | xargs -0 xdotool type --
    else
        # Wayland equivalent
        wtype -M ctrl a -m ctrl
        sleep 0.1
        wtype "$new_text"
    fi
}

# Function for live transcription processing
live_transcribe() {
    local chunk_file="$1"
    local chunk_num="$2"
    
    debug_log "Processing chunk $chunk_num: $chunk_file"
    
    # Build whisper command with appropriate model
    SELECTED_MODEL="$MODEL_PATH"
    if [ "$FAST_MODE" = "true" ]; then
        if [ -f "$FAST_MODEL_PATH" ]; then
            SELECTED_MODEL="$FAST_MODEL_PATH"
        fi
    fi
    
    # Use base model for live mode for speed, even if not explicitly fast
    if [ "$LIVE_MODE" = "true" ] && [ -f "$FAST_MODEL_PATH" ]; then
        SELECTED_MODEL="$FAST_MODEL_PATH"
        debug_log "Using fast model for live mode: $SELECTED_MODEL"
    fi
    
    WHISPER_CMD="$HOME/.local/bin/whisper-cli -m \"$SELECTED_MODEL\" -l auto -nt"
    if [ "$TRANSLATE" = "true" ]; then
        WHISPER_CMD="$WHISPER_CMD -tr"
    fi
    
    debug_log "Executing whisper command for chunk $chunk_num: $WHISPER_CMD"
    
    # Process chunk and get text
    local temp_output="/tmp/whisper_chunk_${chunk_num}.txt"
    $WHISPER_CMD -otxt -of "/tmp/whisper_chunk_${chunk_num}" "$chunk_file" 2>>"$LOG_FILE"
    local whisper_exit=$?
    
    debug_log "Whisper command for chunk $chunk_num exit code: $whisper_exit"
    
    if [ -f "${temp_output}" ]; then
        local text=$(cat "${temp_output}" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        debug_log "Raw text from chunk $chunk_num: '$text'"
        
        if [ -n "$text" ] && [ "$text" != " " ]; then
            debug_log "Live chunk $chunk_num: $text"
            
            # Type the text directly
            type_text "$text "
            
            # Also save to clipboard
            echo "$text" | wl-copy
            debug_log "Text from chunk $chunk_num copied to clipboard"
            
            # Store for potential replacement if translating
            if [ "$TRANSLATE" = "true" ]; then
                echo "$text" >> "$LIVE_OUTPUT_FILE"
            fi
        else
            debug_log "Chunk $chunk_num produced empty or whitespace-only text"
        fi
        rm -f "${temp_output}"
    else
        debug_log "No output file created for chunk $chunk_num"
    fi
    
    # Clean up chunk file
    rm -f "$chunk_file"
}

# Function to start live transcription using whisper-stream
start_live_transcription() {
    debug_log "Starting live transcription with whisper-stream"
    
    # Build whisper-stream command with appropriate model
    SELECTED_MODEL="$MODEL_PATH"
    if [ "$FAST_MODE" = "true" ] || [ "$LIVE_MODE" = "true" ]; then
        if [ -f "$FAST_MODEL_PATH" ]; then
            SELECTED_MODEL="$FAST_MODEL_PATH"
            debug_log "Using fast model for live mode: $SELECTED_MODEL"
        fi
    fi
    
    # Create a wrapper script that processes whisper-stream output
    cat > "/tmp/whisper_live_processor.sh" << 'EOF'
#!/bin/bash
LOG_FILE="/tmp/whisper_debug.log"
LIVE_OUTPUT_FILE="/tmp/whisper_live_output.txt"

debug_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to type text directly
type_text_live() {
    local text="$1"
    ACTIVE_WINDOW=$(hyprctl activewindow -j)
    IS_XWAYLAND=$(echo "$ACTIVE_WINDOW" | jq -r .xwayland)
    
    if [ "$IS_XWAYLAND" = "true" ]; then
        echo "$text " | xargs -0 xdotool type --
    else
        wtype "$text "
    fi
}

echo "" > "$LIVE_OUTPUT_FILE"
debug_log "Live transcription processor started"

# Process each line of output from whisper-stream
while IFS= read -r line; do
    # Skip empty lines and lines that are just whitespace
    if [[ -n "${line// }" ]]; then
        debug_log "Live transcription: $line"
        
        # Type the text directly
        type_text_live "$line"
        
        # Save to clipboard
        echo "$line" | wl-copy
        
        # Store in output file
        echo "$line" >> "$LIVE_OUTPUT_FILE"
        
        debug_log "Text typed and saved to clipboard: $line"
    fi
done
EOF
    
    chmod +x "/tmp/whisper_live_processor.sh"
    
    # Build whisper-stream command
    STREAM_CMD="$HOME/.local/bin/whisper-stream -m \"$SELECTED_MODEL\" -l auto"
    
    # Add translation if requested
    if [ "$TRANSLATE" = "true" ]; then
        STREAM_CMD="$STREAM_CMD -tr"
    fi
    
    # Configure streaming parameters for responsiveness
    STREAM_CMD="$STREAM_CMD --step 2000 --length 8000 --keep 200 --vad-thold 0.3"
    
    debug_log "Starting whisper-stream with command: $STREAM_CMD"
    
    # Start whisper-stream and pipe its output to our processor
    eval "$STREAM_CMD" | "/tmp/whisper_live_processor.sh" &
    
    LIVE_PID=$!
    echo $LIVE_PID > "${PID_FILE}.live"
    debug_log "Live transcription background process started with PID: $LIVE_PID"
}

# Check for mode flags
TRANSLATE=false
FAST_MODE=false
LIVE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        "translate")
            TRANSLATE=true
            debug_log "Translation mode enabled"
            shift
            ;;
        "fast")
            FAST_MODE=true
            debug_log "Fast mode enabled"
            shift
            ;;
        "live")
            LIVE_MODE=true
            debug_log "Live mode enabled"
            shift
            ;;
        *)
            break
            ;;
    esac
done

case "$1" in
    "start")
        debug_log "Starting recording $([ "$TRANSLATE" = "true" ] && echo "for translation" || echo "for transcription")$([ "$LIVE_MODE" = "true" ] && echo " (live mode)" || "")"
        
        # Send start notification
        if [ "$LIVE_MODE" = "true" ]; then
            if [ "$TRANSLATE" = "true" ]; then
                notify-send "Whisper" "Live Translation Started..." -t 1000
            else
                notify-send "Whisper" "Live Transcription Started..." -t 1000
            fi
            
            # Create PID file for live mode
            touch "$PID_FILE"
            start_live_transcription
        else
            # Regular mode
            if [ "$TRANSLATE" = "true" ]; then
                notify-send "Whisper" "Recording (English Translation)..." -t 1000
            else
                notify-send "Whisper" "Recording..." -t 1000
            fi

            # Start recording
            pw-record "$AUDIO_FILE" &
            RECORD_PID=$!
            echo $RECORD_PID > "$PID_FILE"
            debug_log "Recording started with PID: $RECORD_PID"
        fi
        ;;
    "stop")
        if [ -f "$PID_FILE" ]; then
            debug_log "Stopping recording"
            
            if [ "$LIVE_MODE" = "true" ]; then
                # Stop live transcription
                if [ -f "${PID_FILE}.live" ]; then
                    LIVE_PID=$(cat "${PID_FILE}.live")
                    kill $LIVE_PID 2>/dev/null
                    rm -f "${PID_FILE}.live"
                    debug_log "Killed live transcription process: $LIVE_PID"
                fi
                
                # Clean up
                rm -f "$PID_FILE"
                rm -rf "$LIVE_AUDIO_DIR"
                
                # Final notification
                if [ "$TRANSLATE" = "true" ]; then
                    notify-send "Whisper" "Live Translation Stopped" -t 1000
                else
                    notify-send "Whisper" "Live Transcription Stopped" -t 1000
                fi
                
                debug_log "Live mode cleanup completed"
                exit 0
            else
                # Regular mode - kill recording process
                RECORD_PID=$(cat "$PID_FILE")
                kill $RECORD_PID
                debug_log "Killed recording process: $RECORD_PID"
                rm "$PID_FILE"
            fi

            # Notify transcribing
            if [ "$TRANSLATE" = "true" ]; then
                notify-send "Whisper" "Transcribing and Translating..." -t 1000
            else
                notify-send "Whisper" "Transcribing..." -t 1000
            fi

            # Check if audio file exists and has content
            if [ -f "$AUDIO_FILE" ] && [ -s "$AUDIO_FILE" ]; then
                debug_log "Audio file exists and has content"
            else
                debug_log "Audio file missing or empty"
                notify-send "Whisper" "Error: No audio recorded!" -t 2000
                exit 1
            fi

            # Build whisper command with appropriate model
            SELECTED_MODEL="$MODEL_PATH"
            if [ "$FAST_MODE" = "true" ]; then
                if [ -f "$FAST_MODEL_PATH" ]; then
                    SELECTED_MODEL="$FAST_MODEL_PATH"
                    debug_log "Using fast model: $FAST_MODEL_PATH"
                else
                    debug_log "Fast model not found, using default: $MODEL_PATH"
                fi
            fi
            
            WHISPER_CMD="$HOME/.local/bin/whisper-cli -m \"$SELECTED_MODEL\" -l auto"
            if [ "$TRANSLATE" = "true" ]; then
                WHISPER_CMD="$WHISPER_CMD -tr"
                debug_log "Running whisper with translation"
            else
                debug_log "Running whisper without translation"
            fi
            WHISPER_CMD="$WHISPER_CMD -nt -otxt -of \"/tmp/whisper_output\" \"$AUDIO_FILE\""
            
            # Execute whisper command
            debug_log "Executing command: $WHISPER_CMD"
            eval $WHISPER_CMD 2>> "$LOG_FILE"
            WHISPER_EXIT=$?
            debug_log "Whisper command exit code: $WHISPER_EXIT"

            # Copy result to clipboard and auto-paste
            if [ -f "/tmp/whisper_output.txt" ]; then
                TEXT=$(cat "/tmp/whisper_output.txt")
                debug_log "Output text: $TEXT"
                
                # Try copying to clipboard
                if echo "$TEXT" | wl-copy; then
                    debug_log "Text copied to clipboard successfully"
                    if [ "$TRANSLATE" = "true" ]; then
                        notify-send "Whisper" "Translation copied to clipboard!" -t 2000
                    else
                        notify-send "Whisper" "Text copied to clipboard!" -t 2000
                    fi
                    
                    # Small delay to ensure clipboard is ready
                    sleep 0.5
                    
                    # Try pasting using the appropriate method
                    if paste_text; then
                        debug_log "Paste command executed successfully"
                    else
                        debug_log "Paste command failed"
                        notify-send "Whisper" "Auto-paste failed! Text is in clipboard." -t 2000
                    fi
                else
                    debug_log "Failed to copy to clipboard"
                    notify-send "Whisper" "Failed to copy to clipboard!" -t 2000
                fi
                
                rm "/tmp/whisper_output.txt"
            else
                debug_log "$([ "$TRANSLATE" = "true" ] && echo "Translation" || echo "Transcription") failed - no output file"
                notify-send "Whisper" "$([ "$TRANSLATE" = "true" ] && echo "Translation" || echo "Transcription") failed!" -t 2000
            fi

            # Clean up audio file
            rm "$AUDIO_FILE" 2>/dev/null
            debug_log "Cleanup completed"
        else
            debug_log "No PID file found - was recording started?"
        fi
        ;;
esac 