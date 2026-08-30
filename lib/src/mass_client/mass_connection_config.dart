/// Connection details for a Music Assistant server — the same two-field
/// shape as `HaConnectionConfig` (base URL + long-lived token), since MA's
/// own auth model is deliberately the same idea: a token minted from the
/// server's own web UI (Settings → profile), not tied to a Home Assistant
/// login even when MA runs as a HA add-on.
class MassConnectionConfig {
  const MassConnectionConfig({required this.baseUrl, required this.accessToken});

  /// e.g. `http://192.168.1.130:8095`
  final String baseUrl;

  /// A long-lived API token, created from Music Assistant's own web UI.
  final String accessToken;

  /// Normalizes the base URL (strips trailing slash) and builds the `/ws`
  /// endpoint, translating http(s) to ws(s).
  Uri get webSocketUri {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final httpUri = Uri.parse(normalized);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(scheme: scheme, path: '/ws');
  }

  Map<String, dynamic> toJson() => {'baseUrl': baseUrl, 'accessToken': accessToken};

  factory MassConnectionConfig.fromJson(Map<String, dynamic> json) => MassConnectionConfig(
    baseUrl: json['baseUrl'] as String,
    accessToken: json['accessToken'] as String,
  );
}
