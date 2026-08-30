import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../mass_client/mass_connection_config.dart';
import '../../mass_client/mass_websocket_client.dart';
import '../../providers/mass_providers.dart';
import '../../theme/nocturne_theme.dart';
import '../on_screen_keyboard_controller.dart';
import 'settings_save_controller.dart';

/// Settings section for the Music Assistant server connection the Music
/// sheet reads from — its own service with its own long-lived token, same
/// shape as the "Estado"/"Instância" rows Definições already shows for the
/// Home Assistant connection, just for a second, independent backend.
class MassConnectionCard extends ConsumerStatefulWidget {
  const MassConnectionCard({super.key, this.saveController});

  /// When set, this card's save button floats at the page level instead of
  /// rendering inline — see `SettingsSaveController`.
  final SettingsSaveController? saveController;

  @override
  ConsumerState<MassConnectionCard> createState() => _MassConnectionCardState();
}

class _MassConnectionCardState extends ConsumerState<MassConnectionCard> {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  final _urlFocus = FocusNode();
  final _tokenFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final config = ref.read(massConnectionConfigProvider);
    _urlController = TextEditingController(text: config?.baseUrl);
    _tokenController = TextEditingController(text: config?.accessToken);
    _urlFocus.addListener(() => _onFocusChange(_urlFocus, _urlController));
    _tokenFocus.addListener(() => _onFocusChange(_tokenFocus, _tokenController));
    widget.saveController?.bind(_save);
  }

  void _onFocusChange(FocusNode node, TextEditingController controller) {
    if (node.hasFocus) {
      OnScreenKeyboardController.instance.attach(controller);
    } else {
      OnScreenKeyboardController.instance.detach(controller);
    }
  }

  @override
  void dispose() {
    _urlFocus.dispose();
    _tokenFocus.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();
    if (url.isEmpty || token.isEmpty) return;

    final config = MassConnectionConfig(baseUrl: url, accessToken: token);
    await ref.read(massCredentialsStoreProvider).save(config);
    ref.read(massConnectionConfigProvider.notifier).state = config;
    if (!mounted) return;
    widget.saveController?.saved.value = true;
  }

  @override
  Widget build(BuildContext context) {
    // Watched (not read) purely so having this card on screen is what
    // actually triggers/keeps alive the connection this status row reports
    // on — Music Assistant is optional, so nothing connects to it eagerly
    // at app startup the way the HA client does.
    ref.watch(massPlayersProvider);
    final connectionState = ref.watch(massConnectionStateProvider).value ?? MassConnectionState.disconnected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speaker_group_outlined, size: 20, color: NocturneColors.accent),
                const SizedBox(width: 8),
                Text('SERVIDOR', style: NocturneText.cardKicker),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Servidor Music Assistant usado pela folha de Música — o mesmo endereço e token gerados no seu painel.', style: NocturneText.body),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Text('Estado', style: NocturneText.body)),
                Icon(Icons.circle, size: 12, color: _statusColor(connectionState)),
                const SizedBox(width: 8),
                Text(_statusLabel(connectionState), style: NocturneText.itemTitle),
              ],
            ),
            const Divider(height: 32),
            TextField(
              controller: _urlController,
              focusNode: _urlFocus,
              style: const TextStyle(fontSize: 17),
              decoration: const InputDecoration(
                labelText: 'URL do servidor',
                hintText: 'http://192.168.1.130:8095',
                helperText: 'Endereço do add-on/servidor Music Assistant na rede local.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              focusNode: _tokenFocus,
              obscureText: true,
              style: const TextStyle(fontSize: 17),
              decoration: const InputDecoration(
                labelText: 'Token de acesso',
                hintText: 'Criado em Definições → Perfil no Music Assistant',
                helperText: 'Token de longa duração — não é a mesma credencial do Home Assistant.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(MassConnectionState state) => switch (state) {
    MassConnectionState.connected => 'Ligado',
    MassConnectionState.connecting => 'A ligar',
    MassConnectionState.authenticating => 'A autenticar',
    MassConnectionState.error => 'Erro',
    MassConnectionState.disconnected => 'Desligado',
  };

  Color _statusColor(MassConnectionState state) => switch (state) {
    MassConnectionState.connected => NocturneColors.batteryMark,
    MassConnectionState.connecting => NocturneColors.solarMark,
    MassConnectionState.authenticating => NocturneColors.solarMark,
    MassConnectionState.error => NocturneColors.red,
    MassConnectionState.disconnected => NocturneColors.neutral500,
  };
}
