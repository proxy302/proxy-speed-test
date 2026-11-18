# proxy-speed-test: how much latency does a proxy add?

To measure a proxy's speed, time the same request with and without the proxy, several rounds in a row, and compare each stage: the TCP connection, the encrypted tunnel to the site, the first byte of the answer and the total. The difference in time to first byte is the latency the proxy adds to every new connection. Download speed only tells you something when you fetch a file of a few megabytes; on a tiny response it is noise. `proxy-speed.sh` alternates direct and proxied requests with curl's built-in timers and prints every round plus the medians, so one slow round does not decide the result.

Proxy302 maintains this tool and sells these proxies. The cheapest way to measure one of ours from your own location is a static residential (ISP) IP for one day at $0.50 ([prices](https://proxy302.com/pricing/)). The script works with any HTTP or SOCKS5 proxy.

## Usage

```bash
git clone https://github.com/proxy302/proxy-speed-test
cd proxy-speed-test
./proxy-speed.sh 'http://USER:PASS@HOST:PORT'                     # 5 rounds against https://api.ipify.org
./proxy-speed.sh 'socks5h://USER:PASS@HOST:PORT' 10               # 10 rounds
./proxy-speed.sh 'http://USER:PASS@HOST:PORT' 3 'https://YOUR-SITE/large-file.bin'   # throughput
NO_DIRECT=1 ./proxy-speed.sh 'http://USER:PASS@HOST:PORT'         # proxy only, no baseline
```

Needs bash, curl and awk. For throughput, use a file you are allowed to download, ideally from the site or region you care about; your own server or storage bucket is a good choice.

## Example output

Five rounds through a test proxy running on the same machine, so the proxy itself costs almost nothing here. A remote proxy adds its own round trip on top:

```
URL: https://api.ipify.org   rounds: 5
round route      connect        tls first byte      total         size         speed
1     direct        9 ms      22 ms     281 ms     281 ms         14 B     0.00 MB/s  HTTP 200
1     proxy         0 ms      22 ms     292 ms     292 ms         14 B     0.00 MB/s  HTTP 200
2     direct        7 ms      19 ms     281 ms     281 ms         14 B     0.00 MB/s  HTTP 200
2     proxy         0 ms      20 ms     291 ms     291 ms         14 B     0.00 MB/s  HTTP 200
3     direct        9 ms      22 ms     749 ms     750 ms         14 B     0.00 MB/s  HTTP 200
3     proxy         0 ms      22 ms     723 ms     723 ms         14 B     0.00 MB/s  HTTP 200
4     direct        7 ms      19 ms     279 ms     279 ms         14 B     0.00 MB/s  HTTP 200
4     proxy         0 ms      18 ms     252 ms     252 ms         14 B     0.00 MB/s  HTTP 200
5     direct        8 ms      20 ms     269 ms     269 ms         14 B     0.00 MB/s  HTTP 200
5     proxy         0 ms      20 ms     281 ms     281 ms         14 B     0.00 MB/s  HTTP 200

Median of the successful rounds
route      connect        tls first byte      total         speed
direct        8 ms      20 ms     281 ms     281 ms     0.00 MB/s
proxy         0 ms      20 ms     291 ms     291 ms     0.00 MB/s

Time to first byte, proxy minus direct (medians): +10 ms
The response is under 1 MB, so the speed column means little. Pass a large file's URL to measure throughput.
```

Round 3 was slow on both routes at once, which points at the site or the network, not the proxy. The medians leave it out.

## What each column measures

All times count from the start of the request, as curl reports them.

| Column | Direct | Through the proxy |
|---|---|---|
| `connect` | TCP connection to the site | TCP connection to the proxy |
| `tls` | TLS handshake with the site done | Tunnel through the proxy opened and TLS with the site done; `-` for plain `http://` URLs |
| `first byte` | First byte of the answer arrived | Same, now including the trip through the proxy |
| `total` | Whole response received | Same |
| `speed` | Average download speed | Same; meaningful only for files of a few MB or more |

## Reading the numbers

- **`connect` through the proxy is the distance to the proxy.** A high number here means the proxy server is far from you.
- **The jump from `connect` to `tls` through the proxy** is the proxy reaching the site and the TLS handshake travelling back and forth through it. A proxy far from the site makes this grow.
- **The first-byte difference is the figure to compare between proxies.** Every new connection pays it once. Reusing connections (keep-alive) pays it only once for many requests.
- **Direct and proxy slow in the same round** means the site or your own line had a slow moment.
- **Throughput through a proxy** depends on the path from the proxy to the file's server and from the proxy to you. Test with a file hosted where your real traffic goes.

## FAQ

**The proxy route came out faster than direct. Is that possible?** Yes, within the noise of a few rounds, and sometimes for real when the proxy has a better route to the site than your own provider does. Run more rounds before drawing conclusions.

**Why medians and not averages?** One stalled request can double an average. The median of five or more rounds is steadier.

**Does it work with SOCKS5?** Yes, use `socks5h://` so the proxy resolves the site's name.

**Can I test several proxies?** Run it once per proxy with the same URL and number of rounds, ideally at the same time of day, and compare the first-byte medians. To check a whole list for reachability first, see [proxy-list-health-check](https://github.com/proxy302/proxy-list-health-check).

*Facts checked 19 November 2026.*
