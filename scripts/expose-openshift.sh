#!/usr/bin/env bash
#
# expose-openshift.sh — publish a local Red Hat OpenShift Local (CRC) cluster
# to students via ngrok.
#
# Modes
# -----
#   * CLI (always on):  tunnel to the Kubernetes API (127.0.0.1:6443).
#                       Students connect with `oc login <url>`.
#   * Console (browser): tunnel to the OpenShift router (127.0.0.1:443), for the
#                       web console. Needs the apps-crc.testing hostnames mapped
#                       to the tunnel IP (hosts) because OpenShift pins login to
#                       oauth-openshift.apps-crc.testing on port 443.
#   * --proxy : 3 ngrok HTTP tunnels (api + console + oauth) in front of the
#                       router, published via reencrypt Routes on the ngrok hosts.
#                       Students get plain https://<hash>.ngrok-free.app URLs,
#                       valid TLS and standard :443 with ZERO host edits -> `oc`
#                       and everything except the GUI login work out of the box.
#                       GUI login is still operator-pinned to apps-crc.testing,
#                       so --proxy is best paired with --console for login needs.
#
#                       NOTE: the free ngrok plan allows only 3 endpoints/session,
#                       so --proxy uses all three for api/console/oauth.
#
#   * --lan : NO internet, NO ngrok. Forwards only the CRC ports that aren't
#                       already reachable on the Mac's LAN IP (typically just
#                       the API 6443; crc already binds the router on all
#                       interfaces), then generates student scripts that point
#                       api.crc.testing and *.apps-crc.testing at that IP with
#                       STANDARD ports -> the FULL web console login works on the
#                       LAN (no ngrok cert/login caveats). Caveats: everyone must
#                       be on the same network, the Mac must allow incoming for
#                       socat/crc (macOS firewall), and any privileged port that
#                       is NOT already reachable needs sudo.
#
#                       NOTE on console login: the console redirects login to
#   `oauth-openshift.apps-crc.testing` on STANDARD port 443, so for browser
#   login to work the tunnel must be a RESERVED ngrok TCP address on port 443
#   (paid account) — see NGROK_CONSOLE_ADDR. Without it, students can load the
#   console landing page and use `oc` CLI, but browser login will not complete.
#   (LAN mode needs no such trick: everything resolves on the local network.)
#
# Usage
# -----
#   ./expose-openshift.sh                # start CLI + console tunnels
#   ./expose-openshift.sh --console-off  # only expose the API (CLI)
#   ./expose-openshift.sh --proxy        # 3 HTTP tunnels + reencrypt routes
#   ./expose-openshift.sh --lan          # LAN-only, no ngrok (needs socat + sudo)
#   ./expose-openshift.sh --status       # show current tunnels / forwards
#   ./expose-openshift.sh --stop         # stop ngrok tunnels (+ proxy routes)
#   ./expose-openshift.sh --student-script DIR   # copy student scripts to DIR
#
# Env overrides
# -------------
#   NGROK_AUTHTOKEN      ngrok auth token (read from existing config if unset)
#   NGROK_REGION         ngrok region, e.g. eu (safest: leave unset)
#   NGROK_API_ADDR       reserved addr for the API (tcp: 0.tcp.ngrok.io:6443,
#                        http: reserved domain name) — paid accounts
#   NGROK_CONSOLE_ADDR   reserved addr for the router (see NGROK_API_ADDR)
#   NGROK_API_PORT       local API port   (default 6443)
#   NGROK_ROUTER_PORT    local router port (default 443)
#   LAN_IP               force the LAN address (default: auto-detect RFC1918)
#
set -euo pipefail

BASE_DIR="${HOME}/.crc-expose"
NGROK_CONFIG="${BASE_DIR}/ngrok.yml"
NGROK_LOG="${BASE_DIR}/ngrok.log"
NGROK_PID="${BASE_DIR}/ngrok.pid"
CONNECTION_FILE="${BASE_DIR}/connection.txt"
NGROK_API_URL="http://127.0.0.1:4040"
LAN_PID_FILE="${BASE_DIR}/lan.pid"
API_PORT="${NGROK_API_PORT:-6443}"
ROUTER_PORT="${NGROK_ROUTER_PORT:-443}"

