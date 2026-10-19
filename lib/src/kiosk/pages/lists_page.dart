import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/on_screen_keyboard_controller.dart';
import '../data/todo_data.dart';
import '../modals/item_modal.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';

/// Which list Listas shows; Início's "Compras" card points it at the
/// shopping list before navigating here.
final selectedListProvider = StateProvider<String?>((ref) => null);

String listIcon(String key) => switch (key) {
  'cart' => KIcons.cart,
  'pill' => KIcons.pill,
  'home' => KIcons.house,
  'gift' => KIcons.gift,
  _ => KIcons.list,
};

/// Listas: every HA to-do list down the side, the selected one's items on
/// the right — pending first, the completed ones folded underneath.
class ListsPage extends ConsumerStatefulWidget {
  const ListsPage({super.key});

  @override
  ConsumerState<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends ConsumerState<ListsPage> {
  bool _showDone = true;

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(todoListsProvider);
    final selectedId = ref.watch(selectedListProvider);
    final current = lists.where((l) => l.entityId == selectedId).firstOrNull ?? lists.firstOrNull;
    final itemsAsync = current == null ? null : ref.watch(todoItemsProvider(current.entityId));
    final items = itemsAsync?.valueOrNull ?? const <TodoItem>[];
    final pending = items.where((i) => !i.done).toList();
    final done = items.where((i) => i.done).toList();
    final actions = ref.read(todoActionsProvider);

    return KFadeUp(
      child: KSection(
        padding: const EdgeInsets.all(28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Text('Listas', style: KText.pageTitle),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final l in lists) ...[
                          _ListButton(list: l, on: l.entityId == current?.entityId, onTap: () => ref.read(selectedListProvider.notifier).state = l.entityId),
                          const SizedBox(height: 14),
                        ],
                        KPress(
                          onTap: () => showKModal(context, (_) => const _NewListModal()),
                          child: KDashedBox(
                            radius: 26,
                            child: SizedBox(
                              height: 88,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const KIcon(KIcons.plus, size: 28, color: KColors.ink2, stroke: 2.2),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Nova lista',
                                    style: KText.s(22, weight: FontWeight.w600, color: KColors.ink2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(30)),
                child: current == null
                    ? Center(
                        child: Text('Nenhuma lista no Home Assistant', style: KText.s(24, color: KColors.muted)),
                      )
                    : Column(
                        key: ValueKey(current.entityId),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(current.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.d(44, spacing: -1)),
                                    const SizedBox(height: 4),
                                    Text(
                                      pending.isEmpty ? 'Tudo feito' : '${pending.length} ${pending.length == 1 ? 'artigo' : 'artigos'} por fazer',
                                      style: KText.s(21, color: KColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              if (done.isNotEmpty)
                                KButton(
                                  label: 'Limpar concluídos',
                                  height: 60,
                                  fontSize: 20,
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  onTap: () => actions.clearDone(current.entityId).catchError(KToast.error),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          KPress(
                            onTap: () => showItemModal(context, list: current, existing: items),
                            child: Container(
                              height: 80,
                              padding: const EdgeInsets.fromLTRB(18, 0, 24, 0),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(color: KColors.accent, shape: BoxShape.circle),
                                    child: const Center(child: KIcon(KIcons.plus, size: 28, color: Colors.white, stroke: 2.2)),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Adicionar artigo…',
                                    style: KText.s(24, weight: FontWeight.w500, color: KColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: itemsAsync != null && itemsAsync.isLoading && !itemsAsync.hasValue
                                ? const Center(child: CircularProgressIndicator(color: KColors.accent))
                                : ListView(
                                    children: [
                                      for (final it in pending)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: Container(
                                            constraints: const BoxConstraints(minHeight: 80),
                                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                                            child: Row(
                                              children: [
                                                KPress(
                                                  onTap: () => actions.update(current.entityId, it, done: true).catchError(KToast.error),
                                                  child: const SizedBox(width: 92, height: 80, child: Center(child: KCheckCircle(done: false, size: 46))),
                                                ),
                                                Expanded(
                                                  child: KPress(
                                                    onTap: () => showItemModal(context, list: current, item: it, existing: items),
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(right: 24),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(it.name, style: KText.s(24, weight: FontWeight.w500)),
                                                          ),
                                                          if (it.detail.isNotEmpty) ...[
                                                            const SizedBox(width: 16),
                                                            Text(it.detail, style: KText.s(20, color: KColors.muted)),
                                                          ],
                                                          const SizedBox(width: 16),
                                                          const KIcon(KIcons.chevronRight, size: 24, color: KColors.faint),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      if (pending.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 48),
                                          child: Text(
                                            'Nada por fazer nesta lista',
                                            textAlign: TextAlign.center,
                                            style: KText.s(24, color: KColors.muted),
                                          ),
                                        ),
                                      if (done.isNotEmpty) ...[
                                        KPress(
                                          onTap: () => setState(() => _showDone = !_showDone),
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                                            child: SizedBox(
                                              height: 64,
                                              child: Row(
                                                children: [
                                                  AnimatedRotation(
                                                    turns: _showDone ? .25 : 0,
                                                    duration: const Duration(milliseconds: 250),
                                                    child: const KIcon(KIcons.chevronRight, size: 24, color: KColors.ink2, stroke: 2.2),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    'Concluídos (${done.length})',
                                                    style: KText.s(21, weight: FontWeight.w700, color: KColors.ink2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (_showDone)
                                          for (final it in done)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 10),
                                              child: KPress(
                                                onTap: () => actions.update(current.entityId, it, done: false).catchError(KToast.error),
                                                child: Container(
                                                  constraints: const BoxConstraints(minHeight: 80),
                                                  padding: const EdgeInsets.fromLTRB(22, 0, 28, 0),
                                                  decoration: BoxDecoration(color: const Color(0x8CFFFFFF), borderRadius: BorderRadius.circular(22)),
                                                  child: Row(
                                                    children: [
                                                      const KCheckCircle(done: true, size: 46),
                                                      const SizedBox(width: 20),
                                                      Expanded(
                                                        child: Text(
                                                          it.name,
                                                          style: KText.s(
                                                            22,
                                                            weight: FontWeight.w500,
                                                            color: KColors.faint,
                                                          ).copyWith(decoration: TextDecoration.lineThrough),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                      ],
                                    ],
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListButton extends StatelessWidget {
  const _ListButton({required this.list, required this.on, required this.onTap});

  final TodoListInfo list;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 104,
        padding: const EdgeInsets.fromLTRB(16, 0, 22, 0),
        decoration: BoxDecoration(color: on ? KColors.accent : KColors.sub, borderRadius: BorderRadius.circular(26)),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: on ? const Color(0x29FFFFFF) : Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Center(child: KIcon(listIcon(list.icon), size: 30, color: on ? Colors.white : KColors.ink)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.s(24, weight: FontWeight.w600, color: on ? Colors.white : KColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(list.pending == 0 ? 'Tudo feito' : '${list.pending} por fazer', style: KText.s(18, color: on ? KColors.onAccentMuted : KColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Nova lista": a name and an icon. Creates a Local To-do list in HA.
class _NewListModal extends ConsumerStatefulWidget {
  const _NewListModal();

  @override
  ConsumerState<_NewListModal> createState() => _NewListModalState();
}

class _NewListModalState extends ConsumerState<_NewListModal> {
  final _name = TextEditingController();
  String _icon = 'list';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await createTodoList(ref, name, _icon);
      OnScreenKeyboardController.instance.close();
      KToast.show('Lista criada: $name');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      KToast.error(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KModal(
      keyboardTop: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KModalHeader(title: 'Nova lista'),
          const SizedBox(height: 24),
          const KFieldLabel('NOME'),
          const SizedBox(height: 12),
          KTextField(
            controller: _name,
            hint: 'Ex.: Arrumações do sótão',
            autofocus: true,
            options: KeyboardOptions(doneLabel: 'Criar', onDone: _create),
          ),
          const SizedBox(height: 24),
          const KFieldLabel('ÍCONE'),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (i, k) in todoListIcons.indexed) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: KPress(
                    onTap: () => setState(() => _icon = k),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 72,
                      decoration: BoxDecoration(color: _icon == k ? KColors.accent : KColors.sub, borderRadius: BorderRadius.circular(22)),
                      child: Center(child: KIcon(listIcon(k), size: 30, color: _icon == k ? Colors.white : KColors.ink)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          KModalFooter(saveLabel: 'Criar lista', canSave: _name.text.trim().isNotEmpty, busy: _busy, onSave: _create),
        ],
      ),
    );
  }
}
