#!/usr/bin/env bash

# ##################################################
# ufw-ipset-blocklist-autoupdate
#
# Blocking lists of IPs from public blocklists / blacklists (e.g. blocklist.de, spamhaus.org)
#
# Version: 0.0.1
#
# See: https://github.com/ngandrass/ufw-ipset-blocklist-autoupdate
#
#
# MIT License
#
# Copyright (c) 2023 Niels Gandraß <niels@gandrass.de>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# ##################################################

IPSET_BIN="/usr/bin/ipset"  # Path to ipset binary. Updated by detect_ipset().
IPSET_DIR="/var/lib/ipset"  # Folder to write ipset save files to
IPSET_PREFIX="blocklist"    # Prefix for ipset names
IPSET_TYPE="hash:net"       # Type of created ipsets
QUIET=0                     # Default quiet mode setting
VERBOSE=0                   # Default verbosity level
declare -A BLOCKLISTS       # Array for blocklists to use. Populated by CLI args,
IPV4_REGEX="(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/[1-3]?[0-9])?" # Regex for a valid IPv4 address with optional subnet part

##
# Prints the help/usage message
##
function print_usage() {
    cat << EOF
Usage: $0 [-h]
Blocking lists of IPs from public blocklists / blacklists (e.g. blocklist.de, spamhaus.org)

Options:
  -l     : Blocklist to use. Can be specified multiple times.
           Format: "$name $url" (space-separated). See examples below.
  -q     : Quiet mode. Outputs are suppressed if flag is present.
  -v     : Verbose mode. Prints additional information during execution.
  -h     : Print this help message.

Example usage:
$0 -l "spamhaus https://www.spamhaus.org/drop/drop.txt"
$0 -l "blocklist https://lists.blocklist.de/lists/all.txt" -l "spamhaus https://www.spamhaus.org/drop/drop.txt"
EOF
}

##
# Writes argument $1 to stdout if $QUIET is not set
#
# Arguments:
#   $1 Message to write to stdout
##
function log() {
    if [[ $QUIET -eq 0 ]]; then
        echo $1
    fi
}

##
# Writes argument $1 to stdout if $VERBOSE is set and $QUIET is not set
#
# Arguments:
#   $1 Message to write to stdout
##
function log_verbose() {
    if [[ $VERBOSE -eq 1 ]]; then
        if [[ $QUIET -eq 0 ]]; then
            echo $1
        fi
    fi
}

##
# Writes argument $1 to stderr. Ignores $QUIET.
#
# Arguments:
#   $1 Message to write to stderr
##
function log_error() {
    >&2 echo "[ERROR]: $1"
}

##
# Detects ipset binary
#
# Return: Path to ipset
#
function detect_ipset() {
    local IPSET_BIN=$(which ipset)
    if [ ! -x "${IPSET_BIN}" ]; then
        log_error "ipset binary not found."
        exit 1
    fi

    echo "${IPSET_BIN}"
}

##
# Validates the correctness of the BLOCKLISTS array. Exists upon error.
#
function validate_blocklists() {
    if [ ${#BLOCKLISTS[@]} -eq 0 ]; then
        log_error "No blocklists given. Exiting..."
        print_usage
        exit 1
    fi

    for list in "${BLOCKLISTS[@]}"; do
        local list_name=$(echo "$list" | cut -d ' ' -f 1)
        local list_url=$(echo "$list" | cut -d ' ' -f 2)

        if [ -z "$list_name" ]; then
            log_error "Invalid name for list: $list"
            exit 1
        fi

        if [ -z "$list_url" ]; then
            log_error "Invalid url for list: $list"
            exit 1
        fi

        log_verbose "Found valid blocklist: name=${list_name}, url=${list_url}"
    done
}

##
# Updates the given blocklist
#
# Arguments:
#   $1 Name of the blocklist
#   $2 URL of the blocklist
#
function update_blocklist() {
    # Download blocklist
    log "Updating blacklist '$1' ..."
    log_verbose "Downloading blocklist '$1' from: $2 ..."
    local tempfile=$(mktemp "/tmp/blocklist.$1.XXXXXXXX")
    wget -q -O "$tempfile" "$2"

    # Check downloaded list
    linecount=$(cat "$tempfile" | wc -l)
    if [ $linecount -lt 100 ]; then
        log_error "Blacklist '$1' containes only $linecount lines. This seems to short. Exiting..."
        exit 1
    fi

    # Extract ips from raw list data
    grep -v '^[#;]' "$tempfile" | grep -E -o "$IPV4_REGEX" | cut -d ' ' -f 1 > "$tempfile.filtered"
    log_verbose "Got $(cat "$tempfile.filtered" | wc -l) entries from blocklist '$1'"

    # Update ipset for blocklist
    local livelist="${IPSET_PREFIX}-$1"
    local templist="${IPSET_PREFIX}-$1-tmp"

    $IPSET_BIN create -q "$livelist" "$IPSET_TYPE"
    $IPSET_BIN create -q "$templist" "$IPSET_TYPE"
    log_verbose "Prepared ipset lists: livelist='$livelist', templist='$templist'"

    while read -r ip; do
        $IPSET_BIN add "$templist" "$ip" || exit
        log_verbose "Added '$ip' to '$templist'"
    done < "$tempfile.filtered"

    $IPSET_BIN swap "$templist" "$livelist"
    log_verbose "Swapped ipset: $livelist"
    $IPSET_BIN destroy "$templist"
    log_verbose "Destroyed ipset: $templist"

    # Write ipset savefile
    $IPSET_BIN save "$livelist" > "$IPSET_DIR/$livelist.save"
    log_verbose "Wrote savefile for '$livelist' to: $IPSET_DIR/$livelist.save"
    log "Added $(cat "$tempfile.filtered" | wc -l) from blocklist '$1' to ipset '$livelist'"

    # Cleanup
    rm "$tempfile"*
}

##
# Main program loop
##
function main() {
    # Check arguments
    validate_blocklists

    # Setup ipset
    IPSET_BIN=$(detect_ipset)
    mkdir -p "${IPSET_DIR}"

    # Update blocklists
    for list in "${BLOCKLISTS[@]}"; do
        local list_name=$(echo "$list" | cut -d ' ' -f 1)
        local list_url=$(echo "$list" | cut -d ' ' -f 2)

        update_blocklist "$list_name" "$list_url"
    done
}

# Parse arguments
while getopts ":hvl:" opt; do
  case ${opt} in
    l ) BLOCKLISTS[${#BLOCKLISTS[@]}]=${OPTARG}
      ;;
    q ) QUIET=1
      ;;
    v ) VERBOSE=1
      ;;
    h ) print_usage; exit
      ;;
    : ) print_usage; exit
      ;;
    \? ) print_usage; exit
      ;;
  esac
done

# Entry point
main