import 'dart:convert';
import 'dart:io';

import 'ha_connection_config.dart';
import 'ha_exceptions.dart';

/// Creates a new list through HA's "Local To-do" integration — the same
/// two-step config flow as Settings › Devices › Add integration › Local
/// To-do: start the flow, then submit its one field (the list's name). The
/// new `todo.*` entity then arrives through the normal state_changed feed.
Future<void> createLocalTodoList(HaConnectionConfig config, String name) async {
  final base = config.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
      final request = await client.postUrl(Uri.parse('$base$path'));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${config.accessToken}')
        ..contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 300) throw HaCommandException('http_${response.statusCode}', text);
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    }

    final flow = await post('/api/config/config_entries/flow', {'handler': 'local_todo', 'show_advanced_options': false});
    final flowId = flow['flow_id'] as String?;
    if (flowId == null) throw const HaCommandException('no_flow', 'Local To-do flow did not start');
    final result = await post('/api/config/config_entries/flow/$flowId', {'todo_list_name': name});
    if (result['type'] != 'create_entry') {
      throw HaCommandException('flow_${result['type']}', (result['errors'] ?? result['reason'] ?? 'Flow did not finish').toString());
    }
  } finally {
    client.close();
  }
}
