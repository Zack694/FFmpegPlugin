#!/bin/bash
set -euo pipefail

if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    echo "ANDROID_SDK_ROOT not set"
    exit 1
fi
if [ -z "${ANDROID_NDK_ROOT:-}" ]; then
    echo "ANDROID_NDK_ROOT not set"
    exit 1
fi
if [[ "$PWD" == *scripts ]]; then
   cd ..
fi
if [ ! -e ./ffmpeg-kit ]; then
  echo "No ffmpeg-kit. Did you run setup_environ.sh first?"
  exit 1
fi
cd ffmpeg-kit

# Build only arm64-v8a, with the Android MediaCodec encoders (hevc_mediacodec /
# h264_mediacodec) plus software x264/x265. --no-archive skips ffmpeg-kit's AAR
# gradle step (which we don't need and which is fragile across Java versions);
# the prebuilt ffmpeg binary + shared libs are produced before that step.
./android.sh --no-archive --api-level=24 \
  --disable-arm-v7a --disable-arm-v7a-neon --disable-x86 --disable-x86-64 \
  --enable-android-media-codec --enable-gpl --enable-x264 --enable-x265

# Fail loudly if the ffmpeg binary was not actually produced (instead of
# silently shipping an APK with no native libs).
if [ ! -f prebuilt/android-arm64/ffmpeg/bin/ffmpeg ]; then
  echo "ERROR: ffmpeg binary was not built. Last lines of build.log:"
  tail -n 200 build.log || true
  exit 1
fi

# libc++_shared.so is required at runtime (x265 etc. link the C++ runtime).
# Take it straight from the NDK so we don't depend on ffmpeg-kit's packaging.
NDK_CPP_SHARED="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"

function copy_libs {
   local abi="$1"
   local prebuilt_arch="$2"
   mkdir -p "../app/libs/lib/${abi}/"
   rm -f "../app/libs/lib/${abi}/"*
   cp "prebuilt/${prebuilt_arch}/ffmpeg/bin/ffmpeg" \
      "prebuilt/${prebuilt_arch}/ffmpeg/bin/ffprobe" \
      "../app/libs/lib/${abi}/"
   cp "prebuilt/${prebuilt_arch}/ffmpeg/lib/"*.so "../app/libs/lib/${abi}/"
   mv "../app/libs/lib/${abi}/ffmpeg" "../app/libs/lib/${abi}/libffmpeg.so"
   mv "../app/libs/lib/${abi}/ffprobe" "../app/libs/lib/${abi}/libffprobe.so"
   if [ -f "${NDK_CPP_SHARED}" ]; then
      cp "${NDK_CPP_SHARED}" "../app/libs/lib/${abi}/"
   elif [ -f "android/libs/${abi}/libc++_shared.so" ]; then
      cp "android/libs/${abi}/libc++_shared.so" "../app/libs/lib/${abi}/"
   else
      echo "ERROR: could not find libc++_shared.so"
      exit 1
   fi
}

mkdir -p ../app/libs/lib
copy_libs arm64-v8a android-arm64

cd ../app/libs/
rm -f libraries.jar
zip -r ./libraries.jar lib/

# Final sanity check: the jar MUST contain the native libs, or the APK will be
# useless (this is what produced the earlier ~200KB "FFmpeg not found" APK).
if ! unzip -l libraries.jar | grep -q "libffmpeg.so"; then
  echo "ERROR: libraries.jar does not contain libffmpeg.so"
  exit 1
fi
echo "libraries.jar built successfully:"
unzip -l libraries.jar
