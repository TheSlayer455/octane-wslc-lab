"""Build the single comprehensive Octane reference. No network calls."""
from pathlib import Path
import json
import html

from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
    Preformatted, Image as RLImage,
)
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "docs" / "Octane-Complete-Guide.pdf"
DEST.parent.mkdir(exist_ok=True)
status_path = ROOT / "docs" / "validation.json"
status = json.loads(status_path.read_text(encoding="utf-8")) if status_path.exists() else {}

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="Body", fontName="Helvetica", fontSize=9.2, leading=12.4,
    spaceAfter=7, textColor=colors.HexColor("#253442"),
))
styles.add(ParagraphStyle(
    name="CodeBlock", fontName="Courier", fontSize=7.2, leading=9.2,
    spaceBefore=4, spaceAfter=8, backColor=colors.HexColor("#edf2f5"),
    borderPadding=8,
))
styles.add(ParagraphStyle(
    name="SmallNote", fontName="Helvetica", fontSize=7.5, leading=9.4,
    textColor=colors.HexColor("#566778"), spaceAfter=4,
))
styles.add(ParagraphStyle(
    name="CompactNote", fontName="Helvetica", fontSize=6.8, leading=8.2,
    textColor=colors.HexColor("#566778"), spaceAfter=2,
))
for name, size, leading in [
    ("Title", 29, 33), ("Heading1", 20, 24), ("Heading2", 11.5, 14.5)
]:
    styles[name].fontName = "Helvetica-Bold"
    styles[name].fontSize = size
    styles[name].leading = leading
    styles[name].textColor = colors.HexColor("#102f43")
styles["Heading2"].spaceBefore = 6

story = []


def p(text, style="Body"):
    story.append(Paragraph(text, styles[style]))


def h(text):
    story.append(Paragraph(text, styles["Heading2"]))


def code(text):
    story.append(Preformatted(text.strip("\n"), styles["CodeBlock"]))


def page(number, title):
    if story:
        story.append(PageBreak())
    story.append(Paragraph(f"OCTANE / REFERENCE {number:02d}", styles["SmallNote"]))
    story.append(Paragraph(title, styles["Heading1"]))
    story.append(Spacer(1, 8))


def table(headers, rows, widths, compact=False):
    cell_style = styles["CompactNote"] if compact else styles["SmallNote"]
    padding = 3 if compact else 5
    data = [
        [Paragraph(html.escape(str(cell)), cell_style) for cell in row]
        for row in [headers] + rows
    ]
    result = Table(data, colWidths=widths, hAlign="LEFT", repeatRows=1)
    result.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dceaf1")),
        ("GRID", (0, 0), (-1, -1), 0.45, colors.HexColor("#d9d9d9")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), padding),
        ("BOTTOMPADDING", (0, 0), (-1, -1), padding),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [
            colors.white, colors.HexColor("#f4f7f9")
        ]),
    ]))
    story.append(result)
    story.append(Spacer(1, 7))


def link(label, url):
    p(
        f'<link href="{html.escape(url, quote=True)}" color="#14658c">'
        f"{html.escape(label)}</link>",
        "SmallNote",
    )


def image_grid(items):
    cells = []
    for image_path, caption in items:
        picture = RLImage(str(ROOT / image_path))
        aspect_ratio = picture.imageHeight / picture.imageWidth
        picture.drawWidth = 238
        picture.drawHeight = 238 * aspect_ratio
        cells.append([picture, Paragraph(html.escape(caption), styles["SmallNote"])])
    data = [cells[index:index + 2] for index in range(0, len(cells), 2)]
    grid = Table(data, colWidths=[246, 246], hAlign="LEFT")
    grid.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 2),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    story.append(grid)


page(1, "Octane<br/>Windows installer compatibility lab")
p(
    "<b>Complete implementation, operation, and measured-validation reference</b><br/>"
    "Guide revision 12 | November 15, 2026 | Windows x64 + packaged WSL/Docker + Wine 11.21 + qualified browser delivery"
)
p(
    "Octane is a repository-independent, container-runtime-independent lab for a real "
    "Windows Tauri installer. Its reference workload analyzes small files, calculates "
    "SHA-256, groups extensions and duplicates, opens native file dialogs, and exports "
    "JSON. The experiment always installs and launches the Windows artifact through Wine; "
    "it never substitutes a Linux build or browser-only application."
)
link(
    "Public source repository: TheSlayer455/octane-wslc-lab",
    "https://github.com/TheSlayer455/octane-wslc-lab",
)
p(
    "Specification provenance: private ChatGPT conversation <b>Run Windows App Containers</b>, ID "
    "6af79ffb-6048-83ea-b689-8269484af53d. The conversation is historical context; the checked-in handoff, "
    "schemas, locks, and evidence are the self-contained operational authority."
)
h("What is delivered")
p(
    "The public source repository contains the Rust/Tauri reference app, fixtures, Windows NSIS "
    "build workflow, explicit WSLC and Docker adapters, WineGUI and Docker-Wine controls, "
    "a qualified noVNC/TigerVNC browser profile, an importable WSL/Docker appliance, generic target profiles, a runtime doctor, normalized run-state "
    "and evidence tooling, a source-independent runtime kit, regression checks, and this guide. "
    "The measured installer and matching manifest remain retained in the historical v0.1.1 release."
)
h("Headline result")
p(html.escape(status.get("summary", "Validation data unavailable.")))
h("How to read this guide")
p(
    "Pages 3-9 explain architecture, engine choice, diagnosis, artifact intake, and startup. "
    "Pages 10-17 specify the workload, code, evidence, security, and acceptance protocol. "
    "Pages 18-25 preserve the failure diagnosis and historical WineGUI, Docker-Wine, controlled "
    "ole32, native SER8, and early Wine 11.21 results. Pages 26-28 record dialog localization, "
    "normal repainting, the locked runner, and the final historical ten-run qualification. Pages 29-30 "
    "record historical verification, inventory, sources, and continuing work. Pages 31-44 preserve the pre-qualification "
    "browser/appliance candidate record, daily workflow, security/file/network boundaries, runtime kit, operator handoff, "
    "packaging, replacement, and ingestion design. Pages 45-48 supersede that candidate snapshot with the locked browser "
    "10/10 result, final runtime-kit contract, daily workflow, and exact release boundaries. Commands run in "
    "<b>PowerShell 7 from the repository root</b> unless a desktop terminal is named."
)


page(2, "Contents, claims, and boundaries")
topics = [
    "Purpose and measured status", "Contents, claims, and boundaries",
    "Layered architecture and lifecycle", "Runtime adapters and Wine profiles",
    "Runtime doctor and prerequisites", "WSLC timeout diagnosis and repair",
    "Artifact production and portable intake", "WSLC + WineGUI operation",
    "Docker + WineGUI / Docker-Wine operation", "Scenario and operator workflow",
    "File-analysis behavior", "JSON report contract", "Application implementation",
    "Controller and container implementation", "Evidence, status, and cleanup",
    "Security and reproducibility", "Executable acceptance protocol",
    "Runtime and desktop troubleshooting", "Wine and WebView2 troubleshooting",
    "Measured environment and comparison", "Controlled Wine ole32 experiment",
    "WineGUI visual evidence", "Docker-Wine RDP visual evidence",
    "Native SER8 Ansible result", "Wine 11.21 control and candidate result",
    "Native-dialog and normal-repaint diagnosis", "Locked unattended qualification",
    "Final 10/10 schema-v3 qualification", "Verification and repository inventory",
    "References and roadmap", "Browser candidate status and exact identity",
    "Daily unchanged-installer browser workflow", "Viewer, file, network, and security boundaries",
    "Source-independent runtime kit and recovery", "Browser evidence and blocked qualification",
    "Manual browser smoke and qualification resume path",
    "Packaged WSL appliance architecture", "One-command appliance workflow",
    "Appliance build, recovery, and live test", "Appliance verdict and maintenance boundary",
    "Implemented fresh-build session model", "One-active-build replacement and comparison",
    "WSL-backed file ingestion and upload", "Storage placement and measured boundaries",
    "Final browser qualification", "Qualified appliance and runtime kit",
    "Daily clean-build workflow", "Release verdict and maintenance contract",
]
contents_rows = []
for offset in range(24):
    contents_rows.append([
        str(offset + 1), topics[offset],
        str(offset + 25), topics[offset + 24],
    ])
table(["Page", "Topic", "Page", "Topic"], contents_rows, [27, 214, 27, 224], compact=True)
p(
    "<b>Delivered scope:</b> explicit WSLC and Docker adapters; Windows-host Docker through "
    "a named WSL distribution; a qualified browser/noVNC path with generic unchanged-installer intake; "
    "historical WineGUI/Selkies, Docker-Wine/RDP, and native-SER8 controls; fresh-prefix installation; "
    "machine-readable stages; evidence copy-out and exact cleanup."
)
p(
    "<b>Outside scope:</b> Podman, Kubernetes, arbitrary malware, production multi-user "
    "hosting, automatic Windows code signing, and native Windows VM provisioning. RDP here "
    "connects to an XFCE Linux desktop that displays Wine applications; it is not a Windows VM."
)
p(
    "A Windows build pass proves compilation and packaging. A Wine installer pass proves "
    "installation only. Visible WebView rendering, workload correctness, native dialogs, "
    "export correctness, and cleanup are independent gates. This document uses PASS, FAIL, "
    "BLOCKED, and NOT_RUN so a runtime or rendering failure cannot masquerade as an "
    "application compatibility result."
)


page(3, "Layered architecture and lifecycle")
code(r"""
Pipeline/manual download -> unchanged setup.exe + data-only profile
                              |
             streamed hash + immutable local artifact identity
                              |
                   PowerShell lab controller
                              |
 Windows 11 -> named Ubuntu WSL2 -> Docker Engine (explicit)
                              |
 fresh container/prefix/install/settings/WebView2 user data/output
                              |
 pinned Wine 11.21 candidate -> winex11 -> TigerVNC Xvnc/XFCE :1
                              |
    loopback x11vnc <- Websockify/noVNC <- Windows browser
                              |
      run/results/JUnit/logs/browser+native evidence/checksums

Historical WSLC/WineGUI and Docker-Wine/RDP paths remain controls only.
""")
table(["Layer", "Owns", "Must not require"], [
    ["Artifact production", "Compile/package Windows installer and manifest.", "A later container engine or desktop profile."],
    ["Runtime adapter", "Probe, build, run, inspect, exec, copy, stop, and remove.", "GitHub, app-specific logic, or silent engine fallback."],
    ["Wine profile", "Base image, display protocol, user, ports, state and evidence paths.", "CI-provider variables or proprietary source."],
    ["Application scenario", "Install, launch, exercise fixtures/dialogs, validate/export.", "WSLC/Docker command spelling."],
], [90, 202, 200], compact=True)
h("Lifecycle")
p(
    "The browser controller writes run and input identity before creating resources, streams and atomically "
    "hashes the unchanged installer, executes the doctor, reuses the pinned infrastructure image, creates a "
    "fresh labeled container/prefix, copies only selected data, installs and launches one discovered executable, "
    "records native/WebView2 identity, and prints the exact localhost viewer path. Collection precedes removal "
    "of only the exact container, anonymous volumes, and per-run credential."
)
p(
    "Every launch gets a ten-character run ID, container and image name, fresh writable "
    "prefix, endpoint credential, and metadata record. Restarting an existing container "
    "continues its prefix and is not fresh-install evidence."
)


page(4, "Runtime adapters and Wine profiles")
h("One normalized adapter contract")
p(
    "Runtime.ps1 converts every native invocation into startedAtUtc, durationMs, exitCode, "
    "timedOut, stdout, stderr, engine, and context. The shared lifecycle uses the same "
    "operations for both engines: probe, build, create/start, exec, inspect/logs, copy-out, "
    "stop, and remove. Each stage has a timeout; native failures include bounded diagnostic "
    "output rather than an unbounded transcript."
)
table(["Adapter", "Invocation and identity", "Important behavior"], [
    ["Wslc", "wslc.exe on Windows; context wslc:windows", "Requires the Windows host tool and WSLC utility session."],
    ["Docker on Windows", "wsl.exe -d DISTRO --exec docker; context docker:wsl:DISTRO", "Requires -WslDistro; never guesses a daemon or uses another distribution."],
    ["Docker on Linux", "local docker CLI; context docker:local", "Same scripts can run on a Linux controller with PowerShell 7."],
    ["SER8 via Ansible", "strict inventory alias ser8; svc.ansible; jakeubuntu", "Playbooks pin target identity, approved bind address, run labels, artifacts, evidence, and cleanup."],
], [92, 180, 220], compact=True)
p(
    "An acceptance run never silently changes engines. A Docker pass remains a Docker pass; "
    "a WSLC failure remains a WSLC failure. The operator explicitly starts a different run "
    "when comparing engines. The SER8 path is a native-Linux Docker measurement, not Docker "
    "inside WSL, and its Ansible orchestration is recorded separately from the shared runtime adapter."
)
h("Environment profiles")
table(["Profile", "Desktop / user", "State and evidence"], [
    ["DockerWineStaging1121VisRgnBrowser", "noVNC/Websockify -> TigerVNC Xvnc/XFCE / wineuser", "fresh .octane prefix; browser-qualified 10/10 for retained Octane"],
    ["WineGui", "Selkies HTTPS :3001 / octane", "/config; /config/octane-evidence"],
    ["DockerWine", "xrdp RDP :3389 / wineuser", "/home/wineuser/.octane; .octane/evidence"],
    ["DockerWineStaging1121Control", "same RDP desktop / wineuser", "pinned source control; fresh .octane prefix"],
    ["DockerWineStaging1121VisRgn", "same RDP desktop / wineuser", "exact control plus one verified win32u patch"],
], [92, 184, 216], compact=True)
p(
    "The final browser profile layers pinned noVNC/Websockify and TigerVNC Xvnc over the exact historically "
    "qualified Wine image; it does not substitute an upstream WineGUI runtime. WineGUI and Docker-Wine remain "
    "historical controls. All paths consume unchanged installers and keep transport, runtime, target profile, "
    "scenario, and evidence claims separate."
)
code("""WineGUI digest:
sha256:2a4b95b7a8bcb0306509b622c44344efb6c3bc6ce671c3adf6cfb569c12284ab
Docker-Wine index digest:
sha256:c61cfc490aaee10b96782b88733a0f3d0e7b425d93b4e96617d9ab9a2b6bcfd2
Wine / Staging commits: 2528aff26208 / 04414fee61f7
Candidate patch SHA-256: f0ea7e56c4b86ce6e1f99940c4c18ac80f2bee86442c800bc58c2f36bde92752""")


