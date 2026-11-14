ARG BASE_IMAGE=lscr.io/linuxserver/winegui@sha256:2a4b95b7a8bcb0306509b622c44344efb6c3bc6ce671c3adf6cfb569c12284ab
FROM ${BASE_IMAGE}
COPY artifacts/Octane-setup.exe /opt/octane/Octane-setup.exe
COPY artifacts/installer-manifest.json /opt/octane/installer-manifest.json
COPY fixtures/ /opt/octane/fixtures/
COPY lab/octane-lab /usr/local/bin/octane-lab
RUN chmod 755 /usr/local/bin/octane-lab
