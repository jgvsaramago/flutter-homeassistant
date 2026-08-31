import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../mass_client/mass_models.dart';
import '../../mass_client/mass_websocket_client.dart';
import '../../providers/mass_providers.dart';
import '../../theme/nocturne_theme.dart';
import '../../widgets/on_screen_keyboard_controller.dart';
import '../sheet.dart';
import '../sheet_parts.dart';

/// Opens the Music sheet: now-playing for a chosen Music Assistant player,
/// transport/volume, a switcher for which player to control, and Explorar/
/// Rádios tabs to start something new playing. Reads from the server
/// configured in Definições → Música (see `MassConnectionCard`) — with none
/// configured, or none reachable, the sheet says so rather than showing
/// stale/fake data.
///
/// The Agora/Explorar/Rádios bar is a [Sheet] `footer`: pinned to the
/// window's bottom edge regardless of drag, with the tab's own content
/// swapped in above it — not appended below, and not part of the dragged
/// column at all. [_tabNotifier] is what lets the footer (built once, here,
/// outside the dragged content) and the swappable content inside
/// [_MusicSheetBody] (built separately, as a normal child) stay in sync:
/// they're two different subtrees, so a plain `State` field on one
/// wouldn't reach the other.
Future<void> showMusicSheet(BuildContext context) {
  final tabNotifier = ValueNotifier<_BrowseTab>(_BrowseTab.now);
  // A second, independent piece of pinned-footer/content shared state:
  // whether an overlay view (Playlist detail, Onde tocar/Outputs) is
  // showing on top of whichever tab is selected. Kept separate from
  // [tabNotifier] rather than folded into a bigger enum because the footer
  // needs both at once — Explorar reads as "active" while either overlay is
  // open, since both live conceptually under it.
  final viewNotifier = ValueNotifier<_MusicView?>(null);
  return showSheet<void>(
    context,
    heightPct: 0.84,
    children: [_MusicSheetBody(tabNotifier: tabNotifier, viewNotifier: viewNotifier)],
    footer: _MusicTabBar(tabNotifier: tabNotifier, viewNotifier: viewNotifier),
  ).whenComplete(() {
    tabNotifier.dispose();
    viewNotifier.dispose();
  });
}

enum _BrowseTab { now, explore, radio }

enum _MusicView { playlist, outputs, genre }

/// Every selected player's speakers, joined for display — just its own name
/// when it isn't grouped with anything, otherwise every synced player's name
/// joined together. Shared by the Agora player-switcher row and the Playlist
/// detail view's speaker pill, both of which show "where this is playing".
String _speakerLine(MassPlayer player, List<MassPlayer> allPlayers) {
  if (player.groupMembers.isEmpty) return player.name;
  final names = [
    player.name,
    for (final id in player.groupMembers) allPlayers.firstWhere((p) => p.playerId == id, orElse: () => player).name,
  ];
  return names.join(', ');
}

/// "N altifalante(s)" for a player and its group — the Playlist detail
/// pill's and the Outputs group header's own summary, as distinct from
/// [_speakerLine]'s full name list.
String _speakerCountLabel(MassPlayer player) {
  final n = player.groupMembers.length + 1;
  return '$n altifalante${n == 1 ? '' : 's'}';
}

/// How much bottom space [_MusicSheetBody] must reserve so its own content
/// never sits behind the pinned [_MusicTabBar] footer — must track that
/// footer's real rendered height (its own content plus the padding `Sheet`
/// wraps every footer in), since `Sheet` only pins and paints the footer,
/// it doesn't know enough about either side to reserve space itself.
const _tabBarReserve = 96.0;

class _MusicSheetBody extends ConsumerStatefulWidget {
  const _MusicSheetBody({required this.tabNotifier, required this.viewNotifier});

  final ValueNotifier<_BrowseTab> tabNotifier;
  final ValueNotifier<_MusicView?> viewNotifier;

  @override
  ConsumerState<_MusicSheetBody> createState() => _MusicSheetBodyState();
}

class _MusicSheetBodyState extends ConsumerState<_MusicSheetBody> {
  String? _selectedPlayerId;
  MassBrowseItem? _selectedPlaylist;
  MassBrowseItem? _selectedGenre;

  void _openPlaylist(MassBrowseItem playlist) {
    setState(() => _selectedPlaylist = playlist);
    widget.viewNotifier.value = _MusicView.playlist;
  }

  void _openGenre(MassBrowseItem genre) {
    setState(() => _selectedGenre = genre);
    widget.viewNotifier.value = _MusicView.genre;
  }

  void _openOutputs() => widget.viewNotifier.value = _MusicView.outputs;

  void _closeView() => widget.viewNotifier.value = null;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(massConnectionConfigProvider);
    if (config == null) {
      return const Column(
        children: [SheetHandle(), _EmptyState(message: 'Nenhum servidor Music Assistant configurado.\nDefinições → Música.')],
      );
    }

    final playersAsync = ref.watch(massPlayersProvider);

    return playersAsync.when(
      loading: () => const Column(children: [SheetHandle(), _EmptyState(message: 'A ligar ao Music Assistant…')]),
      error: (error, _) => Column(children: [const SheetHandle(), _EmptyState(message: 'Não foi possível ligar ao Music Assistant.\n$error')]),
      data: (players) {
        final available = players.values.where((p) => p.available).toList()..sort((a, b) => a.name.compareTo(b.name));
        if (available.isEmpty) {
          return const Column(children: [SheetHandle(), _EmptyState(message: 'Nenhum leitor disponível no Music Assistant.')]);
        }

        final selectedId = _selectedPlayerId ?? _pickDefault(available);
        final selected = players[selectedId] ?? available.first;
        final selectedPlaylist = _selectedPlaylist;
        final selectedGenre = _selectedGenre;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(paddingBottom: 10),
            ValueListenableBuilder<_MusicView?>(
              valueListenable: widget.viewNotifier,
              builder: (context, view, _) {
                if (view == _MusicView.outputs) {
                  return _OutputsView(key: ValueKey(selected.playerId), player: selected, allPlayers: available, onBack: _closeView);
                }
                if (view == _MusicView.playlist && selectedPlaylist != null) {
                  return _PlaylistDetailView(
                    key: ValueKey(selectedPlaylist.uri),
                    playlist: selectedPlaylist,
                    queueId: selected.playerId,
                    speakerCount: _speakerCountLabel(selected),
                    onBack: _closeView,
                    onOpenOutputs: _openOutputs,
                  );
                }
                if (view == _MusicView.genre && selectedGenre != null) {
                  return _GenreView(
                    key: ValueKey(selectedGenre.uri),
                    genre: selectedGenre,
                    queueId: selected.playerId,
                    onBack: _closeView,
                    onOpenPlaylist: _openPlaylist,
                  );
                }
                return ValueListenableBuilder<_BrowseTab>(
                  valueListenable: widget.tabNotifier,
                  builder: (context, tab, _) => switch (tab) {
                    _BrowseTab.now => _NowPlaying(
                      key: ValueKey(selected.playerId),
                      player: selected,
                      allPlayers: available,
                      onPickPlayer: (id) => setState(() => _selectedPlayerId = id),
                      onOpenOutputs: _openOutputs,
                    ),
                    _BrowseTab.explore => _ExploreHome(
                      key: const ValueKey('explore'),
                      queueId: selected.playerId,
                      onOpenPlaylist: _openPlaylist,
                      onOpenGenre: _openGenre,
                    ),
                    _BrowseTab.radio => _RadiosTab(key: ValueKey(selected.playerId), player: selected),
                  },
                );
              },
            ),
            SizedBox(height: _tabBarReserve + MediaQuery.paddingOf(context).bottom),
          ],
        );
      },
    );
  }

  /// Prefers whichever player is actually making noise, so opening the
  /// sheet lands on the room you almost certainly came to check on, not
  /// alphabetically-first.
  String _pickDefault(List<MassPlayer> players) {
    final playing = players.where((p) => p.playbackState == MassPlaybackState.playing);
    return (playing.isNotEmpty ? playing.first : players.first).playerId;
  }
}