page(5, "Runtime doctor and prerequisites")
table(["Check", "Why it exists"], [
    ["PowerShell 7", "The adapters use modern process and JSON behavior."],
    ["Runtime server", "A version command alone does not prove containers can run."],
    ["Context / distro", "Prevents accidentally testing a different daemon or remote connection."],
    ["Linux amd64", "Both desktop profiles and the Windows x64 Wine path require the expected platform."],
    ["Rootless/storage/memory", "Separates ownership or resource faults from Wine faults."],
    ["Host loopback port", "Detects conflicts before an expensive image build."],
    ["Deep run/copy/cleanup", "Runs alpine:3.22, copies a known file out, and removes its labeled probe."],
], [140, 352], compact=True)
code("""# Windows PowerShell 7
./scripts/Doctor-OctaneLab.ps1 -Engine Wslc -Port 3001 -Deep

./scripts/Doctor-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 -Port 3002 -Deep""")
h("Measured Docker doctor")
p(html.escape(status.get("dockerDoctor", "Docker doctor not recorded.")))
h("Native SER8 preflight")
p(
    "The strict inventory reached svc.ansible@jakeubuntu, confirmed native Ubuntu 24.04.4 "
    "x86_64 and Docker 29.6.0, found about 25.1 GB free storage and 20.1 GB available memory, "
    "verified the selected RDP port was free, and counted 66 unrelated running containers."
)
h("Measured WSLC doctor")
p(html.escape(status.get("wslcRuntime", "WSLC doctor not recorded.")))
h("Prerequisites")
p(
    "The runtime route needs Windows x64, WSL, PowerShell 7, the selected engine, network "
    "access to the pinned image when not cached, several GiB of storage, and a free loopback "
    "port. A local Windows build additionally needs Rust stable MSVC, Visual Studio C++ Build "
    "Tools with a Windows SDK, Node 22, pnpm 11.25.0, and Git. Downloading the retained artifact "
    "pair avoids local compiler prerequisites."
)
p(
    "The Docker doctor reports rootless status but does not escalate automatically. The "
    "measured daemon was rootful. No adapter adds --privileged or switches a daemon from "
    "rootless to rootful to make a desktop image start."
)


page(6, "WSLC timeout diagnosis and repair")
h("Why wslc was 'not found'")
p(
    "wslc.exe and wsl.exe are Windows executables. Running wslc at an Ubuntu prompt correctly "
    "returns command not found; installing Ubuntu's unrelated wsl package is not the fix. Run "
    "the following from Windows PowerShell or Command Prompt."
)
code("""wsl --version
wslc version
wslc run --rm hello-world
wslc container ls -a""")
h("Observed failure")
p(
    "On this WSLC 3.0.1 host, control-plane commands worked but container starts returned "
    "ERROR_TIMEOUT. ProtonVPN had installed a full-tunnel on-link 0.0.0.0 route. WSLC's default "
    "Consomme utility-session networking selected an unusable gateway, so dockerd never became "
    "ready. Moving the utility-session VHD did not change the failure, ruling out the VHD as "
    "the cause."
)
h("Validated repair")
code(r"""# Save as %LOCALAPPDATA%\wslc\settings.yaml
session:
  networkingMode: nat
  idleTimeout: 900

# Then terminate only the WSLC system session and retest.
wslc system session terminate
wslc run --rm hello-world""")
p(
    "The NAT setting restored hello-world in 3.8 seconds and supported fresh WineGUI runs. "
    "It is a targeted workaround for this route conflict, not a universal requirement. Retest "
    "after VPN, WSL, or WSLC updates. To roll back, remove or change the session networking "
    "setting and terminate only the WSLC system session again. Do not remove distributions, "
    "reset WSL globally, or prune unrelated containers as a first response."
)
p(
    "A timestamped copy of the previous utility-session storage VHD was retained under the "
    "WSLC sessions directory. It was not used by the repaired session and was not deleted."
)


page(7, "Artifact production and portable intake")
h("Portable contract")
p(
    "The reusable browser workflow consumes a local EXE, a small application profile, selected inputs, and a "
    "separate output directory—not a GitHub release URL or target source. Stage-OctaneArtifact streams and hashes "
    "the EXE, detects source changes, rehashes the staged bytes, atomically admits a content-addressed identity, and "
    "records length/build label/provenance/signature metadata. The legacy reference pair under artifacts remains a "
    "measured input, not a requirement that another pipeline adopt Octane-specific output."
)
code("""./scripts/Stage-OctaneArtifact.ps1 `
  -Installer 'C:\\Builds\\setup.exe' -OutputDirectory ./runs/artifacts `
  -BuildLabel 'pipeline-12345'

# Local Windows build; does not install Octane on the host.
./scripts/Build-Octane.ps1""")
h("GitHub release and artifact delivery")
p(
    "The v0.1.1 prerelease retains the measured EXE, manifest, and its historical guide; "
    "this revision does not replace that release. The last separately verified "
    "application-build run 43560204604 verified implementation commit 6199155 with locked Rust/core and Node "
    "checks, the 37-assertion PowerShell harness, Tauri's NSIS build, and artifact upload. Its "
    "new installer hash is 7a4ee192...e22c22 and is not substituted for the Wine-tested artifact. "
    "Workflow artifacts expire; release assets remain until explicitly removed. Artifact "
    "production and runtime acceptance remain separate concerns."
)
link(
    "v0.1.1 release",
    "https://github.com/TheSlayer455/octane-wslc-lab/releases/tag/v0.1.1",
)
link(
    "Final implementation CI (PASS)",
    "https://github.com/TheSlayer455/octane-wslc-lab/actions/runs/43560204604",
)
h("Measured artifact identity")
code("""Installer source commit:
7088eed9adb8403b9575afe1cc9e9c2984b29049
Installer SHA-256:
adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a
Size: 219,839,154 bytes   Signed: false   WebView mode: offlineInstaller""")
h("Diagnostic artifact intake")
p(
    "The separate webview2-diagnostic workflow builds Release|x64 and uploads "
    "WebView2Diagnostic.exe plus diagnostic-manifest.json. Before a diagnostic or SER8 run, "
    "download that workflow artifact into diagnostics/webview2-win32/artifacts and "
    "verify its manifest hash. The current measured diagnostic came from commit "
    "0228527976b0ee7b0a8847f453fae37173f46df0 with SDK 1.0.3856.49; its SHA-256 was "
    "82cd1cab4930ffeb940a27898fabdb30322decd84f681ef3d15264c51e86f5b5. Generated binaries "
    "remain Git-ignored and do not make the source repository self-executing without artifact intake."
)
p(
    "The manifest is an integrity companion, not a signature: an actor able to replace both "
    "files can create a matching pair. GitHub is the implemented producer wrapper; the local "
    "artifact-directory contract is provider-neutral. No GitLab pipeline is claimed in this "
    "revision."
)


page(8, "Historical control: WSLC + WineGUI")
code("""# Preflight and start a fresh browser desktop.
./scripts/Doctor-OctaneLab.ps1 -Engine Wslc -Port 3001 -Deep
./scripts/Start-OctaneLab.ps1 -Engine Wslc -WineProfile WineGui -Port 3001""")
p(
    "The launcher prints a container name such as octane-0123456789, the local HTTPS address, "
    "username octane, a cryptographic one-time password, and runs/NAME.json. Open only the "
    "printed localhost endpoint, verify that it is your local service, handle the self-signed "
    "certificate deliberately, and authenticate. The password is not written to run JSON."
)
h("What the launcher creates")
p(
    "It builds lab/Dockerfile from the pinned WineGUI digest, copying the installer, manifest, "
    "fixtures, and octane-lab helper into a run-specific image. The container is labeled with "
    "managed=true, engine=wslc, and profile=WineGui; receives 1 GiB shared memory; publishes "
    "only 127.0.0.1:PORT:3001; and receives no host bind mount or privileged flag."
)
h("Wine/display state")
p(
    "The profile uses /config, WINEPREFIX=/config/octane-prefix, and evidence under "
    "/config/octane-evidence. The helper accepts an inherited live DISPLAY, otherwise chooses "
    "X0 or the first live X socket. This corrects the measured WineGUI mismatch where an exec "
    "session advertised :1 while the visible Xwayland desktop was :0."
)
code("""# In the authenticated desktop terminal, one at a time:
octane-lab notepad
octane-lab install
octane-lab launch""")
p(
    "A launcher failure preserves any created run-scoped resources for diagnosis. Inspect the "
    "named record and container; do not assume an interrupted build cleaned itself up."
)


page(9, "Historical controls: Docker/RDP and native SER8")
h("Docker + WineGUI")
code("""./scripts/Doctor-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 -Port 3002 -Deep
./scripts/Start-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 -WineProfile WineGui -Port 3002""")
p(
    "On Windows the adapter runs docker inside exactly Ubuntu-24.04, converts repository paths "
    "with that distribution's wslpath, records docker:wsl:Ubuntu-24.04, and validates the "
    "Windows-side HTTPS endpoint. A healthy Selkies endpoint returns HTTP 401 before login; "
    "the endpoint gate correctly treats any 2xx-4xx response as reachable."
)
h("Docker + Docker-Wine RDP and pinned source profiles")
code("""# Baseline
./scripts/Start-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 -WineProfile DockerWine -Port 3390
# Wine 11.21 + matching Staging control
./scripts/Start-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 -WineProfile DockerWineStaging1121Control -Port 3392
# Exact control plus visible-region candidate patch
./scripts/Start-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 -WineProfile DockerWineStaging1121VisRgn -Port 3393""")
p(
    "Connect a trusted RDP client to localhost:3390 using the printed wineuser credential. "
    "The profile passes a one-way Unix password hash to the upstream entrypoint and preserves "
    "that entrypoint's RDP mode. The password remains inspectable by a runtime administrator "
    "through container environment metadata, so do not publish raw inspect output."
)
p(
    "The measured client was FreeRDP 3 through WSLg. The RDP session created Xorg display :10; "
    "octane-lab detected that live socket. The visible desktop is Linux XFCE and Wine draws "
    "Windows programs within it. This is useful for comparing display stacks, not proof of a "
    "Windows VM."
)
h("Native SER8 through Ansible")
p(
    "Run these playbooks from the existing Village ansible directory with its strict "
    "ANSIBLE_CONFIG and inventory alias ser8. They require svc.ansible@jakeubuntu, accept only "
    "the reviewed SER8 addresses, label every disposable resource with a ten-character run ID, "
    "and verify the exact target path before cleanup. Values named *_b64 carry secrets across "
    "the controller boundary without placing clear text in command arguments."
)
table(["Playbook", "Required extra variables"], [
    ["ser8-docker-wine-preflight.yml", "bind address and high RDP port (defaults exist)"],
    ["ser8-docker-wine.yml", "run ID, source root, MD5-crypt hash as base64, bind address, port"],
    ["ser8-rdp-probe-start.yml", "run ID, source root, raw password as base64, approved host:port"],
    ["ser8-docker-wine-collect.yml", "run ID and new local fetch destination"],
    ["ser8-docker-wine-stop.yml", "run ID only"],
], [182, 310], compact=True)
p(
    "The caller generates one random password, derives Docker-Wine's required $1$ MD5-crypt "
    "server value with LF-only input, and passes the raw value only to the stopped probe's "
    "one-use 0600 file. Page 24 records the measured run and cleanup proof."
)
h("Profile-specific export paths")
code(r"""WineGUI:    Z:\config\octane-evidence\report.json
Docker-Wine: Z:\home\wineuser\.octane\evidence\report.json""")


page(10, "Scenario and operator workflow")
h("Run the stages in order")
table(["Stage", "Required observation"], [
    ["notepad", "Fresh prefix initializes; Notepad visibly renders, accepts typing, repaints, and closes."],
    ["install", "NSIS pages render; current-user installation completes; WebView2 installation is observed."],
    ["launch", "Installed Octane displays its actual UI and remains responsive. A process or frame is insufficient."],
    ["load sample", "8 files, 6 extension groups, 1 duplicate set, 0 errors."],
    ["choose files", "Native multi-select dialog works; cancel preserves the previous report."],
    ["export", "New JSON file parses and matches UI counts/hashes; existing destination is not replaced."],
], [88, 404], compact=True)
p(
    "The helper sets a profile-specific fresh WINEPREFIX and WINEARCH=win64, writes Wine/kernel "
    "identity, copies the installer manifest, and tees timestamped logs plus a separate "
    ".exitcode file. PIPESTATUS captures Wine's result rather than tee's. Exit code zero is "
    "still not a visual acceptance result."
)
h("Run and review the installed-application scenario")
code("""./scripts/Invoke-OctaneApplicationExperiment.ps1 `
  -Container octane-0123456789 -Engine Docker -WslDistro Ubuntu-24.04 `
  -ExperimentId octane-clean-01

./scripts/Review-OctaneApplicationExperiment.ps1 `
  -Container octane-0123456789 -ExperimentId octane-clean-01 `
  -Status PASS -Detail 'Native client screenshots reviewed.'""")
p(
    "The first command runs the installed octane.exe, requires non-blank client pixels, invokes "
    "the real Rust workload, captures native dialogs, validates JSON independently, and preserves "
    "every failed gate. The reviewer status is only the native-window visual decision; workload, "
    "dialog, and export outcomes remain independent. For one-off manual observations, use "
    "Record-OctaneResult.ps1. BlockRemaining is allowed only with FAIL."
)
h("Reference workload")
p(
    "hello.txt and hello-copy.txt are the expected duplicate pair. Groups are txt, csv, json, "
    "md, html, and (none). Select additional files beneath Z:\\opt\\octane\\fixtures when testing "
    "native dialogs. No host upload, recursive directory selection, or proprietary source is "
    "needed."
)


