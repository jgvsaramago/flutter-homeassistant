/// Connection details for a Home Assistant instance.
class HaConnectionConfig {
  const HaConnectionConfig({required this.baseUrl, required this.accessToken});

  /// e.g. `https://homeassistant.local:8123` or `http://192.168.1.10:8123`
  final String baseUrl;

  /// A long-lived access token generated from the HA user profile page.
  final String accessToken;

  /// Normalizes the base URL (strips trailing slash) and builds the
  /// `/api/websocket` endpoint, translating http(s) to ws(s).
  Uri get webSocketUri {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final httpUri = Uri.parse(normalized);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(scheme: scheme, path: '/api/websocket');
  }

  Map<String, dynamic> toJson() => {'baseUrl': baseUrl, 'accessToken': accessToken};

  factory HaConnectionConfig.fromJson(Map<String, dynamic> json) => HaConnectionConfig(
    baseUrl: json['baseUrl'] as String,
    accessToken: json['accessToken'] as String,
  );
}
