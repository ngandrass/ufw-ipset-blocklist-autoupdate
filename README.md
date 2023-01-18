# ufw-ipset-blocklist-autoupdate

This collection of scripts automatically pulls IP blocklists (e.g. Spamhaus, Blocklist, ...) and drops packages from
listed IP addresses. It integrates with the uncomplicated firewall (`ufw`) and makes use of `ipset` for storing IP
addresses and network ranges.


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
           Format: " " (space-separated). See examples below.
  -q     : Quiet mode. Outputs are suppressed if flag is present.
  -v     : Verbose mode. Prints additional information during execution.
  -h     : Print this help message.

Example usage:
./update-ip-blocklists.sh -l "spamhaus https://www.spamhaus.org/drop/drop.txt"
./update-ip-blocklists.sh -l "blocklist https://lists.blocklist.de/lists/all.txt" -l "spamhaus https://www.spamhaus.org/drop/drop.txt"
```

### Supplying blocklist sources

Blocklists can be passed to the script using the `-l` CLI argument. Each entry consists of a name and download URL,
separated by a space. Examples:

- `-l "spamhaus https://www.spamhaus.org/drop/drop.txt"`
- `-l "mylist http://mylist.local/list.txt`

Lists are stripped of comments. This means all text after one of the following characters is removed before
parsing: `;`, `#`. Valid IPv4 addresses with an optional CIDR are loaded into the ipset to block.


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