import 'package:flutter/widgets.dart';

/// Web / non-Pi fallback: no gstreamer backend, so nothing to register and no
/// live stream. Callers just get the [fallback] (snapshot) widget.
void registerDoorVideo() {}

Widget doorLiveVideo(String subUrl, String mainUrl, {required Widget fallback}) => fallback;