/// Header, art, track info, progress, transport, volume and the player
/// switcher — everything that depends on the selected player's live queue.
/// Fetches that queue itself and refreshes on the relevant events, the same
/// fetch-on-init/update pattern `_TemperatureSectionState` uses for its own
/// per-entity history fetch.
class _NowPlaying extends ConsumerStatefulWidget {
  const _NowPlaying({super.key, required this.player, required this.allPlayers, required this.onPickPlayer, required this.onOpenOutputs});

  final MassPlayer player;
  final List<MassPlayer> allPlayers;
  final ValueChanged<String> onPickPlayer;
  final VoidCallback onOpenOutputs;

  @override
  ConsumerState<_NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends ConsumerState<_NowPlaying> {
  MassPlayerQueue? _queue;
  StreamSubscription<MassEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _load();
    _eventSub = ref.read(massWebSocketClientProvider).events.listen(_onEvent);
  }

  @override
  void didUpdateWidget(covariant _NowPlaying oldWidget) {
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

  void _pickPlayer() {
    showDialog<void>(
      context: context,
      builder: (context) => _PlayerPickerDialog(players: widget.allPlayers, selectedId: widget.player.playerId, onSelect: widget.onPickPlayer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.read(massWebSocketClientProvider);
    final queue = _queue;
    final item = queue?.currentItem;
    final player = widget.player;
    final playing = player.playbackState == MassPlaybackState.playing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderRow(sourceName: queue?.displayName, onClose: () => SheetController.of(context).close()),
        const SizedBox(height: 26),
        _AlbumArt(imageUrl: item == null ? null : client.imageUrl(item.image, size: 500)),
        const SizedBox(height: 34),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item?.name ?? (player.available ? 'Nada em reprodução' : 'Leitor indisponível'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: -0.6, height: 1.1, color: NocturneColors.text, decoration: TextDecoration.none),
                  ),
                  if (item?.artist != null) ...[
                    const SizedBox(height: 9),
                    Text(item!.artist!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 22, color: NocturneColors.neutral400, decoration: TextDecoration.none)),
                  ],
                ],
              ),
            ),
            if (item != null) ...[
              const SizedBox(width: 20),
              Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.favorite, size: 32, color: NocturneColors.accent)),
            ],
          ],
        ),
        const SizedBox(height: 26),
        _ProgressBar(elapsed: queue?.elapsedTime ?? 0, duration: (item?.duration ?? 0).toDouble(), onSeek: queue == null ? null : (v) => client.seekQueue(queue.queueId, v)),
        _TransportRow(
          playing: playing,
          canPlayPause: player.canPlayPause,
          canSkip: player.canSkip,
          shuffleEnabled: queue?.shuffleEnabled,
          repeatOn: queue == null ? null : queue.repeatMode != 'off',
          onPlayPause: () => _cmd('play_pause'),
          onPrevious: () => _cmd('previous'),
          onNext: () => _cmd('next'),
          onShuffle: queue == null ? null : () => client.setQueueShuffle(queue.queueId, !queue.shuffleEnabled),
          onRepeat: queue == null ? null : () => client.setQueueRepeat(queue.queueId, queue.repeatMode == 'off' ? 'all' : 'off'),
        ),
        const SizedBox(height: 26),
        if (player.canSetVolume) ...[
          _VolumeRow(player: player, onChanged: (level) => client.setVolume(player.playerId, level)),
          const SizedBox(height: 22),
        ],
        _PlayerSwitcherRow(speakerLine: _speakerLine(player, widget.allPlayers), onOpenOutputs: widget.onOpenOutputs, onSwitchPlayer: _pickPlayer),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.sourceName, required this.onClose});

  final String? sourceName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose, child: Icon(Icons.keyboard_arrow_down, size: 26, color: NocturneColors.text)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A TOCAR DE',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.68, color: NocturneColors.neutral600, decoration: TextDecoration.none),
              ),
              if (sourceName != null && sourceName!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  sourceName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: NocturneColors.text, decoration: TextDecoration.none),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        Icon(Icons.more_vert, size: 26, color: NocturneColors.neutral500),
      ],
    );
  }
}

/// Resolves a possibly-null image URL to either the real cover or the
/// decorative placeholder, for every hero/shelf art spot in the sheet.
Widget _coverImage(String? url) {
  return url == null ? const _ArtworkPlaceholder() : Image.network(url, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const _ArtworkPlaceholder());
}

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(aspectRatio: 1, child: ClipRRect(borderRadius: BorderRadius.circular(NocturneRadii.insetPanel), child: _coverImage(imageUrl)));
  }
}

