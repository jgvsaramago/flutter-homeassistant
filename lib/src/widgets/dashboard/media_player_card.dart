import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../mass_client/mass_models.dart';
import '../../mass_client/mass_websocket_client.dart';
import '../../providers/mass_providers.dart';
import '../../sheets/dashboard/music_sheet.dart';
import '../../theme/nocturne_theme.dart';
import 'volume_modal.dart';

/// Right half of section 6: the media player. Shows a real Music Assistant
/// player live — the same "prefer whichever's actually playing, else just
/// the first available one" pick the Music sheet's own `_pickDefault` uses,
/// so opening the sheet from here always lands on the same player this card
/// was already showing, ready to hit play rather than mid-track. Falls back
/// to the design reference's own static placeholder copy only when no
/// server is configured, or no player is available at all.
class MediaPlayerCard extends ConsumerWidget {
  const MediaPlayerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(massConnectionConfigProvider);
    if (config == null) return const _StaticMediaPlayerCard();

    final players = ref.watch(massPlayersProvider).value ?? const {};
    final available = players.values.where((p) => p.available).toList()..sort((a, b) => a.name.compareTo(b.name));
    if (available.isEmpty) return const _StaticMediaPlayerCard();

    final playing = available.where((p) => p.playbackState == MassPlaybackState.playing);
    final selected = playing.isNotEmpty ? playing.first : available.first;
    return _LiveMediaPlayerCard(key: ValueKey(selected.playerId), player: selected);
  }
}

/// The real card — mirrors the Music sheet's own `_NowPlaying` fetch-on-
/// init/update pattern for the active queue (same reasoning: the queue
/// isn't part of `MassPlayer` itself, so it needs its own fetch+event
/// subscription, keyed by player so switching players restarts it cleanly).
class _LiveMediaPlayerCard extends ConsumerStatefulWidget {
  const _LiveMediaPlayerCard({super.key, required this.player});

  final MassPlayer player;

  @override
  ConsumerState<_LiveMediaPlayerCard> createState() => _LiveMediaPlayerCardState();
}

class _LiveMediaPlayerCardState extends ConsumerState<_LiveMediaPlayerCard> {
  MassPlayerQueue? _queue;
  StreamSubscription<MassEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _load();
    _eventSub = ref.read(massWebSocketClientProvider).events.listen(_onEvent);
  }

  @override
  void didUpdateWidget(covariant _LiveMediaPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.playerId != widget.player.playerId) _load();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final queue = await ref.read(massWebSocketClientProvider).getActiveQueue(widget.player.playerId);
    if (mounted) setState(() => _queue = queue);
  }

  void _onEvent(MassEvent event) {
    const relevant = {'queue_updated', 'queue_items_updated'};
    if (!relevant.contains(event.event)) return;
    if (event.objectId != widget.player.playerId && event.objectId != _queue?.queueId) return;
    _load();
  }

  Future<void> _cmd(String command) => ref.read(massWebSocketClientProvider).playerCommand(command, widget.player.playerId);

  @override
  Widget build(BuildContext context) {
    final client = ref.read(massWebSocketClientProvider);
    final player = widget.player;
    final item = _queue?.currentItem;
    final playing = player.playbackState == MassPlaybackState.playing;
    final imageUrl = item == null ? null : client.imageUrl(item.image, size: 400);

    return ClipRRect(
      borderRadius: BorderRadius.circular(NocturneRadii.primaryCard),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const _AccentWash())
          else
            const _AccentWash(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xD9000000), Color(0x73000000), Colors.transparent],
                stops: [0, 0.45, 0.75],
              ),
            ),
          ),
          // See the static card below for why this sits here in the stack
          // rather than first or last.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showMusicSheet(context),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item?.name ?? 'Nada em reprodução',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Text(
                  item?.artist ?? player.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, color: Color(0xB3FFFFFF)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: player.canSkip ? () => _cmd('previous') : null,
                      icon: const Icon(Icons.skip_previous, size: 30, color: Colors.white),
                      disabledColor: Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: player.canPlayPause ? () => _cmd('play_pause') : null,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 56, color: Colors.white),
                      disabledColor: Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: player.canSkip ? () => _cmd('next') : null,
                      icon: const Icon(Icons.skip_next, size: 30, color: Colors.white),
                      disabledColor: Colors.white38,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (player.canSetVolume)
            Positioned(
              top: 22,
              right: 24,
              child: IconButton(
                icon: const Icon(Icons.volume_up_outlined, color: Colors.white, size: 24),
                onPressed: () => showVolumeModal(
                  context,
                  initialVolume: player.volumeLevel ?? 50,
                  onChanged: (v) => client.setVolume(player.playerId, v),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Same tint-fill recipe as the static card's background — reused as the
/// live card's fallback for a track with no artwork.
class _AccentWash extends StatelessWidget {
  const _AccentWash();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.alphaBlend(NocturneColors.accent.withValues(alpha: 0.18), NocturneColors.neutral900), NocturneColors.neutral900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

/// Fallback shown when no Music Assistant server is configured, or nothing
/// anywhere is playing — the design reference's own non-templated copy and
/// local-only transport, same as before real playback data existed.
class _StaticMediaPlayerCard extends StatefulWidget {
  const _StaticMediaPlayerCard();

  @override
  State<_StaticMediaPlayerCard> createState() => _StaticMediaPlayerCardState();
}

class _StaticMediaPlayerCardState extends State<_StaticMediaPlayerCard> {
  int _volume = 62;
  bool _playing = true;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(NocturneRadii.primaryCard),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _AccentWash(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xD9000000), Color(0x73000000), Colors.transparent],
                stops: [0, 0.45, 0.75],
              ),
            ),
          ),
          // The card's tap target: anywhere not already claimed by the real
          // controls below opens the Music sheet. Must sit *after* the
          // gradients but *before* the two button-bearing Positioned widgets
          // — Stack hit-tests top-down, so this ordering is what lets the
          // play/pause and volume buttons still win their own taps while
          // this one catches everything else (confirmed empirically: this
          // widget being first in the list, i.e. bottommost, silently never
          // received a tap at all here, for reasons that didn't trace back
          // to any documented Stack hit-testing rule).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showMusicSheet(context),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ambiente Nocturno',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const Text(
                  'Altifalante da Sala',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xB3FFFFFF)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.skip_previous, size: 30, color: Colors.white),
                    const SizedBox(width: 24),
                    IconButton(
                      onPressed: () => setState(() => _playing = !_playing),
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 56, color: Colors.white),
                    ),
                    const SizedBox(width: 24),
                    const Icon(Icons.skip_next, size: 30, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 22,
            right: 24,
            child: IconButton(
              icon: const Icon(Icons.volume_up_outlined, color: Colors.white, size: 24),
              onPressed: () => showVolumeModal(context, initialVolume: _volume, onChanged: (v) => setState(() => _volume = v)),
            ),
          ),
        ],
      ),
    );
  }
}
