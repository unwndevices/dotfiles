#!/bin/bash

# Whisper Live Transcription Script
# Uses whisper-stream for real-time speech-to-text

# Enable debug mode
set -x

# Configuration
MODEL_PATH="/home/unwn/models/ggml-medium.bin"
FAST_MODEL_PATH="/home/unwn/models/ggml-base.bin"
LOG_FILE="/tmp/whisper_live_debug.log"
LIVE_OUTPUT_FILE="/tmp/whisper_live_output.txt"
PID_FILE="/tmp/whisper_live.pid"

# Function to log debug info
debug_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to type text directly (bypassing clipboard)
type_text() {
    local text="$1"
    ACTIVE_WINDOW=$(hyprctl activewindow -j)
    IS_XWAYLAND=$(echo "$ACTIVE_WINDOW" | jq -r .xwayland)
    
    debug_log "Typing text directly: ${text:0:50}..."
    
    if [ "$IS_XWAYLAND" = "true" ]; then
        echo "$text " | xargs -0 xdotool type --
    else
        wtype "$text "
    fi
}

# Check for mode flags
TRANSLATE=false
FAST_MODE=false

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
        *)
            break
            ;;
    esac
done

case "$1" in
    "start")
        debug_log "Starting live transcription $([ "$TRANSLATE" = "true" ] && echo "with translation" || echo "without translation")"
        
        # Send start notification
        if [ "$TRANSLATE" = "true" ]; then
            notify-send "Whisper Live" "Live Translation Started..." -t 1000
        else
            notify-send "Whisper Live" "Live Transcription Started..." -t 1000
        fi
        
        # Select model (use fast model for live mode by default)
        SELECTED_MODEL="$FAST_MODEL_PATH"
        if [ "$FAST_MODE" = "false" ] && [ -f "$MODEL_PATH" ]; then
            SELECTED_MODEL="$MODEL_PATH"
            debug_log "Using full quality model: $SELECTED_MODEL"
        else
            debug_log "Using fast model for live mode: $SELECTED_MODEL"
        fi
        
        # Build whisper-stream command
        STREAM_CMD="$HOME/.local/bin/whisper-stream -m \"$SELECTED_MODEL\" -l auto"
        
        # Add translation if requested
        if [ "$TRANSLATE" = "true" ]; then
            STREAM_CMD="$STREAM_CMD -tr"
        fi
        
        # Configure streaming parameters for responsiveness
        # --step: how often to process audio (ms)
        # --length: length of audio context (ms)  
        # --keep: audio to keep from previous step (ms)
        # --vad-thold: voice activity detection threshold
        STREAM_CMD="$STREAM_CMD --step 2000 --length 8000 --keep 200 --vad-thold 0.3"
        
        debug_log "Starting whisper-stream with command: $STREAM_CMD"
        
        # Create output file
        echo "" > "$LIVE_OUTPUT_FILE"
        
        # Start whisper-stream and process its output
        (
            eval "$STREAM_CMD" | while IFS= read -r line; do
                # Skip empty lines and lines that are just whitespace
                if [[ -n "${line// }" ]]; then
                    debug_log "Live transcription: $line"
                    
                    # Type the text directly
                    type_text "$line"
                    
                    # Save to clipboard
                    echo "$line" | wl-copy
                    
                    # Store in output file
                    echo "$line" >> "$LIVE_OUTPUT_FILE"
                    
                    debug_log "Text typed and saved: $line"
                fi
            done
        ) &
        
        LIVE_PID=$!
        echo $LIVE_PID > "$PID_FILE"
        debug_log "Live transcription started with PID: $LIVE_PID"
        ;;
        
    "stop")
        if [ -f "$PID_FILE" ]; then
            debug_log "Stopping live transcription"
            
            LIVE_PID=$(cat "$PID_FILE")
            kill $LIVE_PID 2>/dev/null
            rm -f "$PID_FILE"
            
            debug_log "Killed live transcription process: $LIVE_PID"
            
            # Final notification
            if [ "$TRANSLATE" = "true" ]; then
                notify-send "Whisper Live" "Live Translation Stopped" -t 1000
            else
                notify-send "Whisper Live" "Live Transcription Stopped" -t 1000
            fi
            
            debug_log "Live transcription cleanup completed"
        else
            debug_log "No live transcription process found"
            notify-send "Whisper Live" "No active session to stop" -t 1000
        fi
        ;;
        
    *)
        echo "Usage: $0 [translate] [fast] {start|stop}"
        echo ""
        echo "Options:"
        echo "  translate  - Enable translation to English"
        echo "  fast      - Use fast model (base) instead of medium"
        echo ""
        echo "Examples:"
        echo "  $0 start                    # Start live transcription"
        echo "  $0 translate start          # Start live translation"
        echo "  $0 fast start              # Start with fast model"
        echo "  $0 fast translate start    # Fast live translation"
        echo "  $0 stop                    # Stop live session"
        ;;
esac