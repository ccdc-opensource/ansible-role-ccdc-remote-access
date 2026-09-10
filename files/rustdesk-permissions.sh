#!/bin/bash

USER_HOME="${HOME:-${RUSTDESK_HOME:-}}"

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

# Update TCC.db for all users
update_tcc_database "/Library/Application Support/com.apple.TCC/TCC.db"

# Update TCC.db for the current user
update_tcc_database "${USER_HOME}/Library/Application Support/com.apple.TCC/TCC.db"
