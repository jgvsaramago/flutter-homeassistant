import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../music/ma_client.dart';
import '../../music/ma_models.dart';
import '../../music/music_store.dart';
import '../../widgets/on_screen_keyboard_controller.dart';
import '../modals/speakers_modal.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';
import '../widgets/music_widgets.dart';
import 'now_playing.dart';

/// "Músicas favoritas": the library's hearted tracks, shown as a playlist.
final _favorites = MaItem(uri: 'ma://favorites', mediaType: 'favorites', name: 'Músicas favoritas', itemId: '', provider: 'library', owner: 'Família', domain: 'ma');

/// The design's Música page, on Music Assistant: Ouvir agora / Pesquisar /
/// Biblioteca, collection and artist pages pushed on top, the full-card
/// "A tocar" view, and the mini player under the card.
class MusicPage extends ConsumerStatefulWidget {
  const MusicPage({super.key});

  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

enum _Tab { home, search, library }

class _MusicPageState extends ConsumerState<MusicPage> {
  _Tab _tab = _Tab.home;
  final _stack = <MaItem>[];
  bool _np = false;
  bool _covered = false;
  int _viewTick = 0;
  final _scroll = ScrollController();
  final _cache = <String, Future<dynamic>>{};
  final _favOverride = <String, bool>{};

  // Pesquisar
  final _q = TextEditingController();
  final _qFocus = FocusNode();
  Timer? _debounce;
  String _searchFor = '';
  String _filter = 'tudo';

  // Biblioteca
  String _lib = 'playlists';
  int _sort = 0;

  @override
  void initState() {
    super.initState();
    _q.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 450), () {
        if (mounted && _q.text.trim() != _searchFor) setState(() => _searchFor = _q.text.trim());
      });
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _qFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  MusicStore get _m => ref.read(musicStoreProvider);

  /// For the views below, which share this page's state.
  void _update(VoidCallback change) => setState(change);

  Future<T> _cached<T>(String key, Future<T> Function() load) => (_cache[key] ??= load()) as Future<T>;