page(11, "File-analysis behavior")
table(["Rule", "Implemented behavior"], [
    ["Selection", "Native multi-file selection; maximum 2,048 submitted paths; new analysis replaces previous report."],
    ["Canonical paths", "Canonicalize and skip repeated canonical paths. Symlinks resolve; distinct hard-link names can remain."],
    ["Reading", "Regular files only; 64 KiB chunks; lowercase SHA-256; no parsing, decompression, execution, or upload."],
    ["Limits", "256 MiB per file and 2 GiB total successful content per batch."],
    ["Extension", "Lowercase final filename extension; no extension becomes (none); not MIME detection."],
    ["Duplicates", "Two or more successful paths with the same SHA-256 form a set; no deletion decision."],
    ["Failures", "Missing, unreadable, non-regular, oversized, or detected-changing files become errors; others continue."],
    ["Mutation check", "Compare length and modified time before/after hashing; not an atomic filesystem snapshot."],
    ["Export", "Backend-held latest report is written with create-new semantics; inputs are never opened for writing."],
], [100, 392], compact=True)
h("Interpretation limits")
p(
    "Zero-byte files are valid and share the empty-content SHA-256. The app groups by hash "
    "without a second byte comparison, so theoretical collisions remain. Mutation that "
    "preserves both length and modification time can evade the stability check. Hard-link "
    "aliases can appear as separate records. Path serialization is lossy only when a path "
    "cannot be represented as UTF-8."
)
p(
    "Errors do not count toward totalBytes or extension counts. The limits constrain successful "
    "content, not every failed I/O attempt. Octane is a deterministic compatibility workload, "
    "not a forensic acquisition tool or hostile-filesystem sandbox."
)


page(12, "JSON report contract")
p(
    "Reports use schemaVersion 1. Rust serializes the backend-owned report, so DOM text is "
    "never the source of exported truth. The example is illustrative; real canonical paths "
    "and hashes vary."
)
code(r"""{
  "schemaVersion": 1,
  "files": [{
    "path": "C:\\sample\\hello.txt",
    "size": 13,
    "modifiedUnixMs": 1794600000000,
    "extension": "txt",
    "sha256": "..."
  }],
  "extensionCounts": {"txt": 1},
  "duplicateSets": [],
  "errors": [],
  "totalBytes": 13
}""")
table(["Field", "Meaning"], [
    ["schemaVersion", "Parser compatibility marker; currently 1."],
    ["files", "Successful canonical path, size, modified time, extension group, SHA-256."],
    ["extensionCounts", "Count of successful records per filename-extension group."],
    ["duplicateSets", "Lists of paths sharing one SHA-256; only sets of at least two."],
    ["errors", "Submitted path and readable failure text for an unsuccessful item."],
    ["totalBytes", "Sum of successful file sizes only."],
], [124, 368], compact=True)
p(
    "The report intentionally omits timestamp, machine ID, provider job ID, and source build "
    "identity. Correlate it with run.json, environment.json, and installer-manifest.json. "
    "Paths can disclose names; review evidence before sharing. A late write/sync error may "
    "leave a partial newly created file, but an existing destination is never overwritten."
)


page(13, "Application implementation")
h("Rust core")
p(
    "crates/octane-core owns FileRecord, FileError, Report, limits, analyze, streaming hashing, "
    "and export_new. BTreeMap/BTreeSet provide stable grouping and canonical-path deduplication. "
    "sha2 calculates hashes; serde/serde_json serialize. create_new, write_all, and sync_all "
    "implement no-overwrite export."
)
h("Tauri host and native commands")
p(
    "src-tauri/src/main.rs exposes choose_files, load_sample, and export_report. The native "
    "picker returns null on cancel; load_sample finds packaged fixtures; export_report prompts "
    "for a new path and writes the backend report. A Mutex stores the latest completed report. "
    "Dialog, hash, and write work uses spawn_blocking so the event loop is not asked to perform "
    "blocking I/O."
)
h("Frontend")
p(
    "ui/index.html, style.css, app.js, and format.mjs render status, summary, files, duplicate "
    "sets, and errors. Controls disable while a command is pending and recover after success, "
    "cancel, or failure. Filenames are inserted with textContent, not HTML. Static assets are "
    "bundled; there is no development server or remote script origin in the packaged app."
)
h("Windows/WebView configuration")
p(
    "tauri.conf.json defines com.octanelab.octane, a current-user NSIS installer, packaged "
    "fixtures, offline WebView2 installation, and a local CSP. dragDropEnabled=false avoids "
    "Tauri's internal drop target after the baseline Wine crash in IDropTarget_Release. The "
    "final measured build passes --disable-gpu while preserving WRY's default disabled WebView "
    "features. It does not use --no-sandbox."
)
p(
    "Frontend plugins do not expose a shell, network API, or generic filesystem. The three "
    "narrow Rust commands own all native behavior. Closing the app discards the transient "
    "report unless export succeeded."
)


page(14, "Controller and container implementation")
table(["Path", "Responsibility"], [
    ["Runtime.ps1", "Engine command selection, process timeouts, path conversion, label assertions, endpoint waits, image identity."],
    ["RuntimeProfiles.ps1", "Pinned WineGUI/Docker-Wine image, Dockerfile, port, user, state and evidence paths."],
    ["RunState.ps1", "Atomic schema-2 metadata, stage updates/blocking, JSON/JUnit generation, checksum and bundle synchronization."],
    ["Doctor-OctaneLab.ps1", "Shallow server/context/port checks and optional real run-copy-cleanup probe."],
    ["Start-OctaneLab.ps1", "Artifact hash, doctor, build, labeled run, endpoint gate, credential output."],
    ["Record-OctaneResult.ps1", "Public PASS/FAIL/BLOCKED/NOT_RUN recorder for visible acceptance."],
    ["Invoke/Review experiment scripts", "Native WebView2 probe and installed-Octane black-box run, visual review, independent fixture/report validation."],
    ["Collect-Evidence.ps1", "Logs/copy-out, environment, results, JUnit, optional screenshots/recording, checksums."],
    ["Stop-OctaneLab.ps1", "Exact labeled removal, anonymous volumes, optional run image, final evidence synchronization."],
    ["lab/octane-lab", "Display discovery, fresh prefix, logged Notepad/install/launch stages."],
    ["lab/ser8-*.yml", "Strict Ansible preflight, native-Docker build/start, black-box RDP probe, collection, and exact cleanup on the SER8."],
], [145, 347], compact=True)
h("Failure-safe state")
p(
    "Run metadata is written before resource creation and atomically replaced on updates. "
    "resources.imageCreated and containerCreated reveal interrupted starts. An exception marks "
    "the active stage FAIL, blocks untouched later stages, preserves created resources, and "
    "prints the metadata path. Cleanup accepts only octane- plus ten lowercase hex characters "
    "and requires com.octanelab.managed=true plus the matching engine label."
)
p(
    "The image contains the installer and fixtures; no host bind mount is needed. Docker-Wine "
    "keeps the upstream /usr/bin/entrypoint so documented RDP initialization still occurs. "
    "Both Dockerfiles have the measured base digest as their default, while -BaseImage permits "
    "a deliberate alternate experiment that run metadata records."
)


page(15, "Evidence, status, and cleanup")
code("""evidence/octane-<run>-<utc>/
  run.json                 final identity, resources, and stages
  environment.json         engine/context/profile/base reference
  installer-manifest.json  artifact identity copied from the container
  results.json             complete normalized status map
  junit.xml                provider-neutral test report
  checksums.sha256         hashes for every retained file
  logs/                    container and Wine stage logs
  screenshots/             optional visible desktop evidence
  recording.mp4            optional actual-display capture
  report.json              present only after a successful app export
  experiments/<id>/        native WebView2 probe evidence
  applications/<id>/       installed-Octane scenario and visual review""")
table(["Status", "Meaning"], [
    ["PASS", "The stated gate was directly observed and its evidence exists."],
    ["FAIL", "The gate ran and did not meet its pass condition."],
    ["BLOCKED", "An earlier failed prerequisite prevented a meaningful attempt."],
    ["NOT_RUN", "No attempt was made and no prerequisite conclusion is implied."],
], [82, 410], compact=True)
code("""./scripts/Collect-Evidence.ps1 -Container octane-0123456789 -ScreenshotDirectory C:\\evidence\\screens

./scripts/Stop-OctaneLab.ps1 -Container octane-0123456789 -RemoveImage""")
p(
    "Collect before removal because copy-out needs the live container. Stop then writes cleanup "
    "PASS, marks resources absent and state REMOVED, rewrites run.json/results.json/JUnit in "
    "every collected bundle for that container, and recalculates checksums. It does not prune "
    "base images, remove unrelated containers, or delete host evidence."
)
p(
    "The collector intentionally avoids raw inspect because environment metadata contains the "
    "desktop credential. It copies whatever stage logs exist and never manufactures a missing "
    "report or screenshot. Optional screenshots are copied from an operator-selected directory; "
    "recording is optional. Review file paths and logs for sensitive data before sharing."
)


page(16, "Security and reproducibility")
h("Conservative defaults")
p(
    "The shared Windows controller binds desktop ports only to 127.0.0.1. Every run gets a "
    "random password. There is no broad host mount, container-engine socket, host networking, "
    "GPU device, privileged mode, or automatic security-profile bypass. Only the generated, "
    "labeled resource name can be removed. Failed environments stay available until explicitly "
    "collected and removed."
)
h("Measured SER8 exception")
p(
    "The native SER8 run temporarily published RDP on the explicitly approved LAN address "
    "192.168.1.159 because the Windows controller could not reach the SER8 RDP service over its "
    "Tailscale address. The Ansible playbook validates that address and the chosen high port. "
    "The server received only Docker-Wine's required MD5-crypt password hash; the black-box probe "
    "received the raw random secret through a mode-0600, one-use file that was removed before it "
    "started. Exact labeled cleanup freed port 3391 and left all 66 pre-existing containers running."
)
h("Trust boundaries")
p(
    "Runtime administrators can inspect container environment and control every container; "
    "the generated desktop password is not a defense from them. LinuxServer desktop images "
    "include powerful in-container tools and follow their upstream privilege model. A Wine "
    "container is not equivalent to an independently hardened Windows VM. Use controlled "
    "installers and fixtures, not malware or production secrets."
)
p(
    "Outbound access is not enforced as blocked. 'Offline WebView2 installer' means the "
    "installer package is bundled; it does not claim a network-isolated run. RDP and HTTPS use "
    "local certificates. Verify the loopback destination before accepting a certificate; never "
    "reuse the test credential elsewhere."
)
h("Identity and repeatability")
p(
    "Cargo.lock and pnpm-lock.yaml pin dependency resolution. Both desktop images are digest "
    "pinned. Each result records installer hash, engine/context, profile, base image, Wine "
    "version, WebView version when captured, display details, and stage timestamps. Windows "
    "runner images, Rust stable, Actions major tags, and downloaded package content can still "
    "change; full byte-for-byte reproducibility is not claimed."
)
p(
    "Wine is outside Microsoft's WebView2 supported-Windows matrix. A Wine pass is evidence "
    "for one environment; a Wine failure does not establish a defect on supported Windows. "
    "Native Windows remains the release authority. The installer is unsigned and no automatic "
    "updater or project-source license grant is supplied."
)


page(17, "Executable acceptance protocol")
table(["Gate", "Pass evidence"], [
    ["A. Artifact", "Installer SHA-256 matches manifest; exact variant identified."],
    ["B. Runtime", "Doctor server/context/platform/port and deep run-copy-cleanup pass."],
    ["C. Desktop", "Fresh container endpoint works from Windows; authenticated desktop receives input."],
    ["D. Basic Wine", "Notepad renders, accepts typed text, visibly repaints, and closes."],
    ["E. Installer", "NSIS and WebView2 installation complete; prompts, version, and exit captured."],
    ["F. Application", "Actual Octane DOM is visible and responsive after installer handoff and standalone launch."],
    ["G. Workload", "Sample reports 8 files, 6 groups, 1 duplicate set, 0 errors."],
    ["H. Native dialogs", "Choose/save render; cancel preserves state; space/Unicode paths exercised."],
    ["I. Export", "New JSON parses and matches counts/hashes; existing file remains unchanged."],
    ["J. Evidence/reset", "Portable bundle validates; exact cleanup passes; a new run starts with no app installed."],
], [106, 386], compact=True)
h("Evidence rules")
p(
    "Record the status and a specific detail for every gate. Attach visible screenshots at "
    "desktop, Notepad, installer, and application stages; retain the parsed JSON at export. "
    "A running process, automation endpoint, exit code zero, or webview-generated bitmap does "
    "not substitute for visible desktop repainting. A failure at F makes G-I BLOCKED, not FAIL."
)
h("Comparisons")
p(
    "Compare the same installer hash across engines and profiles. An Evergreen-versus-Fixed "
    "WebView2 experiment creates different installer variants and must be labeled as such. "
    "Installation time, time to endpoint, time to usable window, workload time, and cleanup "
    "duration are useful comparisons, but speed never overrides a failed gate."
)


page(18, "Runtime and desktop troubleshooting")
h("Doctor fails before image build")
p(
    "Confirm PowerShell 7, the exact engine, selected WSL distribution, Docker context, Linux "
    "amd64 server, free port, storage, memory, and rootless state. On Windows, a Docker command "
    "inside one distribution does not prove another named distribution can access that daemon. "
    "Fix the reported layer; do not switch engines invisibly."
)
h("WSLC ERROR_TIMEOUT")
p(
    "Run the page-6 hello-world checks from Windows. If the full-tunnel route pattern matches, "
    "apply session NAT and terminate only the WSLC system session. Preserve a failing run's "
    "metadata. Do not install the Ubuntu wsl package or delete distributions."
)
h("Desktop endpoint fails")
p(
    "Check the recorded port, run-specific container status, and container logs. WineGUI should "
    "return an HTTPS response even when authentication yields 401. Docker-Wine should accept a "
    "TCP connection on the published RDP port. Confirm 127.0.0.1 publication from Windows, not "
    "merely a listener inside WSL. Try a different explicit port if occupied."
)
h("Notepad is invisible or fails")
p(
    "Inspect the profile user, WINEPREFIX ownership, DISPLAY, X socket, and notepad log. "
    "WineGUI normally exposes X0; an RDP session may expose X10 or another display. octane-lab "
    "selects a live socket, but it cannot create a desktop session. Run the helper as the "
    "profile's normal user after the desktop is connected."
)
h("Collection or cleanup fails")
p(
    "Retain the container. Verify the printed name, engine context, managed label, and profile "
    "evidence path; repeat collection. Cleanup deliberately rejects unrelated names and labels. "
    "Never use global prune as a substitute. If Stop succeeded but local synchronization failed, "
    "the authoritative runs/NAME.json still records resource state and can regenerate result files."
)


