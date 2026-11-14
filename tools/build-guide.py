"""Build the single project reference. Requires reportlab; no network calls."""
from pathlib import Path
import json, html, hashlib
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, Preformatted, Image as RLImage
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'docs'/'Octane-Complete-Guide.pdf'
DEST.parent.mkdir(exist_ok=True)
status_path=ROOT/'docs'/'validation.json'
status=json.loads(status_path.read_text()) if status_path.exists() else {}
styles=getSampleStyleSheet()
styles.add(ParagraphStyle(name='Body',fontName='Helvetica',fontSize=10,leading=14,spaceAfter=9,textColor=colors.HexColor('#253442')))
styles.add(ParagraphStyle(name='CodeBlock',fontName='Courier',fontSize=8,leading=11,spaceBefore=5,spaceAfter=10,backColor=colors.HexColor('#edf2f5'),borderPadding=10))
styles.add(ParagraphStyle(name='SmallNote',fontName='Helvetica',fontSize=8,leading=11,textColor=colors.HexColor('#566778'),spaceAfter=6))
styles.add(ParagraphStyle(name='CompactNote',fontName='Helvetica',fontSize=7.4,leading=9.5,textColor=colors.HexColor('#566778'),spaceAfter=4))
for name,size,leading in [('Title',30,34),('Heading1',21,25),('Heading2',12,16)]:
    styles[name].fontName='Helvetica-Bold';styles[name].fontSize=size;styles[name].leading=leading;styles[name].textColor=colors.HexColor('#102f43')
styles['Heading2'].spaceBefore=9
story=[]
def p(text):story.append(Paragraph(text,styles['Body']))
def h(text):story.append(Paragraph(text,styles['Heading2']))
def code(text):story.append(Preformatted(text.strip('\n'),styles['CodeBlock']))
def page(number,title):
    if story:story.append(PageBreak())
    story.append(Paragraph(f'OCTANE / REFERENCE {number:02d}',styles['SmallNote']))
    story.append(Paragraph(title,styles['Heading1']));story.append(Spacer(1,12))
def table(headers,rows,widths,compact=False):
    cell_style=styles['CompactNote'] if compact else styles['SmallNote']
    padding=4 if compact else 7
    data=[[Paragraph(html.escape(str(c)),cell_style) for c in row] for row in [headers]+rows]
    t=Table(data,colWidths=widths,hAlign='LEFT',repeatRows=1)
    t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#dceaf1')),('GRID',(0,0),(-1,-1),.5,colors.HexColor('#D9D9D9')),('VALIGN',(0,0),(-1,-1),'MIDDLE'),('TOPPADDING',(0,0),(-1,-1),padding),('BOTTOMPADDING',(0,0),(-1,-1),padding),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#f4f7f9')])]))
    story.append(t);story.append(Spacer(1,9))
def link(label,url):p(f'<link href="{html.escape(url,quote=True)}" color="#14658c">{html.escape(label)}</link>')
def image_grid(items):
    cells=[]
    for image_path,caption in items:
        pic=RLImage(str(ROOT/image_path))
        pic.drawWidth=238
        pic.drawHeight=238*pic.imageHeight/pic.imageWidth
        cells.append([pic,Paragraph(html.escape(caption),styles['SmallNote'])])
    data=[cells[i:i+2] for i in range(0,len(cells),2)]
    grid=Table(data,colWidths=[246,246],hAlign='LEFT')
    grid.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(-1,-1),8),('TOPPADDING',(0,0),(-1,-1),3),('BOTTOMPADDING',(0,0),(-1,-1),8)]))
    story.append(grid)

page(1,'Octane<br/>Windows application container lab')
p('<b>Complete implementation, operating, and measured-validation reference</b><br/>Octane 0.1.0 | Guide revision 2 | November 13, 2026 | Windows x64 + WSLC + Wine')
p('Octane is a separate Rust/Tauri Windows desktop application built to test installing and operating a real Windows GUI inside a disposable Linux container. Its useful workload is file analysis: extension groups, SHA-256 hashes, matching contents, and JSON export. Your existing application, installer, and source code are outside this project.')
link('Private repository: TheSlayer455/octane-wslc-lab','https://github.com/TheSlayer455/octane-wslc-lab')
h('What is delivered')
p('The private repository contains application source, sample files, a Windows NSIS installer workflow, PowerShell lifecycle scripts, the Wine desktop image recipe, regression checks, and this single reference. The final controlled installer, matching manifest, and this guide are retained as private v0.1.1 prerelease assets. Builds also produce private GitHub Actions artifacts.')
h('The key compatibility boundary')
p('WSLC runs Linux containers. Wine provides the Windows API compatibility layer. Tauri on Windows uses Microsoft WebView2. Building an installer successfully does not prove that WebView2 will install, render, or behave correctly under Wine. A usable GUI and a correct exported report are separate acceptance gates.')
h('Recorded delivery status')
p(html.escape(status.get('summary','Windows build in progress. Local formatting, UI behavior, and mocked PowerShell checks pass. WSLC runtime operations returned ERROR_TIMEOUT; Wine GUI acceptance remains untested.')))
h('How to use this document')
p('Start with pages 4-7 to repair WSLC, build or download, and run the lab. Pages 8-11 explain the application and automation. Pages 12-15 cover evidence, security, acceptance, and failure diagnosis. Pages 16-20 cover maintenance, measured visual evidence, verification, inventory, and references. Commands use <b>Windows PowerShell from the repository root</b> unless a browser-desktop terminal is explicitly specified.')

