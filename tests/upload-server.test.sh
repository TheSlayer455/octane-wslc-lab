#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temporary=$(mktemp -d)
python_cmd=${PYTHON:-python3}
if ! "$python_cmd" -c 'import sys; raise SystemExit(0)' >/dev/null 2>&1; then
    python_cmd=python
fi
"$python_cmd" -c 'import sys; raise SystemExit(0)' >/dev/null
server_pid=''
cleanup() {
    [[ -z "$server_pid" ]] || kill "$server_pid" 2>/dev/null || true
    [[ -z "$server_pid" ]] || wait "$server_pid" 2>/dev/null || true
    rm -rf -- "$temporary"
}
trap cleanup EXIT INT TERM

uploads="$temporary/uploads"
evidence="$temporary/evidence"
password_file="$temporary/viewer-password"
mkdir -p "$uploads" "$evidence"
printf '%s' 'unit-test-secret' > "$password_file"
port=$("$python_cmd" - <<'PY'
import socket
s = socket.socket()
s.bind(('127.0.0.1', 0))
print(s.getsockname()[1])
s.close()
PY
)
origin='http://127.0.0.1:3005'

OCTANE_UPLOAD_ROOT="$uploads" \
OCTANE_UPLOAD_EVIDENCE="$evidence" \
OCTANE_VIEWER_EVIDENCE="$evidence/viewer" \
OCTANE_VIEWER_PASSWORD_FILE="$password_file" \
OCTANE_UPLOAD_CONTAINER_PORT="$port" \
OCTANE_UPLOAD_MAX_BYTES=64 \
OCTANE_VIEWER_ORIGINS="$origin" \
"$python_cmd" "$root/lab/browser/octane-upload-server" >"$temporary/server.log" 2>&1 &
server_pid=$!

for _ in $(seq 1 100); do
    if curl -fsS "http://127.0.0.1:$port/health" >/dev/null 2>&1; then break; fi
    sleep 0.05
done
kill -0 "$server_pid"

assertions=0
check() {
    if ! eval "$1"; then echo "upload server assertion failed: $2" >&2; exit 1; fi
    assertions=$((assertions+1))
}

status=$(curl -sS -o "$temporary/health.json" -w '%{http_code}' "http://127.0.0.1:$port/health")
check '[[ "$status" = 200 ]]' 'health endpoint'
status=$(curl -sS -o "$temporary/unauthorized.json" -w '%{http_code}' -H "Origin: $origin" "http://127.0.0.1:$port/uploads")
check '[[ "$status" = 401 ]]' 'authentication required'
status=$(curl -sS -o "$temporary/bad-origin.json" -w '%{http_code}' -H 'Origin: http://example.invalid' -H 'Authorization: Bearer unit-test-secret' "http://127.0.0.1:$port/uploads")
check '[[ "$status" = 403 ]]' 'unapproved origin rejected'

status=$(curl -sS -o "$temporary/viewer-event.json" -w '%{http_code}' -X POST \
    -H "Origin: $origin" -H 'Authorization: Bearer unit-test-secret' \
    -H 'Content-Type: application/json' \
    --data '{"event":"vnc-negotiated","runId":"unit-run","detail":{"displayTarget":"noVNC canvas"}}' \
    "http://127.0.0.1:$port/viewer-event")
check '[[ "$status" = 201 ]]' 'authenticated viewer event accepted'
viewer_event=$("$python_cmd" -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["events"][0]["event"])' "$evidence/viewer/viewer-events.json")
check '[[ "$viewer_event" = vnc-negotiated ]]' 'viewer event persisted to its bounded evidence file'
status=$(curl -sS -o "$temporary/secret-event.json" -w '%{http_code}' -X POST \
    -H "Origin: $origin" -H 'Authorization: Bearer unit-test-secret' \
    -H 'Content-Type: application/json' \
    --data '{"event":"browser-input","runId":"unit-run","detail":{"token":"must-not-persist"}}' \
    "http://127.0.0.1:$port/viewer-event")
check '[[ "$status" = 400 ]]' 'secret-bearing viewer detail rejected'
check '! grep -R -F "must-not-persist" "$evidence" >/dev/null' 'rejected viewer secret absent from evidence'

printf '%s' 'controlled input' > "$temporary/payload.bin"
status=$(curl -sS -o "$temporary/upload.json" -w '%{http_code}' -X POST \
    -H "Origin: $origin" -H 'Authorization: Bearer unit-test-secret' \
    -H 'Content-Type: application/octet-stream' --data-binary @"$temporary/payload.bin" \
    "http://127.0.0.1:$port/upload?name=space%20%C3%BC.txt")
check '[[ "$status" = 201 ]]' 'space and Unicode upload accepted'
check '[[ -f "$uploads/space ü.txt" ]]' 'uploaded file retained under exact safe name'
check '[[ "$(stat -c %a "$uploads/space ü.txt")" = 444 ]]' 'uploaded file made read-only'
expected=$(sha256sum "$temporary/payload.bin" | awk '{print $1}')
actual=$("$python_cmd" -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["files"][0]["sha256"])' "$evidence/upload-manifest.json")
check '[[ "$actual" = "$expected" ]]' 'manifest records exact SHA-256'

status=$(curl -sS -o "$temporary/duplicate.json" -w '%{http_code}' -X POST \
    -H "Origin: $origin" -H 'Authorization: Bearer unit-test-secret' \
    --data-binary @"$temporary/payload.bin" "http://127.0.0.1:$port/upload?name=space%20%C3%BC.txt")
check '[[ "$status" = 409 ]]' 'existing destination is not overwritten'
status=$(curl -sS -o "$temporary/traversal.json" -w '%{http_code}' -X POST \
    -H "Origin: $origin" -H 'Authorization: Bearer unit-test-secret' \
    --data-binary @"$temporary/payload.bin" "http://127.0.0.1:$port/upload?name=..%2Fescape.txt")
check '[[ "$status" = 400 ]]' 'path traversal rejected'
status=$(curl -sS -o "$temporary/oversize.json" -w '%{http_code}' -X POST \
    -H "Origin: $origin" -H 'Authorization: Bearer unit-test-secret' \
    -H 'Content-Length: 65' --data-binary '' "http://127.0.0.1:$port/upload?name=large.bin")
check '[[ "$status" = 413 ]]' 'declared oversize request rejected before intake'

status=$(curl -sS -o "$temporary/list.json" -w '%{http_code}' \
    -H "Origin: $origin" -H 'Authorization: Bearer unit-test-secret' "http://127.0.0.1:$port/uploads")
check '[[ "$status" = 200 ]]' 'authenticated manifest listing status'
check '"$python_cmd" -c '\''import json,sys; raise SystemExit(json.load(open(sys.argv[1], encoding="utf-8"))["files"][0]["name"] != "space \u00fc.txt")'\'' "$temporary/list.json"' 'authenticated manifest lists the exact Unicode filename'
check '! grep -R -F "unit-test-secret" "$evidence" "$temporary/server.log" >/dev/null' 'credential absent from evidence and logs'

echo "Browser upload service: $assertions assertions passed (localhost protocol/unit scope; not browser GUI acceptance)."