page(19, "Wine and WebView2 troubleshooting")
h("Separate installation from rendering")
p(
    "Evergreen offlineInstaller removes the WebView2 download dependency during setup but does "
    "not freeze browser behavior or promise Wine compatibility. Confirm the actual installed "
    "Application/VERSION directory and msedgewebview2.exe. Then test installer handoff and a "
    "clean standalone launch separately."
)
h("Measured signatures are now distinct")
p(
    "The retained installer disables Tauri drag/drop and passes --disable-gpu. Baseline Wine 11.0 "
    "still launched the WebView browser, renderer, utilities and restarting GPU processes while "
    "the native client stayed blank/black. The enhanced Win32 probe separately proved environment "
    "creation, local navigation, DOM messages, input events and timers; reviewed client pixels "
    "remained solid white with pixel delta zero. A live DOM or process is not visible acceptance."
)
p(
    "Early pinned Wine 11.21 runs appeared to require three resize/minimize/restore cycles: the "
    "control passed once and stayed black once, while the visible-region candidate rendered the "
    "workload 3/3 but completed dialog/export only 1/3. Later state-based observation showed the "
    "same candidate normally presented after about 19 seconds without the helper, and the final "
    "contract passed 10/10. The minimal probe still remained white. Host-specific presentation and "
    "dialog automation must therefore remain independently measured."
)
h("Research conclusions and resolved hypotheses")
p(
    "Wine bug 60225 remains a close historical crash lead, not an established cause of the current "
    "result. The Wine 11.0 MR !12477 pair and current 11.21 runs did not reproduce the old "
    "IDropTarget_Release crash. WebView2Feedback 5720 correctly motivated independent DOM/pixel "
    "measurement, but its macOS and Linux reports are not universal claims. The Solid Edge patch "
    "is a measured application-specific candidate, not a general WebView2 repair."
)
p(
    "The standalone app-matching IFileOpenDialog/IFileSaveDialog probe passed 7/7 in clean and "
    "post-install prefixes with exact Unicode paths. The failed 9/10 run was localized to an "
    "instantaneous foreground sample, then corrected with a passive bounded wait. The exact candidate "
    "qualified without no-sandbox, privileged mode, broad mounts, opaque DLLs, old runtimes, or an "
    "external repaint helper."
)


page(20, "Measured environment and comparison")
p(status.get("evidenceSummary", "Measured evidence unavailable."))
table(["Run/profile", "Desktop + install", "Visible application / workload", "Dialogs + export / repeatability"], [
    ["Historical WSLC/WineGUI", "PASS", "FAIL blank/black; later BLOCKED", "BLOCKED; historical observation"],
    ["40f739755a baseline Wine 11", "PASS", "Probe white; Octane black", "BLOCKED; one fresh baseline"],
    ["17e5fdec70 Staging control", "PASS", "PASS after 3-cycle nudge; 8/6/1/176/0", "PASS; first clean control"],
    ["615d1bca1e Staging control", "PASS", "FAIL black after same nudge", "BLOCKED; control now 1/2"],
    ["d2cc660dbe visrgn candidate", "PASS", "PASS after 3 cycles; workload PASS", "PASS; candidate full run 1"],
    ["c5c34187fa visrgn candidate", "PASS", "GUI/workload PASS after 3 cycles", "FAIL later sequence; full run 2 failed"],
    ["aef06bc9fa visrgn candidate", "PASS", "GUI/workload PASS after 3 cycles", "FAIL picker/no-overwrite; full run 3 failed"],
    ["948d78d02c normal observer", "PASS", "PASS at 17.615 s; no repaint helper", "Diagnostic only; later gates NOT_RUN"],
    ["qbatch-e2aaafff4b38", "PASS 10/10", "PASS 10/10; 19.000-19.084 s", "PASS 10/10; final schema-v3 lock"],
], [112, 104, 152, 124], compact=True)
h("Exact measured identity")
table(["Item", "Value"], [
    ["Installer", status.get("installerSha256", "")],
    ["Source commit", status.get("sourceCommit", "")],
    ["Installed executable", status.get("installedExecutableSha256", "")],
    ["Diagnostic", status.get("diagnosticSha256", "")],
    ["WSLC", status.get("wslcVersion", "")],
    ["Docker", f'{status.get("dockerVersion", "")}; {status.get("dockerOperatingSystem", "")}; {status.get("dockerArchitecture", "")}'],
    ["Docker execution", f'rootless={status.get("dockerRootless", "")}; {status.get("dockerStorageDriver", "")}; {status.get("dockerMemoryGiB", "")} GiB'],
    ["SER8", f'{status.get("ser8Hostname", "")}; Docker {status.get("ser8DockerVersion", "")}; {status.get("ser8OperatingSystem", "")}; run {status.get("ser8RunId", "")}'],
    ["Wine source / Staging", f'{status.get("wineSourceCommit", "")[:12]} / {status.get("wineStagingCommit", "")[:12]}'],
    ["WebView2", f'Evergreen {status.get("webview2Version", "")}'],
    ["Visible-region patch", status.get("visibleRegionPatchSha256", "")],
    ["Application report", status.get("reportSha256", "")],
    ["Final harness / lock", f'{status.get("qualificationHarnessCommit", "")[:12]} / {status.get("qualificationLockSha256", "")[:16]}...'],
], [126, 366], compact=True)
p(
    "The candidate's native probe remained white (rAF 0, timer callbacks 114, pixel delta 0) "
    "while the installed Tauri host later presented normally. The historical candidate series was "
    "GUI/workload 3/3 but complete acceptance 1/3; it is not rewritten. The final locked schema-v3 "
    "series passed the full contract 10/10 without a repaint helper, hidden retry, or manual override."
)


page(21, "Controlled Wine ole32 experiment")
p(
    "WineHQ bug 60225 and upstream MR !12477 closely matched the earlier Tauri/WebView2 "
    "IDropTarget_Release signature. The lab therefore built a source Wine 11.0 control and a "
    "candidate differing only by MR !12477's ole32 change. Both used the same WineGUI digest, "
    "installer, WebView2 runtime, diagnostic executable, desktop, and fresh-prefix procedure."
)
table(["Gate or observation", "Wine 11 control", "MR !12477 candidate"], [
    ["Basic Wine", "PASS: Notepad repaint/input", "PASS: Notepad repaint/input"],
    ["NSIS + WebView2 install", "PASS", "PASS"],
    ["Minimal diagnostic", "FAIL: DOM/ticks active; pixels blank", "FAIL: DOM/ticks active; pixels blank"],
    ["Process failure", "GPU kind 6 reason 3; 0x80000003", "GPU kind 6 reason 3; 0x80000003"],
    ["Octane", "FAIL: no usable visible UI", "FAIL: no usable visible UI"],
    ["OLE close sequence", "2 RegisterDragDrop; host RevokeDragDrop; exit 0", "2 RegisterDragDrop; host RevokeDragDrop; exit 0"],
    ["IDropTarget_Release crash", "Not reproduced", "Not reproduced"],
], [142, 175, 175], compact=True)
image_grid([
    (
        "docs/evidence/control-diagnostic-initial.png",
        "Control: diagnostic events showed navigation and repaint activity while visible content stayed blank.",
    ),
    (
        "docs/evidence/patched-diagnostic.png",
        "MR !12477: the same blank visible result and process-failure signature.",
    ),
])
p(
    "Conclusion: the candidate did not restore rendering. The lack of a crash in this pair does "
    "not rewrite the earlier observation; it means the current controlled blocker is visible "
    "WebView2 rendering, and this ole32 change made no measured improvement."
)


page(22, "WineGUI visual evidence")
p(
    "These screenshots are visible desktop observations, not inferred process states. The "
    "WSLC and Docker runs used the same pinned WineGUI profile and unchanged installer."
)
image_grid([
    (
        "docs/evidence/wine-notepad.png",
        "WSLC/WineGUI fresh prefix: Wine 11 Notepad rendered and accepted text.",
    ),
    (
        "docs/evidence/docker-winegui-notepad.png",
        "Docker/WineGUI: visible text proves input and repaint through Selkies.",
    ),
    (
        "docs/evidence/docker-winegui-install.png",
        "Docker/WineGUI: NSIS reached visible installation completion.",
    ),
    (
        "docs/evidence/docker-winegui-webview.png",
        "Docker/WineGUI standalone Octane: host frame visible, WebView content blank; FAIL.",
    ),
])
p(
    "WineGUI desktop, Notepad, and installer are therefore PASS. The blank app frame is a "
    "direct application failure. A clean close or process exit zero cannot change that result."
)


page(23, "Docker-Wine RDP visual evidence")
p(
    "The measured alternative resolved scottyhardy/docker-wine:latest to the digest now pinned "
    "by the profile, and used xrdp/xorgxrdp, XFCE, Wine 11, and FreeRDP 3 over the "
    "loopback-only published port."
)
image_grid([
    (
        "docs/evidence/docker-wine-rdp-notepad.jpg",
        "RDP Notepad visibly repainted the typed acceptance string; basic Wine PASS.",
    ),
    (
        "docs/evidence/docker-wine-rdp-install.jpg",
        "RDP NSIS wizard reported installation complete; installer PASS.",
    ),
    (
        "docs/evidence/docker-wine-rdp-webview.jpg",
        "Historical Docker-Wine baseline: Octane host alive but the WebView client stayed black; application FAIL.",
    ),
])
p(
    "Process sampling retained alongside the screenshots shows the renderer and multiple GPU "
    "process generations before all WebView2 children disappeared. The unchanged app host "
    "remained alive. This profile comparison confirms that changing from browser streaming to "
    "RDP did not make the WebView usable."
)


page(24, "Native SER8 Ansible result")
p(
    "The SER8 run answered the key portability question outside WSL. The strict existing inventory "
    "connected as svc.ansible to jakeubuntu (Ubuntu 24.04.4, kernel 6.8.0-142-generic), validated "
    "the hostname and Docker server, built the pinned Docker-Wine profile, and drove its XRDP/XFCE "
    "desktop through a separate FreeRDP probe container. Docker 29.6.0 reported 16 CPUs and "
    "27.16 GiB; the final server image was sha256:bd5a698cb85a59fa75b43a2704b0f95fc5f1bed9f490dea402466eb2f2743e13."
)
code("""ansible-playbook -i inventory.yml lab/ser8-docker-wine-preflight.yml
ansible-playbook -i inventory.yml lab/ser8-docker-wine.yml
ansible-playbook -i inventory.yml lab/ser8-rdp-probe-start.yml
ansible-playbook -i inventory.yml lab/ser8-docker-wine-collect.yml
ansible-playbook -i inventory.yml lab/ser8-docker-wine-stop.yml""")
table(["SER8 gate", "Measured result"], [
    ["Preflight / runtime / desktop", "PASS: strict host identity, native Docker, XRDP/Xorg :10, XFCE 1280x800"],
    ["Basic Wine", "PASS: visible Notepad repaint and typed acceptance string"],
    ["Installer", "PASS: NSIS and offline Evergreen WebView2 157.0.4341.60"],
    ["Minimal diagnostic", "FAIL: local navigation and DOM/repaint ticks; pixels blank; child failures"],
    ["Octane application", "FAIL: white after installer handoff; black on traced standalone launch"],
    ["Workload / dialogs / export", "BLOCKED: no usable visible application"],
    ["Evidence / cleanup", "PASS: checksum-verified bundle; port 3391 free; 66 prior containers preserved"],
], [150, 342], compact=True)
image_grid([
    ("docs/evidence/ser8-notepad-input.png", "Native SER8 RDP: Notepad visible repaint and input PASS."),
    ("docs/evidence/ser8-installer-complete.png", "NSIS completion after bundled WebView2 installation PASS."),
    ("docs/evidence/ser8-webview2-diagnostic.png", "Diagnostic: events progressed, but window pixels remained blank; FAIL."),
    ("docs/evidence/ser8-octane-ole.png", "Octane traced launch: no usable WebView content; application FAIL."),
])
p(
    "Three setup defects were corrected before the measured run: artifact mode 0600 blocked "
    "wineuser, Docker-Wine required MD5-crypt rather than SHA-512, and CRLF added a hidden byte "
    "to an early hash. Those aborted attempts were cleaned and are not compatibility results."
)


page(25, "Historical Wine 11.21 discovery runs")
p(
    "The current experiment kept the retained installer and Evergreen WebView2 157.0.4341.60 "
    "fixed while changing only the pinned Wine environment. The source control is Wine "
    "2528aff... plus the complete matching Staging 04414f... patch set. The candidate adds one "
    "canonical win32u cross-process visible-region patch, SHA-256 f0ea7e56..., from the reviewed "
    "Solid Edge repository. No Solid Edge D2D/SVG changes, fixed runtime, no-sandbox flag, Proton, "
    "Steam, or opaque DLL were imported."
)
table(["Profile / run", "Visible client", "Real workload", "Dialogs / export"], [
    ["Control 17e5fdec70", "PASS after 3-cycle repaint nudge", "PASS 8/6/1/176/0 plus Unicode path", "PASS including cancel/no-overwrite"],
    ["Control 615d1bca1e", "FAIL solid black after 3 cycles", "BLOCKED for acceptance", "BLOCKED"],
    ["Candidate d2cc660dbe", "PASS after 3 cycles (15.432 s)", "PASS 8/6/1/176/0", "PASS including cancel/no-overwrite"],
    ["Candidate c5c34187fa", "PASS after 3 cycles (15.437 s)", "PASS 8/6/1/176/0", "FAIL later sequence; first JSON valid"],
    ["Candidate aef06bc9fa", "PASS after 3 cycles (15.432 s)", "PASS 8/6/1/176/0", "FAIL visible picker/no-overwrite repeat"],
    ["Candidate native probe", "FAIL solid-white client; pixel delta 0", "DOM/input/timers only", "Not applicable"],
], [124, 126, 116, 126], compact=True)
p(
    "Evidence bundle checksum-manifest SHA-256: d2cc660dbe 7301d3b9...c868f6bf; "
    "c5c34187fa f5577280...27fb215; aef06bc9fa 379a035a...a3ca73b. "
    "The full values are in docs/validation.json and each bundle's checksums.sha256.",
    "CompactNote",
)
image_grid([
    (
        "docs/evidence/wine1121-candidate-workload.png",
        "Fresh candidate run 1: real installed Octane visibly reports 8 files, 6 groups, 1 duplicate set and 176 bytes.",
    ),
    (
        "docs/evidence/wine1121-control-black.png",
        "Fresh control run 2: the client remained solid black after the same three bounded repaint cycles; application FAIL.",
    ),
])
p(
    "At this historical checkpoint every visible result required the same intrusive three-cycle "
    "window-state helper. The candidate was GUI/workload 3/3 but complete acceptance 1/3; the "
    "control was 1/2. Pages 26-28 preserve how the helper and dialog failures were localized and "
    "how the later locked result superseded this checkpoint without rewriting it."
)