page(2,'Contents and scope')
table(['Page','Topic'],[[str(i),t] for i,t in enumerate(['Purpose and delivery status','Contents and scope','Architecture and lifecycle','Prerequisites and host diagnosis','Building and obtaining the installer','Starting a fresh lab','Installing and using Octane','File-analysis behavior','JSON report contract','Application implementation','Automation implementation','Evidence and cleanup','Security and reproducibility','Acceptance test protocol','Troubleshooting decision guide','Development and CI maintenance','Measured GUI and WebView2 evidence','Verification record','Repository inventory','References and extension roadmap'],1)],[42,450],compact=True)
p('This project deliberately tests the Windows installer and Windows Tauri runtime. It does not substitute a native Linux build or a browser rewrite. The browser is a remote view of a Linux desktop displaying Wine windows. No Docker Desktop, Podman engine, Windows VM, or RHEL reconfiguration is required by the scripts.')
p('<b>Shell boundary:</b> wsl.exe and wslc.exe are Windows executables. Run every wsl/wslc command in Windows PowerShell or Command Prompt, not at an Ubuntu/RHEL prompt. A Linux shell reporting “wslc: command not found” is expected and does not mean the Windows installation is missing.')
p('A Windows VM remains the appropriate follow-up for native Windows release qualification. This repository does not provision that VM, automate a proprietary installer, sign a production release, or claim to be a hardened service for arbitrary untrusted executables.')

page(3,'Architecture and lifecycle')
code('''Windows source checkout / private GitHub repository
  |
  +-- GitHub Actions: Windows 2022 runner
  |     Rust MSVC + Tauri CLI + NSIS + offline WebView2
  |       -> Octane-setup.exe + installer-manifest.json
  |
  +-- Windows PowerShell -> wslc.exe
        build image with installer and sample files
        run fresh named Linux container
          LinuxServer WineGUI / Selkies desktop
            /config/octane-prefix  (fresh Wine state)
            Wine -> NSIS -> Octane.exe -> WebView2
            /config/octane-evidence (logs + JSON export)
                |
                +-- HTTPS browser view on 127.0.0.1:3001
                +-- wslc container cp -> host evidence
''')
h('Build boundary')
p('The Windows runner compiles and packages Octane. It does not run the installer on your laptop. WebView2 is bundled in offline-installer mode; building still needs internet access to obtain dependencies, NSIS tooling, and the Microsoft runtime package.')
h('Runtime boundary')
p('Each launcher invocation generates a new ten-character identifier, image tag, container name, and desktop password. It requests no host bind mounts. The installer and fixtures are copied into image layers. The Wine prefix lives in that container under /config; base-image anonymous volumes, if present, must be removed during cleanup.')
h('Evidence boundary')
p('The app analyzes files within the container and exports a report there. The collector copies the evidence directory outward using WSLC, without exposing a shared host folder. Container state is retained until you explicitly collect and remove it. Each run is independent; restarting an existing container preserves its existing prefix.')

page(4,'Prerequisites and host diagnosis')
table(['Component','Requirement / role'],[
['Host','Windows x64 with virtualization and WSL available; administrative setup may be required for WSL itself.'],
['WSLC','Microsoft documents WSL 2.9.3 or later. Use a version with build, run, inspect, logs, exec, container cp, and rm -v.'],
['Local build only','Rust stable MSVC; Visual Studio C++ Build Tools with Desktop development with C++ and Windows SDK; Node.js 22; pnpm 11.25.0; Git.'],
['No local compiler route','Download the successful private Actions build artifact and use its installer plus matching manifest.'],
['Connectivity','GitHub/package registries/Microsoft downloads for builds; LinuxServer registry for the desktop image.'],
['Capacity','Plan several GB of free disk for toolchains, images and WebView2. Actual image sizes depend on upstream versions.']],[108,384])
code('''wsl --version
wslc version
wslc run --rm hello-world
wslc container cp --help
wslc build --help
wslc run --help''')
p('When WSL is below the requirement, update it with <b>wsl --update</b> and repeat the checks. An update can affect other WSL work, so schedule it appropriately. The scripts do not update WSL, edit .wslconfig, stop other distributions, or replace your RHEL environment.')
h('Observed timeout and validated repair')
p('This host reported WSL/WSLC 3.0.1.0. Control-plane commands responded, but data-plane commands timed out while ProtonVPN supplied a full-tunnel on-link 0.0.0.0 default route. WSLC\'s default Consommé networking selected that unusable gateway for the utility VM; dockerd did not become ready before the boot timeout. Moving the session VHD did not help, which ruled out the storage file as the cause.')
code(r'''# Windows PowerShell (not a Linux distribution shell)
$settings = Join-Path $env:LOCALAPPDATA 'wslc\settings.yaml'
# Create the parent folder when needed, then save this YAML:
session:
  networkingMode: nat
  idleTimeout: 900

wslc system session terminate
wslc run --rm hello-world''')
p('The active host setting is %LOCALAPPDATA%\\wslc\\settings.yaml. After switching the WSLC session to NAT and terminating the stale session, hello-world pulled and exited successfully in 3.8 seconds. A fresh Octane image then built and ran. NAT is a targeted workaround for this route-selection conflict; retest it after VPN, WSL, or WSLC updates. The previous utility-session VHD was retained as a timestamped backup rather than deleted.')