/// Stand-in cover art for whenever the queue has no real artwork to show —
/// two soft accent/text-tinted shapes on the inset ground, matching the
/// reference design's own cover-art placeholder recipe.
class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final circle = side * 0.4;
        final square = side * 0.26;
        return Container(
          color: NocturneColors.inset,
          child: Stack(
            children: [
              Positioned(
                left: side * 0.2,
                top: side * 0.3,
                child: Container(
                  width: circle,
                  height: circle,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Color.alphaBlend(NocturneColors.accent.withValues(alpha: 0.5), NocturneColors.inset)),
                ),
              ),
              Positioned(
                right: side * 0.11,
                bottom: side * 0.15,
                child: Container(
                  width: square,
                  height: square,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(square * 0.2),
                    color: Color.alphaBlend(NocturneColors.text.withValues(alpha: 0.13), NocturneColors.inset),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.elapsed, required this.duration, required this.onSeek});

  final double elapsed;
  final double duration;
  final ValueChanged<double>? onSeek;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final elapsed = _dragValue ?? widget.elapsed;
    final duration = widget.duration;
    final remaining = (duration - elapsed).clamp(0, double.infinity);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: NocturneColors.text,
            inactiveTrackColor: NocturneColors.neutral800,
            thumbColor: NocturneColors.text,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: duration > 0 ? elapsed.clamp(0, duration) : 0,
            min: 0,
            max: duration > 0 ? duration : 1,
            onChanged: widget.onSeek == null || duration <= 0 ? null : (v) => setState(() => _dragValue = v),
            onChangeEnd: widget.onSeek == null
                ? null
                : (v) {
                    widget.onSeek!(v);
                    setState(() => _dragValue = null);
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(elapsed), style: TextStyle(fontSize: 16, color: NocturneColors.neutral500, decoration: TextDecoration.none).merge(NocturneText.tabularNums)),
              Text('-${_formatDuration(remaining)}', style: TextStyle(fontSize: 16, color: NocturneColors.neutral500, decoration: TextDecoration.none).merge(NocturneText.tabularNums)),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDuration(num seconds) {
    final total = seconds.round();
    final minutes = total ~/ 60;
    final secs = total % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({
    required this.playing,
    required this.canPlayPause,
    required this.canSkip,
    required this.shuffleEnabled,
    required this.repeatOn,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
  });

  final bool playing;
  final bool canPlayPause;
  final bool canSkip;
  final bool? shuffleEnabled;
  final bool? repeatOn;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onShuffle;
  final VoidCallback? onRepeat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _IconTapTarget(icon: Icons.shuffle, size: 28, active: shuffleEnabled ?? false, onTap: onShuffle),
        _IconTapTarget(icon: Icons.skip_previous, size: 34, onTap: canSkip ? onPrevious : null),
        _PlayPauseButton(playing: playing, onTap: canPlayPause ? onPlayPause : null),
        _IconTapTarget(icon: Icons.skip_next, size: 34, onTap: canSkip ? onNext : null),
        _IconTapTarget(icon: Icons.repeat, size: 28, active: repeatOn ?? false, onTap: onRepeat),
      ],
    );
  }
}

class _IconTapTarget extends StatelessWidget {
  const _IconTapTarget({required this.icon, required this.size, required this.onTap, this.active = false});

  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Icon(icon, size: size, color: !enabled ? NocturneColors.neutral700 : active ? NocturneColors.accent : NocturneColors.text),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: enabled ? NocturneColors.text : NocturneColors.neutral700),
        child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 42, color: NocturneColors.bg),
      ),
    );
  }
}

class _VolumeRow extends StatefulWidget {
  const _VolumeRow({required this.player, required this.onChanged});

  final MassPlayer player;
  final ValueChanged<int> onChanged;

  @override
  State<_VolumeRow> createState() => _VolumeRowState();
}

class _VolumeRowState extends State<_VolumeRow> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final level = (_dragValue ?? widget.player.volumeLevel?.toDouble() ?? 0).clamp(0.0, 100.0);
    return Row(
      children: [
        Icon(Icons.volume_down, size: 24, color: NocturneColors.neutral500),
        const SizedBox(width: 16),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(
              context,
            ).copyWith(trackHeight: 3, activeTrackColor: NocturneColors.accent, inactiveTrackColor: NocturneColors.neutral800, thumbColor: NocturneColors.accent, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: SliderComponentShape.noOverlay),
            child: Slider(
              value: level,
              min: 0,
              max: 100,
              onChanged: (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) {
                setState(() => _dragValue = null);
                widget.onChanged(v.round());
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 44,
          child: Text(
            '${level.round()}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 17, color: NocturneColors.neutral500, decoration: TextDecoration.none).merge(NocturneText.tabularNums),
          ),
        ),
      ],
    );
  }
}

/// Shows where a queue is currently playing and opens the full "Onde tocar"
/// grouping view — the reference design's speaker-line row. Switching which
/// player *this sheet controls* (a concept the reference has no equivalent
/// of, since it assumes a single zone) stays a separate, smaller tap target
/// so neither replaces the other.
class _PlayerSwitcherRow extends StatelessWidget {
  const _PlayerSwitcherRow({required this.speakerLine, required this.onOpenOutputs, required this.onSwitchPlayer});

  final String speakerLine;
  final VoidCallback onOpenOutputs;
  final VoidCallback onSwitchPlayer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenOutputs,
            child: Row(
              children: [
                Icon(Icons.speaker_group_outlined, size: 22, color: NocturneColors.accent),
                const SizedBox(width: 11),
                Flexible(
                  child: Text(
                    speakerLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: NocturneColors.accent, decoration: TextDecoration.none),
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSwitchPlayer,
          child: Padding(padding: EdgeInsets.all(4), child: Icon(Icons.swap_horiz, size: 20, color: NocturneColors.neutral500)),
        ),
      ],
    );
  }
}

class _PlayerPickerDialog extends StatelessWidget {
  const _PlayerPickerDialog({required this.players, required this.selectedId, required this.onSelect});