EXPOSE_CONSOLE=1
PROXY=0
LAN=0
ACTION=""
STUDENT_DIR=""

usage() {
    sed -n '2,66p' "${0}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

log() { printf '\n[expose] %s\n' "$*"; }

die() { printf '[expose] ERROR: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- ngrok env
ensure_ngrok() {
    command -v ngrok >/dev/null 2>&1 || die "ngrok is not installed (brew install ngrok)."

    local authtoken="${NGROK_AUTHTOKEN:-}"
    if [[ -z "${authtoken}" ]]; then
        for cfg in "${HOME}/.config/ngrok/ngrok.yml" "${HOME}/Library/Application Support/ngrok/ngrok.yml"; do
            [[ -f "${cfg}" ]] || continue
            authtoken="$(sed -n 's/^[[:space:]]*authtoken:[[:space:]]*\(.*\)/\1/p' "${cfg}" | head -1 | tr -d '"' )"
            [[ -n "${authtoken}" ]] && break
        done
    fi
    [[ -n "${authtoken}" ]] || die "ngrok authtoken not found. Run once: ngrok config add-authtoken <token>"
    mkdir -p "${BASE_DIR}"
    printf '%s\n' "${authtoken}" > "${BASE_DIR}/authtoken"
}

write_ngrok_config() {
    mkdir -p "${BASE_DIR}"
    cat > "${NGROK_CONFIG}" <<EOF
version: "2"
log_level: info
authtoken: "$(cat "${BASE_DIR}/authtoken")"
EOF
    if [[ -n "${NGROK_REGION:-}" ]]; then
        printf 'region: %s\n' "${NGROK_REGION}" >> "${NGROK_CONFIG}"
    fi
    printf 'tunnels:\n' >> "${NGROK_CONFIG}"

    if [[ "${PROXY}" == "1" ]]; then
        # HTTP tunnels in front of the OpenShift router / API server.
        # The router then routes by Host header, so students get plain
        # https://<hash>.ngrok-free.app URLs (valid ngrok TLS, standard :443).
        write_tunnel console http "https://127.0.0.1:${ROUTER_PORT}" "${NGROK_CONSOLE_ADDR:-}"
        write_tunnel oauth  http "https://127.0.0.1:${ROUTER_PORT}" ""
        write_tunnel api    http "https://127.0.0.1:${API_PORT}"    "${NGROK_API_ADDR:-}"
    else
        if [[ "${EXPOSE_CONSOLE}" == "1" ]]; then
            write_tunnel console tcp "127.0.0.1:${ROUTER_PORT}" "${NGROK_CONSOLE_ADDR:-}"
        fi
        write_tunnel api    tcp "127.0.0.1:${API_PORT}"    "${NGROK_API_ADDR:-}"
    fi
}

write_tunnel() { # name proto addr remote_addr(empty ok)
    printf '  %s:\n    proto: %s\n    addr: %s\n' "$1" "$2" "$3" >> "${NGROK_CONFIG}"
    if [[ -n "$4" ]]; then
        printf '    remote_addr: %s\n' "$4" >> "${NGROK_CONFIG}"
    fi
}

# --------------------------------------------------------------- crc / cluster
ensure_cluster() {
    local status
    status="$(crc status 2>/dev/null | sed -n 's/^OpenShift:[[:space:]]*//p' | head -1 || true)"
    if [[ "${status}" == "Running (v"* ]]; then
        log "OpenShift Local already running: ${status}"
        return 0
    fi
    log "Cluster not running — starting 'crc start' (can take 5-15 min)..."
    crc start
    log "Cluster running."
}

# ------------------------------------------------------------------ ngrok run
is_running() { [[ -f "${NGROK_PID}" ]] && kill -0 "$(cat "${NGROK_PID}")" 2>/dev/null; }

start_tunnels() {
    if is_running; then
        log "ngrok already running (pid $(cat "${NGROK_PID}")). Use --status / --stop."
        return 0
    fi
    write_ngrok_config

    local tunnels=()
    if [[ "${PROXY}" == "1" ]]; then
        tunnels=(api console oauth)
    elif [[ "${EXPOSE_CONSOLE}" == "1" ]]; then
        tunnels=(console api)
    else
        tunnels=(api)
    fi

    nohup ngrok start --config "${NGROK_CONFIG}" --log stdout "${tunnels[@]}" > "${NGROK_LOG}" 2>&1 &
    echo $! > "${NGROK_PID}"
    log "ngrok starting (pid $!)..."

    for _ in $(seq 1 60); do
        if all_tunnels_ready "${tunnels[@]}"; then
            break
        fi
        sleep 2
    done
    if ! all_tunnels_ready "${tunnels[@]}"; then
        log "ngrok did not become ready. Last log lines:"
        tail -5 "${NGROK_LOG}"
        return 1
    fi
    log "ngrok tunnels ready."
}

stop_tunnels() {
    if [[ "${PROXY}" == "1" ]]; then
        remove_proxy_routes
    fi
    if [[ "${LAN}" == "1" ]]; then
        stop_lan
    else
        if is_running; then
            kill "$(cat "${NGROK_PID}")" 2>/dev/null || true
            rm -f "${NGROK_PID}"
            log "ngrok stopped."
        else
            pkill -f "ngrok start --config ${NGROK_CONFIG}" 2>/dev/null || true
            log "no ngrok tunnels were running."
        fi
        rm -f "${NGROK_PID}"
    fi
}

# ------------------------------------------------------------- tunnel helpers
get_tunnel() { # name -> host:port of public url (tcp://host:port) or host (https://host)
    curl -sf "${NGROK_API_URL}/api/tunnels" | python3 -c '
import sys, json
d = json.load(sys.stdin)
for t in d["tunnels"]:
    if t["name"] == sys.argv[1]:
        u = t["public_url"]
        if u.startswith("tcp://"):
            print(u[len("tcp://"):])
        else:
            import urllib.parse as p
            print(p.urlparse(u).netloc)
        break' "$1"
}

get_public_url() { # name -> full public_url (https://host or tcp://host:port)
    curl -sf "${NGROK_API_URL}/api/tunnels" | python3 -c '
import sys, json
d = json.load(sys.stdin)
for t in d["tunnels"]:
    if t["name"] == sys.argv[1]:
        print(t["public_url"])
        break' "$1"
}

all_tunnels_ready() { # names... -> exit 0 if every named tunnel is up
    curl -sf "${NGROK_API_URL}/api/tunnels" | python3 -c '
import sys, json
d = json.load(sys.stdin)
names = {t["name"] for t in d["tunnels"]}
want = set(sys.argv[1:])
sys.exit(0 if want <= names else 1)' "$@" 2>/dev/null
}

pub_ip() {
    local ip
    ip="$(dig +short A "$1" 2>/dev/null | tail -1)"
    if [[ -z "${ip}" ]]; then
        ip="$(python3 - "$1" <<'PY'
import socket, sys
try:
    print(socket.gethostbyname(sys.argv[1]))
except Exception:
    pass
PY
)"
    fi
    printf '%s' "${ip}"
}

# --------------------------------------------------------------- student files
write_student_files() {
    local dest="${1}"
    mkdir -p "${dest}"

    if [[ "${LAN}" == "1" ]]; then
        local lip
        lip="${LAN_IP:-$(local_ip)}"
        [[ -n "${lip}" ]] || die "run --lan first (or set LAN_IP)."
        cat > "${dest}/student-setup.sh" <<EOF
#!/usr/bin/env bash
# Add crc hostnames for LAN access (run as admin / with sudo).
# Generated by expose-openshift.sh --lan. Student connects to the instructor's
# LAN IP with STANDARD ports — full web console login works.
set -euo pipefail
LAN_IP="\${LAN_IP:-${lip}}"

for h in \\
    api.crc.testing \\
    console-openshift-console.apps-crc.testing \\
    oauth-openshift.apps-crc.testing \\
    default-route-openshift-image-registry.apps-crc.testing; do
  sed -i '' "/[[:space:]]\$h[[:space:]]*$/d" /etc/hosts 2>/dev/null || sed -i "/[[:space:]]\$h[[:space:]]*$/d" /etc/hosts
  printf '%s\t%s\n' "\${LAN_IP}" "\${h}" >> /etc/hosts
done

echo "Added crc LAN hosts entries -> \${LAN_IP}."
echo "API CLI:     oc login https://api.crc.testing:${API_PORT} --insecure-skip-tls-verify -u developer -p developer"
echo "Console:     https://console-openshift-console.apps-crc.testing (login works)"
echo "Accept the TLS warning once (crc private CA) or trust the crc rootCA.pem."
echo "For lab apps, add more:   echo \${LAN_IP}  <app>.apps-crc.testing >> /etc/hosts"
echo "Same network required. Re-run with LAN_IP=... if the instructor IP changed."
EOF
        cat > "${dest}/student-teardown.sh" <<'EOF'
#!/usr/bin/env bash
# Remove the crc LAN hosts entries that student-setup.sh added.
set -euo pipefail
for h in api.crc.testing console-openshift-console.apps-crc.testing oauth-openshift.apps-crc.testing default-route-openshift-image-registry.apps-crc.testing; do
  sed -i '' "/[[:space:]]$h[[:space:]]*$/d" /etc/hosts 2>/dev/null || sed -i "/[[:space:]]$h[[:space:]]*$/d" /etc/hosts
done
echo "Removed crc LAN hosts entries."
EOF
    elif [[ "${PROXY}" == "1" ]]; then
        local api_url console_url
        api_url="${API_URL:-}"
        console_url="${CONSOLE_URL:-}"
        [[ -n "${api_url}" && -n "${console_url}" ]] || die "run in proxy mode first."
        cat > "${dest}/student-setup.sh" <<EOF
#!/usr/bin/env bash
# Generated by expose-openshift.sh --proxy. NO host edits needed.
set -uo pipefail
API_URL="\${API_URL:-${api_url}}"
CONSOLE_URL="\${CONSOLE_URL:-${console_url}}"

echo "  OpenShift API (oc CLI) — plain https / valid TLS / port 443:"
echo "    oc login \${API_URL} --insecure-skip-tls-verify -u developer -p developer"
echo
echo "  Web console (browser):"
echo "    \${CONSOLE_URL}    <- if asked for a certificate, accept the ngrok cert"
echo
echo "  GUI LOGIN note: OpenShift pins the login callback to *.apps-crc.testing."
echo "  Browsing and oc work everywhere; a full browser login additionally needs"
echo "  these host entries (ask the instructor for the router IP):"
echo "    <router-IP>  console-openshift-console.apps-crc.testing oauth-openshift.apps-crc.testing"
echo "  (or use the instructor's console mode which ships them pre-made.)"
EOF
        cat > "${dest}/student-teardown.sh" <<'EOF'
#!/usr/bin/env bash
# Generated by expose-openshift.sh --proxy. Nothing was written to /etc/hosts,
# so there is nothing to remove. Keep for symmetry.
echo "Proxy mode wrote no local changes. Nothing to tear down."
EOF
    else
        local dport aport
        dport="${ROUTER_PORT:-}"
        aport="${API_PORT:-}"
        cat > "${dest}/student-setup.sh" <<EOF
#!/usr/bin/env bash
# Add OpenShift Local routes to /etc/hosts (run as admin / with sudo).
# Generated by expose-openshift.sh -- re-run when the tunnel URL changes.
set -euo pipefail
API_IP="\${API_IP:-${API_IP:-}}"
API_PORT="\${API_PORT:-${aport}}"
CONSOLE_IP="\${CONSOLE_IP:-${ROUTER_IP:-}}"
CONSOLE_PORT="\${CONSOLE_PORT:-${dport}}"

if [[ -z "\${API_IP}" || -z "\${CONSOLE_IP}" ]]; then
  echo "API_IP / CONSOLE_IP not set. Ask the instructor for the ngrok edge IPs."
  echo "  Usage: API_IP=1.2.3.4 CONSOLE_IP=5.6.7.8 API_PORT=12345 CONSOLE_PORT=54321 sudo bash student-setup.sh"
  exit 1
fi

# api.crc.testing -> API tunnel (pin IPv4 so oc does not pick IPv6 and hang)
printf '%s\t%s\n' "\${API_IP}" "api.crc.testing" >> /etc/hosts

# apps-crc.testing hosts -> router tunnel (SNI routes to the right app)
for h in \
    console-openshift-console.apps-crc.testing \
    oauth-openshift.apps-crc.testing \
    default-route-openshift-image-registry.apps-crc.testing; do
  printf '%s\t%s\n' "\${CONSOLE_IP}" "\${h}" >> /etc/hosts
done

echo "Added crc hosts entries (api and console)."
echo "API CLI:     oc login https://api.crc.testing:\${API_PORT} --insecure-skip-tls-verify -u developer -p developer"
echo "Console:     https://console-openshift-console.apps-crc.testing:\${CONSOLE_PORT}"
echo "Accept the TLS warning once when opening the console (crc uses its own CA)."
echo "For lab apps, add more entries:  echo \${CONSOLE_IP}  <app>.apps-crc.testing >> /etc/hosts"
EOF

        cat > "${dest}/student-teardown.sh" <<'EOF'
#!/usr/bin/env bash
# Remove the crc hosts entries that student-setup.sh added.
set -euo pipefail
for h in api.crc.testing console-openshift-console.apps-crc.testing oauth-openshift.apps-crc.testing default-route-openshift-image-registry.apps-crc.testing; do
  sed -i '' "/[[:space:]]$h[[:space:]]*$/d" /etc/hosts 2>/dev/null || sed -i "/[[:space:]]$h[[:space:]]*$/d" /etc/hosts
done
echo "Removed crc hosts entries."
EOF
    fi
    chmod +x "${dest}/student-setup.sh" "${dest}/student-teardown.sh"
    log "Student scripts written to ${dest}/ (student-setup.sh + student-teardown.sh)."
}

# --------------------------------------------------------- proxy route wiring
# In proxy mode the OpenShift router must answer for the ngrok hosts. We add
# reencrypt routes (routing by Host header rather than SNI/passthrough) that
# point at the existing console / oauth services. The Console operator owns
# the built-in route+OAuth redirect, so we do NOT touch those — therefore
# browser LOGIN still resolves to the apps-crc.testing hostnames, which is why
# the proxy student-script keeps the small /etc/hosts note for full login.
apply_proxy_routes() {
    local console_host oauth_host
    console_host="$(get_tunnel console)"
    oauth_host="$(get_tunnel oauth)"
    [[ -n "${console_host}" && -n "${oauth_host}" ]] || die "proxy tunnels not ready."

    oc create route reencrypt console-ng -n openshift-console \
        --service=console --port=https --hostname="${console_host}" \
        --dry-run=client -o yaml | oc apply -f -
    oc create route reencrypt oauth-ng -n openshift-authentication \
        --service=oauth-openshift --port=https --hostname="${oauth_host}" \
        --dry-run=client -o yaml | oc apply -f -
    log "Published console+oauth Routes on the ngrok hosts (reencrypt)."
}

remove_proxy_routes() {
    oc delete route console-ng -n openshift-console --ignore-not-found >/dev/null 2>&1
    oc delete route oauth-ng -n openshift-authentication --ignore-not-found >/dev/null 2>&1
}

# ----------------------------------------------------------------------- LAN mode
# No ngrok: socat forwards the CRC API/router ports from the Mac's LAN IP to
# 127.0.0.1 so students on the same network reach the cluster with standard
# ports and, because the apps-crc.testing hostnames resolve via hosts, the
# full browser console login works.
local_ip() {
    local ip=""
    if [[ -n "${LAN_IP:-}" ]]; then
        printf '%s\n' "${LAN_IP}"
        return 0
    fi
    for iface in en0 en1 en2; do
        ip="$(ipconfig getifaddr "${iface}" 2>/dev/null || true)"
        if [[ -n "${ip}" ]]; then
            [[ "${ip}" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]] || ip=""
        fi
        [[ -n "${ip}" ]] && break
    done
    if [[ -z "${ip}" ]]; then
        ip="$(ifconfig | awk '/inet / && $2 !~ /^127\./ && ($2 ~ /^10\./ || $2 ~ /^192\.168\./ || $2 ~ /^172\.(1[6-9]|2[0-9]|3[0-1])\./) {print $2; exit}')"
    fi
    printf '%s\n' "${ip}"
}

ensure_socat() {
    command -v socat >/dev/null 2>&1 || {
        log "socat not found — installing via Homebrew..."
        brew install socat
    }
}

lan_running() {
    [[ -f "${LAN_PID_FILE}" ]] || return 1
    local any=0
    while read -r pid; do
        [[ "${pid}" =~ ^[0-9]+$ ]] && kill -0 "${pid}" 2>/dev/null && any=1
    done < "${LAN_PID_FILE}"
    [[ "${any}" == "1" ]]
}

start_lan() {
    local ip
    ip="$(local_ip)"
    [[ -n "${ip}" ]] || die "Could not auto-detect a LAN IP — set LAN_IP=<your-ip>."
    LAN_IP="${ip}"
    ensure_socat

    if lan_running; then
        log "LAN forwards already running (${LAN_IP}). Use --status / --stop."
        return 0
    fi

    mkdir -p "${BASE_DIR}"
    : > "${LAN_PID_FILE}"

    forward_lan_port "${API_PORT}" "API server"
    if [[ "${EXPOSE_CONSOLE}" == "1" ]]; then
        forward_lan_port "${ROUTER_PORT}" "router"
    fi

    sleep 1
    if ! lan_running; then
        log "socat forwards died. Check ${BASE_DIR}/lan.log:"
        tail -5 "${BASE_DIR}/lan.log" 2>/dev/null || true
        return 1
    fi

    log "LAN listening on ${ip}:${API_PORT} (API) and ${ip}:${ROUTER_PORT} (router)."
    log "If students can't reach this: allow socat + crc in macOS firewall"
    log "  (System Settings > Network > Firewall), and re-run --status to confirm."
}

# Ports crc already binds on all interfaces (e.g. the router) need no forward —
# only forward what is NOT reachable on the LAN IP yet.
forward_lan_port() { # port description
    local port="${1}" desc="${2}"
    if nc -z -w2 "${LAN_IP}" "${port}" 2>/dev/null; then
        log ":${port} (${desc}) already reachable on ${LAN_IP}:${port} — no forward needed."
        return 0
    fi
    local cmd=(socat TCP-LISTEN:"${port}",fork,reuseaddr,bind="${LAN_IP}" TCP:127.0.0.1:"${port}")
    if (( port < 1024 )) && ! sudo -n true 2>/dev/null; then
        log ":${port} needs sudo (privileged port) — you may be prompted for your password."
        sudo "${cmd[@]}" >> "${BASE_DIR}/lan.log" 2>&1 &
    else
        "${cmd[@]}" >> "${BASE_DIR}/lan.log" 2>&1 &
    fi
    echo $! >> "${LAN_PID_FILE}"
    log "forwarding ${LAN_IP}:${port} -> 127.0.0.1:${port}."
}

lan_summary() {
    local ip="${LAN_IP:-$(local_ip)}"
    printf '  API oc login : oc login https://api.crc.testing:%s --insecure-skip-tls-verify -u developer -p developer\n' "${API_PORT}"
    printf '  Web console  : https://console-openshift-console.apps-crc.testing\n'
    printf '  Hosts entries (all point at %s):\n' "${ip}"
    printf '    %s api.crc.testing\n' "${ip}"
    printf '    %s console-openshift-console.apps-crc.testing oauth-openshift.apps-crc.testing\n' "${ip}"
    printf '    %s default-route-openshift-image-registry.apps-crc.testing\n' "${ip}"
    printf '  Full browser login works (hostnames resolve on the LAN).\n'
    printf '  TLS: crc uses its own CA — accept the warning once, or trust the crc\n'
    printf '  CA exported from the instructor machine (~/.crc, rootCA.pem).\n'
}

stop_lan() {
    if [[ -f "${LAN_PID_FILE}" ]]; then
        while read -r pid; do
            [[ "${pid}" =~ ^[0-9]+$ ]] || continue
            kill "${pid}" 2>/dev/null || sudo kill "${pid}" 2>/dev/null || true
        done < "${LAN_PID_FILE}"
        rm -f "${LAN_PID_FILE}"
        log "LAN forwards stopped."
    else
        log "no LAN forwards were running."
    fi
}

lan_status() {
    local ip="${LAN_IP:-}"
    if [[ -z "${ip}" ]]; then
        ip="$(sed -n 's/^LAN_IP=//p' "${CONNECTION_FILE}" 2>/dev/null | head -1)"
    fi
    if lan_running; then
        log "LAN forwards running on ${ip:-<ip>}:"
        while read -r pid; do
            [[ "${pid}" =~ ^[0-9]+$ ]] || continue
            ps -o command= -p "${pid}" 2>/dev/null && echo "    (pid ${pid})"
        done < "${LAN_PID_FILE}"
    else
        log "LAN forwards NOT running."
    fi
}

# ------------------------------------------------------------------ reporting
print_connection_info() {
    if [[ "${LAN}" == "1" ]]; then
        local ip
        ip="${LAN_IP:-$(local_ip)}"
        [[ -n "${ip}" ]] || die "Could not detect a LAN IP — set LAN_IP."
        API_IP="${ip}"
        ROUTER_IP="${ip}"
        ROUTER_PORT="${ROUTER_PORT}"
        cat > "${CONNECTION_FILE}" <<EOF
LAN_IP=${ip}
API_PORT=${API_PORT}
ROUTER_PORT=${ROUTER_PORT}
LAN=1
EOF
        log "CONNECTION DETAILS (also saved to ${CONNECTION_FILE})"
        lan_summary
        printf '\nFiles: %s\n' "${BASE_DIR}"
        return 0
    fi

    local api_url api_host api_port api_ip
    api_url="$(get_public_url api)"
    [[ -n "${api_url}" ]] || die "Could not find the API tunnel."
    API_URL="${api_url}"

    log "CONNECTION DETAILS (also saved to ${CONNECTION_FILE})"

    if [[ "${PROXY}" == "1" ]]; then
        CONSOLE_URL="$(get_public_url console)"
        OAUTH_URL="$(get_public_url oauth)"
        [[ -n "${CONSOLE_URL}" && -n "${OAUTH_URL}" ]] || die "proxy tunnels not ready."
        cat > "${CONNECTION_FILE}" <<EOF
API_URL=${API_URL}
CONSOLE_URL=${CONSOLE_URL}
OAUTH_URL=${OAUTH_URL}
PROXY=1
EOF

        printf '\n  OpenShift API (oc) — plain https, valid ngrok cert, no host edits:\n'
        printf '    oc login %s --insecure-skip-tls-verify -u developer -p developer\n' "${API_URL}"
        printf '    (admin: -u kubeadmin -p <from crc start output or crc console --credentials>)\n'
        printf '\n  Web console (browser) — no host edits for browsing:\n'
        printf '    Console   : %s\n' "${CONSOLE_URL}"
        printf '    OAuth     : %s\n' "${OAUTH_URL}"
        printf '\n  CONSOLE LOGIN: the Console operator hard-pins the browser login\n'
        printf '  callback to hostnames in *.apps-crc.testing (see --help). Browsing and\n'
        printf '  oc CLI work everywhere; a full GUI login needs the apps-crc hostnames\n'
        printf '  resolvable (student-setup.sh prints the snippet). For a clean-port\n'
        printf '  login path use --console with a reserved ngrok TCP address on :443.\n'
    else
        api_host="$(get_tunnel api)"
        api_port="${api_host##*:}"
        api_ip="$(pub_ip "${api_host%:*}")"
        API_IP="${api_ip}"
        API_PORT="${api_port}"
        cat > "${CONNECTION_FILE}" <<EOF
API_TUNNEL_HOST=${api_host%:*}
API_TUNNEL_PORT=${api_port}
API_TUNNEL_IP=${api_ip}
EOF

        printf '\n  OpenShift API (oc) — students need api.crc.testing -> %s (in hosts):\n' "${api_ip}"
        printf '    oc login https://api.crc.testing:%s --insecure-skip-tls-verify -u developer -p developer\n' "${api_port}"
        printf '    Direct ngrok URL (IPv6 may hang): https://%s --insecure-skip-tls-verify -u developer\n' "${api_host}"
        printf '    (admin: -u kubeadmin -p <from crc start output or crc console --credentials>)\n'

        if [[ "${EXPOSE_CONSOLE}" == "1" ]]; then
            local console_host console_ip console_port
            console_host="$(get_tunnel console)"
            console_ip="$(pub_ip "${console_host%:*}")"
            console_port="${console_host##*:}"
            ROUTER_IP="${console_ip}"
            ROUTER_PORT="${console_port}"
            cat >> "${CONNECTION_FILE}" <<EOF
ROUTER_TUNNEL_HOST=${console_host%:*}
ROUTER_TUNNEL_PORT=${console_port}
ROUTER_PUBLIC_IP=${console_ip}
EOF

            printf '\n  Web console (browser) — via SNI on the router tunnel:\n'
            printf '    Router IP : %s (map console/oauth/apps hostnames here)\n' "${console_ip}"
            printf '    Console   : https://console-openshift-console.apps-crc.testing:%s\n' "${console_port}"
            printf '    Students must add hosts entries (see generated scripts, or below).\n'
            printf '    %s api.crc.testing\n' "${api_ip}"
            printf '    %s console-openshift-console.apps-crc.testing oauth-openshift.apps-crc.testing\n' "${console_ip}"
            if [[ "${console_port}" != "443" ]]; then
                printf '\n    CAUTION: tunnel is not on standard port 443. The console pages will load,\n'
                printf '    but browser LOGIN likely fails because OpenShift redirects login to\n'
                printf '    oauth-openshift.apps-crc.testing on port 443. Use a reserved TCP address\n'
                printf '    on :443 (NGROK_CONSOLE_ADDR=...:443) for a fully working web console.\n'
                printf '    oc CLI is unaffected.\n'
            fi
        fi
        printf '\n  Students:\n'
        printf '    Copy ~/.crc-expose/student-setup.sh and student-teardown.sh to each student\n'
        printf '    machine (they append the hosts entries above; run with sudo).\n'
    fi
    printf '\nFiles: %s\n' "${BASE_DIR}"
}

status_tunnels() {
    if [[ "${LAN}" == "1" ]]; then
        lan_status
        [[ -f "${CONNECTION_FILE}" ]] && { echo; cat "${CONNECTION_FILE}"; }
        return 0
    fi
    if ! curl -sf "${NGROK_API_URL}/api/tunnels" >/dev/null 2>&1; then
        log "ngrok is NOT running."
        return 0
    fi
    log "ngrok is running:"
    curl -sf "${NGROK_API_URL}/api/tunnels" | python3 -c '
import sys, json
d = json.load(sys.stdin)
for t in sorted(d["tunnels"], key=lambda x: x["name"]):
    print(f"  {t['"'"'name'"'"']:<8} {t['"'"'public_url'"'"']}  ->  {t['"'"'config'"'"']['"'"'addr'"'"']}")'
}

# ---------------------------------------------------------------------- entry
while [[ $# -gt 0 ]]; do
    case "${1}" in
        --console-off) EXPOSE_CONSOLE=0 ;;
        --proxy)       PROXY=1 ;;
        --lan)         LAN=1 ;;
        --status)      ACTION="status" ;;
        --stop)        ACTION="stop" ;;
        --student-script)
            [[ -n "${2:-}" ]] || die "--student-script needs a directory"
            STUDENT_DIR="${2}"
            shift
            ;;
        -h|--help)     usage 0 ;;
        *)             usage 1 ;;
    esac
    shift
done

case "${ACTION}" in
    status)
        if [[ -f "${LAN_PID_FILE}" ]]; then
            lan_status
        else
            status_tunnels
        fi
        [[ -f "${CONNECTION_FILE}" ]] && { echo; cat "${CONNECTION_FILE}"; }
        exit 0
        ;;
    stop)
        stopped=0
        if [[ -f "${LAN_PID_FILE}" ]] || [[ "${LAN}" == "1" ]]; then
            stop_lan
            stopped=1
        fi
        if [[ -f "${NGROK_PID}" ]]; then
            stop_tunnels
            stopped=1
        fi
        if [[ "${stopped}" == "0" ]]; then
            stop_tunnels
        fi
        exit 0
        ;;
esac

cd "$(dirname "${0}")"
ensure_cluster
if [[ "${LAN}" == "1" ]]; then
    start_lan
else
    ensure_ngrok
    start_tunnels
fi
if [[ "${PROXY}" == "1" ]]; then
    apply_proxy_routes
fi
print_connection_info

if [[ -n "${STUDENT_DIR}" ]]; then
    write_student_files "${STUDENT_DIR}"
fi

log "Done. Use --status to re-show, --stop to tear down."