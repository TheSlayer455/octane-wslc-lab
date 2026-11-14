#!/usr/bin/env bash
set -euo pipefail

secret=/run/secrets/rdp_password
test -s "$secret"
test -n "${RDP_TARGET:-}"

Xvfb :99 -screen 0 1280x800x24 -ac +extension RANDR >/tmp/xvfb.log 2>&1 &
for _ in $(seq 1 100); do
    [[ -S /tmp/.X11-unix/X99 ]] && break
    sleep 0.1
done
[[ -S /tmp/.X11-unix/X99 ]]

password=$(<"$secret")
rm -f "$secret"
export DISPLAY=:99
exec xfreerdp \
    "/v:$RDP_TARGET" \
    /u:wineuser \
    "/p:$password" \
    /cert:ignore \
    /size:1280x800 \
    /bpp:24 \
    /network:lan \
    +auto-reconnect \
    /auto-reconnect-max-retries:3
