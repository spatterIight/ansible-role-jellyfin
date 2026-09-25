<!--
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020-2024 MDAD project contributors
SPDX-FileCopyrightText: 2020-2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Jellyfin

This is an [Ansible](https://www.ansible.com/) role which installs [Jellyfin](https://jellyfin.org/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Jellyfin is an open-source personal media server that allows you to organize and stream your collection of movies, TV shows, and music.

See the project's [documentation](https://jellyfin.org/docs/) to learn what Jellyfin does and why it might be useful to you.

## Adjusting the playbook configuration

To enable Jellyfin with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# jellyfin                                                             #
#                                                                      #
########################################################################

jellyfin_enabled: true

########################################################################
#                                                                      #
# /jellyfin                                                            #
#                                                                      #
########################################################################
```

### Set the hostname

To enable Jellyfin you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
jellyfin_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

### Mount data directories

To mount a data directory inside the container, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
jellyfin_media_bind_path: /media
```

This case, the directory specified with `jellyfin_media_path` on the host machine will be available at `/media` inside the container.

To mount additional data directories, add the following configuration to your `vars.yml` file (adapt to your needs):

```yaml
jellyfin_container_additional_volumes_custom:
  - type: bind
    src: /path/to/blackhole
    dst: /downloads
```

### Configuring DLNA & Local discovery

By default your Jellyfin instance cannot be connected to directly, and must be routed through Traefik (usually with HTTPS). This works fine for the web-app, phone, and TV apps. However, depending on your setup, you may want to connect directly to your server on the LAN with no HTTPS.

Keep in mind that doing so will send your Jellyfin password across the network in plain-text. This is not a recommended configuration. That said, here is how:

```yaml
# The main Jellyfin webserver port, setting this variable will expose that port and allow you to connect directly to it (without Traefik).
jellyfin_container_http_host_bind_port: 8096

# The Jellyfin DLNA server, used for clients to discover Jellyfin on the LAN
jellyfin_container_service_discover_bind_port: 1900

# Another service related to discovering Jellyfin on the LAN.
# From the docs:
# "Allows clients to discover Jellyfin on the local network. A broadcast message to this port with 'Who is JellyfinServer?' will get a JSON response that includes the server address, ID, and name."
jellyfin_container_client_discover_bind_port: 7359

# The server address the client discovery service should respond with
jellyfin_published_server_url: "http://{{ ansible_default_ipv4.address }}:{{ jellyfin_container_http_host_bind_port }}"
```

Upstream documentation: <https://jellyfin.org/docs/general/post-install/networking/>

After setting these variables you should be able to discover and connect to your Jellyfin server entirely on the LAN. If for some reason it is still not discoverable try inputting your `jellyfin_published_server_url` manually.

### Hardware Acceleration

To enable hardware acceleration you'll first need to determine your GPU brand. Once you've done this, read the corresponding section below:

#### Intel/ATI/AMD

For Intel/ATI/AMD GPUs enabling hardware acceleration is as easy as mounting the device into the container:

```yaml
# The path where the Intel/ATI/AMD GPU is on the host system
jellyfin_gpu_path: "/dev/dri"

# The path to mount the Intel/ATI/AMD GPU to in the container.
# Takes a path value (e.g. "/dev/dri"), or empty string to not mount.
jellyfin_gpu_bind_path: "{{ jellyfin_gpu_path }}"
```

Upstream documentation: <https://docs.linuxserver.io/images/docker-jellyfin/#intelatiamd>

#### NVIDIA

For NVIDIA GPUs enabling hardware acceleration is a little bit tricky since it (currently) requires the manual installation of the [NVIDIA container runtime](https://github.com/NVIDIA/nvidia-container-toolkit). Consult your distribution's documentation on installing this.

Once the runtime is installed and available, add the following configuration:

```yaml
# The container runtime that the container engine should use
jellyfin_container_runtime: "nvidia"

# To enable NVIDIA GPU hardware acceleration this value should either be 'all' or the UUID value of the GPU
# which can obtained with the command -> 'nvidia-smi --query-gpu=gpu_name,gpu_uuid --format=csv'
jellyfin_nvidia_visible_devices: "all"
```

Upstream documentation: <https://docs.linuxserver.io/images/docker-jellyfin/#nvidia>

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `jellyfin_environment_variables_additional_variables` variable

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Jellyfin becomes available at the specified hostname like `https://example.com`.

To get started, open the URL with a web browser to create an account.

![Jellyfin Configure User](./assets/setup-1.webp)

When prompted to add your media libraries keep in mind that it will be the path **inside** the container, most likely the `dst` parameter of your `jellyfin_container_additional_volumes_custom` variable.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu jellyfin` (or how you/your playbook named the service, e.g. `mash-jellyfin`).
