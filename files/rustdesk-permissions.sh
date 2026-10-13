#!/bin/bash

# Adapted from Cirrus Labs' macOS image templates:
# https://github.com/cirruslabs/macos-image-templates/blob/main/scripts/update-tcc-database.sh
#

USER_HOME="${HOME:-${RUSTDESK_HOME:-}}"
TARGET_USER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --home)
      USER_HOME="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--home /Users/username]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--home /Users/username]" >&2
      exit 1
      ;;
  esac
done

if [[ -n "${USER_HOME:-}" && -f "${USER_HOME}/.zprofile" ]]; then
  source "${USER_HOME}/.zprofile"
fi

set -euo pipefail

if [[ -z "${USER_HOME:-}" ]]; then
  echo "No home directory provided. Use --home /Users/username or set HOME/RUSTDESK_HOME." >&2
  exit 1
fi

if [[ "${USER_HOME}" == /Users/* ]]; then
  TARGET_USER="${USER_HOME##*/}"
fi

resolve_user_tcc_database() {
  local macos_version macos_major user_id open_files line candidate database=""

  macos_version="$(sw_vers -productVersion)"
  macos_major="${macos_version%%.*}"
  case "$macos_major" in
    ''|*[!0-9]*)
      echo "Unexpected macOS version: $macos_version" >&2
      return 1
      ;;
  esac

  if [[ "$macos_major" -lt 27 ]]; then
    database="${USER_HOME}/Library/Application Support/com.apple.TCC/TCC.db"
  else
    user_id="$(id -u "${TARGET_USER:-$(id -un)}" 2>/dev/null || id -u)"
    if ! open_files="$(sudo lsof -a -u "$user_id" -c tccd -Fn)"; then
      echo "Unable to inspect the user TCC daemon for UID $user_id" >&2
      return 1
    fi

    while IFS= read -r line; do
      case "$line" in
        n/private/var/containers/Data/ProtectedSystem/*/Data/Library/Application\ Support/com.apple.TCC/TCC.db)
          candidate="${line#n}"
          if [[ -n "$database" && "$database" != "$candidate" ]]; then
            echo "Found multiple active user TCC databases for UID $user_id" >&2
            return 1
          fi
          database="$candidate"
          ;;
      esac
    done <<< "$open_files"

    if [[ -z "$database" ]]; then
      echo "Unable to find the active user TCC database for UID $user_id; falling back to the legacy home path" >&2
      database="${USER_HOME}/Library/Application Support/com.apple.TCC/TCC.db"
    fi
  fi

  if ! sudo test -f "$database"; then
    echo "User TCC database does not exist: $database" >&2
    return 1
  fi

  if [[ "$macos_major" -ge 27 && "$(sudo stat -f %u "$database")" != "$user_id" ]]; then
    echo "Unexpected owner for user TCC database: $database" >&2
    return 1
  fi

  printf '%s\n' "$database"
}

update_tcc_database() {
  sudo sqlite3 "$1" <<-'EOF'
    INSERT OR REPLACE
    INTO access (
      service,
      client_type,
      client,
      auth_value,
      auth_reason,
      auth_version,
      indirect_object_identifier_type,
      indirect_object_identifier
    ) VALUES
    -- RustDesk (bundle identifier from Info.plist)
    ('kTCCServiceAccessibility', 0, 'com.carriez.rustdesk', 2, 0, 1, NULL, 'UNUSED'),
    ('kTCCServiceScreenCapture', 0, 'com.carriez.rustdesk', 2, 0, 1, NULL, 'UNUSED'),
    ('kTCCServicePostEvent', 0, 'com.carriez.rustdesk', 2, 0, 1, NULL, 'UNUSED'),
    ('kTCCServiceAppleEvents', 0, 'com.carriez.rustdesk', 2, 0, 1, 0, 'com.apple.systemevents');
EOF
}

USER_TCC_DATABASE="$(resolve_user_tcc_database)"

# Update TCC.db for all users
update_tcc_database "/Library/Application Support/com.apple.TCC/TCC.db"

# Update TCC.db for the target user
update_tcc_database "${USER_TCC_DATABASE}"