page(26, "Native-dialog and normal-repaint diagnosis")
p(
    "The retained installer was inspected at source commit 7088eed9adb8403b9575afe1cc9e9c2984b29049. "
    "It locks rfd 0.15.4 and invokes synchronous pick_files and save_file calls from Tauri "
    "spawn_blocking threads. Reviewed rfd commit bac4bd3364f2befaabafa9f58ac77fd8925b2abf uses "
    "IFileOpenDialog/IFileSaveDialog, STA COM with COINIT_DISABLE_OLE1DDE, and no owner HWND when "
    "the application supplies no parent. The native probe reproduces that shape independently of Tauri and WebView2."
)
code("""./scripts/Build-FileDialogProbe.ps1 -WslDistro Ubuntu-24.04
./scripts/Invoke-FileDialogDiagnosticRun.ps1 -WslDistro Ubuntu-24.04 `
  -Phase CleanPrefix -Suite AppMatch -Port 3394
./scripts/Invoke-FileDialogDiagnosticRun.ps1 -WslDistro Ubuntu-24.04 `
  -Phase PostInstall -Suite AppMatch -Port 3394""")
table(["Diagnostic", "Result", "What it establishes"], [
    ["Clean prefix 46953cece8", "PASS 7/7", "Exact Unicode/space select and multi-select; cancel/reopen; save/new/decline"],
    ["Post-install 888f4aca2d", "PASS 7/7", "Same result after retained NSIS and Evergreen WebView2 installation"],
    ["Application path", "PASS 10/10 later", "Octane itself completed open/save/cancel/reopen in final locked runs"],
], [130, 92, 270], compact=True)
image_grid([
    ("docs/evidence/dialog-probe-modern-open.png", "Standalone modern open dialog, synchronized by visible foreground state."),
    ("docs/evidence/dialog-probe-overwrite-confirmation.png", "Modern save overwrite confirmation; decline preserved the existing file hash."),
])
p(
    "The 9/10 batch failure was therefore classified as an automation synchronization defect: "
    "the recording showed the dialog while one instantaneous foreground sample missed it. A bounded passive "
    "foreground wait fixed the oracle without activating, retrying, or replacing a failed dialog."
)
h("Repaint finding")
p(
    "Observer 948d78d02c presented normally after 17.615 seconds with one ordinary activation and no "
    "resize, minimize, restore, click, reconnect, or retry before readiness. All final runs repeated normal "
    "presentation at 19.000-19.084 seconds. The historical three-cycle helper was confounded with startup "
    "latency and was not a causal prerequisite in this exact profile."
)


page(27, "Locked unattended qualification")
p(
    "Qualification is provider-neutral. The controller declares one batch ID, lock hash, ten planned run IDs, "
    "timeouts, and the contract before run one. Each measured run creates a new container, Wine prefix, and "
    "WebView2/application user-data state; installs the retained NSIS artifact; launches the installed executable "
    "once; collects evidence; and removes only its exact labeled resources."
)
code("""./scripts/New-OctaneQualificationLock.ps1 -WslDistro Ubuntu-24.04
./scripts/Invoke-OctaneQualificationBatch.ps1 `
  -LockPath profiles/qualification/docker-wine-staging-11.21-visrgn.lock.json `
  -WslDistro Ubuntu-24.04 -Port 3394""")
table(["Locked item", "Exact measured value"], [
    ["Installer / source", "adde062d79c2857c...d829080a / 7088eed9adb8403b9575afe1cc9e9c2984b29049"],
    ["Harness / lock", "7181a47ee47ae1d63b3bcd4fa6a480d45b560ee3 / 0137c535f4eb0d15...74f6e6377c1"],
    ["Image", "sha256:0443029e26be1d0590fd37491d69ab8fc1e186ef7e80d4d75cb191628188259c"],
    ["Wine", "11.21 + matching Staging 11.21 + visible-region patch f0ea7e56..."],
    ["WebView/display", "Evergreen 157.0.4341.60; winex11; XFCE/Xorgxrdp; 1280x800; llvmpipe"],
    ["Host/runtime", "Windows 10.0.26200.8875; WSL 3.0.1.0; Ubuntu 24.04.4; Docker 29.6.2 inside WSL"],
], [128, 364], compact=True)
h("Qualifying automation policy")
table(["Permitted before readiness", "Forbidden in every measured run"], [
    ["Launch installed Octane once; one normal activation", "Repaint helper; resize/minimize/restore; click; reconnect; restart-until-visible"],
    ["Bounded state-based waits", "Hidden launch/dialog retries; manual input; manual PASS; replacement run"],
], [210, 282], compact=True)
h("Failures were preserved")
table(["Batch", "Outcome", "Finding"], [
    ["qbatch-1546c3560728", "5/10, not qualified", "Port reuse sampled before release; runs 6-10 NOT_RUN"],
    ["qbatch-88b053c067cd", "9/10, not qualified", "Single foreground sample raced a visibly presented picker"],
    ["qbatch-d0d73d52a2b5", "10/10 schema v2", "Superseded when audit found X11 key synthesis dropped literal Omega"],
    ["qbatch-e2aaafff4b38", "10/10 schema v3", "Clipboard round-trip plus exact Unicode and missing-path report assertions"],
], [132, 112, 248], compact=True)
p(
    "The final policy rejects lock drift, missing evidence, hidden retry, manual override, and any count below "
    "10/10. Review-OctaneApplicationExperiment remains historical visual-review tooling and cannot promote qualification."
)


page(28, "Final 10/10 schema-v3 qualification")
p(
    "Batch qbatch-e2aaafff4b38 executed ten sequential fresh runs under lock "
    "0137c535f4eb0d15c12628801020b71f1952a18c65c524b7ac26874f6e6377c1. Every row below passed "
    "ten independent gates, report validation, evidence collection, and exact cleanup."
)
table(["Run", "Initial visible", "Scenario", "Evidence", "Cleanup", "Duration"], [
    ["01", "19.022 s", "10/10 PASS", "PASS", "PASS", "148.098 s"],
    ["02", "19.030 s", "10/10 PASS", "PASS", "PASS", "146.869 s"],
    ["03", "19.059 s", "10/10 PASS", "PASS", "PASS", "145.402 s"],
    ["04", "19.023 s", "10/10 PASS", "PASS", "PASS", "146.656 s"],
    ["05", "19.000 s", "10/10 PASS", "PASS", "PASS", "145.684 s"],
    ["06", "19.004 s", "10/10 PASS", "PASS", "PASS", "145.375 s"],
    ["07", "19.084 s", "10/10 PASS", "PASS", "PASS", "146.319 s"],
    ["08", "19.060 s", "10/10 PASS", "PASS", "PASS", "145.807 s"],
    ["09", "19.069 s", "10/10 PASS", "PASS", "PASS", "146.117 s"],
    ["10", "19.044 s", "10/10 PASS", "PASS", "PASS", "145.725 s"],
], [40, 78, 92, 70, 70, 82], compact=True)
image_grid([
    ("docs/evidence/qualification-workload.png", "Run 10: real Rust workload reports 8 files, 6 groups, 1 duplicate set, 176 bytes, and 0 errors."),
    ("docs/evidence/qualification-post-restore.png", "Run 10: client remained correctly presented after dialogs, scrolling, resize, minimize, and restore."),
])
p(
    "Every run also proved the exact Unicode/space one-file result, a deliberate missing-input error, open and save "
    "cancellation, repeated open use, new export, existing-output protection, unchanged inputs, and independently "
    "validated JSON. forcedRepaintUsed=false, hiddenRetries=0, and manualOverrides=0 in all ten rows."
)
p(
    "Batch-summary SHA-256: ee890ddcf0b4f420cff10a2d5be33ef8c7d6695b1bcb34f10b872df9fd9fff2b. "
    "The 1,853-entry checksum manifest verifies; its SHA-256 is "
    "e148ad2bb58998b62a54c2a0b131e49eaaaf86e11328b2580b8e576b751415e0.",
    "CompactNote",
)
p(
    "<b>Technical feasibility: demonstrated.</b><br/><b>Full Octane acceptance: qualified against the declared "
    "10/10 unattended fresh-prefix contract for the exact recorded installer and configuration.</b> The custom "
    "visible-region patch remains a maintenance condition. This is not a stock-Wine, arbitrary-Tauri, or proprietary-app claim."
)


page(29, "Verification and repository inventory")
table(["Verification", "Observed result"], [
    ["Public source repository", "TheSlayer455/octane-wslc-lab; public main and v0.1.1 prerelease as of 2026-11-15."],
    ["Windows artifact", status.get("windowsBuild", "")],
    ["Node checks", "19 PASS: application, diagnostic, dialog-probe, and qualification contracts."],
    ["Rust core", "4 historical PASS in measured installer build: fixtures/hash, path errors, export/no-overwrite, limits."],
    ["PowerShell", "48 mocked + 12 qualification-policy + 48 browser/runtime + 30 appliance assertions PASS; scripts parse under PowerShell 7."],
    ["Upload protocol", "12 PASS: exact origin/auth, safe names, size, atomic completion, hash manifest, no overwrite/listing/download."],
    ["Bash / Ansible", "Current helpers pass bash -n; existing SER8 playbooks retain prior syntax evidence."],
    ["Docker doctor", "PASS with real alpine run, known-file copy-out, and managed cleanup."],
    ["Minimal diagnostic", "Hash 82cd1c...; environment/controller/navigation/DOM/input/timers PASS; pixels FAIL in three profiles."],
    ["Controlled ole32", "Control/MR !12477 comparison completed; rendering unchanged; no crash in either member."],
    ["Dialog diagnostic", "Clean and post-install app-matching suites each PASS 7/7 with exact Unicode paths."],
    ["Live GUI", "Final schema-v3 lock PASS 10/10; each run ten gates, no repaint helper/retry/manual override."],
    ["Browser candidate", "Component suite PASS; clean install/native/WebView identity PASS; browser framebuffer/input BLOCKED."],
    ["Checksums", "All 1,853 final batch entries verify; batch and manifest hashes retained."],
    ["Cleanup", "Every exact run container/volume removed; final image retained; unrelated resources untouched."],
], [112, 380], compact=True)
h("Repository map")
table(["Path", "Purpose"], [
    ["crates/octane-core/", "Analysis/report/export library and unit tests."],
    ["src-tauri/", "Windows Tauri host, config, resources, icon, NSIS/WebView settings."],
    ["ui/ and fixtures/", "Static frontend and deterministic eight-file workload."],
    ["diagnostics/webview2-win32/", "Minimal native Win32 WebView2 diagnostic and event logging."],
    ["diagnostics/win32-file-dialog/", "Modern and legacy native open/save dialog localization probe."],
    ["scripts/Runtime*.ps1", "Engine adapter and Wine environment profiles."],
    ["scripts/RunState.ps1", "Atomic state, normalized results, JUnit, checksum synchronization."],
    ["scripts/Doctor/Start/Record/Collect/Stop", "Public operator lifecycle."],
    ["scripts/Invoke/Review/Validate", "Diagnostics, installed-app scenario, visual review boundary, and report validation."],
    ["scripts/*Qualification*.ps1", "Immutable lock creation and strict ten-run unattended batch aggregation."],
    ["profiles/qualification/", "Final machine-readable schema-v3 environment and contract lock."],
    ["profiles/candidates/", "Browser candidate lock and ten-row BLOCKED/NOT_RUN declaration; not a qualification lock."],
    ["schemas/ and templates/", "Generic data-only application/artifact contracts and example-app overlay."],
    ["lab/browser/", "Pinned noVNC/Websockify/x11vnc viewer, session, and unchanged-target helper."],
    ["lab/", "Pinned profile Dockerfiles, helpers, and strict native-SER8 Ansible lifecycle."],
    ["tests/", "Node behavior tests and mocked adapter/lifecycle harness."],
    [".github/workflows/", "GitHub Windows installer build and artifact upload."],
    ["docs/ and tools/", "Validation snapshot, visual evidence, PDF, and generator."],
    ["artifacts/runs/evidence", "Generated installer intake, run state, and portable output; Git-ignored."],
], [170, 322], compact=True)
p(
    "Generated target/, node_modules/, artifacts/, runs/, and evidence/ are not committed. "
    "Never commit a desktop password, raw inspect dump, credential file, or production report."
)