page(5,'Building and obtaining the installer')
h('Download the compiled private release')
p('Open the repository\'s <b>Releases - v0.1.1</b> page. Download Octane-setup.exe and installer-manifest.json into this checkout\'s artifacts/ directory, creating that directory if necessary. Both assets must come from the same release. The release also retains this guide and its measured compatibility conclusion.')
link('Private v0.1.1 release','https://github.com/TheSlayer455/octane-wslc-lab/releases/tag/v0.1.1')
h('For later builds: private GitHub Actions')
p('Select Actions and open a successful <b>Windows installer</b> run. Download <b>Octane-windows-x64</b>. Its ZIP contains artifacts/Octane-setup.exe, artifacts/installer-manifest.json, and Cargo.lock. Copy the two artifacts/ files into this checkout\'s artifacts/ directory. Actions artifacts expire after 14 days; release assets remain until explicitly removed.')
link('Windows installer workflow','https://github.com/TheSlayer455/octane-wslc-lab/actions/workflows/windows-build.yml')
h('Local build')
code('''git clone https://github.com/TheSlayer455/octane-wslc-lab.git
cd octane-wslc-lab
./scripts/Build-Octane.ps1''')
p('Authenticate to GitHub using your usual credential manager. The build runs pnpm install with the frozen lockfile, locked Rust core tests, six JavaScript checks, the mocked PowerShell harness, and Tauri\'s NSIS build. A nonzero result stops the script. The output name is normalized to Octane-setup.exe; exactly one matching NSIS installer is required.')
h('Manifest and verification')
p('The manifest records schemaVersion, file, SHA-256, sourceCommit, builtAtUtc, webviewMode, and signed=false. The launch script hashes the installer and rejects a mismatch. The manifest is an integrity companion, not an independently signed attestation. Anyone able to replace both files can create a matching pair.')
code('''Get-FileHash ./artifacts/Octane-setup.exe -Algorithm SHA256
Get-Content ./artifacts/installer-manifest.json''')
p('The build creates an installer without installing Octane on the host. The installer is unsigned; Windows trust prompts are expected. Its bundled offline WebView2 package adds substantial size. This project does not aim to reproduce the approximate 400 MB size of your separate application.')

page(6,'Starting a fresh lab')
code('''./scripts/Start-OctaneLab.ps1
# If port 3001 is in use:
./scripts/Start-OctaneLab.ps1 -Port 3002
# To freeze the upstream image after validation:
./scripts/Start-OctaneLab.ps1 -BaseImage `
  'lscr.io/linuxserver/winegui@sha256:ACTUAL_DIGEST' ''')
p('Replace ACTUAL_DIGEST with a real image digest; it is a placeholder, not a runnable value. The default base tag is latest so that the initial experiment can retrieve the current image. It is mutable and must not be treated as a reproducible baseline.')
h('What the launcher does')
p('It checks the installer and matching hash, checks WSLC availability, generates a random run ID and a 24-byte cryptographic password, builds the image using lab/Dockerfile, and starts it detached. The container is labeled com.octanelab.managed=true, receives 1 GB shared memory, and publishes only 127.0.0.1:PORT:3001. No host filesystem mount or privileged flag is requested.')
p('The printed container name has the form octane-0123456789. The corresponding image is octane-lab:0123456789. The launcher prints the desktop address, octane username, generated password, and runs/NAME.json metadata path. Retain the actual name for evidence collection and cleanup. It does not automatically open the browser.')
h('Connecting')
p('Open the printed HTTPS localhost address. LinuxServer uses a self-signed certificate by default. Confirm that you are visiting your own local endpoint before accepting its certificate. Use the generated credentials. Wait for the desktop, open a terminal within it, and run the commands on page 7 as the normal desktop user.')
p('For non-interactive diagnostics, the helper now detects the live Xwayland socket and selects DISPLAY=:0. The tested WineGUI image advertises DISPLAY=:1 to exec sessions even though its visible desktop is :0; relying on that inherited value caused invisible windows. The helper also supplies /config/.XDG as XDG_RUNTIME_DIR when it is absent.')
p('Startup may take time while the image initializes. If the launcher fails after creating an image or container, inspect only that printed/generated run and clean up its resources explicitly. Do not assume that an interrupted launcher removed everything. Run metadata is written after successful start and intentionally omits the password.')

page(7,'Installing and using Octane')
h('Inside the browser desktop terminal')
code('''octane-lab notepad
# Interact with Wine Notepad, then close it.
octane-lab install
# Complete the interactive installer wizard.
octane-lab launch''')
p('Run the commands one at a time. The helper uses WINEPREFIX=/config/octane-prefix and WINEARCH=win64 consistently. The NSIS installer uses current-user installation. Its bundled Microsoft WebView2 installer may display an additional wizard. Complete or record every prompt. A zero installer exit code alone is not a GUI pass.')
h('Exercise the workload')
p('<b>Load sample set:</b> the installed app locates bundled resources, reads the eight sample files, and displays 8 analyzed files, 6 extension groups, 1 duplicate set, and 0 errors. hello.txt and hello-copy.txt should be the matching pair. Extension groups are txt, csv, json, md, html, and (none).')
p('<b>Choose files:</b> a native Windows file picker appears inside Wine. Select files available within the container, such as the copies under Z:\\opt\\octane\\fixtures. Cancel once and confirm the current analysis remains visible. Select additional test files to exercise file paths and permission failures. There is no automatic host-file upload or recursive folder selection.')
p('<b>Export JSON:</b> use the native save dialog and save a new filename under the evidence directory:')
code(r'Z:\config\octane-evidence\report.json')
p('The file must not already exist. Existing destinations are rejected even if the dialog offers an overwrite confirmation. Choose a different name for each export. Canceling export leaves the current report intact. Confirm that the app reports a saved path and that the JSON is present before collecting evidence.')
h('What to record')
p('Record visible rendering, responsive controls, working native dialogs, sample counts, exported content, and any WebView2 prompts or errors. Capture screenshots with the desktop/browser capture controls and save them into the evidence directory or your collected evidence folder. Screenshot capture is a manual acceptance step, not implemented by the helper.')

