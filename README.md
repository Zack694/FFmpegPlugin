# FFmpegPlugin (MediaCodec HEVC build)

FFmpeg Plugin for PojavLauncher / ZalithLauncher.

This fork rebuilds the plugin's FFmpeg with **Android MediaCodec support enabled**,
so the bundled `ffmpeg` exposes the hardware encoders **`hevc_mediacodec`** and
**`h264_mediacodec`** (in addition to the existing software encoders like x264 /
x265). This lets recording mods (e.g. RecordZy) use the phone's hardware HEVC
encoder.

### Why this works inside PojavLauncher
Pojav/Zalith run Minecraft on a bundled desktop OpenJDK, which has no access to
Android's Java framework. FFmpeg's MediaCodec encoder handles this: when no Java
VM is present it automatically uses the **NDK (`libmediandk`) path** instead of
JNI, so a standalone `ffmpeg` binary can still drive the hardware encoder.

### What changed vs upstream
- `scripts/build_libs.sh`: added `--enable-android-media-codec` and restricted the
  build to **arm64-v8a** (the only ABI modern phones need; keeps CI fast).
- `.github/workflows/android.yml`: builds a **debug APK** (no signing secret
  required), pins **NDK r25c**, and uploads the APK as a build artifact.
- Gradle wrapper pinned to 7.6.4 to match AGP 7.4.1.

FFmpeg version: **n6.0** (via arthenica/ffmpeg-kit 6.0), which includes the
MediaCodec encoder.

### How to get the built APK (no PC needed)
1. Push this branch / open the PR — **GitHub Actions** builds it automatically.
2. Open the workflow run under the **Actions** tab and download the
   **`FFmpegPlugin-mediacodec-debug`** artifact.
3. Install that APK and select it as the FFmpeg plugin in Zalith/Pojav.

### Building locally (Linux only)
```
# Requires ANDROID_SDK_ROOT + ANDROID_NDK_ROOT (NDK r25c recommended)
# and: autoconf automake libtool pkg-config nasm yasm cmake ninja-build build-essential
./scripts/setup_environ.sh
./scripts/build_libs.sh
./gradlew assembleDebug
```

### Caveats
- Some Adreno GPUs reject FFmpeg's default input color space for MediaCodec; if
  encoding fails, feeding `nv12`/`yuv420p` usually fixes it.
- Hardware encoder rate-control/quality differs from x264/x265.
