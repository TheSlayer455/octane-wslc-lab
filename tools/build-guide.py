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
        picture.drawWidth = 238
        picture.drawHeight = 238 * picture.imageHeight / picture.imageWidth
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
    "Guide revision 5 | November 14, 2026 | Windows x64 + Docker/WSLC/Ansible + Wine 11.21"
)
p(
    "Octane is a repository-independent, container-runtime-independent lab for a real "
    "Windows Tauri installer. Its reference workload analyzes small files, calculates "
    "SHA-256, groups extensions and duplicates, opens native file dialogs, and exports "
    "JSON. The experiment always installs and launches the Windows artifact through Wine; "
    "it never substitutes a Linux build or browser-only application."
)
link(
    "Private repository: TheSlayer455/octane-wslc-lab",
    "https://github.com/TheSlayer455/octane-wslc-lab",
)
h("What is delivered")
p(
    "The private repository contains the Rust/Tauri reference app, fixtures, Windows NSIS "
    "build workflow, explicit WSLC and Docker adapters, WineGUI and Docker-Wine profiles, "
    "a runtime doctor, normalized run-state and evidence tooling, regression checks, and "
    "this single comprehensive document. The measured installer and matching manifest are "
    "retained in the private v0.1.1 prerelease."
)
h("Headline result")
p(html.escape(status.get("summary", "Validation data unavailable.")))
h("How to read this guide")
p(
    "Pages 3-9 explain architecture, engine choice, diagnosis, artifact intake, and startup. "
    "Pages 10-17 specify the workload, code, evidence, security, and acceptance protocol. "
    "Pages 18-25 diagnose failures and show the measured WineGUI, Docker-Wine, controlled "
    "ole32, native SER8, and Wine 11.21 candidate results. Pages 26-27 record verification, repository inventory, "
    "sources, and remaining work. Commands run in "
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
    "Verification and repository inventory", "References and roadmap",
]
table(["Page", "Topic"], [[str(i), topic] for i, topic in enumerate(topics, 1)], [38, 454], compact=True)
p(
    "<b>Delivered scope:</b> explicit WSLC and Docker adapters; Windows-host Docker through "
    "a named WSL distribution; a strict Ansible path to native Docker on the SER8; "
    "WineGUI/Selkies and Docker-Wine/RDP profiles; fresh-prefix installation; machine-readable "
    "stages; evidence copy-out and exact cleanup."
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
Local build / private GitHub Actions / another artifact producer
                         |
           Octane-setup.exe + installer-manifest.json + fixtures
                         |
                 PowerShell lab controller
                         |
             selected runtime adapter (explicit)
                   /                       \
             WSLC on Windows       Docker local or in named WSL
                   \                       /
              selected Wine environment profile
               /                            \
      WineGUI + Selkies HTTPS        Docker-Wine + xrdp RDP
                         |
          Windows NSIS -> Octane.exe -> WebView2
                         |
       run.json + results.json + JUnit + logs + screenshots + hashes
""")
table(["Layer", "Owns", "Must not require"], [
    ["Artifact production", "Compile/package Windows installer and manifest.", "A later container engine or desktop profile."],
    ["Runtime adapter", "Probe, build, run, inspect, exec, copy, stop, and remove.", "GitHub, app-specific logic, or silent engine fallback."],
    ["Wine profile", "Base image, display protocol, user, ports, state and evidence paths.", "CI-provider variables or proprietary source."],
    ["Application scenario", "Install, launch, exercise fixtures/dialogs, validate/export.", "WSLC/Docker command spelling."],
], [90, 202, 200], compact=True)
h("Lifecycle")
p(
    "The controller writes run identity before creating resources, verifies the installer "
    "hash, executes the doctor, builds a run-specific image, creates a labeled container, "
    "waits for the Windows-side loopback endpoint, and leaves the environment running for "
    "interactive acceptance. The operator records stage outcomes, copies evidence, then "
    "removes only the exact labeled container, anonymous volumes, and optional run image."
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
    ["WineGui", "Selkies HTTPS :3001 / octane", "/config; /config/octane-evidence"],
    ["DockerWine", "xrdp RDP :3389 / wineuser", "/home/wineuser/.octane; .octane/evidence"],
    ["DockerWineStaging1121Control", "same RDP desktop / wineuser", "pinned source control; fresh .octane prefix"],
    ["DockerWineStaging1121VisRgn", "same RDP desktop / wineuser", "exact control plus one verified win32u patch"],
], [92, 184, 216], compact=True)
p(
    "Both upstream base images are digest pinned. WineGUI is the browser-streamed baseline. Docker-Wine "
    "is an interchangeable upstream environment reached through an Octane-owned Dockerfile "
    "adapter; its convenience script is not Octane's public interface. The two profiles may "
    "differ in desktop behavior, but they consume the same installer, manifest, fixtures, "
    "helper commands, stage model, and evidence contract."
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
    "Tools with a Windows SDK, Node 22, pnpm 11.25.0, and Git. Downloading the private artifact "
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
    "Octane consumes files, not a GitHub release URL: artifacts/Octane-setup.exe, "
    "artifacts/installer-manifest.json, and the repository fixtures. The manifest identifies "
    "the filename, SHA-256, source commit, build time, WebView distribution mode, and signing "
    "state. Start-OctaneLab hashes the installer and rejects a mismatch before runtime work."
)
code("""Get-FileHash ./artifacts/Octane-setup.exe -Algorithm SHA256
Get-Content ./artifacts/installer-manifest.json

# Local Windows build; does not install Octane on the host.
./scripts/Build-Octane.ps1""")
h("Private GitHub delivery")
p(
    "The v0.1.1 private prerelease retains the measured EXE, manifest, and its historical guide; "
    "this revision does not replace that release. The last separately verified "
    "application-build run 43560204604 verified implementation commit 6199155 with locked Rust/core and Node "
    "checks, the 37-assertion PowerShell harness, Tauri's NSIS build, and artifact upload. Its "
    "new installer hash is 7a4ee192...e22c22 and is not substituted for the Wine-tested artifact. "
    "Workflow artifacts expire; release assets remain until explicitly removed. Artifact "
    "production and runtime acceptance remain separate concerns."
)
link(
    "Private v0.1.1 release",
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
    "download that private workflow artifact into diagnostics/webview2-win32/artifacts and "
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


page(8, "Running WSLC + WineGUI")
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


page(9, "Running Docker profiles")
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
    "Pinned Wine 11.21 plus matching Staging changed the Tauri-host result: Octane sometimes "
    "presented after three resize/minimize/restore cycles. The control passed one full clean run "
    "and stayed black in the next. The visible-region candidate rendered Octane and its real "
    "workload in three fresh runs, but completed every dialog/export gate only once. The minimal "
    "probe remained white even with that patch. Rendering, repaint reliability, and native-dialog "
    "behavior are therefore separate failure layers."
)
h("Research conclusions and next experiment")
p(
    "Wine bug 60225 remains a close historical crash lead, not an established cause of the current "
    "result. The Wine 11.0 MR !12477 pair and current 11.21 runs did not reproduce the old "
    "IDropTarget_Release crash. WebView2Feedback 5720 correctly motivated independent DOM/pixel "
    "measurement, but its macOS and Linux reports are not universal claims. The Solid Edge patch "
    "is a measured application-specific candidate, not a general WebView2 repair."
)
p(
    "The smallest next experiment is a native IFileOpenDialog/GetOpenFileName probe in the same "
    "candidate prefix, recording HRESULT and window lifecycle. Then rerun one fresh candidate with "
    "the committed input synchronizer. Do not add no-sandbox, privileged mode, broad mounts, opaque "
    "DLLs, or old runtimes without one explicit hypothesis and a separately named profile."
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
    ["Harness commits", "cf6baba (fresh 1-2); a84bab1 (fresh 3); 17683ea final synchronizer"],
], [126, 366], compact=True)
p(
    "The candidate's native probe remained white (rAF 0, timer callbacks 114, pixel delta 0) "
    "while the Tauri host later rendered after a window-state nudge. Candidate GUI/workload was "
    "3/3, but full native-dialog/export acceptance was 1/3. The result is conditional and not "
    "repeatably demonstrated. Each named container/image was removed after evidence collection."
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
        status.get("finalScreenshotCaption", "Docker-Wine WebView result."),
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


page(25, "Wine 11.21 control and candidate result")
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
    "Every visible control/candidate result required the same intrusive three-cycle window-state "
    "helper. The candidate is GUI/workload 3/3 but full acceptance 1/3; the control is full "
    "acceptance 1/2. Verdict: NOT YET DEMONSTRATED repeatably. The evidence supports conditional "
    "laboratory feasibility, not a default environment or a claim about another proprietary app."
)


page(26, "Verification and repository inventory")
table(["Verification", "Observed result"], [
    ["Private repository", "TheSlayer455/octane-wslc-lab; private main and private v0.1.1 prerelease."],
    ["Windows artifact", status.get("windowsBuild", "")],
    ["Node checks", "15 PASS: app/probe contracts, formatting, summary, literal paths, cancellation, failures, export state."],
    ["Rust core", "4 historical PASS in measured installer build: fixtures/hash, path errors, export/no-overwrite, limits."],
    ["PowerShell", "48 mocked assertions PASS; adapter/lifecycle/schema/cleanup behavior checked."],
    ["Bash / Ansible", "Current application/probe helpers pass bash -n; existing SER8 playbooks retain prior syntax evidence."],
    ["Docker doctor", "PASS with real alpine run, known-file copy-out, and managed cleanup."],
    ["Minimal diagnostic", "Hash 82cd1c...; environment/controller/navigation/DOM/input/timers PASS; pixels FAIL in three profiles."],
    ["Controlled ole32", "Control/MR !12477 comparison completed; rendering unchanged; no crash in either member."],
    ["Live GUI", "Wine 11.21 control 1/2 full; candidate GUI/workload 3/3 but complete scenario 1/3."],
    ["Cleanup", "No Octane-managed Docker container remained after measured runs; unrelated resources untouched."],
], [112, 380], compact=True)
h("Repository map")
table(["Path", "Purpose"], [
    ["crates/octane-core/", "Analysis/report/export library and unit tests."],
    ["src-tauri/", "Windows Tauri host, config, resources, icon, NSIS/WebView settings."],
    ["ui/ and fixtures/", "Static frontend and deterministic eight-file workload."],
    ["diagnostics/webview2-win32/", "Minimal native Win32 WebView2 diagnostic and event logging."],
    ["scripts/Runtime*.ps1", "Engine adapter and Wine environment profiles."],
    ["scripts/RunState.ps1", "Atomic state, normalized results, JUnit, checksum synchronization."],
    ["scripts/Doctor/Start/Record/Collect/Stop", "Public operator lifecycle."],
    ["scripts/Invoke/Review/Validate", "Native probe, installed-app scenario, visual review, and independent report contract."],
    ["lab/", "Pinned profile Dockerfiles, helpers, and strict native-SER8 Ansible lifecycle."],
    ["tests/", "Node behavior tests and mocked adapter/lifecycle harness."],
    [".github/workflows/", "Private Windows installer build and artifact upload."],
    ["docs/ and tools/", "Validation snapshot, visual evidence, PDF, and generator."],
    ["artifacts/runs/evidence", "Generated installer intake, run state, and portable output; Git-ignored."],
], [170, 322], compact=True)
p(
    "Generated target/, node_modules/, artifacts/, runs/, and evidence/ are not committed. "
    "Never commit a desktop password, raw inspect dump, credential file, or production report."
)


page(27, "References and roadmap")
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
    ("Wine bug 60225: cross-process IDropTarget_Release report", "https://bugs.winehq.org/show_bug.cgi?id=60225"),
    ("Wine MR !12477: revoke foreign drop targets in their own process", "https://gitlab.winehq.org/wine/wine/-/merge_requests/12477"),
    ("G6rm0k: wine-ole32-fix proof of concept", "https://github.com/G6rm0k/wine-ole32-fix"),
    ("WebView2Feedback 5720: rendering/composition reports", "https://github.com/MicrosoftEdge/WebView2Feedback/issues/5720"),
    ("JustNotesa: Solid Edge Wine fixes reviewed source", "https://github.com/JustNotesa/solid-edge-wine-fixes"),
    ("khoipm06: wuwa-tappo-wine community implementation", "https://github.com/khoipm06/wuwa-tappo-wine"),
    ("Source conversation: Run Windows App Containers", "chatgpt-conversation://6af79ffb-6048-83ea-b689-8269484af53d"),
]:
    link(label, url)
h("Next milestone")
p(status.get("nextMilestone", "Qualify the identical installer on supported Windows."))
h("After compatibility is understood")
p(
    "Add a separately versioned Fixed Version WebView2 artifact; execute native Windows GUI "
    "automation; add a validated GitLab wrapper if that provider is needed; compare fresh and "
    "prepared-preview performance without confusing their claims; then add SBOM, vulnerability "
    "scan, and signed provenance. None of those supply-chain steps can substitute for visible "
    "WebView repainting or correct exported data."
)
p(
    "A different proprietary Windows installer can use the same artifact/profile/scenario "
    "contract without sharing source. Its installation path, executable discovery, dialogs, "
    "workload, and acceptance data must be separately configured and reported."
)


def decorate(canvas, doc):
    canvas.setTitle("Octane - Complete Windows Installer Compatibility Lab Guide")
    canvas.setAuthor("Octane Lab")
    canvas.setStrokeColor(colors.HexColor("#dce5eb"))
    canvas.line(54, 44, 558, 44)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#657989"))
    canvas.drawString(54, 30, "OCTANE / PRIVATE PROJECT REFERENCE / GUIDE REVISION 5")
    canvas.drawRightString(558, 30, str(doc.page))


doc = SimpleDocTemplate(
    str(DEST), pagesize=(612, 792), rightMargin=54, leftMargin=54,
    topMargin=44, bottomMargin=60,
)
doc.build(story, onFirstPage=decorate, onLaterPages=decorate)
print(DEST)
