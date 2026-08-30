/// Raised when the HA websocket rejects our auth message.
class HaAuthException implements Exception {
  const HaAuthException(this.message);
  final String message;

  @override
  String toString() => 'HaAuthException: $message';
}

/// Raised when a `call_service` / command result comes back with success: false.
class HaCommandException implements Exception {
  const HaCommandException(this.code, this.message);
  final String? code;
  final String message;

  @override
  String toString() => 'HaCommandException($code): $message';
}

/// Raised when the socket disconnects while a command is in flight, or before
/// a connection could be established.
class HaConnectionException implements Exception {
  const HaConnectionException(this.message);
  final String message;

  @override
  String toString() => 'HaConnectionException: $message';
}