page(30, "References and roadmap")
p(
    "Primary sources define supported interfaces and upstream behavior; they do not prove this "
    "particular Wine/WebView combination. Measured claims come from the retained run metadata, "
    "logs, process samples, and screenshots."
)
for label, url in [
    ("Microsoft: WSL container feature", "https://learn.microsoft.com/en-us/windows/wsl/wsl-container"),
    ("Microsoft: WSLC session settings", "https://learn.microsoft.com/en-us/windows/wsl/wsl-container-settings"),
    ("Microsoft WSL issue 41740: Consomme/full-tunnel timeout", "https://github.com/microsoft/WSL/issues/41740"),
    ("Docker: WSL best practices", "https://docs.docker.com/desktop/features/wsl/best-practices/"),
    ("LinuxServer: WineGUI image and security", "https://docs.linuxserver.io/images/docker-winegui/"),
    ("scottyhardy/docker-wine upstream README", "https://github.com/scottyhardy/docker-wine/blob/master/README.md"),
    ("Tauri: Windows installer and WebView2 modes", "https://v2.tauri.app/distribute/windows-installer/"),
    ("Tauri: configuration reference", "https://v2.tauri.app/reference/config/"),
    ("Microsoft: WebView2 distribution modes", "https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution"),
    ("Microsoft: WebView2 supported platforms", "https://learn.microsoft.com/en-us/microsoft-edge/webview2/"),
    ("Microsoft: WebView2 Win32 getting started", "https://learn.microsoft.com/en-us/microsoft-edge/webview2/get-started/win32"),
    ("Microsoft: WebView2 process-related events", "https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-related-events"),
    ("MicrosoftEdge: WebView2Samples", "https://github.com/MicrosoftEdge/WebView2Samples"),
    ("rfd 0.15.4 retained Windows dialog implementation", "https://github.com/PolyMeilex/rfd/tree/bac4bd3364f2befaabafa9f58ac77fd8925b2abf"),
    ("Wine bug 60225: cross-process IDropTarget_Release report", "https://bugs.winehq.org/show_bug.cgi?id=60225"),
    ("Wine MR !12477: revoke foreign drop targets in their own process", "https://gitlab.winehq.org/wine/wine/-/merge_requests/12477"),
    ("G6rm0k: wine-ole32-fix proof of concept", "https://github.com/G6rm0k/wine-ole32-fix"),
    ("WebView2Feedback 5720: rendering/composition reports", "https://github.com/MicrosoftEdge/WebView2Feedback/issues/5720"),
    ("JustNotesa: Solid Edge Wine fixes reviewed source", "https://github.com/JustNotesa/solid-edge-wine-fixes"),
    ("khoipm06: wuwa-tappo-wine community implementation", "https://github.com/khoipm06/wuwa-tappo-wine"),
    ("Source conversation: Run Windows App Containers", "chatgpt-conversation://6af79ffb-6048-83ea-b689-8269484af53d"),
]:
    link(label, url)
h("Next maintenance milestone")
p(status.get("nextMilestone", "Qualify the identical installer on supported Windows."))
h("After compatibility is understood")
p(
    "Browser smoke and the fresh ten-run browser qualification are complete for the retained Octane artifact. Later, add a separately versioned Fixed "
    "Version WebView2 diagnostic; execute native Windows GUI automation; validate the thin GitLab wrapper on an "
    "actual project if needed; compare fresh and prepared-preview performance without confusing their claims; "
    "then add SBOM, vulnerability "
    "scan, and signed provenance. None of those supply-chain steps can substitute for visible "
    "WebView repainting or correct exported data."
)
p(
    "A different proprietary Windows installer can use the same artifact/profile/scenario "
    "contract without sharing source. Its installation path, executable discovery, dialogs, "
    "workload, and acceptance data must be separately configured and reported."
)


page(31, "Historical browser-candidate status and identity")
p(
    "This page preserves the pre-qualification browser-candidate snapshot and its failures. Pages 45-48 supersede its "
    "then-current status without rewriting the first outcomes. The candidate was not a relabeling of the historical RDP result. It preserved "
    "the exact qualified Wine/Staging/visible-region foundation, changes the display session to Xvfb/XFCE and the "
    "viewer to x11vnc/Websockify/noVNC, and keeps browser acceptance independent. A later manual run proved noVNC "
    "negotiation and framebuffer delivery, then exposed an installed WebView2 host failure."
)
table(["Verdict", "Current result"], [
    ["Historical Octane/RDP", "QUALIFIED 10/10 under lock 0137c535..."],
    ["Browser transport", "PASS: authenticated VNC negotiated and intended XFCE framebuffer reached the in-app browser"],
    ["Manual browser smoke", "FAIL: Octane absent after original host exited with WebView2 HRESULT 0x800700AA"],
    ["Sustained native readiness", "FAIL on Xorg and Xvnc: CrBrowserMain defunct after Wine stack overflow"],
    ["Automated browser acceptance", "BLOCKED / NOT_RUN; approved control unavailable and app readiness fails"],
    ["Browser 10/10", "BLOCKED; zero of ten runs executed"],
    ["Browser runtime release", "NOT QUALIFIED"],
], [165, 327], compact=True)
code("""Runtime commit: 136944da9e8b0ee4f3c6727613d062abbd958857
Image ID: sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a
Candidate lock SHA-256: 5227a24f4279a599679ff6adb00138776b93fd5205e8627ef11780b26acb4fff
noVNC: 63107bd06d9e1f6136ff21aeda8cd62cbf0d433e
Websockify: e81894751365afc19fe64fc9d0e5c6fc52655c36
Executable reference run: octane-3ca7d5cbb6
Browser smoke: octane-0e2276a168 / checksum 3bf8bb7b...
Xorg image/run: sha256:8d611400... / octane-e1e95b2d01
Xvnc image/run: sha256:10205a6e... / octane-7d9e41587c""")
p(
    "HTTP 200 still proves only static delivery. Run 0e2276a168 went farther: VNC negotiated and the intended framebuffer "
    "was visible in the browser. It did not prove application readiness; Octane had exited. A transport PASS cannot promote "
    "the target pixels, input, dialogs, workload, or export gates."
)
h("What component PASS established")
p(
    "Exactly one 127.0.0.1 viewer and one scoped upload publication; one read-only secret-file bind; raw VNC on container loopback only; "
    "bad WebSocket/upload origin rejection; fixed :1/1280x800 display; target process DISPLAY=:1 with winex11.drv loaded; "
    "no XRDP/FreeRDP process or listener; exact unchanged installer/executable; loaded Evergreen 157.0.4341.60 path, "
    "hash, and command lines; fresh prefix/data; attributable collection and exact cleanup."
)


page(32, "Daily unchanged-installer browser workflow")
code(r"""# Windows PowerShell 7 at repo or extracted-kit root
./scripts/Doctor-OctaneLab.ps1 -Engine Docker `
  -WslDistro Ubuntu-24.04 -Port 3005 -Deep

./scripts/New-OctaneTarget.ps1 -Id example-app `
  -Output ../example-app-octane

# Review app.json; verify rather than guess flags/path/title/dependencies.
./scripts/Test-OctaneTargetProfile.ps1 `
  -Profile ../example-app-octane/app.json -Operational

./scripts/Start-OctanePreview.ps1 `
  -Profile ../example-app-octane/app.json `
  -Installer 'C:\Builds\setup.exe' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -WslDistro Ubuntu-24.04 -Port 3005 -UploadPort 3006 `
  -Image octane-lab:browser-appliance-v1-136944d `
  -BuildLabel 'pipeline-12345' `
  -LifecycleMode ReplaceActive
""")
p(
    "The start command streams and hashes the stable EXE before replacing an active run, atomically caches it by bytes, journals run/input identity, "
    "creates a marker-owned WSL-native container/prefix/install/user-data/output/upload tree, exposes only selected/artifact input readonly, validates the EXE "
    "again inside the container, installs with verified argument arrays, discovers exactly one executable, launches "
    "once, records a native window and WebView2 identity, and prints the exact /octane.html URL. It never executes the "
    "installer on Windows and never falls back to the reference app."
)
code(r"""./scripts/Get-OctaneViewerCredential.ps1 `
  -Container octane-0123456789

./scripts/Show-OctaneManualBrowserHandoff.ps1 `
  -Container octane-0123456789 -WslDistro Ubuntu-24.04

./scripts/Collect-OctanePreview.ps1 `
  -Container octane-0123456789 -WslDistro Ubuntu-24.04 `
  -ScreenshotDirectory 'C:\Evidence\browser-smoke'

./scripts/Stop-OctaneLab.ps1 `
  -Container octane-0123456789 -Engine Docker -WslDistro Ubuntu-24.04""")
p(
    "Credential retrieval copies to the Windows clipboard without printing. Collection refuses to overwrite a "
    "prior run output. Stop collects an uncollected preview, asserts the exact managed resource, and removes only its container, "
    "marker-owned WSL session tree, active journal, and per-run credential."
)


page(33, "Viewer, file, network, and security boundaries")
h("Viewer")
p(
    "The published services are Websockify/noVNC and the scoped upload intake on independent 127.0.0.1 ports. x11vnc listens on 127.0.0.1:5901 and [::1]:5901 "
    "inside the container and requires an eight-character per-run RFB password. Allowed Origins match the exact local "
    "host/port. Raw VNC, X11, RDP, terminal, file manager APIs, Docker socket, and automation ports are not published."
)
p(
    "The current viewer uses plaintext HTTP/WebSocket on loopback. The password is never placed in the URL; it is an "
    "ignored file mounted read-only and entered into the form. This is not a LAN/internet or multi-user security design. "
    "Clipboard and remote resize are disabled; server resolution remains fixed so viewer scaling cannot act as a hidden "
    "repaint workaround."
)
h("File bridge")
table(["Path", "Policy"], [
    ["Selected host input", "Enumerate/hash; reject reparse points; copy only; rehash host and container copies"],
    ["C:\\octane-input\\selected", "Per-run staged copy visible readonly to the native picker; host source is never writable"],
    ["C:\\octane-input\\uploaded", "Authenticated atomic upload manifest; readonly target view; no overwrite/download/listing API"],
    ["C:\\octane-output", "Separate per-run writable output; collect even after GUI failure"],
    ["Operator output/run-id", "Non-overwriting retained result with checksums"],
], [135, 357], compact=True)
h("Network")
p(
    "Profiles allow only explicit HTTP/HTTPS endpoint URLs without embedded credentials and declare accepted status codes. "
    "The bounded Linux curl probe records status/remote IP/time and returns failure if a required endpoint is unavailable. "
    "A controlled endpoint passed; an unavailable port failed. This does not prove Wine/WebView2/target protocols, proxy, "
    "corporate CA, integrated identity, client certificates, domain access, or Windows localhost equivalence."
)
p(
    "No profile copies browser cookies, Credential Manager data, tickets, private keys, machine identity, or certificates. "
    "No privileged mode, host network, host GPU, ptrace, no-sandbox flag, broad mount, or disabled host control was added."
)


page(34, "Source-independent runtime kit and recovery")
code(r"""./scripts/New-OctaneRuntimeKit.ps1 `
  -OutputDirectory 'C:\Approved\Octane Kit 1' `
  -Version browser-appliance-v1-136944d-candidate `
  -HarnessCommit 136944da9e8b0ee4f3c6727613d062abbd958857""")
p(
    "The kit contains runtime scripts/modules, schemas/templates, browser image layer, reference profile/fixtures, locks, "
    "validation helpers, AI handoff, quick start, compatibility/research records, and checksums. It excludes target source, "
    "installer/image bytes, Git metadata, credentials, provider tokens, and raw evidence. Operating a supplied installer "
    "does not require Rust, Node, Visual Studio, target source, or a hosting-provider CLI."
)
p(
    "The extracted-kit test used a path containing spaces and Unicode, generated example-app-octane, validated it, staged "
    "the external retained EXE to its exact hash, started a clean preview with no source-tree fallback, passed component "
    "checks, collected output/evidence, and cleaned the exact container. Browser pixels/input remained blocked."
)
h("Private image recovery")
code(r"""./scripts/Export-OctaneBrowserImage.ps1 `
  -OutputPath 'C:\Approved\octane-wine-image-136944d.tar' `
  -Image octane-lab:browser-appliance-v1-136944d -WslDistro Ubuntu-24.04

./scripts/Import-OctaneBrowserImage.ps1 `
  -ArchivePath 'C:\Approved\octane-wine-image-136944d.tar' `
  -ExpectedSha256 5ef18bde39da0d3d56b48b416300034ef0f0a92355468e012ec21a8960039ebe `
  -ExpectedImageId sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a `
  -WslDistro Ubuntu-24.04""")
p(
    "The refreshed Docker-save archive is 2,083,894,784 bytes. Export/hash/image-ID checks passed without deleting the "
    "known-good base or prior candidate. A refreshed cold package import is a separate package-test gate. Archive checksum "
    "is integrity, not authenticity; the recipe records inputs but does not prove a byte-for-byte reproducible rebuild."
)
h("Large artifact intake")
p(
    "A 440,401,920-byte synthetic fixture passed streaming/hash/copy in about 1.5 seconds, same filename/different bytes "
    "created distinct IDs, a truncation failed the producer hash, and identical bytes reused the immutable cache. This is "
    "transport capacity only. A second real installer was unavailable, so two-build application acceptance is NOT_TESTED."
)


page(35, "Browser evidence and blocked qualification")
p(
    "Component run 3ca7d5cbb6 remains the final appliance/file-bridge result. Browser run 0e2276a168 proved negotiation and "
    "framebuffer delivery but failed application visibility. The candidate lock remains blocked and cannot start a ten-run batch."
)
table(["Required browser batch gate", "Current status"], [
    ["Viewer listener, authentication, intended session", "PASS in browser run 0e2276a168"],
    ["Fresh install/executable/WebView2 identity", "PASS in reference candidate"],
    ["Sustained original host/browser process", "FAIL on Xvfb/Xorg/Xvnc candidates"],
    ["Initial target pixels in browser without helper", "FAIL / BLOCKED by readiness"],
    ["Continuing browser pixels + mouse/keyboard/scroll/focus", "NOT_RUN / BLOCKED"],
    ["Real 8-file Rust workload", "NOT_RUN through browser"],
    ["Unicode/space/missing/open-save cancel/repeat", "NOT_RUN through browser"],
    ["Independent export/no-overwrite/input validation", "NOT_RUN through browser"],
    ["Post-dialog resize/restore and evidence", "NOT_RUN through browser"],
    ["Ten sequential fresh runs", "0/10; readiness prerequisite failed"],
], [255, 237], compact=True)
p(
    "An HTTP response, noVNC shell, VNC connect event, native X11 screenshot, process, loaded WebView2, live DOM, or direct "
    "X11 automation cannot promote any browser row. A manual operator result is separate and cannot count as unattended. "
    "The historical RDP batch remains valid in its own scope and cannot be reused."
)
h("Available verification")
p(
    "Current local checks: 61 browser/runtime assertions, 30 appliance-packaging assertions, 12 upload-protocol assertions, "
    "48 mocked PowerShell assertions, 12 qualification-policy assertions, 19 Node tests, Bash/PowerShell parsing, "
    "controlled endpoint positive/negative cases, synthetic 420 MiB "
    "transport, extracted-kit lifecycle, archive export/import, and exact cleanup. These are not browser GUI acceptance."
)


