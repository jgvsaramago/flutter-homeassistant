import 'package:flutter/widgets.dart';

import '../kiosk/modals/intercom_modal.dart';

/// Web / non-Pi fallback: no gstreamer backend, so nothing to register and no
/// live stream. Callers just get the [fallback] (snapshot) widget.
void registerDoorVideo() {}

Widget doorLiveVideo(
  String subUrl,
  String mainUrl, {
  required ValueNotifier<IntercomVideoStatus> status,
  required ValueNotifier<bool> audio,
  required Widget fallback,
}) => fallback;

/// No door sound off the Pi.
class DoorAudio {
  DoorAudio(this.rtspUrl);

  final String rtspUrl;

  void setPlaying(bool on) {}
}
