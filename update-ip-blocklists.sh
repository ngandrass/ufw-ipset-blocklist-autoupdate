#!/usr/bin/env bash

# ##################################################
# ufw-ipset-blocklist-autoupdate
#
# Blocking lists of IPs from public blocklists / blacklists (e.g. blocklist.de, spamhaus.org)
#
# Version: 1.1.1
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
IPSET_PREFIX="bl"           # Prefix for ipset names
IPSET_TYPE="hash:net"       # Type of created ipsets
IPV4=1                      # Enable IPv4 by default
IPV6=1                      # Enable IPv6 by default
QUIET=0                     # Default quiet mode setting
VERBOSE=0                   # Default verbosity level
declare -A BLOCKLISTS       # Array for blocklists to use. Populated by CLI args,
IPV4_REGEX="(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/[1-3]?[0-9])?" # Regex for a valid IPv4 address with optional subnet part
IPV6_REGEX="(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))(/[1-6]?[0-9])?" # Regef for a valid IPv6 address with optional subnet part

##
# Prints the help/usage message
##
function print_usage() {
    cat << EOF
Usage: $0 [-h]
Blocking lists of IPs from public blocklists / blacklists (e.g. blocklist.de, spamhaus.org)

Options:
  -l     : Blocklist to use. Can be specified multiple times.
           Format: "\$name \$url" (space-separated). See examples below.
  -4     : Run in IPv4 only mode. Ignore IPv6 addresses.
  -6     : Run in IPv6 only mode. Ignore IPv4 addresses.
  -q     : Quiet mode. Outputs are suppressed if flag is present.
  -v     : Verbose mode. Prints additional information during execution.
  -h     : Print this help message.

Example usage:
$0 -l "spamhaus https://www.spamhaus.org/drop/drop.txt"
$0 -l "blocklist https://lists.blocklist.de/lists/all.txt" -l "spamhaus https://www.spamhaus.org/drop/drop.txt"
$0 -l "spamhaus https://www.spamhaus.org/drop/drop.txt" -l "spamhaus6 https://www.spamhaus.org/drop/dropv6.txt"
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
# Updates an ipset based on a list of IP addresses 
#
# Arguments:
#   $1 Name of the ipset to update
#   $2 File containing all IP addresses to store in ipset
#   $3 Procotol family (e.g. inet OR inet6)
function update_ipset() {
    # Setup local vars
    local setname=$1
    local ipfile=$2
    local family=$3

    # Create temporary ipset to build and ensure existence of live ipset
    local livelist="$setname-$family"
    local templist="$setname-$family-T"

    $IPSET_BIN create -q "$livelist" "$IPSET_TYPE" family $family
    $IPSET_BIN create -q "$templist" "$IPSET_TYPE" family $family
    log_verbose "Prepared ipset lists: livelist='$livelist', templist='$templist'"

    while read -r ip; do
        if $IPSET_BIN add "$templist" "$ip"; then
            log_verbose "Added '$ip' to '$templist'"
        else
            log "Failed to add '$ip' to '$templist'"
        fi
    done < "$ipfile"

    $IPSET_BIN swap "$templist" "$livelist"
    log_verbose "Swapped ipset: $livelist"
    $IPSET_BIN destroy "$templist"
    log_verbose "Destroyed ipset: $templist"

    # Write ipset savefile
    $IPSET_BIN save "$livelist" > "$IPSET_DIR/$livelist.save"
    log_verbose "Wrote savefile for '$livelist' to: $IPSET_DIR/$livelist.save"
    log "Added $(cat "$ipfile" | wc -l) to ipset '$livelist'"
}

##
# Updates the given blocklist from an URL
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
    if [ $linecount -lt 10 ]; then
        log_error "Blacklist '$1' containes only $linecount lines. This seems to short. Exiting..."
        exit 1
    fi

    # Extract ips from raw list data
    if [[ $IPV4 -eq 1 ]]; then
        grep -v '^[#;]' "$tempfile" | grep -E -o "$IPV4_REGEX" | cut -d ' ' -f 1 > "$tempfile.filtered"
        local numips=$(cat "$tempfile.filtered" | wc -l)
        log_verbose "Got $numips IPv4 entries from blocklist '$1'"

        if [[ $numips -gt 0 ]]; then
            update_ipset "${IPSET_PREFIX}-$1" "$tempfile.filtered" "inet"
        else
            log_verbose "No IPv4 addresses found in blocklist '$1'. Skipping"
        fi
    fi
    if [[ $IPV6 -eq 1 ]]; then
        grep -v '^[#;]' "$tempfile" | grep -E -o "$IPV6_REGEX" | cut -d ' ' -f 1 > "$tempfile.filtered6"
        local numips=$(cat "$tempfile.filtered6" | wc -l)
        log_verbose "Got $numips IPv6 entries from blocklist '$1'"

        if [[ $numips -gt 0 ]]; then
            update_ipset "${IPSET_PREFIX}-$1" "$tempfile.filtered6" "inet6"
        else
            log_verbose "No IPv6 addresses found in blocklist '$1'. Skipping"
        fi
    fi

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
while getopts ":hqv46l:" opt; do
    case ${opt} in
        l) BLOCKLISTS[${#BLOCKLISTS[@]}]=${OPTARG}
            ;;
        4) IPV4=1
           IPV6=0
           log "Using IPv4 only mode. Skipping IPv6 addresses."
            ;;
        6) IPV4=0
           IPV6=1
           log "Using IPv6 only mode. Skipping IPv4 addresses."
            ;;
        q) QUIET=1
            ;;
        v) VERBOSE=1
            ;;
        h) print_usage; exit
            ;;
        :) print_usage; exit
            ;;
        \? ) print_usage; exit
            ;;
  esac
done

# Entry point
main