  final List<MassPlayer> players;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: NocturneColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NocturneRadii.primaryCard)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final player in players)
                ListTile(
                  title: Text(player.name, style: TextStyle(color: player.playerId == selectedId ? NocturneColors.accent : NocturneColors.text)),
                  trailing: player.playerId == selectedId ? Icon(Icons.check, color: NocturneColors.accent) : null,
                  onTap: () {
                    onSelect(player.playerId);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Music sheet's pinned footer (see [showMusicSheet]) — reads and
/// writes [tabNotifier] directly rather than through a callback, since
/// nothing here needs to know what the notifier is *for*, only that
/// changing it is what switching tabs means.
class _MusicTabBar extends StatelessWidget {
  const _MusicTabBar({required this.tabNotifier, required this.viewNotifier});

  final ValueNotifier<_BrowseTab> tabNotifier;
  final ValueNotifier<_MusicView?> viewNotifier;

  void _selectTab(_BrowseTab tab) {
    // Tapping any tab always drops back to plain tab content — matches the
    // reference's own `setMusicTab` clearing `view`.
    viewNotifier.value = null;
    tabNotifier.value = tab;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: NocturneColors.divider))),
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: AnimatedBuilder(
          animation: Listenable.merge([tabNotifier, viewNotifier]),
          builder: (context, _) {
            final tab = tabNotifier.value;
            final view = viewNotifier.value;
            // Both overlay views (Playlist detail, Outputs) live conceptually
            // under Explorar, so it stays lit while either is open.
            final exploreActive = tab == _BrowseTab.explore || view != null;
            return Row(
              children: [
                _TabItem(icon: Icons.adjust, label: 'Agora', active: tab == _BrowseTab.now && view == null, onTap: () => _selectTab(_BrowseTab.now)),
                _TabItem(icon: Icons.search, label: 'Explorar', active: exploreActive, onTap: () => _selectTab(_BrowseTab.explore)),
                _TabItem(icon: Icons.settings_input_antenna, label: 'Rádios', active: tab == _BrowseTab.radio && view == null, onTap: () => _selectTab(_BrowseTab.radio)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? NocturneColors.accent : NocturneColors.neutral500;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }
}

/// Shared header for the two overlay views (Playlist detail, Outputs) — a
/// back chevron plus a title, unlike [_HeaderRow]'s "A TOCAR DE" framing
/// which only makes sense for the Agora view it was built for.
class _ViewHeader extends StatelessWidget {
  const _ViewHeader({required this.title, required this.onBack, this.style});

  final String title;
  final VoidCallback onBack;

  /// Defaults to the Playlist detail view's muted label; Outputs passes its
  /// own bold page-title style — the two overlay views share this header's
  /// layout but not its type treatment.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: onBack, child: Icon(Icons.chevron_left, size: 28, color: NocturneColors.text)),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style ?? TextStyle(fontSize: 18, color: NocturneColors.neutral500, decoration: TextDecoration.none),
          ),
        ),
      ],
    );
  }
}

/// "Playlist" overlay view: hero art/name, a "Tocar" action that starts the
/// whole playlist, and every track in it (fetched live via
/// `MassWebSocketClient.getPlaylistTracks`) — each independently tappable to
/// play just that track. The reference's "guardar"/heart action has no real
/// backend equivalent to wire up, so it stays a static icon, same as the
/// Agora header's own decorative overflow icon.
class _PlaylistDetailView extends ConsumerStatefulWidget {
  const _PlaylistDetailView({
    super.key,
    required this.playlist,
    required this.queueId,
    required this.speakerCount,
    required this.onBack,
    required this.onOpenOutputs,
  });

  final MassBrowseItem playlist;
  final String queueId;

  /// "N altifalantes" — the reference's outputs pill shows the group's
  /// size here, not the full [_speakerLine] name list.
  final String speakerCount;
  final VoidCallback onBack;
  final VoidCallback onOpenOutputs;

  @override
  ConsumerState<_PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends ConsumerState<_PlaylistDetailView> {
  List<MassBrowseItem>? _tracks;
  bool _shuffle = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tracks = await ref.read(massWebSocketClientProvider).getPlaylistTracks(widget.playlist.uri);
    if (mounted) setState(() => _tracks = tracks);
  }

  Future<void> _playAll() async {
    final client = ref.read(massWebSocketClientProvider);
    await client.playMedia(widget.queueId, widget.playlist.uri);
    if (_shuffle) await client.setQueueShuffle(widget.queueId, true);
  }

  Future<void> _playTrack(MassBrowseItem track) {
    if (track.uri.isEmpty) return Future.value();
    return ref.read(massWebSocketClientProvider).playMedia(widget.queueId, track.uri);
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.read(massWebSocketClientProvider);
    final tracks = _tracks;
    final canPlay = tracks != null && tracks.isNotEmpty;
    final imageUrl = client.imageUrl(widget.playlist.image, size: 500);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ViewHeader(title: 'Playlist', onBack: widget.onBack),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(NocturneRadii.smallCard),
              child: SizedBox(width: 200, height: 200, child: _AlbumArt(imageUrl: imageUrl)),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.playlist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -0.5, height: 1.1, color: NocturneColors.text, decoration: TextDecoration.none),
                  ),
                  const SizedBox(height: 11),
                  Text('Playlist da casa', style: TextStyle(fontSize: 18, color: NocturneColors.neutral400, decoration: TextDecoration.none)),
                  const SizedBox(height: 11),
                  Text(
                    tracks == null ? ' ' : '${tracks.length} música${tracks.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 16, color: NocturneColors.neutral600, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canPlay ? _playAll : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                decoration: BoxDecoration(color: canPlay ? NocturneColors.text : NocturneColors.neutral700, borderRadius: BorderRadius.circular(NocturneRadii.pill)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 20, color: NocturneColors.bg),
                    const SizedBox(width: 12),
                    Text('Tocar', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: NocturneColors.bg, decoration: TextDecoration.none)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            _IconTapTarget(icon: Icons.shuffle, size: 28, active: _shuffle, onTap: () => setState(() => _shuffle = !_shuffle)),
            const SizedBox(width: 16),
            Padding(padding: EdgeInsets.all(11), child: Icon(Icons.favorite_border, size: 28, color: NocturneColors.neutral500)),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpenOutputs,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(NocturneRadii.pill), border: Border.all(color: NocturneColors.accent)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speaker_group_outlined, size: 18, color: NocturneColors.accent),
                    const SizedBox(width: 10),
                    Text(widget.speakerCount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: NocturneColors.accent, decoration: TextDecoration.none)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (tracks == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()))
        else if (tracks.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Playlist vazia.', style: TextStyle(fontSize: 16, color: NocturneColors.neutral600, decoration: TextDecoration.none)),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tracks.length; i++)
                _TrackRow(index: i + 1, track: tracks[i], imageUrl: client.imageUrl(tracks[i].image, size: 150), onTap: () => _playTrack(tracks[i])),
            ],
          ),
      ],
    );
  }
}

String _formatTrackDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final secs = seconds % 60;
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}

