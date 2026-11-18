#!/usr/bin/env bash
# proxy-speed.sh: measure what a proxy adds to each stage of a request (connect, TLS, first byte,
# total) by timing the same URL with and without the proxy, round after round.
# Usage: ./proxy-speed.sh 'PROXY_URL' [rounds=5] [url=https://api.ipify.org]
#   PROXY_URL is http://USER:PASS@HOST:PORT or socks5h://USER:PASS@HOST:PORT
#   For download speed pass the URL of a large file you may download (a few MB or more).
#   NO_DIRECT=1 skips the baseline without the proxy.
# Needs bash, curl and awk. Maintained by Proxy302 (https://proxy302.com). MIT licence.
set -u
proxy="${1:?usage: $0 PROXY_URL [rounds] [url]}"
rounds="${2:-5}"
url="${3:-https://api.ipify.org}"
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
fmt='%{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{size_download} %{speed_download} %{http_code}'

routes="proxy"; [ "${NO_DIRECT:-0}" = 1 ] || routes="direct proxy"

measure() {   # $1 = round, $2 = route; appends one line to $tmp and prints it
  local opts=(-s -o /dev/null --max-time 120 -w "$fmt") out rc
  [ "$2" = proxy ] && opts+=(-x "$proxy")
  out=$(curl "${opts[@]}" "$url"); rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%-5s %-7s request failed (curl exit %s)\n' "$1" "$2" "$rc"; return
  fi
  echo "$2 $out" >> "$tmp"
  echo "$1 $2 $out" | awk '{
    tls = ($4 > 0) ? sprintf("%7.0f ms", $4 * 1000) : "      -   "
    if ($7 < 1000) size = sprintf("%d B", $7)
    else if ($7 < 1e6) size = sprintf("%.1f KB", $7 / 1e3)
    else size = sprintf("%.1f MB", $7 / 1e6)
    printf "%-5s %-7s %7.0f ms %s %7.0f ms %7.0f ms %12s %8.2f MB/s  HTTP %s\n",
           $1, $2, $3 * 1000, tls, $5 * 1000, $6 * 1000, size, $8 / 1e6, $9 }'
}

echo "URL: $url   rounds: $rounds"
printf '%-5s %-7s %10s %10s %10s %10s %12s %13s\n' round route connect tls "first byte" total size speed
for r in $(seq 1 "$rounds"); do
  for route in $routes; do measure "$r" "$route"; done
done

median() {   # $1 = route, $2 = column number in $tmp
  awk -v r="$1" -v c="$2" '$1 == r { print $c }' "$tmp" | sort -n \
    | awk '{ v[NR] = $1 } END { if (NR == 0) print "nan"; else if (NR % 2) print v[(NR + 1) / 2]; else print (v[NR / 2] + v[NR / 2 + 1]) / 2 }'
}

echo
echo "Median of the successful rounds"
printf '%-7s %10s %10s %10s %10s %13s\n' route connect tls "first byte" total speed
for route in $routes; do
  c=$(median "$route" 2); t=$(median "$route" 3); f=$(median "$route" 4); a=$(median "$route" 5); s=$(median "$route" 7)
  [ "$c" = nan ] && { printf '%-7s no successful rounds\n' "$route"; continue; }
  awk -v r="$route" -v c="$c" -v t="$t" -v f="$f" -v a="$a" -v s="$s" 'BEGIN {
    tls = (t > 0) ? sprintf("%7.0f ms", t * 1000) : "      -   "
    printf "%-7s %7.0f ms %s %7.0f ms %7.0f ms %8.2f MB/s\n", r, c * 1000, tls, f * 1000, a * 1000, s / 1e6 }'
  eval "${route}_ttfb=$f ${route}_total=$a"
done

if [ "${direct_ttfb:-}" != "" ] && [ "${proxy_ttfb:-}" != "" ]; then
  awk -v d="$direct_ttfb" -v p="$proxy_ttfb" 'BEGIN {
    printf "\nTime to first byte, proxy minus direct (medians): %+.0f ms\n", (p - d) * 1000 }'
fi
size=$(median proxy 6)
if [ "$size" != nan ] && awk -v s="$size" 'BEGIN { exit !(s < 1000000) }'; then
  echo "The response is under 1 MB, so the speed column means little. Pass a large file's URL to measure throughput."
fi
