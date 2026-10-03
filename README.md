# Echo Show 5 (checkers) test build: no sound while the mic is open

A small patch to the LineageOS audio HAL wrapper for the **2026-09-27 test builds** of LineageOS 18.1 for the Echo
Show 5 1st gen (checkers), the builds that turn on Amazon's capture processing (ASP).

## Symptom

The microphone works, but **nothing plays** once an app keeps the mic open: no voice answers, no chimes, no music.
Sounds that play before the mic opens (boot sounds) are fine. Apps that hold the mic continuously, such as
[Kiosk Satellite](https://github.com/jxlarrea/kiosk-satellite) as a voice satellite, hit this all the time.

The log shows the speaker pipeline waiting for a reference that never comes:

```
ASP/ER: sync is enabled for writer pipeline 3 (speaker)
ASP/ER: Loopback signal is zero. Cannot synchronize yet
```

## Cause

Commit `ebb02460ed` in [amazon-oss/android_hardware_amazon](https://github.com/amazon-oss/android_hardware_amazon)
("audio: Run Amazon's capture processing for mic captures") remaps plain `MIC` captures to
`VOICE_COMMUNICATION`, so ASP runs its **voice-call** pipeline. With that pipeline open, every playback gets a speaker
pipeline that waits to synchronise with the echo reference (`DL1_AWB_Record`). The reference is a loopback of the
speaker output, so it stays at zero until the speaker plays, and the speaker waits for the reference: nothing is
heard.

The kernel path is fine: with the mic closed, `tinycap -D 0 -d 8 -c 2 -r 48000` records playback normally.

## Fix

Remap plain mic captures to **`VOICE_RECOGNITION`** instead, which runs ASP's ASR pipeline (the one Alexa listens
with). Its speaker pipeline synchronises within about a second (`Synchronized. Slice 1`) and everything plays.

The patch makes the choice a property, so nothing changes until you set it:

| `persist.vendor.audio.mic_remap` | Mic captures go to | |
|---|---|---|
| `voip` (default, also when unset) | voice communication | as in the test build |
| `vr` | voice recognition (ASR: beamforming + echo cancellation) | **the fix** |
| `none` | the plain mic, no remap | no Amazon processing |

Tested on an Echo Show 5 1st gen with the 2026-09-27 test build and Kiosk Satellite 2026.10.3 as a Home Assistant
voice satellite, with `vr`: voice answers, chimes and music play; the wake word triggers over music; interrupting a
realtime conversation works at a normal speaking voice; the voice level reaching the app was about 3x the plain
mic's. The test build's commit notes that the voice recognition path has no gain or noise-reduction stage; in this
use it sounded better than the plain mic.

## Files

| File | |
|---|---|
| `mic_remap.patch` | Against `audio/hal/audio_hw.cpp` at `e9e61757b8`; applies with `git apply`. ~25 lines. |
| `prebuilt/audio.primary.amazon_wrapper.so` | Built from that commit + the patch (armv7, API 30). Checksum in `prebuilt/SHA256SUMS`. |
| `build.sh` | Rebuilds it: NDK + LineageOS 18.1 headers + three system libraries pulled from the device. Reproducible: it produced the same bytes as the prebuilt. |
| `install.sh` | Installs it, keeps the original on the device, sets `vr`, reboots. |
| `revert.sh` | Restores the original and clears the property. |

## Install

Requires the 2026-09-27 test build on a checkers device, `adb` with root (the userdebug build allows `adb root`).

```sh
./install.sh                     # prebuilt, or out/ if you ran build.sh
adb logcat -d | grep mic_remap   # after boot: "mic_remap=vr: input source 1 -> 6"
```

To build it yourself instead: `ANDROID_NDK_HOME=/path/to/ndk ./build.sh`, then `./install.sh`.

Switching modes without reinstalling: `adb shell setprop persist.vendor.audio.mic_remap voip|vr|none` and reboot.

**A ROM update replaces the wrapper** (it lives on the system partition); reinstall afterwards until the change is
in the ROM.

## Revert

```sh
./revert.sh
```

or reflash the ROM zip from TWRP (no wipe needed).

## Not tested

Echo Show 5 2nd gen (cronos) and Echo Show 8 (crown) test builds share the wrapper source, so the same patch should
apply, but neither has been tried.

## License

The wrapper is LineageOS code under the Apache License 2.0; this patch is offered under the same license.
