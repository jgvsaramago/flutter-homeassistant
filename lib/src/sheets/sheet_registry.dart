import 'package:flutter/material.dart';

/// Lets any sheet register itself under a stable string id, and lets
/// anything without a `BuildContext` — chiefly the MQTT command handler,
/// for opening a sheet on the real device without a finger on the glass —
/// request it be opened. Mirrors `ScreenPowerController`'s bridge pattern
/// for the same reason: the caller and the widget tree don't share a
/// context, so a plain singleton is what connects them.
class SheetRegistry {
  SheetRegistry._();

  static final instance = SheetRegistry._();

  final Map<String, Future<void> Function(BuildContext context)> _openers = {};

  /// Called once by whatever owns a given sheet (its trigger card, or the
  /// app shell) so [open] has something to dispatch to.
  void register(String id, Future<void> Function(BuildContext context) open) => _openers[id] = open;

  void unregister(String id) => _openers.remove(id);

  /// Set to a sheet's id to request it opens; whatever hosts the app's
  /// stable root context (see `MainShell`) listens for this and clears it
  /// back to null once handled, so setting the same id twice in a row
  /// still fires a second open.
  final ValueNotifier<String?> requestedId = ValueNotifier(null);

  void open(String id) => requestedId.value = id;

  Future<void>? dispatch(BuildContext context, String id) => _openers[id]?.call(context);

  /// Incremented to request the topmost sheet route be popped — the same
  /// bridge as [open], for closing a sheet from outside the widget tree
  /// (an MQTT test command, for instance, to check the close animation
  /// without a finger on the glass).
  final ValueNotifier<int> closeRequests = ValueNotifier(0);

  void closeTop() => closeRequests.value++;
}
