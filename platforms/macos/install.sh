#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$root/../.." && pwd)"
app_dir="$HOME/Applications/Firehawk Focus.app"
contents="$app_dir/Contents"
launch_agents_dir="$HOME/Library/LaunchAgents"
label="com.lordfirehawk.firehawk-focus"
legacy_label="org.lordfirehawk.firehawk-focus"
plist_path="$launch_agents_dir/$label.plist"
enable_login=1
login_only=0

for arg in "$@"; do
  case "$arg" in
    --no-login) enable_login=0 ;;
    --login-only) login_only=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./platforms/macos/install.sh [--no-login] [--login-only]

  --login-only  Migrate/install the LaunchAgent and open the existing app
                without rebuilding (useful when Xcode license is pending).
EOF
      exit 0
      ;;
  esac
done

prefer_xcode_toolchain() {
  local xcode="/Applications/Xcode.app/Contents/Developer"
  if [[ -d "$xcode" ]]; then
    export DEVELOPER_DIR="$xcode"
    if ! xcodebuild -license check >/dev/null 2>&1; then
      cat >&2 <<'EOF'
Xcode is installed but the license is not accepted yet.

  sudo xcodebuild -license

Then re-run this installer. Until then you can keep the existing app running with:

  ./platforms/macos/install.sh --login-only
EOF
      return 1
    fi
    return 0
  fi
  return 0
}

install_login_agent() {
  mkdir -p "$HOME/.local/bin"
  cat << 'EOF' > "$HOME/.local/bin/firehawk-focus"
#!/usr/bin/env bash
open -a "$HOME/Applications/Firehawk Focus.app" "$@"
osascript -e 'tell application "Firehawk Focus" to activate' 2>/dev/null || true
EOF
  chmod +x "$HOME/.local/bin/firehawk-focus"

  # Migrate legacy org.* label → com.*
  launchctl bootout "gui/$UID/$legacy_label" 2>/dev/null || true
  rm -f "$launch_agents_dir/$legacy_label.plist"

  if [[ "$enable_login" -eq 1 ]]; then
    mkdir -p "$launch_agents_dir"
    cat << EOF > "$plist_path"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>-a</string>
        <string>$app_dir</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF
    launchctl bootout "gui/$UID/$label" 2>/dev/null || true
    launchctl bootstrap "gui/$UID" "$plist_path"
    echo "==> Startup at Login enabled: $plist_path"
  else
    echo "==> Left login LaunchAgent unchanged (--no-login)"
  fi
}

if [[ "$login_only" -eq 1 ]]; then
  if [[ ! -d "$app_dir" ]]; then
    echo "Missing $app_dir — run a full install once Xcode license is accepted." >&2
    exit 1
  fi
  install_login_agent
  open "$app_dir"
  echo "LaunchAgent refreshed for existing Firehawk Focus.app"
  exit 0
fi

if ! prefer_xcode_toolchain; then
  exit 1
fi

command -v swift >/dev/null || {
  echo "Swift compiler not found. Install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
}

echo "==> Building Firehawk Focus (Release)..."
if ! swift build --package-path "$root" -c release; then
  cat >&2 <<'EOF'
Swift build failed. If you only have Command Line Tools, install/agree to full Xcode,
or keep the current app with: ./platforms/macos/install.sh --login-only
EOF
  exit 1
fi

bin_dir="$(swift build --package-path "$root" -c release --show-bin-path)"

echo "==> Creating macOS App Bundle..."
pkill -x "FirehawkFocus" 2>/dev/null || true

rm -rf "$app_dir"
mkdir -p "$contents/MacOS" "$contents/Resources" "$HOME/Applications"

cp "$bin_dir/FirehawkFocus" "$contents/MacOS/FirehawkFocus"
cp "$root/Info.plist" "$contents/Info.plist"
cp "$repo_root/FocusModel.js" "$contents/Resources/FocusModel.js"

if [ -f "$root/Resources/AppIcon.icns" ]; then
  cp "$root/Resources/AppIcon.icns" "$contents/Resources/AppIcon.icns"
fi

if [ -d "$bin_dir/FirehawkFocus_FirehawkFocus.bundle" ]; then
  cp -R "$bin_dir/FirehawkFocus_FirehawkFocus.bundle" "$contents/Resources/"
fi

chmod +x "$contents/MacOS/FirehawkFocus"
codesign --force --deep --sign - "$app_dir"

ln -sfn "$app_dir" "/Applications/Firehawk Focus.app" 2>/dev/null || true
touch "$app_dir"

install_login_agent

echo "==> Installed Firehawk Focus to: $app_dir"
echo "==> CLI shortcut installed: ~/.local/bin/firehawk-focus"
echo "==> Launching Firehawk Focus..."
open "$app_dir"

echo "Firehawk Focus is now active in your macOS Menu Bar!"