/// One playlist track row: index, 54px art, title/artist, trailing duration —
/// no row background, unlike every other list row in this sheet.
class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.index, required this.track, required this.imageUrl, required this.onTap});

  final int index;
  final MassBrowseItem track;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text('$index', style: TextStyle(fontSize: 17, color: NocturneColors.neutral600, decoration: TextDecoration.none).merge(NocturneText.tabularNums)),
            ),
            const SizedBox(width: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 54,
                height: 54,
                child: imageUrl == null
                    ? const _ArtPlaceholder()
                    : Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const _ArtPlaceholder()),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: NocturneColors.text, decoration: TextDecoration.none),
                  ),
                  if (track.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(track.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, color: NocturneColors.neutral500, decoration: TextDecoration.none)),
                  ],
                ],
              ),
            ),
            if (track.duration != null) ...[
              const SizedBox(width: 14),
              Text(
                _formatTrackDuration(track.duration!),
                style: TextStyle(fontSize: 16, color: NocturneColors.neutral600, decoration: TextDecoration.none).merge(NocturneText.tabularNums),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Onde tocar" (Outputs) overlay view: the current player's group volume,
/// and every player it's able to sync with — each a checkbox toggling
/// `players/cmd/set_members` membership live. The reference's "Grupos
/// guardados" (saved group presets) has no Music Assistant equivalent, so
/// it's omitted rather than faked.
class _OutputsView extends ConsumerWidget {
  const _OutputsView({super.key, required this.player, required this.allPlayers, required this.onBack});

  final MassPlayer player;
  final List<MassPlayer> allPlayers;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(massWebSocketClientProvider);
    final candidates = player.canGroupWith.map((id) {
      return allPlayers.firstWhere(
        (p) => p.playerId == id,
        orElse: () => MassPlayer(
          playerId: id,
          name: id,
          available: false,
          playbackState: MassPlaybackState.unknown,
          powered: null,
          volumeLevel: null,
          volumeMuted: null,
          supportedFeatures: const {},
          groupMembers: const {},
          canGroupWith: const {},
        ),
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ViewHeader(
          title: 'Onde tocar',
          onBack: onBack,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: NocturneColors.text, decoration: TextDecoration.none),
        ),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(NocturneRadii.insetPanel)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Grupo · ${_speakerCountLabel(player)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: NocturneColors.text, decoration: TextDecoration.none)),
                  const Spacer(),
                  if (player.volumeLevel != null)
                    Text(
                      '${player.volumeLevel}',
                      style: TextStyle(fontSize: 18, color: NocturneColors.neutral500, decoration: TextDecoration.none).merge(NocturneText.tabularNums),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (player.canSetVolume)
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: NocturneColors.text,
                    inactiveTrackColor: NocturneColors.neutral800,
                    thumbColor: NocturneColors.text,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: (player.volumeLevel ?? 0).toDouble().clamp(0, 100),
                    min: 0,
                    max: 100,
                    onChanged: (v) => client.setGroupVolume(player.playerId, v.round()),
                  ),
                ),
              const SizedBox(height: 14),
              Text('O volume mestre move todos em proporção.', style: TextStyle(fontSize: 15, color: NocturneColors.neutral500, decoration: TextDecoration.none)),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('DISPONÍVEIS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 1.8, color: NocturneColors.neutral600, decoration: TextDecoration.none)),
        ),
        const SizedBox(height: 14),
        _SpeakerRow(player: player, selected: true, sub: 'Líder do grupo', onChanged: null),
        if (candidates.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Sem outros leitores disponíveis para agrupar.', style: TextStyle(fontSize: 15, color: NocturneColors.neutral600, decoration: TextDecoration.none)),
          )
        else
          for (final candidate in candidates) ...[
            const SizedBox(height: 12),
            _SpeakerRow(
              player: candidate,
              selected: player.groupMembers.contains(candidate.playerId),
              sub: !candidate.available ? 'Indisponível' : (player.groupMembers.contains(candidate.playerId) ? 'Em grupo' : 'Livre'),
              onChanged: candidate.available ? (v) => client.setGroupMembership(player.playerId, candidate.playerId, v) : null,
              onVolume: candidate.canSetVolume ? (v) => client.setVolume(candidate.playerId, v) : null,
            ),
          ],
      ],
    );
  }
}

/// One "Disponíveis" card: a checkbox row (name/sub/current volume) plus,
/// only while selected, an inline volume slider. [onChanged] null means the
/// row can't be toggled — either it's offline, or (when [selected] is
/// already true with no [onChanged]) it's the group's own leader, which is
/// always a member of its own group.
class _SpeakerRow extends StatelessWidget {
  const _SpeakerRow({required this.player, required this.selected, required this.sub, required this.onChanged, this.onVolume});

  final MassPlayer player;
  final bool selected;
  final String sub;
  final ValueChanged<bool>? onChanged;
  final ValueChanged<int>? onVolume;

  @override
  Widget build(BuildContext context) {
    final offline = !player.available;
    final checked = selected && !offline;
    return Opacity(
      opacity: offline ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: NocturneColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: checked ? NocturneColors.accent.withValues(alpha: 0.5) : NocturneColors.neutral800),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onChanged == null ? null : () => onChanged!(!selected),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: checked ? NocturneColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: checked ? null : Border.all(color: NocturneColors.neutral700, width: 1.5),
                    ),
                    child: checked ? Icon(Icons.check, size: 18, color: NocturneColors.bg) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500, color: offline ? NocturneColors.neutral400 : NocturneColors.text, decoration: TextDecoration.none),
                        ),
                        const SizedBox(height: 4),
                        Text(sub, style: TextStyle(fontSize: 15, color: NocturneColors.neutral500, decoration: TextDecoration.none)),
                      ],
                    ),
                  ),
                  if (player.volumeLevel != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${player.volumeLevel}',
                      style: TextStyle(fontSize: 18, color: NocturneColors.neutral500, decoration: TextDecoration.none).merge(NocturneText.tabularNums),
                    ),
                  ],
                ],
              ),
            ),
            if (checked && onVolume != null) ...[
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: NocturneColors.accent,
                  inactiveTrackColor: NocturneColors.neutral800,
                  thumbColor: NocturneColors.accent,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(value: (player.volumeLevel ?? 0).toDouble().clamp(0, 100), min: 0, max: 100, onChanged: (v) => onVolume!(v.round())),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Explorar" tab content: a search box over Playlists/Rádios/Artistas/
/// Álbuns shelves (browse-home), which a non-empty query replaces with a
/// flat mixed-type results list — the same split Spotify-style "search"
/// screens use, and the shape the reference design was built from.
class _ExploreHome extends ConsumerStatefulWidget {
  const _ExploreHome({super.key, required this.queueId, required this.onOpenPlaylist, required this.onOpenGenre});

  final String queueId;
  final ValueChanged<MassBrowseItem> onOpenPlaylist;
  final ValueChanged<MassBrowseItem> onOpenGenre;

  @override
  ConsumerState<_ExploreHome> createState() => _ExploreHomeState();
}

class _ExploreHomeState extends ConsumerState<_ExploreHome> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<MassBrowseItem>? _searchResults;
  bool _searching = false;

  List<MassBrowseItem>? _playlists;
  List<MassBrowseItem>? _artists;
  List<MassBrowseItem>? _albums;
  List<MassBrowseItem>? _genres;
  List<MassRecommendationFolder>? _recommendations;

  @override
  void initState() {
    super.initState();
    _loadHome();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHome() async {
    final client = ref.read(massWebSocketClientProvider);
    // Fired together, awaited one by one — same concurrency as
    // `Future.wait`, without needing a single element type for the list.
    final playlistsF = client.getLibraryPlaylists(limit: 20);
    final artistsF = client.getLibraryArtists(limit: 8);
    final albumsF = client.getLibraryAlbums(limit: 8);
    final genresF = client.getGenres(limit: 20);
    final recommendationsF = client.getRecommendations();

    final playlists = await playlistsF;
    final artists = await artistsF;
    final albums = await albumsF;
    final genres = await genresF;
    final recommendations = await recommendationsF;
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
      _artists = artists;
      _albums = albums;
      _genres = genres;
      _recommendations = recommendations;
    });
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final results = await ref.read(massWebSocketClientProvider).search(query);
    if (!mounted || _searchController.text.trim() != query) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  Future<void> _play(MassBrowseItem item) {
    if (item.uri.isEmpty) return Future.value();
    return ref.read(massWebSocketClientProvider).playMedia(widget.queueId, item.uri);
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.read(massWebSocketClientProvider);
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchField(controller: _searchController),
        const SizedBox(height: 22),
        if (hasQuery)
          _searching
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()))
              : _SearchResultsList(items: _searchResults ?? const [], onTap: _play)
        else
          _ExploreSections(
            playlists: _playlists,
            artists: _artists,
            albums: _albums,
            genres: _genres,
            recommendations: _recommendations,
            client: client,
            onTap: _play,
            onOpenPlaylist: widget.onOpenPlaylist,
            onOpenGenre: widget.onOpenGenre,
          ),
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller, this.hintText = 'Procurar músicas, álbuns, artistas'});

  final TextEditingController controller;
  final String hintText;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      OnScreenKeyboardController.instance.attach(widget.controller);
    } else {
      OnScreenKeyboardController.instance.detach(widget.controller);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(color: NocturneColors.neutral900, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.search, size: 24, color: NocturneColors.neutral500),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              style: TextStyle(fontSize: 19, color: NocturneColors.text, decoration: TextDecoration.none),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(fontSize: 19, color: NocturneColors.neutral600, decoration: TextDecoration.none),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
              // onTapOutside left at its default — see keyboard_text_field.dart
              // for why that's the right behavior for every text field in
              // this app now.
            ),
          ),
        ],
      ),
    );
  }
}

