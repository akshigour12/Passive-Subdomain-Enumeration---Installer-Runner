#!/bin/bash

# Passive Subdomain Enumeration - Installer + Runner

# ---------- Help Menu ----------
show_help() {
    echo "------------------------------------------------------------"
    echo " Passive Subdomain Enumeration - Installer & Runner"
    echo "------------------------------------------------------------"
    echo "Usage: $0 -d <domain> [-t github_token] [-o output_file]"
    echo
    echo "Options:"
    echo "  -d DOMAIN         Target domain (e.g., example.com)"
    echo "  -t GITHUB_TOKEN   GitHub Personal Access Token (optional)"
    echo "  -o OUTPUT_FILE    Save final results to this file (default: enum_results/final_subs.txt)"
    echo "  -h                Show this help menu"
    echo
    echo "Examples:"
    echo "  $0 -d example.com"
    echo "  $0 -d example.com -t ghp_yourtokenhere"
    echo "  $0 -d example.com -t ghp_yourtokenhere -o my_results.txt"
    echo
    echo "GitHub Token Instructions:"
    echo "  1. Visit: https://github.com/settings/tokens"
    echo "  2. Click 'Generate new token (Classic)'"
    echo "  3. Permissions: repo, read:public_key"
    echo "  4. Copy token & use with -t option"
    echo "------------------------------------------------------------"
    exit 0
}

# ---------- Parse Arguments ----------
OUTPUT_FILE=""
DOMAIN=""
GITHUB_TOKEN=""

while getopts "d:t:o:h" opt; do
    case ${opt} in
        d ) DOMAIN="$OPTARG" ;;
        t ) GITHUB_TOKEN="$OPTARG" ;;
        o ) OUTPUT_FILE="$OPTARG" ;;
        h ) show_help ;;
        \? ) show_help ;;
    esac
done

if [[ -z "$DOMAIN" ]]; then
    echo "[!] Error: Domain is required."
    show_help
fi

# Default output file if not provided
if [[ -z "$OUTPUT_FILE" ]]; then
    mkdir -p enum_results
    OUTPUT_FILE="enum_results/final_subs.txt"
fi

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

# ---------- Install Required Packages ----------
echo "[*] Installing required packages..."
sudo apt update
sudo apt install -y git curl jq golang-go python3 python3-pip

# Install Subfinder
if ! command -v subfinder &>/dev/null; then
    echo "[*] Installing Subfinder..."
    go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    export PATH=$PATH:~/go/bin
fi

# Install Amass
if ! command -v amass &>/dev/null; then
    echo "[*] Installing Amass..."
    go install github.com/owasp-amass/amass/v4/...@latest
    export PATH=$PATH:~/go/bin
fi

# Install anew
if ! command -v anew &>/dev/null; then
    echo "[*] Installing anew..."
    go install github.com/tomnomnom/anew@latest
    export PATH=$PATH:~/go/bin
fi

# Install github-subdomains (Go version)
if ! command -v github-subdomains &>/dev/null; then
    echo "[*] Installing GitHub-Subdomains..."
    git clone https://github.com/gwen001/github-subdomains.git
    cd github-subdomains || exit
    go build main.go
    sudo mv main /usr/local/bin/github-subdomains
    cd ..
fi

# ---------- Start Enumeration ----------
echo "[*] Starting Passive Subdomain Enumeration for $DOMAIN..."

# Subfinder
subfinder -d "$DOMAIN" -silent -all -recursive -o "$OUTPUT_DIR/subfinder.txt"

# Amass Passive
amass enum -passive -d "$DOMAIN" -o "$OUTPUT_DIR/amass.txt"

# CRT.sh Query
curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" \
    | jq -r '.[].name_value' \
    | sed 's/\*\.//g' \
    | anew "$OUTPUT_DIR/crtsh.txt" > /dev/null

# GitHub Subdomains
if [[ -n "$GITHUB_TOKEN" ]]; then
    github-subdomains -d "$DOMAIN" -t "$GITHUB_TOKEN" -o "$OUTPUT_DIR/github.txt"
else
    echo "[!] Skipping GitHub Subdomains (no token provided)"
fi

# ---------- Combine & Deduplicate ----------
cat "$OUTPUT_DIR"/*.txt | sort -u > "$OUTPUT_FILE"

echo "[+] Passive Enumeration Complete!"
echo "[+] Final results saved in: $OUTPUT_FILE"