  void _go(VoidCallback change) {
    setState(() {
      change();
      _viewTick++;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _open(MaItem item) {
    if (item.mediaType == 'radio') {
      _play(item, context: PlayContext('RÁDIO EM DIRETO', item.name, item));
      return;
    }
    if (item.mediaType == 'track') {
      _play(item);
      return;
    }
    _go(() {
      _stack.add(item);
      _np = false;
    });
  }

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      KToast.show('$e'.replaceFirst('Bad state: ', ''), error: true);
    }
  }

  Future<void> _play(dynamic media, {PlayContext? context, String? startItem, bool shuffle = false, bool radio = false}) =>
      _run(() => _m.play(media is MaItem ? media.uri : media, context: context, startItem: startItem, shuffle: shuffle, radio: radio));

  PlayContext _contextFor(MaItem item) => PlayContext(switch (item.mediaType) {
    'playlist' || 'favorites' => 'A TOCAR DA PLAYLIST',
    'album' => 'A TOCAR DO ÁLBUM',
    'artist' => 'A TOCAR DO ARTISTA',
    'podcast' => 'A TOCAR DO PODCAST',
    'radio' => 'RÁDIO EM DIRETO',
    _ => 'A TOCAR',
  }, item.name, item);

  bool _isFav(MaItem item) => _favOverride[item.uri] ?? item.favorite;

  Future<void> _toggleFav(MaItem item) async {
    final on = !_isFav(item);
    setState(() => _favOverride[item.uri] = on);
    try {
      await _m.setFavorite(item, on);
    } catch (e) {
      setState(() => _favOverride[item.uri] = !on);
      KToast.show('Não foi possível guardar', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only what changes the page's structure — position ticks don't rebuild it.
    final s = ref.watch(
      musicStoreProvider.select(
        (m) => (
          conn: m.connection,
          loaded: m.loaded,
          target: m.targetLabel,
          group: m.active.length,
          track: m.queue?.current?.media?.uri ?? m.queue?.current?.name,
          playing: m.queue?.playing ?? false,
          ctx: m.context?.item?.uri,
        ),
      ),
    );
    final hasTrack = s.track != null;
    return Column(
      children: [
        Expanded(
          child: KFadeUp(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(36)),
              child: Stack(
                children: [
                  // Under "A tocar": its own layer while that slides over it,
                  // then hidden (and its animations paused) once covered.
                  Positioned.fill(
                    child: Visibility(
                      visible: !(_np && _covered),
                      maintainState: true,
                      child: RepaintBoundary(
                        child: Column(
                          children: [
                            _topBar(s.target, s.group),
                            Expanded(child: _content(s.conn, s.loaded)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_np)
                    Positioned.fill(
                      child: NowPlayingView(
                        onClose: () => setState(() => _np = false),
                        onCovered: (covered) => setState(() => _covered = covered),
                        onOpenContext: (item) => _go(() {
                          _stack
                            ..clear()
                            ..add(item);
                          _np = false;
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (hasTrack && !_np) ...[const SizedBox(height: 32), MiniPlayer(
            onOpen: () => setState(() {
              _np = true;
              _covered = false;
            }),
          )],
      ],
    );
  }

  Widget _topBar(String target, int group) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Row(
        children: [
          if (_stack.isNotEmpty) ...[
            KCircleButton(icon: KIcons.chevronLeft, size: 64, iconSize: 28, stroke: 2.2, bg: KMusic.sand, border: null, onTap: () => _go(() => _stack.removeLast())),
            const SizedBox(width: 16),
          ],
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: KMusic.sand, borderRadius: BorderRadius.circular(34)),
            child: Row(
              children: [
                for (final (t, label, icon) in [
                  (_Tab.home, 'Ouvir agora', KIcons.homeOutline),
                  (_Tab.search, 'Pesquisar', KIcons.search),
                  (_Tab.library, 'Biblioteca', KIcons.library),
                ]) ...[
                  if (t != _Tab.home) const SizedBox(width: 4),
                  KPress(
                    onTap: () {
                      if (_tab == t && _stack.isEmpty) return;
                      OnScreenKeyboardController.instance.close();
                      _go(() {
                        _tab = t;
                        _stack.clear();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      decoration: BoxDecoration(
                        color: _tab == t ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: _tab == t ? const [BoxShadow(color: Color(0x1A17191C), blurRadius: 8, offset: Offset(0, 2))] : null,
                      ),
                      child: Row(
                        children: [
                          KIcon(icon, size: 24, color: _tab == t ? KColors.ink : KColors.muted, stroke: 2),
                          const SizedBox(width: 10),
                          Text(label, style: KText.s(20, weight: FontWeight.w600, color: _tab == t ? KColors.ink : KColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          SpeakersButton(label: target, count: group),
        ],
      ),
    );
  }

  Widget _content(MaConnectionState conn, bool loaded) {
    if (conn != MaConnectionState.connected || !loaded) {
      final unavailable = conn == MaConnectionState.unavailable;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!unavailable) const SizedBox(width: 64, height: 64, child: CircularProgressIndicator(strokeWidth: 5, color: KColors.accent)),
            if (unavailable) const KIcon(KIcons.music, size: 72, color: KColors.faint),
            const SizedBox(height: 24),
            Text(unavailable ? 'Music Assistant indisponível' : 'A ligar ao Music Assistant…', style: KText.d(34)),
            if (unavailable) ...[
              const SizedBox(height: 10),
              Text('O add-on Music Assistant não foi encontrado no Home Assistant.', style: KText.s(20, color: KColors.muted)),
            ],
          ],
        ),
      );
    }
    final top = _stack.isEmpty ? null : _stack.last;
    final Widget view = switch ((top?.mediaType, _tab)) {
      ('artist', _) => _ArtistView(key: ValueKey(top!.uri), artist: top, page: this),
      (final String _, _) => _CollectionView(key: ValueKey(top!.uri), item: top, page: this),
      (_, _Tab.home) => _HomeView(page: this),
      (_, _Tab.search) => _SearchView(page: this),
      (_, _Tab.library) => _LibraryView(page: this),
    };
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(36, 32, 36, 40),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_viewTick),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 340),
        curve: kEase,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
        ),
        child: view,
      ),
    );
  }
}

/// The speakers pill in the top bar: who's playing, and how many.
class SpeakersButton extends StatelessWidget {
  const SpeakersButton({super.key, required this.label, required this.count, this.dark = false, this.height = 64});

  final String label;
  final int count;
  final bool dark;
  final double height;

  @override
  Widget build(BuildContext context) {
    return KPress(
      onTap: () => showSpeakers(context),
      child: Container(
        height: height,
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.fromLTRB(18, 0, 22, 0),
        decoration: BoxDecoration(
          color: dark ? KColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(height / 2),
          border: dark ? null : Border.all(color: KMusic.line, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KIcon(KIcons.speaker, size: 28, color: dark ? Colors.white : KColors.accent, stroke: 1.9),
            const SizedBox(width: 12),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(dark ? 22 : 20, weight: FontWeight.w600, color: dark ? Colors.white : KColors.ink)),
            ),
            if (count > 1) ...[
              const SizedBox(width: 12),
              Container(
                constraints: const BoxConstraints(minWidth: 32),
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: KColors.accent, borderRadius: BorderRadius.circular(16)),
                child: Text('$count', style: KText.s(16, weight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Ouvir agora

class _HomeView extends StatelessWidget {
  const _HomeView({required this.page});

  final _MusicPageState page;

  @override
  Widget build(BuildContext context) {
    final m = page._m;
    final hour = DateTime.now().hour;
    final greeting = '${hour < 13 ? 'Bom dia' : (hour < 20 ? 'Boa tarde' : 'Boa noite')}, família';
    return FutureBuilder(
      future: page._cached(
        'home',
        () => Future.wait([
          m.recentlyPlayed(limit: 16),
          m.library('playlists', limit: 16),
          m.library('radios', limit: 16),
          m.library('podcasts', limit: 12),
          m.library('artists', favorite: true, limit: 16),
        ]),
      ),
      builder: (context, snap) {
        if (snap.hasError) return _Failed(onRetry: () => page._update(() => page._cache.remove('home')));
        final d = snap.data;
        if (d == null) return const _Loading();
        final recent = d[0], playlists = d[1], radios = d[2], podcasts = d[3];
        var artists = d[4];
        final shortcuts = <MaItem>[];
        for (final x in [...recent, ...playlists]) {
          if (shortcuts.length < 8 && !shortcuts.any((s) => s.uri == x.uri)) shortcuts.add(x);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(greeting, style: KText.d(46, spacing: -0.5)),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 302 / 96,
              children: [
                _ShortcutTile(item: _favorites, page: page),
                for (final x in shortcuts.take(7)) _ShortcutTile(item: x, page: page),
              ],
            ),
            if (recent.isNotEmpty) ...[const SizedBox(height: 48), _rail('Tocado recentemente', recent, note: 'Nesta casa')],
            if (playlists.isNotEmpty) ...[const SizedBox(height: 48), _rail('As vossas playlists', playlists)],
            if (radios.isNotEmpty) ...[const SizedBox(height: 48), _rail('Rádios', radios, note: 'Em direto')],
            if (podcasts.isNotEmpty) ...[const SizedBox(height: 48), _rail('Podcasts', podcasts)],
            if (artists.isNotEmpty) ...[const SizedBox(height: 48), _rail('Artistas favoritos', artists)],
          ],
        );
      },
    );
  }

  Widget _rail(String title, List<MaItem> items, {String? note}) => MusicRail(
    title: title,
    note: note,
    children: [for (final x in items) _PlayingAware(item: x, builder: (playing) => MusicCard(item: x, playing: playing, onTap: () => page._open(x)))],
  );
}

/// Rebuilds a card only when whether *it* is what's playing changes.
class _PlayingAware extends ConsumerWidget {
  const _PlayingAware({required this.item, required this.builder});

  final MaItem item;
  final Widget Function(bool playing) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(musicStoreProvider.select((m) => m.queue?.playing == true && m.context?.item?.uri == item.uri));
    return builder(playing);
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.item, required this.page});

  final MaItem item;
  final _MusicPageState page;

  @override
  Widget build(BuildContext context) {
    final artist = item.mediaType == 'artist';
    final fav = item.mediaType == 'favorites';
    return KPress(
      onTap: () => page._open(item),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: KMusic.paper, borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            if (fav)
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4B2ACF), Color(0xFFA7C7E7)]),
                ),
                alignment: Alignment.center,
                child: const KIcon(KIcons.heart, size: 38, color: Colors.white, filled: true),
              )
            else
              MaArt(item: item, size: 96, radius: 0, circle: artist, labelSize: artist ? 30 : null),
            const SizedBox(width: 18),
            Expanded(
              child: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.s(20, weight: FontWeight.w600, height: 1.25)),
            ),
            _PlayingAware(item: item, builder: (p) => p ? const Padding(padding: EdgeInsets.only(right: 16), child: PlayingBars(height: 20)) : const SizedBox(width: 16)),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- Pesquisar

const _genres = [
  'Português', 'Fado', 'Pop', 'Rock', 'Jazz', 'Clássica', //
  'Hip-hop', 'Relax', 'Festa', 'Treino', 'Dormir', 'Anos 80',
];

class _SearchView extends StatelessWidget {
  const _SearchView({required this.page});

  final _MusicPageState page;

  @override
  Widget build(BuildContext context) {
    final q = page._searchFor;
    final recent = page._m.recentSearches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KTextField(
          controller: page._q,
          focusNode: page._qFocus,
          hint: 'Artistas, músicas, álbuns, rádios ou podcasts',
          height: 84,
          fontSize: 28,
          background: KMusic.paper,
          leading: const KIcon(KIcons.search, size: 32, color: KColors.muted),
          options: KeyboardOptions(
            doneLabel: 'Pesquisar',
            capitalize: false,
            suggestions: (t) => t.isEmpty ? [...recent.take(3), 'Fado', 'Jazz', 'Relax'] : const [],
          ),
          trailing: page._q.text.isEmpty
              ? null
              : KCircleButton(
                  icon: KIcons.close,
                  size: 60,
                  iconSize: 26,
                  stroke: 2.2,
                  bg: Colors.transparent,
                  fg: KColors.muted,
                  border: null,
                  onTap: () => page._update(() {
                    page._q.clear();
                    page._searchFor = '';
                    page._filter = 'tudo';
                  }),
                ),
        ),
        const SizedBox(height: 36),
        if (q.isEmpty) ...[
          if (recent.isNotEmpty) ...[
            Text('PESQUISAS RECENTES', style: KText.s(15, weight: FontWeight.w700, color: KColors.muted, spacing: 1)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final r in recent) MusicChip(label: r, icon: KIcons.clock, onTap: () => _query(r))],
            ),
            const SizedBox(height: 36),
          ],
          Text('Explorar tudo', style: KText.d(34)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 302 / 150,
            children: [
              for (final (i, g) in _genres.indexed)
                KPress(
                  onTap: () => _query(g),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(colors: [KMusic.gradients[i % 12].$1, KMusic.gradients[i % 12].$2]),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Text(g, style: KText.d(28, color: Colors.white)),
                        Positioned(
                          right: -40,
                          bottom: -42,
                          child: Transform.rotate(
                            angle: 0.42,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(color: const Color(0x38FFFFFF), borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ] else
          _SearchResults(key: ValueKey(q), page: page, query: q),
      ],
    );
  }

  void _query(String text) {
    OnScreenKeyboardController.instance.close();
    page._update(() {
      page._q.text = text;
      page._searchFor = text;
      page._filter = 'tudo';
    });
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({super.key, required this.page, required this.query});

  final _MusicPageState page;
  final String query;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MaSearchResults>(
      future: page._cached('search:$query', () => page._m.search(query)),
      builder: (context, snap) {
        if (snap.hasError) return _Failed(onRetry: () => page._update(() => page._cache.remove('search:$query')));
        final r = snap.data;
        if (r == null) return const _Loading();
        final f = page._filter;
        const filters = [('tudo', 'Tudo'), ('musicas', 'Músicas'), ('artistas', 'Artistas'), ('albuns', 'Álbuns'), ('playlists', 'Playlists'), ('outros', 'Podcasts e rádios')];
        final best = _best(r);
        Widget rail(String title, List<MaItem> items) => items.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 36),
                child: MusicRail(
                  title: title,
                  wrap: f != 'tudo',
                  children: [for (final x in items) MusicCard(item: x, onTap: () => page._open(x))],
                ),
              );
        final empty = r.isEmpty ||
            (f == 'musicas' && r.tracks.isEmpty) ||
            (f == 'artistas' && r.artists.isEmpty) ||
            (f == 'albuns' && r.albums.isEmpty) ||
            (f == 'playlists' && r.playlists.isEmpty) ||
            (f == 'outros' && r.podcasts.isEmpty && r.radios.isEmpty);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final (k, label) in filters) MusicChip(label: label, on: f == k, onTap: () => page._go(() => page._filter = k))],
            ),
            if (empty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(color: KMusic.sand, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const KIcon(KIcons.search, size: 44, color: KColors.muted, stroke: 1.8),
                    ),
                    const SizedBox(height: 14),
                    Text('Sem resultados para "$query"', style: KText.d(34)),
                    const SizedBox(height: 14),
                    Text('Pesquisámos em todos os serviços ligados ao Music Assistant.', style: KText.s(20, color: KColors.muted)),
                  ],
                ),
              )
            else ...[
              if (f == 'tudo' && (best != null || r.tracks.isNotEmpty)) ...[
                const SizedBox(height: 36),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (best != null) ...[Expanded(flex: 5, child: _BestResult(item: best, page: page)), const SizedBox(width: 28)],
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Músicas', style: KText.d(34)),
                            const SizedBox(height: 16),
                            for (final t in r.tracks.take(4)) TrackRow(track: t, compact: true, onTap: () => page._play(t)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (f == 'musicas') ...[
                const SizedBox(height: 36),
                for (final t in r.tracks) TrackRow(track: t, onTap: () => page._play(t), showAlbum: true),
              ],
              if (f == 'tudo' || f == 'artistas') rail('Artistas', r.artists),
              if (f == 'tudo' || f == 'albuns') rail('Álbuns', r.albums),
              if (f == 'tudo' || f == 'playlists') rail('Playlists', r.playlists),
              if (f == 'tudo' || f == 'outros') rail('Podcasts e rádios', [...r.podcasts, ...r.radios]),
            ],
          ],
        );
      },
    );
  }

  MaItem? _best(MaSearchResults r) {
    final q = query.toLowerCase();
    for (final list in [r.artists, r.albums, r.playlists, r.radios, r.podcasts]) {
      final hit = list.where((x) => x.name.toLowerCase().contains(q)).firstOrNull;
      if (hit != null) return hit;
    }
    return r.artists.firstOrNull ?? r.albums.firstOrNull ?? r.playlists.firstOrNull;
  }
}

class _BestResult extends StatelessWidget {
  const _BestResult({required this.item, required this.page});

  final MaItem item;
  final _MusicPageState page;

  @override
  Widget build(BuildContext context) {
    final kind = switch (item.mediaType) {
      'artist' => 'ARTISTA',
      'album' => 'ÁLBUM',
      'playlist' => 'PLAYLIST',
      'radio' => 'RÁDIO',
      'podcast' => 'PODCAST',
      _ => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Melhor resultado', style: KText.d(34)),
        const SizedBox(height: 16),
        Expanded(
          child: KPress(
            onTap: () => page._open(item),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: KMusic.paper, borderRadius: BorderRadius.circular(28)),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MaArt(item: item, size: 168, circle: item.mediaType == 'artist', shadow: true, labelSize: item.mediaType == 'artist' ? 56 : null),
                      const SizedBox(height: 20),
                      Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.d(40, height: 1.1)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (item.mediaType != 'artist' && describe(item).isNotEmpty) ...[
                            Flexible(child: Text(describe(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(20, color: KColors.muted))),
                            const SizedBox(width: 10),
                          ],
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: Text(kind, style: KText.s(15, weight: FontWeight.w700, spacing: 1)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MusicPlayButton(
                      playing: false,
                      size: 80,
                      onTap: () => page._play(item, context: page._contextFor(item), radio: item.mediaType == 'artist'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- Biblioteca

class _LibraryView extends StatelessWidget {
  const _LibraryView({required this.page});

  final _MusicPageState page;

  static const _kinds = [('playlists', 'Playlists'), ('albums', 'Álbuns'), ('artists', 'Artistas'), ('podcasts', 'Podcasts'), ('radios', 'Rádios')];
  static const _sorts = [('Recentes', 'last_played_desc'), ('A–Z', 'sort_name'), ('Adicionados', 'timestamp_added_desc')];

  @override
  Widget build(BuildContext context) {
    final m = page._m;
    final order = _sorts[page._sort].$2;
    return FutureBuilder(
      future: page._cached(
        'library:$order',
        () => Future.wait([
          for (final (k, _) in _kinds) m.library(k, orderBy: order, limit: 200),
          m.library('tracks', favorite: true, limit: 500, orderBy: 'timestamp_added_desc'),
        ]),
      ),
      builder: (context, snap) {
        if (snap.hasError) return _Failed(onRetry: () => page._update(() => page._cache.remove('library:$order')));
        final d = snap.data;
        final counts = {for (final (i, (k, _)) in _kinds.indexed) k: d == null ? null : d[i].length};
        final i = _kinds.indexWhere((k) => k.$1 == page._lib);
        final items = d == null ? null : [if (page._lib == 'playlists') _favorites, ...d[i]];
        final favCount = d?.last.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Biblioteca', style: KText.d(46, spacing: -0.5)),
                const Spacer(),
                KPress(
                  onTap: () => page._go(() => page._sort = (page._sort + 1) % _sorts.length),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.fromLTRB(18, 0, 22, 0),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: KMusic.line, width: 1.5)),
                    child: Row(
                      children: [
                        const KIcon(KIcons.sort, size: 22, stroke: 2),
                        const SizedBox(width: 10),
                        Text(_sorts[page._sort].$1, style: KText.s(20, weight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (k, label) in _kinds)
                  MusicChip(
                    label: label,
                    on: page._lib == k,
                    count: counts[k] == null ? null : '${counts[k]! + (k == 'playlists' ? 1 : 0)}',
                    onTap: () => page._go(() => page._lib = k),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            if (items == null)
              const _Loading()
            else if (items.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('Nada guardado aqui ainda.', style: KText.s(22, color: KColors.muted))))
            else
              for (final x in items) _LibraryRow(item: x, page: page, favCount: favCount),
          ],
        );
      },
    );
  }
}

class _LibraryRow extends ConsumerWidget {
  const _LibraryRow({required this.item, required this.page, this.favCount});

  final MaItem item;
  final _MusicPageState page;
  final int? favCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(musicStoreProvider.select((m) => m.queue?.playing == true && m.context?.item?.uri == item.uri));
    final fav = item.mediaType == 'favorites';
    final artist = item.mediaType == 'artist';
    final (dot, source) = KMusic.source(item.domain);
    final sub = fav ? 'Playlist · ${favCount ?? 0} músicas · Music Assistant' : '${switch (item.mediaType) {
        'playlist' => 'Playlist${item.owner == null ? '' : ' · ${item.owner}'}',
        'album' => ['Álbum', if (item.artistNames.isNotEmpty) item.artistNames, if (item.year != null) '${item.year}'].join(' · '),
        'artist' => 'Artista',
        'podcast' => 'Podcast${item.owner == null ? '' : ' · ${item.owner}'}',
        'radio' => 'Rádio',
        _ => '',
      }} · $source';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: KPress(
        onTap: () => page._open(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(color: playing ? KMusic.playingRow : Colors.transparent, borderRadius: BorderRadius.circular(22)),
          child: Row(
            children: [
              if (fav)
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4B2ACF), Color(0xFFA7C7E7)]),
                  ),
                  alignment: Alignment.center,
                  child: const KIcon(KIcons.heart, size: 36, color: Colors.white, filled: true),
                )
              else
                MaArt(item: item, size: 88, radius: 16, circle: artist, labelSize: artist ? 30 : null),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(24, weight: FontWeight.w600, color: playing ? KColors.accent : KColors.ink)),
                        ),
                        if (fav) ...[const SizedBox(width: 10), const KIcon(KIcons.pinFilled, size: 20, color: KColors.accent, filled: true)],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Flexible(child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(17, color: KColors.muted))),
                      ],
                    ),
                  ],
                ),
              ),
              if (playing) const Padding(padding: EdgeInsets.only(right: 12), child: PlayingBars(height: 24, barWidth: 5, gap: 4)),
              const KIcon(KIcons.chevronRight, size: 26, color: KMusic.faint, stroke: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------- Playlist / Álbum / Podcast

class _CollectionView extends ConsumerWidget {
  const _CollectionView({super.key, required this.item, required this.page});

  final MaItem item;
  final _MusicPageState page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = page._m;
    final fav = item.mediaType == 'favorites';
    final podcast = item.mediaType == 'podcast';
    final album = item.mediaType == 'album';
    final target = ref.watch(musicStoreProvider.select((m) => m.targetLabel));
    final isThis = ref.watch(musicStoreProvider.select((m) => m.context?.item?.uri == item.uri && m.queue?.current != null));
    final playing = ref.watch(musicStoreProvider.select((m) => m.queue?.playing == true)) && isThis;
    final (dot, source) = KMusic.source(item.domain);
    return FutureBuilder<List<MaItem>>(
      future: page._cached(
        'tracks:${item.uri}',
        () => fav ? m.library('tracks', favorite: true, limit: 500, orderBy: 'timestamp_added_desc') : m.tracksOf(item),
      ),
      builder: (context, snap) {
        final tracks = snap.data ?? const <MaItem>[];
        final kind = switch (item.mediaType) {
          'album' => 'ÁLBUM',
          'podcast' => 'PODCAST',
          _ => 'PLAYLIST',
        };
        final meta = [
          if (album && item.year != null) '${item.year}',
          if (snap.hasData) podcast ? '${tracks.length} episódios' : '${tracks.length} músicas, ${totalDuration(tracks)}',
        ].join(' · ');
        void play({int? start, bool shuffle = false}) {
          if (start == null && !shuffle && isThis) {
            page._run(m.playPause);
            return;
          }
          if (fav) {
            final uris = [for (final t in tracks) t.uri];
            if (uris.isEmpty) return;
            page._play(start == null ? uris : uris.sublist(start), context: page._contextFor(item), shuffle: shuffle);
            return;
          }
          page._play(item, context: page._contextFor(item), startItem: start == null ? null : tracks[start].uri, shuffle: shuffle);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                fav
                    ? Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4B2ACF), Color(0xFFA7C7E7)]),
                          boxShadow: const [BoxShadow(color: Color(0x3817191C), blurRadius: 40, offset: Offset(0, 16))],
                        ),
                        alignment: Alignment.center,
                        child: const KIcon(KIcons.heart, size: 120, color: Colors.white, filled: true),
                      )
                    : MaArt(item: item, size: 320, radius: 28, shadow: true, labelSize: 36),
                const SizedBox(width: 36),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kind, style: KText.s(15, weight: FontWeight.w700, color: KColors.muted, spacing: 1)),
                        const SizedBox(height: 12),
                        Text(item.name, maxLines: 3, overflow: TextOverflow.ellipsis, style: KText.d(56, height: 1.05, spacing: -0.8)),
                        if (fav) ...[const SizedBox(height: 12), Text('As músicas marcadas com coração.', style: KText.s(20, color: KColors.muted, height: 1.4))],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if ((album ? item.artistNames : item.owner ?? '').isNotEmpty) Text(album ? item.artistNames : item.owner!, style: KText.s(20, weight: FontWeight.w600)),
                            if (meta.isNotEmpty) Text('· $meta', style: KText.s(20, color: KColors.muted)),
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: KMusic.sand, borderRadius: BorderRadius.circular(16)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text(source, style: KText.s(15, weight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                MusicPlayButton(playing: playing, onTap: () => play()),
                const SizedBox(width: 16),
                MusicRoundButton(icon: KIcons.shuffle, onTap: () => play(shuffle: true)),
                if (!fav) ...[
                  const SizedBox(width: 16),
                  MusicRoundButton(
                    icon: KIcons.heart,
                    fg: page._isFav(item) ? KColors.accent : KColors.ink,
                    filled: page._isFav(item),
                    onTap: () => page._toggleFav(item),
                  ),
                ],
                const SizedBox(width: 16),
                MusicRoundButton(
                  icon: KIcons.addQueue,
                  onTap: () async {
                    if (fav) {
                      await page._run(() => m.play([for (final t in tracks) t.uri], option: 'add'));
                    } else {
                      await page._run(() => m.play(item.uri, option: 'add'));
                    }
                    KToast.show('Adicionado à fila');
                  },
                ),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    text: 'Toca em ',
                    children: [TextSpan(text: target, style: KText.s(17, weight: FontWeight.w600))],
                  ),
                  style: KText.s(17, color: KColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: KMusic.rule, width: 1.5))),
              child: Row(
                children: [
                  SizedBox(width: 56, child: Text('#', textAlign: TextAlign.center, style: _head)),
                  const SizedBox(width: 20),
                  Expanded(flex: 3, child: Text(podcast ? 'EPISÓDIO' : 'TÍTULO', style: _head)),
                  if (!album && !podcast) ...[const SizedBox(width: 20), Expanded(flex: 2, child: Text('ÁLBUM', style: _head))],
                  const SizedBox(width: 20),
                  SizedBox(width: 120, child: Text('DURAÇÃO', textAlign: TextAlign.right, style: _head)),
                ],
              ),
            ),
            if (snap.hasError)
              _Failed(onRetry: () => page._update(() => page._cache.remove('tracks:${item.uri}')))
            else if (!snap.hasData)
              const _Loading()
            else if (tracks.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: Center(child: Text('Sem faixas.', style: KText.s(22, color: KColors.muted))))
            else
              for (final (i, t) in tracks.take(300).indexed)
                TrackRow(
                  track: t,
                  number: i + 1,
                  showArt: !album && !podcast,
                  showAlbum: !album && !podcast,
                  contextUri: item.uri,
                  favorite: page._isFav(t),
                  onTap: () => play(start: i),
                ),
          ],
        );
      },
    );
  }
}