/// MA's own English `translation_key` for a recommendations/genre-overview
/// folder, mapped to this app's pt-PT label. An unrecognized key (a future
/// MA folder type this app hasn't seen yet) falls back to the server's own
/// `name` rather than hiding the shelf.
const _recommendationTitles = {
  'in_progress_items': 'Continuar a ouvir',
  'recently_played': 'Reproduzido recentemente',
  'recently_added_tracks': 'Adicionado recentemente',
  'recently_added_albums': 'Álbuns adicionados recentemente',
  'random_artists': 'Artistas para descobrir',
  'random_albums': 'Álbuns para descobrir',
  'recent_favorite_tracks': 'Favoritos recentes',
  'favorite_playlists': 'As tuas playlists',
  'favorite_radio_stations': 'Rádios favoritas',
};

String _folderTitle(MassRecommendationFolder folder) => _recommendationTitles[folder.translationKey] ?? folder.name;

class _ExploreSections extends StatelessWidget {
  const _ExploreSections({
    required this.playlists,
    required this.artists,
    required this.albums,
    required this.genres,
    required this.recommendations,
    required this.client,
    required this.onTap,
    required this.onOpenPlaylist,
    required this.onOpenGenre,
  });

  final List<MassBrowseItem>? playlists;
  final List<MassBrowseItem>? artists;
  final List<MassBrowseItem>? albums;
  final List<MassBrowseItem>? genres;
  final List<MassRecommendationFolder>? recommendations;
  final MassWebSocketClient client;
  final ValueChanged<MassBrowseItem> onTap;

  /// Separate from [onTap]: a playlist card opens the Playlist detail view
  /// rather than playing immediately, unlike every other shelf here.
  final ValueChanged<MassBrowseItem> onOpenPlaylist;
  final ValueChanged<MassBrowseItem> onOpenGenre;

  @override
  Widget build(BuildContext context) {
    final playlists = this.playlists;
    if (playlists == null) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()));
    }
    final recommendations = this.recommendations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recommendations != null)
          for (final folder in recommendations)
            if (folder.items.any((i) => i.mediaType != 'radio')) ...[
              _RecommendationShelf(
                title: _folderTitle(folder),
                items: folder.items.where((i) => i.mediaType != 'radio').toList(),
                client: client,
                onOpenPlaylist: onOpenPlaylist,
                onPlay: onTap,
              ),
              const SizedBox(height: 32),
            ],
        if (playlists.isNotEmpty) ...[
          const _SectionHeader(title: 'Playlists'),
          const SizedBox(height: 16),
          _CardRow(items: playlists, client: client, onTap: onOpenPlaylist, cardSize: 160, nameFontSize: 17, decorative: true),
          const SizedBox(height: 30),
        ],
        if (genres != null && genres!.isNotEmpty) ...[
          const _SectionHeader(title: 'POR GÉNERO', muted: true),
          const SizedBox(height: 16),
          _GenreShelf(items: genres!, onTap: onOpenGenre),
          const SizedBox(height: 32),
        ],
        if (artists != null && artists!.isNotEmpty) ...[
          const _SectionHeader(title: 'ARTISTAS', muted: true),
          const SizedBox(height: 16),
          _AvatarRow(items: artists!, client: client, onTap: onTap),
          const SizedBox(height: 32),
        ],
        if (albums != null && albums!.isNotEmpty) ...[
          const _SectionHeader(title: 'ÁLBUNS', muted: true),
          const SizedBox(height: 16),
          _CardRow(items: albums!, client: client, onTap: onTap, cardSize: 150, showSubtitle: true),
        ],
      ],
    );
  }
}

/// One `music/recommendations` (or genre-overview) shelf — a titled
/// horizontal row that renders as circles when every item is an artist,
/// otherwise as square cards, and routes a tap to "open" for playlists or
/// straight to "play" for everything else, since a folder mixes types only
/// in principle (MA's own folders are homogeneous in practice).
class _RecommendationShelf extends StatelessWidget {
  const _RecommendationShelf({required this.title, required this.items, required this.client, required this.onOpenPlaylist, required this.onPlay});

  final String title;
  final List<MassBrowseItem> items;
  final MassWebSocketClient client;
  final ValueChanged<MassBrowseItem> onOpenPlaylist;
  final ValueChanged<MassBrowseItem> onPlay;

