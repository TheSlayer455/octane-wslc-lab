ARG BASE_IMAGE=lscr.io/linuxserver/winegui@sha256:2a4b95b7a8bcb0306509b622c44344efb6c3bc6ce671c3adf6cfb569c12284ab
FROM ${BASE_IMAGE}
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg imagemagick jq mesa-utils procps xdotool x11-utils \
    && rm -rf /var/lib/apt/lists/*
COPY artifacts/Octane-setup.exe /opt/octane/Octane-setup.exe
COPY artifacts/installer-manifest.json /opt/octane/installer-manifest.json
COPY diagnostics/webview2-win32/artifacts/WebView2Diagnostic.exe /opt/octane/WebView2Diagnostic.exe
COPY diagnostics/webview2-win32/artifacts/diagnostic-manifest.json /opt/octane/diagnostic-manifest.json
COPY fixtures/ /opt/octane/fixtures/
COPY lab/octane-lab /usr/local/bin/octane-lab
COPY lab/octane-webview2-experiment /usr/local/bin/octane-webview2-experiment
RUN chmod 755 /usr/local/bin/octane-lab /usr/local/bin/octane-webview2-experiment
