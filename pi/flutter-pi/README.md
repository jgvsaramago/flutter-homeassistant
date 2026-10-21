# Patched flutter-pi (live door video)

The kiosk's live door-camera video needs a patched flutter-pi. Stock flutter-pi
1.1.1 can't play a live RTSP stream through its gstreamer video player:

1. **`initialized` never fires for a live source.** flutter-pi only reports a
   player as ready once it knows duration and seekability. For live streams it
   fakes those, but only when `is_live` is set, and `is_live` is only set when
   the initial `set_state(PAUSED)` returns `NO_PREROLL` synchronously. `rtspsrc`
   connects asynchronously, so it returns `ASYNC`. Fix: treat any
   unknown-duration stream as unbounded and non-seekable (`fetch_duration`,
   `fetch_seeking`).
2. **No frames in PAUSED.** flutter-pi parks pipelines in PAUSED until Dart
   calls `play()`, and Dart only calls `play()` after `initialized`. A live
   source produces no data in PAUSED, so caps never reach the appsink. Fix:
   custom-pipeline players start straight in PLAYING (`init`).
3. **1080p system-memory frames can't be uploaded.** To hand a system-memory
   frame to EGL, flutter-pi copies it into a GBM buffer allocated as one row
   `frame_size` pixels wide, which is past the GPU's maximum width for any real
   frame. Fix: a 4096-byte-wide linear buffer with as many rows as needed
   (same contiguous bytes).
4. **`setVolume` does nothing.** `gstplayer_set_volume` is an unimplemented
   stub upstream. Fix: it sets the `volume` property of the pipeline element
   named `volume`, which the app puts in front of the door audio's sink.

The patch is `live-video.patch`, against tag `release/1.1.1` of
https://github.com/ardera/flutter-pi (the version `flutterpi_tool` 0.12.0
bundles for Flutter 3.44.6).

## Install on the Pi

The systemd service runs `/usr/local/bin/flutter-pi`, not the copy inside the
app bundle, so normal app deploys don't overwrite the patched binary. A Pi
reimage does, so redo this after one:

```sh
sudo apt-get install -y cmake libdrm-dev libgbm-dev libegl-dev libgles-dev \
  libsystemd-dev libinput-dev libudev-dev libxkbcommon-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libvulkan-dev
git clone --depth 1 --branch release/1.1.1 https://github.com/ardera/flutter-pi.git ~/src/flutter-pi-build
cd ~/src/flutter-pi-build
git apply /path/to/live-video.patch
mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Release .. && make -j4
sudo systemctl stop flutter-homeassistant.service
sudo cp flutter-pi /usr/local/bin/flutter-pi.new && sudo mv -f /usr/local/bin/flutter-pi.new /usr/local/bin/flutter-pi
sudo systemctl start flutter-homeassistant.service
```

Check: `strings /usr/local/bin/flutter-pi | grep -c "GBM BO stride"` prints 1.
The stock binary is kept at `/usr/local/bin/flutter-pi.orig-1.1.1`.

## Don't use the hardware HEVC decoder

The door camera's H.265 stream made the Pi 5's HEVC kernel driver
(`rpi_hevc_dec`) hang in `hevc_d_h265_stop`. The process was stuck in the
kernel where even SIGKILL couldn't touch it, freezing the kiosk and blocking a
clean reboot. The app therefore software-decodes the H.264 main stream
(`avdec_h264`, about 10% of total CPU at 1080p25). Keep both door streams on
H.264; the neighbours' indoor station needs the sub-stream (ch102) on H.264
regardless.
