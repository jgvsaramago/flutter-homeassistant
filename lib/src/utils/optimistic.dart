import 'dart:async';

import 'package:flutter/foundation.dart';

/// One change the screen shows before its source (Home Assistant, Music
/// Assistant) confirms it: how it alters the real value, and how to tell
/// the real value now reflects it.
class OptimisticChange<V> {
  const OptimisticChange(this.key, {required this.patch, required this.confirmed, String? slot}) : slot = slot ?? key;

  /// What it changes — an entity id, a list id, a player id.
  final String key;

  /// A newer change in the same key and slot replaces this one (tapping a
  /// light on then off); changes in other slots stack (ticking two items
  /// on one list).
  final String slot;
  final V Function(V real) patch;
  final bool Function(V real) confirmed;
}

class _Entry<V> {
  _Entry(this.change, this.token);

  final OptimisticChange<V> change;
  final Object token;
}

/// Optimistic UI over some live state: a change shows the moment it's
/// touched, stays while its source hasn't confirmed it, and is dropped
/// again — the screen going back to the real value — when the command
/// fails or nothing confirms it within [timeout].
///
/// The owner keeps the real values, calls [settle] whenever they change,
/// and shows [overlay]/[view] of them.
class OptimisticLayer<V extends Object> {
  OptimisticLayer({required this.real, required this.onChanged, required this.notConfirmed});

  final V? Function(String key) real;
  final VoidCallback onChanged;

  /// What [onNotConfirmed] says when a change times out.
  final String notConfirmed;

  /// How the app tells the user a change was undone (a toast); set once at
  /// start-up so data code needn't know about widgets.
  static void Function(String message)? onNotConfirmed;

  static const defaultTimeout = Duration(seconds: 6);

  final _entries = <_Entry<V>>[];
  final _timers = <Object, Timer>{};

  bool isPending(String key) => _entries.any((e) => e.change.key == key);

  V? view(String key, V? real) {
    if (real == null) return null;
    var v = real;
    for (final e in _entries) {
      if (e.change.key == key) v = e.change.patch(v);
    }
    return v;
  }

  Map<String, V> overlay(Map<String, V> real) {
    if (_entries.isEmpty) return real;
    final out = Map<String, V>.of(real);
    for (final e in _entries) {
      final v = out[e.change.key];
      if (v != null) out[e.change.key] = e.change.patch(v);
    }
    return out;
  }

  /// Drops every change the real values now reflect (or whose subject is
  /// gone). True when anything was dropped.
  bool settle() {
    final before = _entries.length;
    _entries.removeWhere((e) {
      final r = real(e.change.key);
      return r == null || e.change.confirmed(r);
    });
    _dropIdleTimers();
    return _entries.length != before;
  }

  /// Shows [changes] at once, then runs [call]. A failed call undoes them
  /// right away and rethrows (the caller shows the error); a call that
  /// succeeds but never shows up in the real values is undone after
  /// [timeout].
  Future<void> run(List<OptimisticChange<V>> changes, Future<void> Function() call, {Duration timeout = defaultTimeout}) async {
    final token = Object();
    for (final c in changes) {
      _entries.removeWhere((e) => e.change.key == c.key && e.change.slot == c.slot);
      _entries.add(_Entry(c, token));
    }
    settle();
    if (_entries.any((e) => e.token == token)) _timers[token] = Timer(timeout, () => _expire(token));
    onChanged();
    try {
      await call();
    } catch (_) {
      _drop(token);
      rethrow;
    }
    if (settle()) onChanged();
  }

  bool _drop(Object token) {
    _timers.remove(token)?.cancel();
    final before = _entries.length;
    _entries.removeWhere((e) => e.token == token);
    final dropped = _entries.length != before;
    if (dropped) onChanged();
    return dropped;
  }

  void _expire(Object token) {
    if (_drop(token)) onNotConfirmed?.call(notConfirmed);
  }

  void _dropIdleTimers() {
    _timers.removeWhere((token, timer) {
      final idle = !_entries.any((e) => e.token == token);
      if (idle) timer.cancel();
      return idle;
    });
  }

  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _entries.clear();
  }
}