  void _handleTap(MassBrowseItem item) => item.mediaType == 'playlist' ? onOpenPlaylist(item) : onPlay(item);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isArtists = items.every((i) => i.mediaType == 'artist');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: title.toUpperCase(), muted: true),
        const SizedBox(height: 16),
        isArtists
            ? _AvatarRow(items: items, client: client, onTap: _handleTap)
            : _CardRow(items: items, client: client, onTap: _handleTap, cardSize: 150, showSubtitle: items.any((i) => i.subtitle != null)),
      ],
    );
  }
}

/// The "Por género" shelf: flat colour tiles (genres carry no artwork),
/// cycling a small fixed palette by index rather than hashing the name, so
/// the same handful of muted tones repeat instead of a jarring random one.
class _GenreShelf extends StatelessWidget {
  const _GenreShelf({required this.items, required this.onTap});

  final List<MassBrowseItem> items;
  final ValueChanged<MassBrowseItem> onTap;

  static const _tints = [0xFF3A2E5C, 0xFF1E4A3D, 0xFF5C3A2E, 0xFF2E3F5C, 0xFF5C2E4A, 0xFF2E5C3A, 0xFF5C4A2E, 0xFF2E3A5C];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(item),
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(color: Color(_tints[index % _tints.length]), borderRadius: BorderRadius.circular(NocturneRadii.listRow)),
              child: Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: NocturneColors.text, decoration: TextDecoration.none),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Por género" drill-in: one genre's own home feed (`music/genres/overview`),
/// rendered the same way as the top-level recommendation shelves.
class _GenreView extends ConsumerStatefulWidget {
  const _GenreView({super.key, required this.genre, required this.queueId, required this.onBack, required this.onOpenPlaylist});

  final MassBrowseItem genre;
  final String queueId;
  final VoidCallback onBack;
  final ValueChanged<MassBrowseItem> onOpenPlaylist;

  @override
  ConsumerState<_GenreView> createState() => _GenreViewState();
}

class _GenreViewState extends ConsumerState<_GenreView> {
  List<MassRecommendationFolder>? _folders;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final folders = await ref.read(massWebSocketClientProvider).getGenreOverview(widget.genre);
    if (mounted) setState(() => _folders = folders);
  }

  Future<void> _play(MassBrowseItem item) {
    if (item.uri.isEmpty) return Future.value();
    return ref.read(massWebSocketClientProvider).playMedia(widget.queueId, item.uri);
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.read(massWebSocketClientProvider);
    final folders = _folders;
    final shelves = folders?.map((f) => (title: f.name, items: f.items.where((i) => i.mediaType != 'radio').toList())).where((s) => s.items.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ViewHeader(
          title: widget.genre.name,
          onBack: widget.onBack,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: NocturneColors.text, decoration: TextDecoration.none),
        ),
        const SizedBox(height: 22),
        if (shelves == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()))
        else if (shelves.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Sem sugestões para este género.', style: TextStyle(fontSize: 16, color: NocturneColors.neutral600, decoration: TextDecoration.none)),
          )
        else
          for (final shelf in shelves) ...[
            _RecommendationShelf(title: shelf.title, items: shelf.items, client: client, onOpenPlaylist: widget.onOpenPlaylist, onPlay: _play),
            const SizedBox(height: 32),
          ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.muted = false});

  final String title;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: muted
              ? TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 1.8, color: NocturneColors.neutral600, decoration: TextDecoration.none)
              : TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: NocturneColors.text, decoration: TextDecoration.none),
        ),
        // Decorative: there's no "view every playlist/radio/artist/album"
        // destination in scope yet, only the shelves themselves.
        Text('Ver tudo', style: TextStyle(fontSize: 16, color: NocturneColors.accent, decoration: TextDecoration.none)),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.items,
    required this.client,
    required this.onTap,
    this.cardSize = 150,
    this.showSubtitle = false,
    this.nameFontSize = 17,
    this.decorative = false,
  });

  final List<MassBrowseItem> items;
  final MassWebSocketClient client;
  final ValueChanged<MassBrowseItem> onTap;
  final double cardSize;
  final bool showSubtitle;
  final double nameFontSize;

  /// Radio-shelf and playlist art get the reference's soft accent/text
  /// decorative shapes when there's no real cover; plainer shelves (albums)
  /// just get a muted icon.
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardSize + (showSubtitle ? 62 : 46),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          final url = client.imageUrl(item.image, size: 300);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(item),
            child: SizedBox(
              width: cardSize,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(NocturneRadii.chip),
                    child: SizedBox(
                      width: cardSize,
                      height: cardSize,
                      child: url != null
                          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => decorative ? const _ArtworkPlaceholder() : const _ArtPlaceholder())
                          : (decorative ? const _ArtworkPlaceholder() : const _ArtPlaceholder()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: nameFontSize, fontWeight: FontWeight.w500, color: NocturneColors.text, decoration: TextDecoration.none),
                  ),
                  if (showSubtitle && item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: NocturneColors.neutral500, decoration: TextDecoration.none),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ArtPlaceholder extends StatelessWidget {
  const _ArtPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(color: NocturneColors.inset, alignment: Alignment.center, child: Icon(Icons.music_note, size: 32, color: NocturneColors.neutral600));
  }
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.items, required this.client, required this.onTap});

  final List<MassBrowseItem> items;
  final MassWebSocketClient client;
  final ValueChanged<MassBrowseItem> onTap;

  static const _circleSize = 130.0;
  static const _columnWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _circleSize + 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final item = items[index];
          final url = client.imageUrl(item.image, size: 260);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(item),
            child: SizedBox(
              width: _columnWidth,
              child: Column(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: _circleSize,
                      height: _circleSize,
                      child: url == null
                          ? const _AvatarPlaceholder()
                          : Image.network(url, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const _AvatarPlaceholder()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: NocturneColors.text, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(color: NocturneColors.inset, alignment: Alignment.center, child: Icon(Icons.person, size: 32, color: NocturneColors.neutral600));
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({required this.items, required this.onTap});

  final List<MassBrowseItem> items;
  final ValueChanged<MassBrowseItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('Sem resultados.', style: TextStyle(fontSize: 16, color: NocturneColors.neutral600, decoration: TextDecoration.none)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _BrowseRow(item: items[i], onTap: () => onTap(items[i])),
          if (i != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// "Rádios" tab content: title row, a station search, a "live" hero card
/// for whichever saved station is currently loaded on [player]'s queue (MA
/// has no separate "radio session" concept — a station counts as live the
/// same way a track does, by name-matching the queue's `display_name`), and
/// the full saved-stations list below.
class _RadiosTab extends ConsumerStatefulWidget {
  const _RadiosTab({super.key, required this.player});

  final MassPlayer player;

  @override
  ConsumerState<_RadiosTab> createState() => _RadiosTabState();
}

class _RadiosTabState extends ConsumerState<_RadiosTab> {
  final _searchController = TextEditingController();
  List<MassBrowseItem>? _stations;
  MassPlayerQueue? _queue;
  StreamSubscription<MassEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _loadStations();
    _loadQueue();
    _eventSub = ref.read(massWebSocketClientProvider).events.listen(_onEvent);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    final items = await ref.read(massWebSocketClientProvider).getLibraryRadios();
    if (mounted) setState(() => _stations = items);
  }

  Future<void> _loadQueue() async {
    final queue = await ref.read(massWebSocketClientProvider).getActiveQueue(widget.player.playerId);
    if (mounted) setState(() => _queue = queue);
  }

  void _onEvent(MassEvent event) {
    const relevant = {'queue_updated', 'queue_items_updated'};
    if (!relevant.contains(event.event)) return;
    if (event.objectId != widget.player.playerId && event.objectId != _queue?.queueId) return;
    _loadQueue();
  }

  Future<void> _play(MassBrowseItem item) {
    if (item.uri.isEmpty) return Future.value();
    return ref.read(massWebSocketClientProvider).playMedia(widget.player.playerId, item.uri);
  }

  Future<void> _togglePlay() => ref.read(massWebSocketClientProvider).playerCommand('play_pause', widget.player.playerId);

  MassBrowseItem? _findByName(List<MassBrowseItem> items, String name) {
    for (final item in items) {
      if (item.name == name) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.read(massWebSocketClientProvider);
    final stations = _stations;
    final query = _searchController.text.trim().toLowerCase();
    final filtered = stations == null ? null : (query.isEmpty ? stations : stations.where((s) => s.name.toLowerCase().contains(query)).toList());
    final queue = _queue;
    final playing = widget.player.playbackState == MassPlaybackState.playing;
    final liveStation = stations == null || queue == null ? null : _findByName(stations, queue.displayName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text('Rádios', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: NocturneColors.text, decoration: TextDecoration.none))),
            Text('Editar', style: TextStyle(fontSize: 16, color: NocturneColors.accent, decoration: TextDecoration.none)),
          ],
        ),
        const SizedBox(height: 22),
        _SearchField(controller: _searchController, hintText: 'Procurar estações'),
        const SizedBox(height: 26),
        if (liveStation != null && playing) ...[
          _LiveRadioCard(
            imageUrl: client.imageUrl(liveStation.image, size: 400),
            name: liveStation.name,
            meta: liveStation.subtitle ?? queue!.currentItem?.artist ?? '',
            playing: playing,
            onToggle: _togglePlay,
          ),
          const SizedBox(height: 28),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('GUARDADAS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 1.8, color: NocturneColors.neutral600, decoration: TextDecoration.none)),
        ),
        const SizedBox(height: 14),
        if (filtered == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Sem estações na biblioteca.', style: TextStyle(fontSize: 16, color: NocturneColors.neutral600, decoration: TextDecoration.none)),
          )
        else
          Column(
            children: [
              for (var i = 0; i < filtered.length; i++) ...[
                _StationRow(
                  item: filtered[i],
                  imageUrl: client.imageUrl(filtered[i].image, size: 150),
                  live: playing && filtered[i].name == queue?.displayName,
                  onTap: () => _play(filtered[i]),
                ),
                if (i != filtered.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }
}

/// The Rádios tab's "Em direto" hero: whichever saved station the player's
/// queue is currently loaded with.
class _LiveRadioCard extends StatelessWidget {
  const _LiveRadioCard({required this.imageUrl, required this.name, required this.meta, required this.playing, required this.onToggle});

  final String? imageUrl;
  final String name;
  final String meta;
  final bool playing;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(NocturneRadii.insetPanel)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(NocturneRadii.listRow), child: SizedBox(width: 140, height: 140, child: _coverImage(imageUrl))),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('EM DIRETO', style: TextStyle(fontSize: 14, letterSpacing: 1.68, color: NocturneColors.neutral600, decoration: TextDecoration.none)),
                const SizedBox(height: 9),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.15, color: NocturneColors.text, decoration: TextDecoration.none)),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, color: NocturneColors.neutral500, decoration: TextDecoration.none)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: NocturneColors.text),
              child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 30, color: NocturneColors.bg),
            ),
          ),
        ],
      ),
    );
  }
}

