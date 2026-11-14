ARG BASE_IMAGE=lscr.io/linuxserver/winegui:latest
FROM ${BASE_IMAGE}
COPY artifacts/Octane-setup.exe /opt/octane/Octane-setup.exe
COPY artifacts/installer-manifest.json /opt/octane/installer-manifest.json
COPY fixtures/ /opt/octane/fixtures/
COPY lab/octane-lab /usr/local/bin/octane-lab
RUN chmod 755 /usr/local/bin/octane-lab
