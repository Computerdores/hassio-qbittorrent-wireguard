# Home Assistant Add-on: qBittorrent-Wireguard

## How to use

A wireguard config is strictly required. Place it as `wg0.conf` in `/addon_configs/*-qbittorrent_wireguard/wireguard/`.

For security reasons the WebUI password is randomly generated at startup instead of having a default value. Using the WebUI from outside of ingress will therefore require using the ingress WebUI to set a password first.

## Base Image
All documentation is provided in the [wiki](https://github.com/tenseiken/docker-qbittorrent-wireguard/wiki).
