import 'dart:io';

/// The process environment — set via a systemd unit's `Environment=`/
/// `EnvironmentFile=`, or plain `export` before `exec`-ing the app in a
/// launch script. Unlike argv on flutter-pi, this reliably reaches the app:
/// it's inherited through the OS process model, not something the embedder
/// has to deliberately forward.
Map<String, String> readLaunchEnvironment() => Platform.environment;
