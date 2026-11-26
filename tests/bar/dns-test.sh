#!/usr/bin/env bash
# bar-dns against a fake nmcli that answers from, and records into, a scratch directory.
set -euo pipefail

helper=$1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

mkdir "$tmp/bin"
cat >"$tmp/bin/nmcli" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE/calls"
case "$*" in
  *"connection show --active") cat "$FAKE/active" ;;
  *"ipv4.dns connection show"*) cat "$FAKE/dns" ;;
esac
STUB
chmod +x "$tmp/bin/nmcli"
export FAKE=$tmp PATH=$tmp/bin:$PATH

printf 'tun0:tun:tailscale0\nuuid-1:802-11-wireless:wlan0\n' >"$tmp/active"

: >"$tmp/dns"
[[ $("$helper") == "DHCP" ]] || fail "no servers set reads as DHCP"

echo "1.1.1.1,1.0.0.1" >"$tmp/dns"
[[ $("$helper") == "Cloudflare" ]] || fail "Cloudflare's servers read as Cloudflare"

echo "9.9.9.9" >"$tmp/dns"
[[ $("$helper") == "Custom" ]] || fail "other servers read as Custom"
echo "ok - the provider is read from the connection in use"

: >"$tmp/calls"
"$helper" Google
grep -qxF 'connection modify uuid-1 ipv4.dns 8.8.8.8 8.8.4.4 ipv4.ignore-auto-dns yes ipv6.dns 2001:4860:4860::8888 2001:4860:4860::8844 ipv6.ignore-auto-dns yes' "$tmp/calls" ||
  fail "a provider's servers replace the network's own"
grep -qxF 'device reapply wlan0' "$tmp/calls" || fail "the change is applied to the device"
echo "ok - a provider's servers replace the network's own"

: >"$tmp/calls"
"$helper" DHCP
grep -qxF 'connection modify uuid-1 ipv4.dns  ipv4.ignore-auto-dns no ipv6.dns  ipv6.ignore-auto-dns no' "$tmp/calls" ||
  fail "DHCP hands the servers back to the network"
echo "ok - DHCP hands the servers back to the network"

: >"$tmp/calls"
if "$helper" Nonsense 2>/dev/null; then
  fail "an unknown provider is refused"
fi
[[ ! -s $tmp/calls || -z $(grep modify "$tmp/calls") ]] || fail "an unknown provider changes nothing"
echo "ok - an unknown provider is refused"

printf 'tun0:tun:tailscale0\n' >"$tmp/active"
[[ $("$helper") == "DHCP" ]] || fail "with no network connection it reads as DHCP"
if "$helper" Google 2>/dev/null; then
  fail "with no network connection nothing can be set"
fi
echo "ok - with no network connection nothing is set"
