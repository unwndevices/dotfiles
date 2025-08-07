#!/usr/bin/env python3
"""
hypr-minimizer.py - A simple window minimizer for Hyprland
Inspired by NiflVeil (https://github.com/Mauitron/NiflVeil)
"""

import os
import json
import subprocess
import sys
import argparse

# Constants
CACHE_DIR = "/tmp/hypr-minimizer"
CACHE_FILE = os.path.join(CACHE_DIR, "windows.json")

def ensure_cache_exists():
    """Ensure cache directory and file exist"""
    os.makedirs(CACHE_DIR, exist_ok=True)
    if not os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, 'w') as f:
            f.write("[]")

def run_command(cmd):
    """Run a shell command and return its output"""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command {cmd}: {e}", file=sys.stderr)
        return ""

def parse_json(json_str):
    """Parse JSON string safely"""
    try:
        return json.loads(json_str)
    except json.JSONDecodeError:
        return {}

def get_active_window_info():
    """Get information about the currently active window"""
    output = run_command(["hyprctl", "activewindow", "-j"])
    if not output:
        return None
    return parse_json(output)

def get_active_workspace():
    """Get the current workspace ID"""
    output = run_command(["hyprctl", "activeworkspace", "-j"])
    if not output:
        return 1
    workspace_data = parse_json(output)
    return workspace_data.get("id", 1)

def minimize_window():
    """Minimize the currently active window"""
    window_info = get_active_window_info()
    if not window_info:
        print("No active window found")
        return

    # Skip certain windows like wofi
    if window_info.get("class") in ["wofi", "rofi"]:
        return

    window_addr = window_info.get("address")
    if not window_addr:
        print("No window address found")
        return

    class_name = window_info.get("class", "Unknown")
    title = window_info.get("title", "Unknown")
    short_addr = window_addr[-4:] if len(window_addr) >= 4 else window_addr

    # Create window data
    window_data = {
        "address": window_addr,
        "display_title": f"{class_name} - {title} [{short_addr}]",
        "class": class_name,
        "original_title": title
    }

    # Move window to special workspace
    run_command([
        "hyprctl", "dispatch", "movetoworkspacesilent", 
        f"special:minimum,address:{window_addr}"
    ])

    # Update cache
    try:
        with open(CACHE_FILE, 'r') as f:
            windows = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        windows = []

    windows.append(window_data)
    
    with open(CACHE_FILE, 'w') as f:
        json.dump(windows, f, indent=2)

def restore_window(window_id=None):
    """Restore a minimized window"""
    try:
        with open(CACHE_FILE, 'r') as f:
            windows = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        windows = []

    if not windows:
        print("No minimized windows")
        return

    # If no window_id is provided, restore the last minimized window
    if window_id is None:
        window_to_restore = windows[-1]
    else:
        # Find window with matching ID
        window_to_restore = None
        for window in windows:
            if window["address"] == window_id:
                window_to_restore = window
                break
        
        if not window_to_restore:
            print(f"Window with ID {window_id} not found")
            return

    # Get current workspace
    current_ws = get_active_workspace()

    # Move window from special workspace to current workspace
    run_command([
        "hyprctl", "dispatch", "movetoworkspace", 
        f"{current_ws},address:{window_to_restore['address']}"
    ])

    # Focus the window
    run_command([
        "hyprctl", "dispatch", "focuswindow", 
        f"address:{window_to_restore['address']}"
    ])

    # Update cache
    windows = [w for w in windows if w["address"] != window_to_restore["address"]]
    with open(CACHE_FILE, 'w') as f:
        json.dump(windows, f, indent=2)

def restore_all_windows():
    """Restore all minimized windows"""
    try:
        with open(CACHE_FILE, 'r') as f:
            windows = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        windows = []

    if not windows:
        print("No minimized windows")
        return

    for window in windows.copy():
        restore_window(window["address"])

def list_windows():
    """List all minimized windows"""
    try:
        with open(CACHE_FILE, 'r') as f:
            windows = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        windows = []

    if not windows:
        print("No minimized windows")
        return

    print(f"Minimized windows ({len(windows)}):")
    for i, window in enumerate(windows, 1):
        print(f"{i}. {window['display_title']}")

def main():
    """Main function"""
    ensure_cache_exists()

    parser = argparse.ArgumentParser(description="Hyprland Window Minimizer")
    subparsers = parser.add_subparsers(dest="command", help="Command to run")

    # Minimize command
    subparsers.add_parser("minimize", help="Minimize the active window")

    # Restore command
    restore_parser = subparsers.add_parser("restore", help="Restore a minimized window")
    restore_parser.add_argument("window_id", nargs="?", help="Window ID to restore (optional)")

    # Restore all command
    subparsers.add_parser("restore-all", help="Restore all minimized windows")

    # List command
    subparsers.add_parser("list", help="List all minimized windows")

    args = parser.parse_args()

    if args.command == "minimize":
        minimize_window()
    elif args.command == "restore":
        restore_window(args.window_id)
    elif args.command == "restore-all":
        restore_all_windows()
    elif args.command == "list":
        list_windows()
    else:
        parser.print_help()

if __name__ == "__main__":
    main()