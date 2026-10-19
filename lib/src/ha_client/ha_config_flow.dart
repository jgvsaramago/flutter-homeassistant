// Starts Home Assistant config flows over REST — HA exposes flows only at
// `/api/config/config_entries/flow`, not over the websocket. Uses dart:io's
// HttpClient, so a stub swaps in on web (where it doesn't work at all, and
// the cross-origin REST call would be CORS-blocked anyway).
export 'ha_config_flow_stub.dart' if (dart.library.io) 'ha_config_flow_io.dart';
