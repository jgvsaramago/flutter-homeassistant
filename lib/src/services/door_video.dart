// Live door-camera video, flutter-pi only.
//
// registerDoorVideo() must run once in main() before runApp (the flutter-pi
// gstreamer backend registers itself as the video_player platform); it's a
// no-op on web. doorLiveVideo() returns a live RTSP view on the Pi, or just
// its fallback (the snapshot view) everywhere else and while connecting.
export 'door_video_stub.dart' if (dart.library.io) 'door_video_io.dart';