page(8,'File-analysis behavior')
table(['Rule','Implemented behavior'],[
['Selection','Native multi-file selection. Maximum 2,048 paths submitted in one analysis. A new analysis replaces the previous report.'],
['Path handling','Canonicalize each selected path and skip repeated canonical paths. Symlinks resolve to their targets; distinct hard-link names can appear separately.'],
['File contents','Read regular files in 64 KiB chunks and calculate lowercase SHA-256. No file parsing, decompression, execution, indexing service, or cloud upload.'],
['Limits','256 MiB per file and 2 GiB total successfully analyzed contents per batch. Exceeding a per-file or remaining-batch limit records a file error.'],
['Extension','Final filename extension lowercased; no extension becomes (none). This is a filename group, not MIME or content-type validation.'],
['Duplicates','Two or more successfully analyzed paths with the same SHA-256 form a duplicate set. This is content matching, not an automatic deletion decision.'],
['Failures','Missing, unreadable, non-regular, oversized, or changing files are listed in errors. Other eligible files continue.'],
['Changes','Compare length and modification time before/after hashing. Reject a detected change. This is not an atomic filesystem snapshot.'],
['Output','Export the backend-held latest report to a new file only. Inputs are not opened for writing.']],[100,392])
h('Interpretation limits')
p('Zero-byte files are valid and share the SHA-256 of empty contents. Hash collisions are theoretically possible; the app does not compare bytes after grouping by hash. Concurrent mutation with unchanged metadata can evade the stability check. Paths are serialized with lossy Unicode conversion if a path cannot be represented as UTF-8; Windows filenames generally round-trip, but unusual paths need explicit testing.')
p('Errors do not count toward totalBytes or extension counts. The limits constrain the successful batch and each read, not the absolute I/O across every failed attempt. The core is intended for a small compatibility workload, not large forensic acquisitions or hostile filesystem races.')

page(9,'JSON report contract')
p('Reports use schemaVersion 1. Rust serializes the backend-owned report, so frontend display text is never trusted as the source of exported analysis. The following is an illustrative one-file report; real paths and hashes vary.')
code(r'''{
  "schemaVersion": 1,
  "files": [{
    "path": "C:\\example\\hello.txt",
    "extension": "txt",
    "bytes": 6,
    "sha256": "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03"
  }],
  "errors": [],
  "groups": { "txt": 1 },
  "duplicateSets": [],
  "totalBytes": 6
}''')
table(['Field','Meaning'],[
['schemaVersion','Integer 1. Increment it when making an incompatible report-format change.'],
['files[]','Successful records in selection order (sample paths sorted before analysis). Canonical path, extension group, byte count, content hash.'],
['errors[]','Original submitted path plus an OS or application error string. Error wording is not a stable machine-readable code.'],
['groups','Sorted extension keys mapped to successful-file counts.'],
['duplicateSets[]','Arrays of canonical paths for hashes appearing at least twice. Hash ordering determines set ordering; no numeric duplicate ID is persisted.'],
['totalBytes','Sum of successful file sizes; file metadata and JSON formatting are excluded.']],[95,397])
p('No timestamp, machine ID, or source build ID is embedded in this report format. Correlate reports with the separately collected run metadata and installer manifest. Paths can contain sensitive names; review reports before sharing. Export errors may leave a partial newly created file if a write or disk sync fails. Select a new output path when retrying.')

page(10,'Application implementation')
h('Rust core: crates/octane-core/src/lib.rs')
p('The standalone library owns FileRecord, FileError, Report, resource limits, analyze, hash_file, and export_new. BTreeMap and BTreeSet provide predictable grouping and canonical-path deduplication. sha2 performs streaming SHA-256; serde and serde_json implement serialization. export_new uses atomic create_new followed by write_all and sync_all to avoid replacing an existing file.')
h('Tauri host: src-tauri/src/main.rs')
p('Three commands form the app interface: choose_files opens the native picker and optionally returns a report; load_sample locates the fixtures in the installed resource directory and returns a report; export_report prompts for an output and optionally returns its saved path. Cancel returns null for picker/export. Failures return error text. A Mutex-protected optional Report stores the latest completed analysis.')
p('Native dialogs, hashing, and output writing execute through Tauri spawn_blocking from async commands. The frontend disables its actions while work is pending. The export command takes no file contents from JavaScript: it clones the backend report. Sample-directory listing is small and occurs before the hashing worker. There is no cancellation button, background queue, or progress percentage.')
h('Frontend: ui/')
p('Static HTML, CSS, and JavaScript are bundled into the executable; no frontend development server is needed. app.js invokes Tauri, renders totals and rows, handles cancellation/errors, and restores controls. It writes filenames via textContent rather than injecting HTML. format.mjs formats byte sizes and summaries. UI state is transient; closing the application loses the last report unless exported.')
h('Packaging and capability boundary')
p('tauri.conf.json defines the app ID com.octanelab.octane, main-window size, bundled fixture directory mapping, NSIS current-user installation, and offline WebView2 mode. The compatibility rebuild disables Tauri\'s internal WebView2 drag/drop handler because Octane uses native pickers and the baseline Wine crash ended in IDropTarget_Release. A final controlled variant also passes --disable-gpu while retaining WRY\'s three default disabled WebView2 features, isolating the graphics path without adding no-sandbox flags. The CSP allows local scripts/styles and Tauri IPC, without remote script origins. No shell, network, or filesystem frontend plugins are enabled. The three custom Rust commands implement the needed filesystem access. This is not a general command executor.')

