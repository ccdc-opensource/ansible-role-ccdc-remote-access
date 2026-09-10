# Ansible Role: ccdc.remote_access

Configure remote desktop access for supported Linux and macOS hosts. The role selects the appropriate remote access method based on the target OS and version, then enables the service and reboots when required.

## Supported platforms

- Ubuntu 20.x and 22.x: installs and configures xrdp
- Ubuntu 24.x: installs and configures GNOME Remote Desktop
- AlmaLinux 8.x and 9.x: installs and configures xrdp
- AlmaLinux 10.x: installs and configures GNOME Remote Desktop
- macOS / Darwin: installs rustdesk with Homebrew and configures RustDesk permissions and service launch items

## Requirements

This role expects the following collections/modules to be available in the Ansible environment:

- ansible.posix for firewalld support
- community.general for Homebrew package installation

## Role variables

```yaml
rdp_user: ""
rdp_password: ""
```

These variables are used when enabling GNOME Remote Desktop on Ubuntu and AlmaLinux systems.

- `rdp_user`: username or account to be used for remote desktop access
- `rdp_password`: password associated with the remote desktop account

## What this role does

### Linux hosts

- Ubuntu 20/22 and AlmaLinux 8/9:
  - installs `xrdp`
  - disables GDM / autologin-related services where needed
  - adjusts X11 configuration for xrdp
  - enables the xrdp service
  - reboots the host

- Ubuntu 24 and AlmaLinux 10:
  - creates a GNOME Remote Desktop certificate and key under the `gnome-remote-desktop` user home
  - configures the TLS certificate/key for the RDP service
  - sets the remote desktop credentials using `grdctl`
  - enables GNOME Remote Desktop and the service
  - reboots the host

- AlmaLinux hosts also open TCP port 3389 in firewalld.

### macOS hosts

- installs RustDesk via Homebrew
- updates the macOS TCC database for the required RustDesk permissions
  Note: Direct SQLite writes to the protected TCC databases are rejected on a normally configured modern macOS host unless the invoking process already has Full Disk Access. In practice, the relevant privacy permissions must already be in place before this script can modify the TCC database successfully.
- creates a LaunchAgent / LaunchDaemon setup for the RustDesk service
- configures permissions and service files in `/tmp` before applying them

## Example playbook

```yaml
- hosts: all
  become: true
  vars:
    rdp_user: "remoteadmin"
    rdp_password: "StrongPassword123!"
  roles:
    - ccdc.remote_access
```

## Dependencies

None.

## License

MIT

## Author information

This role was created in 2024 by Samuel Jackson, based on existing roles at CCDC, by Jeff Geerling and google searches
