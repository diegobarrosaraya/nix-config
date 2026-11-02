#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
phone_dir="/sdcard/Download/phone"
staging="$(mktemp -d /tmp/phone-nix-config.XXXXXX)"
trap 'rm -rf "$staging"' EXIT

cd "$repo"

mkdir -p "$staging"
for f in \
  flake.nix \
  flake.lock \
  parts \
  overlays \
  pkgs \
  hosts/jade/nix-on-droid.nix \
  modules/home-manager/colorschemes; do
  cp -r --parents "$f" "$staging/"
done

adb shell "rm -rf $phone_dir/nix-config $phone_dir/nix-config.tar.gz"
adb push "$staging/." "$phone_dir/nix-config/"

adb shell "cat > /sdcard/Download/switch-jade.sh" <<'EOF'
set -e
rm -rf $HOME/nix-config
mkdir -p $HOME/nix-config
cp -r /sdcard/Download/phone/nix-config/. $HOME/nix-config/
cd $HOME/nix-config
(
  while true; do echo "HB $(date +%H:%M:%S)" >> $HOME/switch_hb.txt; sleep 30; done
) &
HB=$!
echo "=== starting switch $(date) ===" > $HOME/switch.log
nix-on-droid switch --flake .#jade >> $HOME/switch.log 2>&1
echo "SWITCH_EXIT=$?" >> $HOME/switch.log
kill $HB 2>/dev/null
cp -f $HOME/switch.log /sdcard/Download/switch.log 2>/dev/null || true
cp -f $HOME/switch_hb.txt /sdcard/Download/switch_hb.txt 2>/dev/null || true
echo SWITCH_SCRIPT_DONE
EOF
adb shell "chmod 755 /sdcard/Download/switch-jade.sh"

echo "Deployed $(find "$staging" -type f | wc -l | tr -d ' ') files to $phone_dir/nix-config/"
echo
echo "On the phone (nix-on-droid app), run:"
echo "  bash /sdcard/Download/switch-jade.sh"
