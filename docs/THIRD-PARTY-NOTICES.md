# Third-party runtime notice

The source kit does not redistribute Wine, WebView2, noVNC, Websockify, x11vnc, or their binary dependencies. The browser image recipe obtains pinned source or distribution packages during an authorized build, and the private image-recovery archive is retained separately from Git.

The browser candidate uses these independently licensed projects:

- Wine and Wine-Staging, with the repository's pinned source revisions and visible-region patch.
- noVNC at commit `63107bd06d9e1f6136ff21aeda8cd62cbf0d433e`.
- Websockify at commit `e81894751365afc19fe64fc9d0e5c6fc52655c36`.
- x11vnc and the Ubuntu packages recorded by the browser-candidate lock.
- Microsoft Edge WebView2 Evergreen, provisioned through the retained installer/runtime process rather than bundled in this source kit.

Upstream license texts and package copyright records remain authoritative. Before redistributing a container image or recovery archive beyond its current private scope, review every included component's license and Microsoft redistribution terms. A checksum or private recovery copy is not a license grant.