page(11,'Automation implementation')
table(['Component','Behavior and failure boundary'],[
['Build-Octane.ps1','Frozen pnpm install; locked Rust tests; frontend checks; mocked script checks; NSIS build; normalized EXE and SHA-256 manifest. Stops on failing native exit codes.'],
['Start-OctaneLab.ps1','Hash validation, unique run/image names, cryptographic password, WSLC build/run, loopback desktop port, run metadata. Does not install Octane on Windows.'],
['Wslc.ps1','Invoke-Wslc wraps native exit codes. Assert-OctaneContainer validates name pattern and managed label before collection/removal.'],
['Collect-Evidence.ps1','Copies runtime logs and /config/octane-evidence into a unique host folder; includes run metadata when available. Avoids persisting raw inspect with passwords.'],
['Stop-OctaneLab.ps1','Removes only the requested managed container with rm -f -v; optional removal of its matching run image. Evidence should be collected first.'],
['lab/Dockerfile','.dockerignore admits only lab files, installer/manifest, and fixtures. COPY bakes those assets into a LinuxServer WineGUI-derived image.'],
['lab/octane-lab','Sets one 64-bit prefix and selects the live :0 display. notepad records Wine/kernel/manifest; install runs NSIS; launch finds exactly one installed octane.exe under Wine users.']],[116,376])
h('Logging semantics')
p('The Bash helper tees separate timestamped stage logs to the evidence directory and writes the Wine process exit code into a sibling .exitcode file. PIPESTATUS captures the Wine command result rather than tee\'s exit code. The default WINEDEBUG enables timestamp and exception diagnostics while disabling unrelated channels. Override WINEDEBUG in the desktop terminal when investigating a specific failure.')
p('The helper records command completion, not GUI correctness. Commands with the same stage and second-level timestamp may reuse log filenames; avoid rapid repeated invocations or copy evidence between attempts. launch intentionally refuses zero or multiple installed EXEs. It does not guess alternate installation locations or silently fall back to another executable.')

page(12,'Evidence collection and cleanup')
code('''# Use the actual name printed by the launcher.
./scripts/Collect-Evidence.ps1 -Container octane-0123456789

# After verifying the copied evidence:
./scripts/Stop-OctaneLab.ps1 -Container octane-0123456789 `
  -RemoveImage''')
h('Expected evidence folder')
code('''evidence/octane-ID-UTC_TIMESTAMP/
  container.log
  run.json
  installer-manifest.json   # copied by octane-lab notepad
  wine-version.txt         # copied by octane-lab notepad
  kernel.txt               # copied by octane-lab notepad
  notepad-TIMESTAMP.log / .exitcode
  install-TIMESTAMP.log / .exitcode
  launch-TIMESTAMP.log / .exitcode
  report.json              # exported manually from Octane
  screenshots...           # saved manually
''')
p('Not all files exist if a stage was skipped or failed. The collector copies the directory as it exists; it does not manufacture missing reports, screenshots, or a pass result. Wait for stage completion and finish export before collecting if you need a consistent record. The container can remain running while logs are copied.')
h('What removal does')
p('rm -f -v terminates the named container and requests removal of its anonymous volumes, including disposable /config state if declared by the base image. -RemoveImage removes only the run-specific octane-lab tag. It does not prune base images or delete unrelated containers. Host evidence and runs metadata remain. The source artifacts directory remains as well.')
h('Retaining or retrying')
p('Keep a failed container temporarily when troubleshooting. A repeated Start-OctaneLab creates a different clean environment. Restarting the same container is a continuation of the previous prefix and must not be described as a fresh install. If collection fails, fix the copy command or destination and repeat before removing the container.')

page(13,'Security and reproducibility')
h('Access and secrets')
p('The repository is private. Desktop access is published on loopback and protected by a per-run password. The password is printed for the operator and is also part of container environment metadata; a user with runtime-admin access can inspect it. Run JSON omits it. Do not paste full launcher transcripts or raw container inspection into public reports. The collector skips raw inspect, but logs may still contain sensitive information.')
h('Container privileges and trust')
p('No host bind mounts, runtime socket, GPU passthrough, host networking, privileged mode, or security-profile bypass is requested. The desktop image itself provides powerful in-container access and follows its upstream privilege model. Containers are not equivalent to an independently hardened Windows VM. This lab is for the Octane test artifact and controlled inputs, not arbitrary malware or multi-user hosting. Outbound network access is not blocked by the scripts.')
h('Data exposure')
p('The installer and fixtures are baked into image layers and may remain in the local image cache. Reports expose canonical paths and file hashes. Input contents stay in the environment where they were selected; the app has no intentional upload behavior. LinuxServer, Wine, WebView2, and dependency downloaders have their own behavior and licensing. Do not place production secrets in fixtures or CI logs.')
h('Reproducibility')
p('pnpm-lock.yaml and Cargo.lock lock dependency resolution after the initial build. The CLI is pinned to 2.10.1. The default LinuxServer latest tag, Windows runner image, stable Rust toolchain, Actions major-version tags, and downloaded offline WebView2 version can change. Full byte-for-byte reproducibility is not claimed. Use a validated base digest, a specific Rust release, and pinned Actions commit SHAs when promoting the experiment into a maintained test service.')
p('Microsoft documents WebView2 against supported Windows client/server versions; Wine is outside that support matrix. A Wine pass would be environment-specific evidence, and a Wine failure does not establish a defect on supported Windows. Keep a native Windows baseline as the release authority.')
h('Release posture')
p('The installer is unsigned and no automatic updater is configured. No open-source license grant is supplied for project source; third-party components retain their licenses. GitHub Actions private-repository usage can consume account quotas or incur charges under that account\'s settings. Actions artifacts expire after 14 days; this delivery\'s private release retains the installer, manifest, and guide. No automatic release publishing or public hosting is configured.')

