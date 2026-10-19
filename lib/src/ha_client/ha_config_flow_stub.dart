import 'ha_connection_config.dart';

/// Web build — config flows need a direct REST call this build can't make.
Future<void> createLocalTodoList(HaConnectionConfig config, String name) async {
  throw UnsupportedError('Criar listas só funciona no ecrã da casa');
}