/// One saved-station row, with the reference's 3-bar equaliser standing in
/// for "this is what's live right now".
class _StationRow extends StatelessWidget {
  const _StationRow({required this.item, required this.imageUrl, required this.live, required this.onTap});

  final MassBrowseItem item;
  final String? imageUrl;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: NocturneColors.surface,
          borderRadius: BorderRadius.circular(NocturneRadii.listRow),
          border: Border.all(color: live ? NocturneColors.accent.withValues(alpha: 0.5) : Colors.transparent),
        ),
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(NocturneRadii.chip), child: SizedBox(width: 64, height: 64, child: _coverImage(imageUrl))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: live ? NocturneColors.accent : NocturneColors.text, decoration: TextDecoration.none),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(item.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, color: NocturneColors.neutral500, decoration: TextDecoration.none)),
                  ],
                ],
              ),
            ),
            if (live) ...[
              const SizedBox(width: 16),
              const _EqualizerBars(),
            ],
          ],
        ),
      ),
    );
  }
}

class _EqualizerBars extends StatelessWidget {
  const _EqualizerBars();

  @override
  Widget build(BuildContext context) {
    Widget bar(double height) => Container(width: 3, height: height, decoration: BoxDecoration(color: NocturneColors.accent, borderRadius: BorderRadius.circular(2)));
    return SizedBox(
      height: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [bar(8), const SizedBox(width: 3), bar(16), const SizedBox(width: 3), bar(11)],
      ),
    );
  }
}

class _BrowseRow extends StatelessWidget {
  const _BrowseRow({required this.item, required this.onTap});

  final MassBrowseItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: NocturneSpacing.compactCardPadding,
        decoration: BoxDecoration(color: NocturneColors.inset, borderRadius: BorderRadius.circular(NocturneRadii.insetPanel)),
        child: Row(
          children: [
            Icon(Icons.play_circle_outline, size: 22, color: NocturneColors.neutral500),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.name, style: TextStyle(fontSize: 16, color: NocturneColors.text, decoration: TextDecoration.none), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(item.subtitle!, style: TextStyle(fontSize: 13, color: NocturneColors.neutral500, decoration: TextDecoration.none), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: NocturneColors.neutral600, decoration: TextDecoration.none)),
    );
  }
}