page(14,'Acceptance test protocol')
table(['Gate','Pass evidence'],[
['A. WSLC','hello-world exits successfully; required runtime commands work; record WSLC version.'],
['B. Desktop','Fresh container starts; local authenticated HTTPS desktop renders and receives mouse/keyboard input.'],
['C. Basic Wine','Wine Notepad renders, accepts typing, and closes; Wine version and logs collected.'],
['D. Installer','Current-user NSIS wizard and WebView2 installation complete; record prompts and exit codes.'],
['E. Application','Installed Octane shows its actual Tauri UI; controls respond. A process or blank window is insufficient.'],
['F. Sample workload','Load sample: 8 files, 6 groups, 1 duplicate set, 0 errors; matching pair is hello.txt and hello-copy.txt.'],
['G. Native dialogs','Choose files and save dialogs render/respond. Canceling retains state. Unicode/space paths tested separately.'],
['H. Export','New JSON export parses and matches displayed counts and expected hashes; existing-file export fails without changing that file.'],
['I. Reset','Evidence copied before removal. New launcher run has a fresh prefix and repeats gates successfully.']],[98,394])
h('Evidence rules')
p('For each gate record PASS, FAIL, or NOT TESTED, UTC time, installer SHA-256, source commit, base image reference, Wine/WSLC versions, and brief observations. Attach screenshots at D-G and the parsed JSON at H. Do not infer a pass from a prior gate. If a prerequisite blocks later gates, mark the later gates NOT TESTED.')
h('Native Windows baseline')
p('For authoritative Windows behavior, install the same artifact in a disposable Windows VM or test host and repeat E-H. Keep that evidence separate. A Wine failure can be a compatibility limitation even when native Windows passes. A Wine success is useful evidence for this environment, not a universal Windows compatibility guarantee. VM provisioning is outside this implementation.')

page(15,'Troubleshooting decision guide')
h('WSLC cannot start a basic container')
p('First confirm that the prompt is Windows PowerShell: wsl.exe and wslc.exe are host commands and are not expected inside Ubuntu/RHEL. Check wsl --version and wslc version, then retry hello-world and wslc container ls. Version/help success alone does not prove the utility VM is healthy. If a full-tunnel VPN is active and the timeout matches the recorded 3.0.1 route failure, set session.networkingMode to nat in %LOCALAPPDATA%\\wslc\\settings.yaml, terminate only the WSLC system session, and retry hello-world. Do not install Ubuntu\'s unrelated “wsl” package, remove distributions, or globally prune images as a first response.')
h('Desktop cannot be reached')
p('Check the launcher\'s exit code, printed port, and container status. Use wslc logs NAME for startup errors. Confirm the port is unused or launch with -Port 3002. Use https, verify the local certificate, and enter the generated password. If logs report sandbox or graphics problems, diagnose the image/runtime combination; do not automatically grant privileged mode or disable host security profiles.')
h('Notepad fails')
p('This is a Wine/display/prefix problem before Tauri. Check the notepad log, Wine version, DISPLAY environment, /tmp/.X11-unix/X0, and prefix permissions. In the measured image the interactive Xwayland display was :0 while inherited image metadata said :1; the helper now corrects that mismatch. Run it as the desktop user. Reproduce in a new lab so mixed prefix ownership or previous installations cannot contaminate the result.')
h('Installer or WebView2 fails')
p('Save the installation-stage log, all prompts, and the exit code. In the measured baseline the current-user NSIS installer returned 0 and installed WebView2 157.0.4341.60, including msedgewebview2.exe. Browser, renderer, network, storage, crashpad, and GPU processes then started. That proves installation and process startup, not rendering compatibility. The first Octane build produced a white window and Wine page fault in IDropTarget_Release. Preserve that evidence and test any workaround as a distinct build.')
h('Octane starts blank or dialogs fail')
p('Record rendering and launch logs separately from installer success. In this run, dragDropEnabled=false removed the Wine host access violation but left a black frame. The final build proved --disable-gpu was passed to WebView2; browser/renderer processes started, GPU subprocesses still crashed, all WebView2 children exited, and both installer handoff and clean standalone launch remained black. Closing that blank frame produced launch exit 0, demonstrating that exit code alone is not a render pass. Avoid no-sandbox flags. Compare the same artifact on supported Windows before blaming Octane\'s core logic.')
h('Build or collection fails')
p('For locked dependency failures, restore the committed lockfiles. For linker failures install MSVC C++ tools/SDK on the build host. For collection failures check container name/managed label and WSLC cp support; retain the container until the evidence is copied. README and this guide point to the same lifecycle scripts.')

