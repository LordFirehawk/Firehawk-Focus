#!/usr/bin/env bash
set -euo pipefail

app_dir="$HOME/Applications/Firehawk Focus.app"
launch_agents_dir="$HOME/Library/LaunchAgents"
label="com.lordfirehawk.firehawk-focus"
legacy_label="org.lordfirehawk.firehawk-focus"

pkill -x "FirehawkFocus" 2>/dev/null || true
launchctl bootout "gui/$UID/$label" 2>/dev/null || true
launchctl bootout "gui/$UID/$legacy_label" 2>/dev/null || true
rm -f "$launch_agents_dir/$label.plist" "$launch_agents_dir/$legacy_label.plist"
rm -rf "$app_dir"
rm -f "/Applications/Firehawk Focus.app" "$HOME/.local/bin/firehawk-focus"
echo "Removed Firehawk Focus app and LaunchAgents."
