#!/bin/bash
# Slightly custom version of https://github.com/rustdesk/rustdesk/wiki/macOS-Auto%E2%80%90Start-Service-Setup-(for-Remote---MDM-Deployment)
set -euo pipefail

APP_PATH="${RUSTDESK_APP_PATH:-/Applications/RustDesk.app}"
TARGET_USER="${RUSTDESK_TARGET_USER:-}"
SUDO_CMD="sudo"

if [[ -z "$TARGET_USER" ]]; then
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
  elif [[ -n "${USER:-}" && "$USER" != "root" ]]; then
    TARGET_USER="$USER"
  else
    TARGET_USER="$(scutil <<< "show State:/Users/ConsoleUser" 2>/dev/null | awk '/Name :/ && !/loginwindow/ { print $3 }')"
  fi
fi

if [[ -z "$TARGET_USER" ]]; then
  echo "Unable to determine a target user for the RustDesk service" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "RustDesk app not found at $APP_PATH" >&2
  exit 1
fi

APP_NAME="$(basename "$APP_PATH" .app)"
APP_NAME_LOWER="$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')"
FULL_NAME="com.carriez.${APP_NAME}"
BUNDLE_ID="$($SUDO_CMD /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
if [[ -z "$BUNDLE_ID" ]]; then
  BUNDLE_ID="com.carriez.${APP_NAME_LOWER}"
fi

AGENT_PATH="/Library/LaunchAgents/${FULL_NAME}_server.plist"
DAEMON_PATH="/Library/LaunchDaemons/${FULL_NAME}_service.plist"
ROOT_PREF_PATH="/var/root/Library/Preferences/${FULL_NAME}"
USER_HOME="$($SUDO_CMD dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null | sed 's/^NFSHomeDirectory:[[:space:]]*//')"
if [[ -z "$USER_HOME" ]]; then
  USER_HOME="$HOME"
fi
USER_PREF_PATH="${USER_HOME}/Library/Preferences/${FULL_NAME}"

$SUDO_CMD mkdir -p "$USER_PREF_PATH"
$SUDO_CMD chown "$TARGET_USER" "$USER_PREF_PATH"

for file in "${APP_NAME}.toml" "${APP_NAME}2.toml"; do
  if [[ ! -f "$USER_PREF_PATH/$file" ]]; then
    $SUDO_CMD touch "$USER_PREF_PATH/$file"
    $SUDO_CMD chown "$TARGET_USER" "$USER_PREF_PATH/$file"
  fi
done

$SUDO_CMD mkdir -p "$ROOT_PREF_PATH"
$SUDO_CMD cp -a "$USER_PREF_PATH"/* "$ROOT_PREF_PATH"/ 2>/dev/null || true

AGENT_PLIST="$($SUDO_CMD curl -fsSL 'https://raw.githubusercontent.com/rustdesk/rustdesk/master/src/platform/privileges_scripts/agent.plist' \
  | sed -e "s|com.carriez.rustdesk|${BUNDLE_ID}|g" \
        -e "s|rustdesk|${APP_NAME_LOWER}|g" \
        -e "s|RustDesk|${APP_NAME}|g" \
        -e "s|/Applications/RustDesk.app|${APP_PATH}|g")"

DAEMON_PLIST="$($SUDO_CMD curl -fsSL 'https://raw.githubusercontent.com/rustdesk/rustdesk/master/src/platform/privileges_scripts/daemon.plist' \
  | sed -e "s|com.carriez.rustdesk|${BUNDLE_ID}|g" \
        -e "s|rustdesk|${APP_NAME_LOWER}|g" \
        -e "s|RustDesk|${APP_NAME}|g" \
        -e "s|/Applications/RustDesk.app|${APP_PATH}|g")"

$SUDO_CMD tee "$AGENT_PATH" >/dev/null <<< "$AGENT_PLIST"
$SUDO_CMD tee "$DAEMON_PATH" >/dev/null <<< "$DAEMON_PLIST"
$SUDO_CMD chown root:wheel "$AGENT_PATH" "$DAEMON_PATH"
$SUDO_CMD chmod 0644 "$AGENT_PATH" "$DAEMON_PATH"

TARGET_UID="$($SUDO_CMD id -u "$TARGET_USER")"

$SUDO_CMD launchctl bootout "gui/${TARGET_UID}/${FULL_NAME}_server" >/dev/null 2>&1 || true
$SUDO_CMD launchctl bootout "system/${FULL_NAME}_service" >/dev/null 2>&1 || true
$SUDO_CMD launchctl unload -w "$DAEMON_PATH" >/dev/null 2>&1 || true
$SUDO_CMD launchctl disable "system/${FULL_NAME}_service" >/dev/null 2>&1 || true

$SUDO_CMD launchctl bootstrap system "$DAEMON_PATH" >/dev/null 2>&1 || true
$SUDO_CMD launchctl enable "system/${FULL_NAME}_service" >/dev/null 2>&1 || true

if $SUDO_CMD launchctl bootstrap "gui/${TARGET_UID}" "$AGENT_PATH" >/dev/null 2>&1; then
  $SUDO_CMD launchctl enable "gui/${TARGET_UID}/${FULL_NAME}_server" >/dev/null 2>&1 || true
else
  echo "RustDesk agent was installed but could not be bootstrapped into the GUI domain yet; it will load on user login." >&2
fi

cat <<EOF
RustDesk service setup complete.
- App path: $APP_PATH
- Bundle ID: $BUNDLE_ID
- Agent plist: $AGENT_PATH
- Daemon plist: $DAEMON_PATH
- Target user: $TARGET_USER
EOF
