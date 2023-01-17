# ufw-ipset-blocklist-autoupdate


## Installation

1. Install `ufw` and `ipset`.
2. Deploy `after.init` script via executing: `./setup-ufw.sh`
3. Determine the blocklist you would like to use.
4. Get initial set of blocklists: `./update-ip-blocklists.sh -l "blocklist https://lists.blocklist.de/lists/all.txt" -l "spamhaus https://www.spamhaus.org/drop/drop.txt"`
5. Add `update-ip-blocklists.sh` to your crontab:
```text
@daily /path/to/update-ip-blocklists.sh  -l "blocklist https://lists.blocklist.de/lists/all.txt" -l "spamhaus https://www.spamhaus.org/drop/drop.txt"
```


## Acknowledgments

This project is inspired by [this post on Xela's Linux Blog](https://spielwiese.la-evento.com/xelasblog/archives/74-Ipset-aus-der-Spamhaus-DROP-gemeinsam-mit-ufw-nutzen.html).