page(16,'Development and CI maintenance')
code('''pnpm install --frozen-lockfile
pnpm test
cargo test -p octane-core --locked
./tests/scripts.test.ps1
pnpm exec tauri dev
./scripts/Build-Octane.ps1''')
p('Run Tauri development and builds on a properly configured Windows development machine. Rust core tests do not need the GUI running. The current core workspace shares a lockfile with the Tauri host. JavaScript tests use Node\'s built-in runner and no web server.')
h('Workflow contract')
p('The Windows installer workflow runs on main pushes, pull requests, or workflow_dispatch. It checks out source, sets Node 22 and pnpm 11.25.0, selects stable MSVC Rust, runs the build/test script, and uploads the EXE, manifest, and Cargo.lock. Permissions are contents:read; no signing key or release token is required. The job timeout is 40 minutes. Artifact upload fails if outputs are absent.')
p('The initial bootstrap run generates Cargo.lock if missing. Once committed, --locked prevents a normal build from silently resolving new Rust dependencies. Preserve the build\'s sourceCommit so that its artifact remains attributable even when later documentation commits change the repository head.')
h('Changing the project')
p('For behavior changes, update the core and tests first; add matching UI behavior and report-schema changes deliberately. Keep resource fixture counts and the known hello.txt hash synchronized with tests and this guide. A Tauri, WebView2, Wine, base-image, or WSLC update requires renewed compatibility acceptance, even if Rust unit tests continue to pass.')
p('For dependency updates, intentionally regenerate the appropriate lockfile, inspect the diff, rebuild, and retain a new artifact/manifest pair. For a distributable product, add code signing, an explicit licensing decision, immutable CI/image references, and Windows-native end-to-end automation. These are future steps rather than completed features.')
h('Regenerating this reference')
p('tools/build-guide.py uses ReportLab to produce docs/Octane-Complete-Guide.pdf. docs/validation.json supplies the verified build snapshot. Update both when the implementation or verification status changes, render the PDF, and check page layout before replacing the guide. The PDF is the single comprehensive narrative deliverable; README is an entry point.')

page(17,'Measured Wine GUI and WebView2 evidence')
p(status.get('evidenceSummary','The images below are from the measured WSLC/Wine run. Captions identify passed and failed gates; a visible process or window frame is not counted as rendered application content.'))
image_grid([
('docs/evidence/wine-notepad.png','Fresh prefix: Wine 11.0 Notepad rendered, accepted text, and exited 0.'),
('docs/evidence/webview2-install.png','Bundled WebView2 157.0.4341.60 installer reached completion inside Wine.'),
('docs/evidence/webview2-baseline-crash.png','Baseline Octane: Wine debugger captured the IDropTarget_Release access violation.'),
('docs/evidence/webview2-final.png',status.get('finalScreenshotCaption','Final controlled WebView2 result.')),
])
p('Screenshots were captured from the authenticated loopback WineGUI/Selkies stream. They contain no desktop password. Full stage logs, exit-code files, manifests, and run metadata were collected before each disposable container and its anonymous volume were removed.')

page(18,'Verification record')
p('<b>Verification date:</b> November 13, 2026, America/Chicago. GitHub timestamps may display November 14 in UTC.')
table(['Check','Observed result'],[
['Repository','Created under TheSlayer455; GitHub API returned private=true; source pushed to main.'],
['Node checks','6 passed: byte boundaries, report summary, literal filename rendering, picker cancellation, native error recovery, export cancellation/success. Native calls are mocked.'],
['PowerShell harness','8 assertions passed using a mock WSLC executable: loopback bind, no host mounts, no privileged flag, no persisted password, cp collection, volume cleanup, unrelated-name rejection, hash mismatch rejection.'],
['Static scripts','All five PowerShell scripts parsed. Bash helper passed bash -n.'],
['Rust and Windows build',status.get('windowsBuild','In progress at document generation; see linked workflow for current status.')],
['WSLC runtime',status.get('wslcRuntime','See the host diagnosis and retry before running the lab.')],
['Wine desktop',status.get('wineDesktop','Not tested.')],
['Installer / WebView2',status.get('installerAcceptance','Not tested.')],
['Octane launch',status.get('webviewAcceptance','Not tested.')],
['Workload / export',status.get('workloadAcceptance','Not tested.')],
['Native Windows GUI','NOT TESTED: no host installation performed. Compilation does not exercise installed GUI behavior.']],[116,376],compact=True)
run_links=[]
if status.get('baselineRunUrl'):run_links.append(f'<link href="{html.escape(status["baselineRunUrl"],quote=True)}" color="#14658c">baseline build</link>')
if status.get('dragDropRunUrl'):run_links.append(f'<link href="{html.escape(status["dragDropRunUrl"],quote=True)}" color="#14658c">drag/drop-disabled build</link>')
if status.get('runUrl'):run_links.append(f'<link href="{html.escape(status["runUrl"],quote=True)}" color="#14658c">final controlled build</link>')
if run_links:story.append(Paragraph('<b>Build records:</b> '+' | '.join(run_links),styles['CompactNote']))
identity=[]
if status.get('sourceCommit'):identity.append('<b>Installer source commit:</b> '+html.escape(status['sourceCommit']))
if status.get('installerSha256'):identity.append('<b>Installer SHA-256:</b> '+html.escape(status['installerSha256']))
if identity:story.append(Paragraph('<br/>'.join(identity),styles['CompactNote']))
p('Local script and frontend mocks validate control flow only. The four Rust tests cover the eight-file fixture contract and known SHA-256, repeated/missing/non-regular paths, export roundtrip/no-overwrite, and count/size limits. Measured Wine results are reported separately and never inferred from these tests. Unexecuted acceptance gates remain explicitly open.')

