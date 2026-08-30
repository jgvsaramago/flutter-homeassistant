/// Raised when the Music Assistant websocket rejects our auth token.
class MassAuthException implements Exception {
  const MassAuthException(this.message);
  final String message;

  @override
  String toString() => 'MassAuthException: $message';
}

/// Raised when a command comes back as an `ErrorResultMessage`.
class MassCommandException implements Exception {
  const MassCommandException(this.errorCode, this.message);
  final int? errorCode;
  final String message;

  @override
  String toString() => 'MassCommandException($errorCode): $message';
}

/// Raised when the socket disconnects while a command is in flight, or
/// before a connection could be established.
class MassConnectionException implements Exception {
  const MassConnectionException(this.message);
  final String message;

  @override
  String toString() => 'MassConnectionException: $message';
}
