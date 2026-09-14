<!--
SPDX-FileCopyrightText: 2018-2025 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## Scenarios

Currently there is one testing scenario available.

### `default`

Installs Jellyfin the way the role would, then checks the running instance. The main objects of the scenario are as below:

- The published server URL, timezone, additional environment variable, additional volume, extra container argument, device passthrough and container runtime the scenario configures all arrive at the container or the process
- The first-run wizard is completed, an administrator logs in, and the authenticated API answers in order to confirm the mounted data path is writable
- Jellyfin is asked to list the media path and the additional volume back through its own API, so a mount that docker accepted but the process cannot see does not pass

#### What this scenario does not cover

- **Hardware transcoding**: `jellyfin_gpu_path` / `jellyfin_gpu_bind_path` exist to hand a GPU (`/dev/dri`) to the container, and `jellyfin_container_runtime` / `jellyfin_nvidia_visible_devices` exist to do the NVIDIA equivalent. The GitHub CI runner happens to have neither a GPU nor the NVIDIA container toolkit. The scenario therefore exercises these settings only up to the boundary that GitHub can currently reach: it passes through a device that does exist (`/dev/null`) and selects the runtime that is always installed (`runc`), and asserts that both arrive in the container's definition.
- **Media playback**: No media is placed in the library and no library scan is run.
- **The first-run wizard as a security boundary**: The scenario completes the wizard itself. On a real deployment the wizard is open to anonymous callers from the moment the service starts until somebody completes it, which the scenario demonstrates against the unconfigured control container rather than papering over.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
