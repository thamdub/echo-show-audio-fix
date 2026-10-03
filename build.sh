#!/usr/bin/env bash
# Build audio.primary.amazon_wrapper.so with the mic_remap patch.
#
# Needs: an Android NDK (r26 or newer), curl, git, and the device connected over adb (the three system libraries
# the wrapper links against are taken from it).
#
#   ANDROID_NDK_HOME=/path/to/ndk ./build.sh            # uses the only adb device
#   ANDROID_NDK_HOME=/path/to/ndk ANDROID_SERIAL=<serial> ./build.sh
#
# Output: out/audio.primary.amazon_wrapper.so
set -euo pipefail

UPSTREAM_REPO="https://github.com/amazon-oss/android_hardware_amazon"
UPSTREAM_COMMIT="e9e61757b8"          # the audio wrapper as shipped in the 2026-09-27 test builds
LINEAGE_BRANCH="lineage-18.1"

here="$(cd "$(dirname "$0")" && pwd)"
work="$here/work"
out="$here/out"
: "${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME to your NDK directory}"

host_tag="$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64"   # NDK ships x86_64 host tools; Apple Silicon runs them under Rosetta
cxx="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$host_tag/bin/armv7a-linux-androideabi30-clang++"
[ -x "$cxx" ] || { echo "compiler not found: $cxx" >&2; exit 1; }

rm -rf "${work:?}" "${out:?}"
mkdir -p "$work/inc" "$work/libs" "$out"

echo "== wrapper source at $UPSTREAM_COMMIT"
git clone -q "$UPSTREAM_REPO" "$work/src"
git -C "$work/src" checkout -q "$UPSTREAM_COMMIT"
git -C "$work/src" apply "$here/mic_remap.patch"

echo "== LineageOS $LINEAGE_BRANCH headers"
fetch_headers() {   # repo, then the include directories to copy
    local repo="$1"; shift
    curl -sfL "https://codeload.github.com/LineageOS/$repo/tar.gz/refs/heads/$LINEAGE_BRANCH" -o "$work/$repo.tgz"
    local top; top="$(tar tzf "$work/$repo.tgz" | head -1 | cut -d/ -f1)"
    for dir in "$@"; do
        tar xzf "$work/$repo.tgz" -C "$work" "$top/$dir"
        cp -R "$work/$top/$dir/." "$work/inc/"
    done
}
fetch_headers android_system_core libcutils/include liblog/include libsystem/include libutils/include
fetch_headers android_hardware_libhardware include
fetch_headers android_system_media audio/include

echo "== link libraries from the device"
for lib in libcutils libhardware liblog; do
    adb pull "/system/lib/$lib.so" "$work/libs/$lib.so" >/dev/null
done

echo "== build"
"$cxx" -shared -fPIC -O2 -Wall -Werror -Wno-unused-parameter -fno-exceptions -fno-rtti -nostdlib++ \
    -I"$work/inc" -o "$out/audio.primary.amazon_wrapper.so" \
    "$work/src/audio/hal/audio_hw.cpp" "$work/src/audio/hal/audio_stream.cpp" \
    -L"$work/libs" -lcutils -lhardware -llog -Wl,-soname,audio.primary.amazon_wrapper.so

(cd "$out" && shasum -a 256 audio.primary.amazon_wrapper.so)
echo "built: $out/audio.primary.amazon_wrapper.so"
