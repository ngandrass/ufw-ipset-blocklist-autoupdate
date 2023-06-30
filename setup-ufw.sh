#!/usr/bin/env bash

# ##################################################
# ufw-ipset-blocklist-autoupdate
#
# Blocking lists of IPs from public blacklists / blocklists (e.g. blocklist.de, spamhaus.org)
#
# Version: 1.0.0
#
# See: https://github.com/ngandrass/ufw-ipset-blacklist-autoupdate
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

UFW_CONF_DIR=/etc/ufw
UFW_AFTER_INIT_FILE=$UFW_CONF_DIR/after.init
IPSET_DIR="/var/lib/ipset"  # Folder to write ipset save files to
CONFIGURE_IPV6=0

# Let user abort
read -r -p "Configure UFW to block IPs listed in blocklist ipsets? [Y/n] " ret
case "$ret" in
    [nN][oO]|[nN]) exit
        ;;
    *)
        ;;
esac

read -r -p "Would you like to enable IPv6 support? [Y/n] " ret
case "$ret" in
    [nN][oO]|[nN]) CONFIGURE_IPV6=0
        ;;
    *)
        CONFIGURE_IPV6=1
        ;;
esac

# Ensure that IPSET_DIR exists
mkdir -p "$IPSET_DIR" || exit

# Check that ufw has IPv6 enabled
if [[ "$CONFIGURE_IPV6" == 1 ]]; then
    if ! grep -q -E "IPV6=(yes|YES)" /etc/default/ufw; then
        echo "ERROR: IPv6 rules requested but UFW is not configured to use IPv6. Set IPV6=yes in /etc/default/ufw and rerun this script."
        exit 1
    fi
fi

# Check if file already exists.
if [ -f "$UFW_AFTER_INIT_FILE" ]; then
    read -r -p "The file $UFW_UFW_AFTER_INIT_FILE already exists. Are you sure that you want to overwrite it? [y/N] " ret
    case "$ret" in
        [yY][eE][sS]|[yY])
            # continue
            ;;
        *)
            exit
            ;;
    esac
fi

# Deploy after.init
if [[ "$CONFIGURE_IPV6" == 1 ]]; then
    cp "ufw/after6.init" "$UFW_AFTER_INIT_FILE" || exit
else
    cp "ufw/after.init" "$UFW_AFTER_INIT_FILE" || exit
fi
chmod 755 "$UFW_AFTER_INIT_FILE"
echo "Deployed $UFW_UFW_AFTER_INIT_FILE"

# Restart ufw
read -r -p "Reload ufw to apply changes? [Y/n] " ret
case "$ret" in
    [nN][oO]|[nN]) exit
        ;;
    *)
        ufw reload
        ;;
esac
