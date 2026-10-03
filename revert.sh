#!/usr/bin/env bash
# Put back the wrapper that came with the ROM (saved by install.sh) and clear the property, then reboot.
#
#   ./revert.sh
#   ANDROID_SERIAL=<serial> ./revert.sh
set -euo pipefail

target=/vendor/lib/hw/audio.primary.amazon_wrapper.so
adb root >/dev/null; sleep 2; adb wait-for-device
adb remount >/dev/null
adb shell "[ -f /data/local/tmp/audio.primary.amazon_wrapper.so.orig ]" || { echo "no saved original on the device; reflash the ROM zip instead" >&2; exit 1; }
adb shell "cp /data/local/tmp/audio.primary.amazon_wrapper.so.orig $target && chmod 644 $target && chcon u:object_r:vendor_file:s0 $target && setprop persist.vendor.audio.mic_remap ''"
echo "== original restored, rebooting"
adb reboot
