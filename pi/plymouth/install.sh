#!/bin/sh
# Boot splash for the kiosk Pi (design: "Arranque"). Run on the Pi as root
# from this folder, then reboot. The images are pre-rotated: the panel is
# portrait but scans out landscape, portrait top on the HDMI picture's left.
set -e

apt-get install -y plymouth
rm -rf /usr/share/plymouth/themes/casa
cp -r casa /usr/share/plymouth/themes/casa

# Kernel/systemd text off the screen; Plymouth ignores the serial console
# (otherwise it falls back to text mode).
CMDLINE=/boot/firmware/cmdline.txt
sed -i 's/console=tty1 /console=tty3 /' "$CMDLINE"
grep -q ' splash' "$CMDLINE" || sed -i 's/$/ quiet splash plymouth.ignore-serial-consoles loglevel=3 logo.nologo vt.global_cursor_default=0 systemd.show_status=false rd.systemd.show_status=false udev.log_level=3 rd.udev.log_level=3/' "$CMDLINE"
grep -q '^disable_splash=1' /boot/firmware/config.txt || echo 'disable_splash=1' >> /boot/firmware/config.txt
# Note: no DSI overlay may stay enabled in config.txt — Plymouth draws on
# the first DRM device only, and a DSI one would win over HDMI.

# Keep the last splash frame until the app draws over it, and no login
# prompt on tty1 in between.
mkdir -p /etc/systemd/system/plymouth-quit.service.d /etc/systemd/system/flutter-homeassistant.service.d
printf '[Service]\nExecStart=\nExecStart=-/usr/bin/plymouth quit --retain-splash\n' > /etc/systemd/system/plymouth-quit.service.d/retain-splash.conf
printf '[Unit]\nAfter=plymouth-start.service\n\n[Service]\nExecStartPre=+-/usr/bin/plymouth quit --retain-splash\n' > /etc/systemd/system/flutter-homeassistant.service.d/plymouth.conf
systemctl disable getty@tty1.service
systemctl daemon-reload

plymouth-set-default-theme -R casa
