#!/bin/bash

source ~/.zprofile
set -euo pipefail

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
    ('kTCCServiceAppleEvents', 0, 'com.carriez.rustdesk', 2, 0, 1, 0, 'com.apple.systemevents'),
    EOF
}

# Update TCC.db for all users
update_tcc_database "/Library/Application Support/com.apple.TCC/TCC.db"

# Update TCC.db for the current user
update_tcc_database "${HOME}/Library/Application Support/com.apple.TCC/TCC.db"