page(19,'Repository inventory')
table(['Path','Purpose'],[
['Cargo.toml / Cargo.lock','Rust workspace membership and resolved crate graph.'],
['crates/octane-core/','File-analysis library, report serialization, export rules, four core unit tests.'],
['src-tauri/Cargo.toml','Windows application and Tauri/rfd dependencies.'],
['src-tauri/build.rs','Tauri compile-time resource/packaging integration.'],
['src-tauri/src/main.rs','Application entry point, backend report state, native command bridge.'],
['src-tauri/tauri.conf.json','Window, local frontend, CSP, fixtures mapping, NSIS and WebView2 settings.'],
['src-tauri/icons/icon.ico','Multi-resolution Octane application icon.'],
['ui/index.html / style.css','Accessible action controls, status region, inventory table and responsive styling.'],
['ui/app.js / format.mjs','Native invocation, DOM rendering, state transitions and byte formatting.'],
['fixtures/','8 small files, 6 extension groups, one identical-content pair; no proprietary data.'],
['package.json / pnpm-lock.yaml','Pinned Tauri CLI and locked Node dependency graph.'],
['scripts/','Five PowerShell files for build, start, evidence, removal, and shared WSLC checks.'],
['lab/Dockerfile / octane-lab','Linux desktop image recipe and in-container Wine stage helper.'],
['tests/','Two JavaScript test files and the mocked PowerShell harness.'],
['.github/workflows/','Windows build, checks, and artifact publication within the private repository.'],
['.dockerignore / .gitignore','Minimal image context and exclusion of generated artifacts, evidence, run data and dependencies.'],
['.gitattributes','LF text normalization to keep Bash and fixture hashes stable.'],
['docs/ / tools/build-guide.py','Single PDF reference, validation snapshot and reproducible guide authoring source.']],[173,319])
p('Generated directories are artifacts/ for installer+manifest, runs/ for run metadata, evidence/ for collected output, target/ for Rust build products, and node_modules/ for CLI dependencies. They are excluded from Git. Do not commit a desktop password, production file report, credential file, or container dump.')

page(20,'References and extension roadmap')
p('Primary technical references were checked while implementing this lab. Upstream documentation establishes supported interfaces and prerequisites; it does not establish a successful run of this particular combination.')
for label,url in [
('Microsoft: WSL container feature and minimum WSL version','https://learn.microsoft.com/en-us/windows/wsl/wsl-container'),
('Microsoft: get started with containers on WSL','https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-containers'),
('Microsoft: WSLC settings','https://learn.microsoft.com/en-us/windows/wsl/wsl-container-settings'),
('Microsoft WSL issue 41740: Consommé networking and full-tunnel VPN timeout','https://github.com/microsoft/WSL/issues/41740'),
('LinuxServer: WineGUI image, desktop access and security','https://docs.linuxserver.io/images/docker-winegui/'),
('Tauri: Windows installer and WebView2 installation modes','https://v2.tauri.app/distribute/windows-installer/'),
('Tauri: development prerequisites','https://v2.tauri.app/start/prerequisites/'),
('Tauri: configuration reference','https://v2.tauri.app/reference/config/'),
('Microsoft: WebView2 supported Windows versions','https://learn.microsoft.com/en-us/microsoft-edge/webview2/'),
('Source conversation: Run Windows App Containers','chatgpt-conversation://6af79ffb-6048-83ea-b689-8269484af53d')]:link(label,url)
h('Next acceptance milestone')
p(status.get('nextMilestone','Repeat the measured build in a fresh prefix, preserve all failure evidence, and compare the same artifact on native Windows before broadening a Wine workaround.'))
h('Optional extensions after the first measured run')
p('Pin a validated image digest and Rust/tooling versions; add stable structured error codes, per-file progress and cancellation; make log filenames collision-resistant; add native Windows GUI automation and artifact attestation; automate evidence validation; and create an independently scoped Windows VM baseline. These changes should follow the measured compatibility outcome.')
p('Adapting the harness to a different compiled installer requires only that installer and its runtime requirements, not its application source code. Do not assume that Octane\'s per-user installation path, executable discovery, sample contract, or WebView2 configuration applies to an unrelated program. Keep the separate application\'s test results and artifacts distinct.')

def decorate(canvas,doc):
    canvas.setTitle('Octane - Complete Windows Application Container Lab Guide')
    canvas.setAuthor('Octane Lab')
    canvas.setStrokeColor(colors.HexColor('#dce5eb'));canvas.line(54,44,558,44)
    canvas.setFont('Helvetica',8);canvas.setFillColor(colors.HexColor('#657989'))
    canvas.drawString(54,30,'OCTANE / PRIVATE PROJECT REFERENCE / GUIDE REVISION 2')
    canvas.drawRightString(558,30,str(doc.page))

doc=SimpleDocTemplate(str(DEST),pagesize=(612,792),rightMargin=54,leftMargin=54,topMargin=44,bottomMargin=60)
doc.build(story,onFirstPage=decorate,onLaterPages=decorate)
print(DEST)
