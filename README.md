# ufw-ipset-blocklist-autoupdate

[![Latest Version](https://img.shields.io/github/v/release/ngandrass/ufw-ipset-blocklist-autoupdate)](https://github.com/ngandrass/ufw-ipset-blocklist-autoupdate/releases)
[![Maintenance Status](https://img.shields.io/maintenance/yes/9999)](https://github.com/ngandrass/ufw-ipset-blocklist-autoupdate/)
[![License](https://img.shields.io/github/license/ngandrass/ufw-ipset-blocklist-autoupdate)](https://github.com/ngandrass/ufw-ipset-blocklist-autoupdate/blob/master/LICENSE)
[![GitHub Issues](https://img.shields.io/github/issues/ngandrass/ufw-ipset-blocklist-autoupdate)](https://github.com/ngandrass/ufw-ipset-blocklist-autoupdate/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/ngandrass/ufw-ipset-blocklist-autoupdate)](https://github.com/ngandrass/ufw-ipset-blocklist-autoupdate/pulls)
[![Donate with PayPal](https://img.shields.io/badge/PayPal-donate-orange)](https://www.paypal.me/ngandrass)
[![Sponsor with GitHub](https://img.shields.io/badge/GitHub-sponsor-orange)](https://github.com/sponsors/ngandrass)
[![GitHub Stars](https://img.shields.io/github/stars/ngandrass/ufw-ipset-blocklist-autoupdate?style=social)](https://github.com/ngandrass/ufw-ipset-blocklist-autoupdate/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/ngandrass/ufw-ipset-blocklist-autoupdate?style=social)](https://github.com/ngandrass/ufw-ipset-blocklist-autoupdate/network/members)
[![GitHub Contributors](https://img.shields.io/github/contributors/ngandrass/ufw-ipset-blocklist-autoupdate?style=social)](https://github.com/ngandrass/ufw-ipset-blocklist-autoupdate/graphs/contributors)

This collection of scripts automatically pulls IP blocklists (e.g. Spamhaus, Blocklist, ...) and drops packages from
listed IP addresses. It integrates with the uncomplicated firewall (`ufw`) and makes use of `ipset` for storing IP
addresses and network ranges. Both IPv4 and IPv6 blocklists are supported.


## Installation

1. Install `ufw` and `ipset`.
2. Deploy `after.init` script via executing: `./setup-ufw.sh`
3. Determine the blocklist you would like to use.
4. Get initial set of blocklists: `./update-ip-blocklists.sh -l "blocklist https://lists.blocklist.de/lists/all.txt" -l "spamhaus https://www.spamhaus.org/drop/drop.txt"`
5. Add `update-ip-blocklists.sh` to your crontab:
```text
@daily /path/to/update-ip-blocklists.sh  -l "blocklist https://lists.blocklist.de/lists/all.txt" -l "spamhaus https://www.spamhaus.org/drop/drop.txt"
```

## Usage
```text
Usage: ./update-ip-blocklists.sh [-h]
Blocking lists of IPs from public blocklists / blacklists (e.g. blocklist.de, spamhaus.org)

Options:
  -l     : Blocklist to use. Can be specified multiple times.
           Format: "$name $url" (space-separated). See examples below.
  -4     : Run in IPv4 only mode. Ignore IPv6 addresses.
  -6     : Run in IPv6 only mode. Ignore IPv4 addresses.
  -q     : Quiet mode. Outputs are suppressed if flag is present.
  -v     : Verbose mode. Prints additional information during execution.
  -h     : Print this help message.

Example usage:
./update-ip-blocklists.sh -l "spamhaus https://www.spamhaus.org/drop/drop.txt"
./update-ip-blocklists.sh -l "blocklist https://lists.blocklist.de/lists/all.txt" -l "spamhaus https://www.spamhaus.org/drop/drop.txt"
./update-ip-blocklists.sh -l "spamhaus https://www.spamhaus.org/drop/drop.txt" -l "spamhaus6 https://www.spamhaus.org/drop/dropv6.txt"
```

### Supplying blocklist sources

Blocklists can be passed to the script using the `-l` CLI argument. Each entry consists of a name and download URL,
separated by a space. Examples:

- `-l "spamhaus https://www.spamhaus.org/drop/drop.txt"`
- `-l "mylist http://mylist.local/list.txt"`
- `-l "spamhaus6 https://www.spamhaus.org/drop/dropv6.txt"`

Lists are stripped of comments. This means all text after one of the following characters is removed before
parsing: `;`, `#`. Valid IPv4/IPv6 addresses with an optional CIDR are loaded into the ipset to block.

Processing of either IPv6 or IPv4 addresses can be disabled by supplying the `-4` (IPv4 only) or `-6` (IPv6 only)
flags respectively.


### Listing blocked IPs

The total number of blocked IPs is indicated by running `ipset -t list`. A full list of all blocked addresses is given
by `ipset list`.


## Components

- `update-ip-blocklist.sh`: Pulls the latest versions of requested blocklists, updates ipsets, and exports created
  ipsets to `$IPSET_DIR` (default: `/var/lib/ipset`). Ipsets are swapped during update to minimize the update downtime.
- `ufw/after.init`: Inserts and deletes the required `iptables` rules on `ufw` reloads. Ipsets are loaded
  from `$IPSET_DIR`.
- `setup-ufw.sh`: Helper script to deploy `ufw/after.init`.


## Acknowledgments

This project is inspired by [this post on Xela's Linux Blog](https://spielwiese.la-evento.com/xelasblog/archives/74-Ipset-aus-der-Spamhaus-DROP-gemeinsam-mit-ufw-nutzen.html).

