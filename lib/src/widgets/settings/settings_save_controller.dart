import 'package:flutter/foundation.dart';

/// Bridges a settings card's own save logic — which lives deep in that
/// card's `State`, nested inside the page's scroll content — up to the
/// floating save button `SettingsSubPageScaffold` renders as a page-level
/// overlay outside that scroll content. Each settings sub-page has exactly
/// one save action (see the "one card, one save" convention), so one
/// controller per page, created by the page and handed to both its card and
/// its `SettingsSubPageScaffold`, is enough.
class SettingsSaveController {
  Future<void> Function()? _onSave;

  /// Whether the card's draft currently matches what's last been saved —
  /// the floating button reads this to show "Guardado" instead of
  /// "Guardar". The owning card's State is responsible for setting this
  /// back to `false` on every edit and `true` once a save completes, same
  /// as the `_saved` field each settings card already tracked locally
  /// before this existed.
  final ValueNotifier<bool> saved = ValueNotifier(false);

  /// Whether a save triggered by [requestSave] is still in flight — now
  /// that saving means a real HA websocket round trip (not an instant local
  /// write), the floating button uses this to show a third "a guardar..."
  /// state and to guard against a second tap firing a concurrent save.
  final ValueNotifier<bool> saving = ValueNotifier(false);

  /// Called by the settings card's own State in `initState`, wiring its
  /// private `_save` method up to this controller.
  void bind(Future<void> Function() onSave) => _onSave = onSave;

  /// Called by the floating save button when tapped. No-ops while a save is
  /// already in flight.
  Future<void> requestSave() async {
    if (saving.value || _onSave == null) return;
    saving.value = true;
    try {
      await _onSave!();
    } finally {
      saving.value = false;
    }
  }

  void dispose() {
    saved.dispose();
    saving.dispose();
  }
}
