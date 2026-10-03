#!/usr/bin/env bash
# Install the patched wrapper on a device running the 2026-09-27 test build, select the voice-recognition
# remap, and reboot. Keeps the original on the device at /data/local/tmp/audio.primary.amazon_wrapper.so.orig.
#
#   ./install.sh [path/to/audio.primary.amazon_wrapper.so]      (default: out/, else prebuilt/)
#   ANDROID_SERIAL=<serial> ./install.sh                        (several adb devices)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
lib="${1:-}"
[ -n "$lib" ] || { [ -f "$here/out/audio.primary.amazon_wrapper.so" ] && lib="$here/out/audio.primary.amazon_wrapper.so" || lib="$here/prebuilt/audio.primary.amazon_wrapper.so"; }
target=/vendor/lib/hw/audio.primary.amazon_wrapper.so

echo "== installing $lib"
adb root >/dev/null; sleep 2; adb wait-for-device
adb remount >/dev/null
adb shell "[ -f /data/local/tmp/audio.primary.amazon_wrapper.so.orig ] || cp $target /data/local/tmp/audio.primary.amazon_wrapper.so.orig"
adb push "$lib" "$target" >/dev/null
adb shell "chmod 644 $target && chcon u:object_r:vendor_file:s0 $target && setprop persist.vendor.audio.mic_remap vr"
adb shell "ls -lZ $target; echo mic_remap=\$(getprop persist.vendor.audio.mic_remap)"
echo "== rebooting"
adb reboot
echo "After boot, check: adb logcat -d | grep mic_remap   (expect: mic_remap=vr: input source 1 -> 6)"