page(36, "Measured browser smoke and qualification resume path")
code("""# Create a fresh diagnostic run; use the emitted container identity and URL.
./scripts/Start-OctanePreview.ps1 `
  -Profile ../example-app-octane/app.json `
  -Installer 'C:\\Builds\\setup.exe' `
  -InputDirectory 'C:\\TestData\\Inputs' `
  -OutputDirectory 'C:\\TestData\\Results' `
  -WslDistro Ubuntu-24.04 `
  -Port 3005 -UploadPort 3006 `
  -Image octane-lab:browser-appliance-v1-136944d `
  -BuildLabel 'diagnostic' -LifecycleMode ReplaceActive

# Copy the per-run password without printing it.
./scripts/Get-OctaneViewerCredential.ps1 -Container octane-<run-id>""")
table(["Operator step", "Required observation"], [
    ["Connect", "VNC negotiated, then actual Octane client—not merely desktop/frame/viewer"],
    ["Initial presentation", "Normal pixels without resize/minimize/restore/click/reconnect/relaunch/helper"],
    ["Input", "Browser mouse, keyboard, focus, and scroll reach the intended application"],
    ["Open dialog", "Select controlled C:\\octane-input files, cancel, reopen, repeat"],
    ["Workload", "Actual retained 8-file/6-group/1-duplicate/176-byte/0-error result"],
    ["Save dialog", "Cancel, export to C:\\octane-output, return to responsive app"],
    ["Validate", "Independent JSON/content/hash/no-overwrite/input checks"],
    ["Collect/stop", "Browser-attributable evidence first; exact run cleanup second"],
], [112, 380], compact=True)
p(
    "Use only the fresh run identity and URL emitted by Start-OctanePreview; never guess a stale URL or use RDP. Label "
    "resulting evidence operator-performed browser smoke. If it passes, configure an approved "
    "browser-control path, freeze a new final lock, declare ten run IDs before run one, and execute every fresh run through "
    "the browser framebuffer/input path. Preserve all first outcomes; any FAIL/BLOCKED/NOT_RUN means not 10/10."
)
p(
    "The checklist was attempted on run 0e2276a168. The viewer negotiated and showed the intended desktop, but the application "
    "was absent after a WebView2 host exit, so the smoke is FAIL and later steps are BLOCKED. Historical RDP acceptance remains "
    "qualified for its exact lock. The next action is a bounded Wine exception trace of the CrBrowserMain stack overflow and "
    "a comparison with the historically qualified Xorgxrdp lock—not another display rebuild."
)


page(37, "Packaged WSL appliance architecture")
code(r"""
Windows 11
  |
  +-- Install-Octane.ps1 / Octane.cmd / default browser
  |
  +-- dedicated imported Octane WSL2 appliance
        Ubuntu 24.04 + systemd + Docker Engine 29.6.2
        |
        +-- fresh Docker container per build
              patched Wine-Staging 11.21 + WebView2
              Xvfb/XFCE + x11vnc + Websockify/noVNC
              unchanged Windows setup.exe and installed application
""")
p(
    "Docker Engine belongs in the imported WSL appliance and remains outside the application container. Wine, WebView2, "
    "the graphical desktop, viewer services, installer, and target belong inside the disposable container. The Windows "
    "browser receives pixels and sends normal input; it is not a separately hosted application frontend."
)
h("Release layout")
code(r"""Octane-v1/
  Install-Octane.ps1  Octane.ps1  Octane.cmd  Uninstall-Octane.ps1
  appliance/octane-ubuntu.tar
  images/octane-wine-image.tar.zst
  runtime/  profiles/  docs/  manifest.json  checksums.sha256""")
p(
    "The WSL TAR contains the management userspace and pinned Docker packages, but no populated /var/lib/docker. The "
    "separate image archive preserves Docker layers/tags and is streamed into docker load only after both package and "
    "runtime checksums pass. Target installers, credentials, raw evidence, and application state are excluded."
)
table(["Measured artifact", "Identity"], [
    ["WSL rootfs TAR", "503,298,560 bytes; SHA-256 1c8cb6e36a880dcf491aaa12dc1d52c0819824902a2b272b36d3837c451e3368"],
    ["Compressed image archive", "2,078,023,379 bytes; SHA-256 bf47e58e50ef56396ee3e1d43fdecda5de0426ede6c37342609c01c154240b05"],
    ["Docker-save source", "2,083,894,784 bytes; SHA-256 5ef18bde39da0d3d56b48b416300034ef0f0a92355468e012ec21a8960039ebe"],
    ["Loaded image ID", "sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a"],
], [145, 347], compact=True)


page(38, "One-command appliance workflow")
h("One-time install")
code(r"""# Windows PowerShell 7, from extracted Octane-v1
./Install-Octane.ps1 -PackageRoot $PWD -PlanOnly
./Install-Octane.ps1 -PackageRoot $PWD

# Open a new terminal after PATH is updated.
octane doctor -Deep""")
p(
    "PlanOnly reads and verifies the rootfs, compressed image, runtime checksum manifest, and every listed runtime file "
    "without changing the host. Install refuses an existing distro, launcher home, or storage root; imports WSL2; verifies "
    "the appliance marker; starts its Docker service; loads and inspects the exact image; and installs the launcher."
)
h("Everyday new-build preview")
code(r"""octane target -Id example-app `
  -TargetOutput 'C:\Octane Targets\example-app-octane'

octane open 'C:\Builds\setup.exe' `
  -Profile 'C:\Octane Targets\example-app-octane\app.json' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -BuildLabel 'pipeline-12345'

octane collect -Container octane-0123456789
octane stop -Container octane-0123456789""")
p(
    "Open stages and hashes the exact EXE before replacing an active run, collects and removes only that prior exact session, "
    "starts a fresh WSL-native container/prefix/install, waits for the viewer and native window, "
    "copies the per-run password to the Windows clipboard, and opens the exact localhost path in the default browser. "
    "Use -NoBrowser when policy blocks automatic opening. No target source, Git provider, Rust, Node, Visual Studio, or "
    "Windows-side target installation is required."
)
h("Boundaries")
p(
    "The host must already permit WSL import/execution. The installer does not enable Windows features, elevate, weaken "
    "policy, replace a distro, expose a LAN listener, or mount a broad host tree. Uninstall requires an explicit destructive "
    "switch and checks the exact appliance marker and approved storage roots before unregistering."
)


page(39, "Appliance build, recovery, and live test")
h("Pinned build inputs")
p(
    "The rootfs uses Ubuntu digest 2198e4c65076... and exact Docker CE 29.6.2, containerd 2.2.6, buildx 0.36.0, and "
    "Compose 5.3.1 packages. Rootfs source commit is 136944da9e8b0ee4f3c6727613d062abbd958857. The browser image remains "
    "the separately measured Wine candidate; packaging did not rebuild or silently replace it."
)
code(r"""./scripts/Build-OctaneWslAppliance.ps1 `
  -OutputPath 'work\appliance\octane-ubuntu.tar'

./scripts/Compress-OctaneImageArchive.ps1 `
  -InputPath 'work\moonshot-appliance-136944d\images\octane-wine-image.tar' `
  -OutputPath 'work\appliance\octane-wine-image.tar.zst'

./scripts/New-OctaneApplianceRelease.ps1 `
  -ApplianceTar 'work\appliance\octane-ubuntu.tar' `
  -ImageArchive 'work\appliance\octane-wine-image.tar.zst' `
  -RuntimeKitDirectory 'work\runtime-kit' `
  -OutputDirectory 'work\Octane-v1' `
  -Version '1.0.0-browser-candidate.136944d' `
  -ImageReference 'octane-lab:browser-appliance-v1-136944d' `
  -ImageId 'sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a' `
  -UncompressedImageArchiveSha256 5ef18bde39da0d3d56b48b416300034ef0f0a92355468e012ec21a8960039ebe""")
h("Refreshed package lifecycle result")
table(["Stage", "Result"], [
    ["Rootfs/image archives", "PASS: generated manifests and exact hashes for executable commit 136944d"],
    ["Source-tree live candidate", "PASS: fresh install/runtime, upload/Wine path, collection, exact cleanup"],
    ["Active replacement", "PASS with identical installer bytes; two distinct real builds NOT_TESTED"],
    ["Extracted package", "PASS: unique import, Docker/image, doctor, preview/components, collection, exact cleanup"],
    ["Browser application acceptance", "FAIL: transport/framebuffer PASS; stable Octane/WebView2 client FAIL"],
    ["Cleanup", "PASS: exact container, credential, distro, marker-owned storage, ports, and active journal removed"],
], [150, 342], compact=True)
p(
    "Refreshed test 2164864404 used container octane-3fd2c8f429 from an 84-file / 2,583,977,275-byte package under "
    "a path containing spaces and Unicode. Result SHA-256 is 8ad04f36734b35b2a22e7578791fd4cc81889fc7e35f457a9682a870b005073f; "
    "component checksum-manifest SHA-256 is 7f023762d400fed8b43e4bf9e3348718a8597782a81f62ccefd460016f73e288."
)


page(40, "Appliance verdict and maintenance boundary")
table(["Conclusion", "Status"], [
    ["Historical Octane/RDP", "QUALIFIED 10/10 for its exact immutable lock"],
    ["Browser image components", "PASS in the source-tree and imported-appliance paths"],
    ["Refreshed appliance packaging", "PASS for exact extracted component lifecycle and cleanup"],
    ["Manual browser smoke", "FAIL after transport PASS and application host exit"],
    ["Automated browser acceptance", "BLOCKED / NOT_RUN; app readiness also fails"],
    ["Browser-specific ten-run batch", "BLOCKED; 0/10 executed"],
    ["Another Windows application", "UNTESTED; never inherits the reference result"],
], [190, 302], compact=True)
h("What the appliance changes")
p(
    "It makes setup predictable: one verified import, one pinned image load, and one Windows launcher. It does not change "
    "the target bytes, Wine compatibility, the custom patch maintenance condition, the white minimal WebView2 probe, or "
    "the measured browser-process failure."
)
h("Environment-specific test note")
p(
    "This Codex Windows sandbox projects LocalAppData files into a view invisible to wsl.exe. The package's default "
    "LocalAppData plan and hashes passed, while the live lifecycle used an explicit project-scoped WSL-visible state root. "
    "No ACL, policy, or broad security setting was weakened to hide that limitation. A normal unsandboxed default-path "
    "install and a second-machine cold import remain untested."
)
h("Next action")
p(
    "Capture one bounded Wine exception trace for the CrBrowserMain stack overflow on integrated Xvnc and compare it with the "
    "same unchanged installer under the historically qualified Xorgxrdp lock. Begin browser input and ten fresh runs only after "
    "the original browser process survives the 90-second stability gate."
)


page(41, "Implemented fresh-build session model")
p(
    "<b>Implementation status:</b> Executable commit 136944da9e8b0ee4f3c6727613d062abbd958857 now provides "
    "validate-before-replace intake, one active build by default, explicit comparison mode, WSL-native marker-owned "
    "application state, selected/uploaded/output separation, authenticated upload, evidence collection, and exact cleanup. "
    "Browser transport pixels were observed, but target readiness/input/upload and the browser ten-run batch remain failed or blocked."
)
code(r"""
pipeline -> new Windows x64 installer
             |
      streamed hash and immutable byte identity
             |
 fresh container + Wine prefix + registry/settings
 + WebView2 user data + application profile + output
             |
 install and launch the unchanged Windows EXE through Wine
             |
 authenticated localhost browser -> actual streamed GUI
""")
h("Everyday command")
code(r"""octane open 'C:\Builds\Application-v2.4.0.exe'""")
p(
    "For a generic target, pass the implemented -Profile, -InputDirectory, and -OutputDirectory parameters. Immutable "
    "intake must finish before Octane collects and removes the prior active run. The new installer is the major changing "
    "artifact; the WSL appliance, Docker Engine, and pinned Wine/browser image stay installed and cached."
)
h("Stable foundation versus fresh session")
table(["Layer", "Policy"], [
    ["Ubuntu WSL appliance", "Keep; do not reimport for every application build."],
    ["Docker Engine", "Keep inside the selected appliance distribution."],
    ["Patched Wine/browser image", "Keep by exact image identity; no warmed installed-app prefix."],
    ["Application container", "Create new for every build."],
    ["Wine registry/settings/profile", "Create new inside that disposable session."],
    ["WebView2 user data and output", "Create new; collect outputs before exact cleanup."],
], [176, 316], compact=True)
p(
    "This model makes a new build clean without repeatedly installing infrastructure on Windows. It also preserves the "
    "qualification boundary: a cached base image is reusable infrastructure, not persisted application state."
)


page(42, "One-active-build replacement and comparison")
h("Implemented replacement sequence")
table(["Step", "Required behavior"], [
    ["1. Build 101 active", "Fresh container, installation, viewer credential, inputs, outputs, and evidence identity."],
    ["2. Build 102 requested", "Stream/hash/admit Build 102 first; only then record and collect Build 101."],
    ["3. Retire Build 101", "Remove only its exact container, writable layer, prefix, app/WebView data, secret, and owned storage."],
    ["4. Start Build 102", "Create a new clean session; never replace a failed start with hidden reuse or fallback."],
], [112, 380], compact=True)
h("Retention policy")
table(["Resource", "After replacement"], [
    ["WSL appliance / Docker / pinned image", "KEEP"],
    ["Old application container and writable layer", "DELETE after collection"],
    ["Old Wine prefix, settings, profile, WebView2 data", "DELETE"],
    ["Installer copy inside the old session", "DELETE"],
    ["Optional verified installer cache", "Separate bounded retention policy"],
    ["Test-input library", "KEEP"],
    ["Exports and evidence", "KEEP outside disposable state"],
    ["Producer-pipeline EXE", "Pipeline retention policy"],
], [214, 278], compact=True)
p(
    "Docker documents that docker rm -v removes anonymous volumes but does not remove named volumes. Octane must journal "
    "every session-owned mount or directory and remove only those exact resources. Global docker system prune is neither "
    "required nor permitted by this design."
)
link("Docker container removal and volume behavior", "https://docs.docker.com/reference/cli/docker/container/rm/")
h("Two explicit modes")
table(["Mode", "Implemented meaning"], [
    ["open", "Replace the one active build by default, after attributable collection."],
    ["compare", "Retain an isolated comparison with different viewer/upload ports, prefix, credential, I/O, and evidence."],
], [132, 360], compact=True)
p(
    "Live pair 750fc957af -> 603b83b9bf passed validate-first replacement, prior collection/removal, fresh state, port "
    "reuse, journal transfer, and final cleanup. Both used the same installer, so two-distinct-build application behavior "
    "remains NOT_TESTED. Neither lifecycle result is browser GUI qualification."
)