final _head = KText.s(15, weight: FontWeight.w700, color: KColors.muted, spacing: 1);

/// One track: number (or the playing bars), art, title and artists,
/// album, favourite heart and duration. Highlighted while it's playing.
class TrackRow extends ConsumerWidget {
  const TrackRow({
    super.key,
    required this.track,
    required this.onTap,
    this.number,
    this.showArt = true,
    this.showAlbum = false,
    this.contextUri,
    this.favorite = false,
    this.compact = false,
  });

  final MaItem track;
  final VoidCallback onTap;
  final int? number;
  final bool showArt;
  final bool showAlbum;
  final String? contextUri;
  final bool favorite;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      musicStoreProvider.select((m) {
        final on = m.queue?.current?.media?.uri == track.uri && (contextUri == null || m.context?.item?.uri == contextUri);
        return (on: on, playing: on && m.queue?.playing == true);
      }),
    );
    final on = current.on;
    final (dot, source) = KMusic.source(track.domain);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: KPress(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: BoxConstraints(minHeight: compact ? 84 : 88),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(color: on ? KMusic.playingRow : Colors.transparent, borderRadius: BorderRadius.circular(22)),
          child: Row(
            children: [
              if (number != null) ...[
                SizedBox(
                  width: 56,
                  child: Center(
                    child: on ? PlayingBars(playing: current.playing) : Text('$number', style: KText.s(20, color: KColors.muted)),
                  ),
                ),
                const SizedBox(width: 20),
              ],
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    if (showArt) ...[MaArt(item: track, size: compact ? 60 : 64, radius: 12), const SizedBox(width: 18)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(22, weight: FontWeight.w600, color: on ? KColors.accent : KColors.ink)),
                          const SizedBox(height: 3),
                          Text(
                            [track.artistNames, if (number == null && showAlbum && track.albumName != null) track.albumName!].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KText.s(17, color: KColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (number != null && showAlbum) ...[
                const SizedBox(width: 20),
                Expanded(flex: 2, child: Text(track.albumName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(20, color: KColors.muted))),
              ],
              if (number == null) ...[
                Tooltip(message: source, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle))),
                const SizedBox(width: 16),
              ],
              SizedBox(
                width: number == null ? 64 : 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (favorite) ...[const KIcon(KIcons.heart, size: 20, color: KColors.accent, filled: true), const SizedBox(width: 14)],
                    Text(fmtDuration(track.duration), style: KText.s(20, color: KColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------ Artista

class _ArtistView extends ConsumerWidget {
  const _ArtistView({super.key, required this.artist, required this.page});

  final MaItem artist;
  final _MusicPageState page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = page._m;
    final isThis = ref.watch(musicStoreProvider.select((m) => m.context?.item?.uri == artist.uri && m.queue?.current != null));
    final playing = ref.watch(musicStoreProvider.select((m) => m.queue?.playing == true)) && isThis;
    final following = page._isFav(artist);
    final (_, source) = KMusic.source(artist.domain);
    return FutureBuilder(
      future: page._cached('artist:${artist.uri}', () => Future.wait([m.tracksOf(artist), m.albumsOf(artist)])),
      builder: (context, snap) {
        final top = snap.data?[0].take(5).toList() ?? const <MaItem>[];
        final albums = snap.data?[1] ?? const <MaItem>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 380,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: KMusic.gradientFor(artist.uri)),
              child: Stack(
                children: [
                  Positioned(right: 60, top: 40, child: MaArt(item: artist, size: 300, circle: true, labelSize: 110)),
                  Positioned(
                    left: 36,
                    bottom: 36,
                    right: 400,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ARTISTA', style: KText.s(15, weight: FontWeight.w700, color: Colors.white.withValues(alpha: .85), spacing: 1)),
                        const SizedBox(height: 10),
                        Text(artist.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.d(80, color: Colors.white, height: 1, spacing: -1)),
                        const SizedBox(height: 10),
                        Text('${following ? 'Segue este artista' : 'Artista'} · $source', style: KText.s(20, color: Colors.white.withValues(alpha: .9))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                MusicPlayButton(
                  playing: playing,
                  onTap: () => isThis ? page._run(m.playPause) : page._play(artist, context: page._contextFor(artist)),
                ),
                const SizedBox(width: 16),
                MusicRoundButton(icon: KIcons.shuffle, onTap: () => page._play(artist, context: page._contextFor(artist), shuffle: true)),
                const SizedBox(width: 16),
                KPress(
                  onTap: () => page._toggleFav(artist),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: following ? Colors.white : KColors.accent,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: following ? KMusic.line : KColors.accent, width: 1.5),
                    ),
                    child: Text(following ? 'A seguir' : 'Seguir', style: KText.s(20, weight: FontWeight.w600, color: following ? KColors.ink : Colors.white)),
                  ),
                ),
                const SizedBox(width: 16),
                MusicChip(
                  label: 'Rádio do artista',
                  icon: KIcons.radio,
                  onTap: () => page._play(artist, context: PlayContext('RÁDIO DO ARTISTA', artist.name, artist), radio: true),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text('Populares', style: KText.d(34)),
            const SizedBox(height: 16),
            if (snap.hasError)
              _Failed(onRetry: () => page._update(() => page._cache.remove('artist:${artist.uri}')))
            else if (!snap.hasData)
              const _Loading()
            else
              for (final (i, t) in top.indexed)
                TrackRow(
                  track: t,
                  number: i + 1,
                  contextUri: artist.uri,
                  onTap: () => page._play([for (final x in top.sublist(i)) x.uri], context: page._contextFor(artist)),
                ),
            if (albums.isNotEmpty) ...[
              const SizedBox(height: 40),
              MusicRail(
                title: 'Discografia',
                children: [for (final a in albums) MusicCard(item: a, sub: [if (a.year != null) '${a.year}', 'Álbum'].join(' · '), onTap: () => page._open(a))],
              ),
            ],
          ],
        );
      },
    );
  }
}

// --------------------------------------------------------------------- helpers

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 80),
    child: Center(child: SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5, color: KColors.accent))),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        Text('Não foi possível carregar.', style: KText.s(22, color: KColors.muted)),
        const SizedBox(height: 20),
        KButton(label: 'Tentar de novo', icon: KIcons.refresh, height: 64, onTap: onRetry),
      ],
    ),
  );
}
