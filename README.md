# Jellyfin Ansible role

This is an [Ansible](https://www.ansible.com/) role which installs [Jellyfin](https://jellyfin.org/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)

Check [defaults/main.yml](defaults/main.yml) for the full list of supported options.

For an Ansible playbook which integrates this role and makes it easier to use, see the [mash-playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

# Limitations

Most LinuxServer docker images support non-root user operation and read-only capabilities. The Jellyfin image is not one of these. By default this role is configured to:

1. Run as root user
2. Run the container as read/write (NOT read-only)

Additionally, like all LinuxServer docker images, full `cap-drop` is not supported, and several capabilities related to permissions are added to the container: 
   - SETUID
   - SETGID
   - CHOWN
   - FOWNER
   - DAC_OVERRIDE