page(43, "WSL-backed file ingestion and upload")
p(
    "Prefer the WSL Linux filesystem for intensive Octane working data while allowing the operator to select permitted "
    "Windows inputs and output destinations. Keep operator files, disposable session state, and retained evidence in "
    "separate lifecycle and trust zones."
)
code(r"""
Windows input                     Implemented WSL working state
C:\Octane\Input                  /var/lib/octane/sessions/octane-<run>/
                                    artifact/   selected/   upload/
                                    home/.octane/prefix/
                                    home/.octane/output/

Wine paths                        Windows collection destination
C:\octane-input\selected          C:\Octane\Output
C:\octane-input\uploaded
C:\octane-output
""")
p(
    "The session root is created before container resources and carries an exact marker checked before deletion. Wine Z: "
    "exists while NSIS executes from its read-only Unix mount, then is removed before the installed application launches. "
    "The preserved 9500a6e5d0 failure records why installation and target-launch drive policy must stay separate."
)
h("Two ingestion methods")
table(["Method", "Contract"], [
    ["A. Windows folder staging", "Validate paths, reject escapes, hash/copy/rehash to WSL-native per-run storage, mount selected input readonly, collect output separately."],
    ["B. Browser upload", "Exact viewer origin + bearer credential; 512 MiB/file; safe basename; atomic no-overwrite write; SHA-256 manifest; target readonly view."],
], [150, 342], compact=True)
h("Command surface")
code(r"""
# Implemented PowerShell parameters
octane open 'C:\Builds\Application.exe' `
  -InputDirectory 'C:\Octane\Input' `
  -OutputDirectory 'C:\Octane\Output'

# Isolated comparison requires its own viewer/upload ports
octane compare 'C:\Builds\Previous.exe' -Port 3010 -UploadPort 3011
""")
p(
    "Direct upload-protocol and Wine-path checks passed, including a Unicode filename and manifest hash. No approved browser "
    "clicked the upload control or drove application ingestion, so browser-origin upload remains NOT_RUN. Docker mounts "
    "resolve on the daemon host; selected/artifact/application-upload views are readonly."
)
link("Docker bind mounts and read-only options", "https://docs.docker.com/engine/storage/bind-mounts/")


page(44, "Storage placement and measured boundaries")
table(["Data", "Recommended physical location"], [
    ["WSL appliance and reusable Docker image", "WSL virtual disk"],
    ["Per-build prefix, settings, and WebView2 state", "Disposable WSL/container storage"],
    ["Large active ingestion datasets", "WSL ext4 storage"],
    ["Installer downloaded from CI", "Windows build folder, then immutable staged copy in WSL"],
    ["Exported results", "Per-run WSL staging, then selected Windows output"],
    ["Screenshots, logs, machine-readable evidence", "Persistent WSL evidence, optionally exported after review/redaction"],
], [216, 276], compact=True)
p(
    "Microsoft recommends the WSL filesystem when Linux tools perform intensive work rather than repeatedly operating "
    "across /mnt/c. Windows can inspect Linux files through \\\\wsl$\\<DistroName>\\... or "
    "\\\\wsl.localhost\\<DistroName>\\.... The controller-owned session root is /var/lib/octane/sessions; for diagnosis, "
    "an imported distro named Octane appears at \\\\wsl.localhost\\Octane\\var\\lib\\octane\\sessions\\. Use collection "
    "for normal operation and never edit a live session tree then claim integrity."
)
link("Microsoft: working across Windows and Linux filesystems", "https://learn.microsoft.com/en-us/windows/wsl/filesystems")
link("Microsoft: WSL interop and UNC access", "https://learn.microsoft.com/en-us/windows/dev-environment/wsl-interop")
h("Application-level checks")
table(["Capability", "Required interpretation"], [
    ["Native open/save dialogs", "Browse, select, cancel, reopen, and return to a responsive app."],
    ["Filesystem semantics", "Read real contents; cover folders, spaces, Unicode, missing files, and unchanged inputs."],
    ["Exports", "Write only to separate writable output; independently validate collected bytes."],
    ["Network", "Test only explicitly approved endpoints and authentication mechanisms."],
    ["Windows equivalence", "Do not infer native ACL, domain, mapped-drive, certificate, or device identity parity."],
], [160, 332], compact=True)
h("Security and implementation boundary")
p(
    "Destroy application settings and caches with the session. Preserve only deliberately separated inputs, bounded verified "
    "cache entries, exports, and evidence. Use approved artifacts and permitted data; WSL must not bypass endpoint controls, "
    "execution policy, data-handling rules, identity restrictions, or missing authorization."
)
table(["Established in executable candidate", "Still unqualified / unavailable"], [
    ["Fresh marker-owned state, validate-before-replace, compare contract, selected/uploaded/output bridge", "Browser-origin pixels, input, upload, ingestion, dialogs, and export"],
    ["420 MiB transport; same-installer active replacement; exact cleanup", "Two distinct real installer builds and browser 10/10 qualification"],
], [246, 246], compact=True)
p(
    "The intended result is a repeatable loop: produce an EXE, open it in Octane, inspect the real browser-streamed GUI, "
    "ingest controlled files, collect results, and replace the build without reinstalling the stable foundation."
)


page(45, "Final browser-only qualification")
p(
    "This page is the current result and supersedes the candidate-status snapshot on pages 31-44. Batch "
    "<b>browser-qbatch-06f2a54afe0c</b> passed ten of ten predeclared, sequential, unattended fresh-container runs. "
    "Every row used the same retained installer, final image, profile, fixtures, lock, and trusted browser scenario."
)
table(["Run", "Scenario", "Components", "Report", "Evidence", "Cleanup"], [
    ["513b6385f0", "PASS", "PASS", "PASS", "PASS", "PASS"],
    ["1bb8a0ec9f", "PASS", "PASS", "PASS", "PASS", "PASS"],
    ["23367b15c9", "PASS", "PASS", "PASS", "PASS", "PASS"],
    ["1c2750d422", "PASS", "PASS", "PASS", "PASS", "PASS"],
    ["5fd8ba417d", "PASS", "PASS", "PASS", "PASS", "PASS"],
    ["89019ca3ed", "PASS", "PASS", "PASS", "PASS", "PASS"],
    ["3f42f907d7", "PASS", "PASS", "PASS", "PASS", "PASS"],
    ["e103eef43d", "PASS", "PASS", "PASS", "PASS", "PASS"],
    ["f9f807aa18", "PASS", "PASS", "PASS", "PASS", "PASS"],
    ["a164c028eb", "PASS", "PASS", "PASS", "PASS", "PASS"],
], [90, 80, 80, 80, 80, 82], compact=True)
code("""Harness commit: ad1ba74644bdab49a17ccc40caf26f477d848a6a
Image: octane-lab:browser-xvnc-ad1ba74
Image ID: sha256:6e77b89e7d5f8d3f9472998bd33859413b6982038c9cc64054a9eb035b25e786
Browser lock SHA-256: db5babdf10bb9c3aef12731c398a75437d280385799512e1b92838f028d68249
Installer SHA-256: adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a
Batch summary SHA-256: 9254405b6f211314a25092f32ddaa5e369ad83d8ed9c841cf9e55502d02b15c0
Batch checksum-manifest SHA-256: 37c5b7459ced5c393c990b43f295412e9f1d20fb5132718f7e08fe993d45dd07""")
p(
    "The authenticated noVNC client received changing application frames and sent the interaction used for the real "
    "8-file, 6-group, 1-duplicate, 176-byte Rust workload, native open/save dialogs, cancellation/reopen behavior, "
    "JSON export, existing-output protection, and post-dialog responsiveness. No RDP process, repaint helper, relaunch, "
    "hidden retry, operator action, or manual override entered the ten measured runs."
)


page(46, "Qualified appliance and runtime kit")
p(
    "The Windows-facing distribution keeps Docker Engine in the imported Ubuntu 24.04 WSL appliance and keeps Wine, "
    "WebView2, Xvnc/XFCE, noVNC, Websockify, and the installed target inside the separately versioned Docker image. "
    "The image archive is loaded after import; a populated /var/lib/docker is never baked into the rootfs."
)
table(["Deliverable", "Identity / contract"], [
    ["Runtime kit", "Source-independent scripts, schemas, profiles, fixtures, trusted reference scenario, guide, and checksums; no target source or provider account."],
    ["WSL rootfs", "Ubuntu 24.04 rootfs and pinned Docker Engine; exact source commit, length, and SHA-256 are carried in its sibling build manifest."],
    ["Docker image archive", "Final loaded image ID sha256:6e77b89e...; Docker-save and compressed SHA-256 values are distinct and carried in the release manifest."],
    ["Extracted-kit test", "Import, image load, deep doctor, fresh preview, collection, exact stop, unregister, and storage cleanup are tested from a path containing spaces and Unicode."],
    ["Release checksums", "The top-level release manifest and checksums file are generated after assembly; exact final values belong in the release evidence, avoiding self-referential guide hashes."],
], [138, 354], compact=True)
code(r"""# One-time Windows PowerShell 7
.\Install-Octane.ps1

# Daily operation after installation
octane open 'C:\Builds\Application-setup.exe' `
  -Profile 'C:\Targets\example-app-octane\app.json' `
  -InputDirectory 'C:\Octane\Input' `
  -OutputDirectory 'C:\Octane\Output'
""")
p(
    "The launcher admits and hashes immutable bytes, creates a fresh container/prefix/settings/WebView2 data/output tree, "
    "installs the unchanged Windows EXE through Wine, starts the authenticated loopback viewer, copies the per-run "
    "credential to the Windows clipboard, and opens the Windows default browser."
)


page(47, "Daily clean-build workflow")
table(["Action", "Measured or implemented behavior"], [
    ["open", "Validate the new installer first, collect and exactly retire the prior active run, then launch a clean build."],
    ["compare", "Keep two separately journaled runs with distinct ports, secrets, prefixes, inputs, outputs, and evidence."],
    ["input", "Hash/copy selected Windows files into WSL-native staging; expose them read-only at stable Wine paths."],
    ["upload", "Authenticated, exact-origin, bounded, atomic no-overwrite upload into a separate read-only target view."],
    ["output", "Keep a distinct writable target output; collect it even when the GUI fails."],
    ["stop", "Collect first, then remove only marker-owned container/session/secret resources; no global prune."],
], [98, 394], compact=True)
h("Clean-state invariant")
p(
    "The Ubuntu appliance, Docker Engine, pinned browser/Wine image, fixtures, and optional verified artifact cache may "
    "remain. Every application build receives a new container, Wine prefix, registry/settings, user profile, WebView2 "
    "user-data directory, installation, output directory, credential, and run journal. Exports and evidence have a "
    "separate retained lifecycle and cannot seed the next application run."
)
h("Large artifacts and build identity")
p(
    "The transport contract streams and hashes with bounded buffers, detects source mutation and incomplete copies, "
    "uses atomic completion, and keys identity by bytes rather than a reused setup.exe name. A 440,401,920-byte synthetic "
    "fixture passed capacity, interruption, same-name/different-content, mismatch, reuse, and cleanup tests. It is not a "
    "second executable installer or a second application acceptance result."
)
h("File and network limits")
p(
    "Loopback viewer exposure is not egress isolation. Required endpoints are explicit and bounded. Linux curl reachability "
    "does not prove Wine, WebView2, target protocol, TLS, proxy, domain identity, client certificate, mapped drive, or "
    "integrated-authentication behavior. Never copy Windows credentials, cookies, certificates, or machine identity into "
    "the appliance automatically."
)


page(48, "Release verdict and maintenance contract")
table(["Conclusion", "Measured scope"], [
    ["Historical RDP qualification", "Preserved, separate 10/10 result under its original lock; not evidence for browser transport."],
    ["Browser-only Octane qualification", "QUALIFIED 10/10 for the exact retained installer, final Xvnc/noVNC image, lock, fixtures, scenario, and host record."],
    ["Reusable product", "Profile-driven unchanged-installer intake, clean replacement, browser launch, controlled files, evidence, cleanup, appliance, and runtime kit are delivered."],
    ["External application", "UNTESTED until its exact installer/profile is previewed or scenario-tested; it never inherits Octane qualification."],
    ["General WebView2/Wine", "NOT established. The minimal native probe remains white and the custom visible-region patch is a maintenance condition."],
], [154, 338], compact=True)
h("Requalification triggers")
p(
    "Re-freeze and rerun relevant acceptance after changes to installer bytes, Wine/Staging or patches, WebView2, "
    "Xvnc/XFCE/noVNC/Websockify, browser client, resolution/DPI/renderer, application profile, trusted scenario, fixtures, "
    "security policy, or executable harness. Do not silently pull latest, warm a prefix, swap a backend, or promote a "
    "manual review to an unattended pass."
)
h("Protected history and safety")
p(
    "The original v0.1.1 assets, historical RDP/browser failures, WSLC VHD backup, unrelated WSL distributions, Docker "
    "resources, and private raw evidence remain untouched. The final profile uses loopback publication and authentication; "
    "it does not use privileged mode, host networking, Docker-socket mounts, broad host mounts, host-GPU passthrough, "
    "ptrace escalation, disabled sandboxing, global pruning, or machine-wide security changes."
)
p(
    "<b>Verdict:</b> the actual installed Windows Octane application is demonstrated and qualified through the localhost "
    "browser path for its exact recorded configuration. That is a bounded compatibility result, not a promise that every "
    "Windows or Tauri application behaves like native Windows under Wine."
)


def decorate(canvas, doc):
    canvas.setTitle("Octane - Complete Windows Installer Compatibility Lab Guide")
    canvas.setAuthor("Octane Lab")
    canvas.setStrokeColor(colors.HexColor("#dce5eb"))
    canvas.line(54, 44, 558, 44)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#657989"))
    canvas.drawString(54, 30, "OCTANE / PUBLIC SOURCE REFERENCE / GUIDE REVISION 12")
    canvas.drawRightString(558, 30, str(doc.page))


doc = SimpleDocTemplate(
    str(DEST), pagesize=(612, 792), rightMargin=54, leftMargin=54,
    topMargin=44, bottomMargin=60,
)
doc.build(story, onFirstPage=decorate, onLaterPages=decorate)
print(DEST)
