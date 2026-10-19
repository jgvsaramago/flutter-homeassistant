import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calendar_data.dart';
import '../data/chores_data.dart';
import '../data/family_data.dart';
import '../data/house_models.dart';
import '../data/meals_data.dart';
import '../data/pt_dates.dart';
import '../data/todo_data.dart';
import '../kiosk_shell.dart';
import '../modals/climate_modal.dart';
import '../modals/event_modal.dart';
import '../modals/intercom_modal.dart';
import '../modals/item_modal.dart';
import '../modals/meal_modal.dart';
import '../modals/task_modal.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/ac_widgets.dart';
import '../widgets/car_card.dart';
import '../widgets/energy_flow.dart';
import '../widgets/house_widgets.dart';
import '../widgets/kiosk_header.dart';
import '../widgets/kiosk_nav_bar.dart';
import '../widgets/kiosk_widgets.dart';
import 'calendar_page.dart';
import 'lists_page.dart';

/// Início: the house at a glance, this week's calendar, and today's tasks,
/// meals and shopping list.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _HouseSection(),
        SizedBox(height: 32),
        Expanded(child: _WeekSection()),
        SizedBox(height: 32),
        SizedBox(
          height: 440,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _TasksCard()),
              SizedBox(width: 24),
              Expanded(child: _MealsCard()),
              SizedBox(width: 24),
              Expanded(child: _ShoppingCard()),
            ],
          ),
        ),
      ],
    );
  }
}

void _goTo(WidgetRef ref, KioskPage page) => ref.read(kioskPageProvider.notifier).state = page;

class _HouseSection extends ConsumerWidget {
  const _HouseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(acUnitsProvider);
    final heater = ref.watch(waterHeaterProvider);
    final energy = ref.watch(energyInfoProvider);
    final cars = ref.watch(evCarsProvider);
    final locks = ref.watch(locksProvider);
    return KSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KPress(
                onTap: () => _goTo(ref, KioskPage.house),
                child: Text('Casa', style: KText.d(40)),
              ),
              const Spacer(),
              const HouseStatusChips(),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 420,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: KAcSummaryCard(units: units, onSeeAll: () => showClimateModal(context)),
                      ),
                      if (heater != null) ...[const SizedBox(height: 16), Expanded(child: WaterHeaterCard(info: heater))],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(width: 420, child: KEnergyFlow(info: energy)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 400,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(28)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GateCameraTile(height: 220, onTap: () => showIntercom(context)),
                        const SizedBox(height: 14),
                        for (final l in locks.take(3))
                          SizedBox(
                            height: 46,
                            child: Row(
                              children: [
                                KIcon(l.icon, size: 26, color: KColors.ink2, stroke: 1.9),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(17)),
                                ),
                                Text(
                                  l.stateLabel,
                                  style: KText.s(15, weight: FontWeight.w600, color: l.secured ? KColors.greenInk : KColors.orangeInk),
                                ),
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: KCarCard(car: cars[0])),
              const SizedBox(width: 16),
              Expanded(child: KCarCard(car: cars[1])),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekSection extends ConsumerStatefulWidget {
  const _WeekSection();

  @override
  ConsumerState<_WeekSection> createState() => _WeekSectionState();
}

class _WeekSectionState extends ConsumerState<_WeekSection> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final now = watchNow(ref);
    final monday = addDays(mondayOf(now), _offset * 7);
    final events = ref.watch(calendarRangeProvider(weekRange(monday))).valueOrNull ?? const <KEvent>[];
    final sources = ref.watch(calendarSourcesProvider).where((s) => !s.holiday).toList();
    final sunday = addDays(monday, 6);
    final title = monday.month == sunday.month
        ? PtDates.monthYear(monday)
        : '${PtDates.cap(PtDates.months[monday.month - 1])} – ${PtDates.months[sunday.month - 1]} ${sunday.year}';
    return KSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: KPress(
                  onTap: () => _goTo(ref, KioskPage.calendar),
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.d(48, spacing: -1)),
                ),
              ),
              KCircleButton(icon: KIcons.chevronLeft, onTap: () => setState(() => _offset--)),
              const SizedBox(width: 12),
              KCircleButton(icon: KIcons.chevronRight, onTap: () => setState(() => _offset++)),
              const SizedBox(width: 12),
              KButton(label: 'Hoje', onTap: () => setState(() => _offset = 0)),
              const SizedBox(width: 12),
              KButton.primary(
                label: 'Novo evento',
                icon: KIcons.plus,
                onTap: () async {
                  final d = await showEventModal(context, day: _offset == 0 ? now : monday);
                  if (d != null && mounted) setState(() => _offset = daysBetween(mondayOf(now), mondayOf(d)) ~/ 7);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final s in sources)
                Container(
                  height: 64,
                  padding: const EdgeInsets.fromLTRB(8, 0, 24, 0),
                  decoration: BoxDecoration(color: s.color.tint, borderRadius: BorderRadius.circular(32)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KAvatar(initial: s.initial, color: s.color.color),
                      const SizedBox(width: 12),
                      Text(s.name, style: KText.s(22, weight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _DayColumn(day: addDays(monday, i), events: events, now: now),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayColumn extends ConsumerWidget {
  const _DayColumn({required this.day, required this.events, required this.now});

  final DateTime day;
  final List<KEvent> events;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = sameDay(day, now);
    final allDay = events.where((e) => e.allDay && e.coversDay(day)).toList();
    final timed = events.where((e) => !e.allDay && e.coversDay(day)).toList();
    final holiday = allDay.any((e) => e.source.holiday);
    final nowIndex = today ? timed.indexWhere((e) => e.start.isAfter(now)) : -1;
    final cards = <Widget>[for (final e in timed) _EventCard(e)];
    if (today && timed.isNotEmpty) cards.insert(nowIndex < 0 ? cards.length : nowIndex, const _NowMarker());
    return KPress(
      onTap: () {
        ref.read(calendarFocusProvider.notifier).state = (date: day, view: CalView.day);
        _goTo(ref, KioskPage.calendar);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: today ? KColors.todayBg : (holiday ? KColors.holidayBg : KColors.sub), borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              PtDates.abbr[day.weekday - 1],
              textAlign: TextAlign.center,
              style: KText.s(18, weight: FontWeight.w700, spacing: 1.5, color: holiday ? KColors.red : (today ? KColors.todayInk : KColors.muted)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: today ? KColors.accent : (holiday ? KColors.redTint : Colors.transparent), shape: BoxShape.circle),
                child: Text('${day.day}', style: KText.d(32, color: today ? Colors.white : (holiday ? KColors.redInk : KColors.ink))),
              ),
            ),
            const SizedBox(height: 18),
            for (final a in allDay) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                decoration: BoxDecoration(color: a.source.color.color, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.source.holiday ? 'FERIADO' : 'DIA TODO',
                      style: KText.s(13, weight: FontWeight.w700, color: Colors.white, spacing: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KText.s(19, weight: FontWeight.w600, color: Colors.white, height: 1.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (allDay.isNotEmpty && timed.isNotEmpty) ...[
              Container(height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 4), color: KColors.border),
              const SizedBox(height: 12),
            ],
            if (today && timed.isEmpty && allDay.isEmpty) const _NowMarker(),
            if (timed.isEmpty && allDay.isEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Center(child: KIcon(KIcons.calendarCheck, size: 34, color: KColors.faint, stroke: 1.8)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Dia livre',
                        style: KText.s(20, weight: FontWeight.w600, color: KColors.ink2),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NowMarker extends StatelessWidget {
  const _NowMarker();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(color: KColors.now, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          'Agora',
          style: KText.s(16, weight: FontWeight.w700, color: KColors.now),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 2, color: KColors.now)),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard(this.e);

  final KEvent e;

  @override
  Widget build(BuildContext context) {
    final c = e.source.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.timeRange,
            style: KText.s(17, weight: FontWeight.w700, color: c.ink),
          ),
          const SizedBox(height: 6),
          Text(
            e.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: KText.s(21, weight: FontWeight.w600, height: 1.2),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.s(16, color: KColors.ink3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bottom row ────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.sub, this.onTitle, this.onAdd});

  final String title;
  final String sub;
  final VoidCallback? onTitle;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        KPress(
          onTap: onTitle,
          child: Text(title, style: KText.cardTitle),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KText.s(20, weight: FontWeight.w500, color: KColors.muted),
          ),
        ),
        if (onAdd != null)
          KCircleButton(icon: KIcons.plus, size: 56, iconSize: 28, stroke: 2.2, bg: KColors.accent, fg: Colors.white, border: null, onTap: onAdd),
      ],
    );
  }
}

class _TasksCard extends ConsumerWidget {
  const _TasksCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchNow(ref);
    final state = ref.watch(choresProvider);
    final members = {for (final m in ref.watch(familyMembersProvider)) m.id: m};
    final today = state.forDay(now);
    final done = today.where((c) => state.isDone(now, c)).length;
    return KSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            title: 'Tarefas',
            sub: today.isEmpty ? 'Nada para hoje' : '$done de ${today.length} feitas',
            onTitle: () => _goTo(ref, KioskPage.tasks),
            onAdd: () => showTaskModal(context, day: now),
          ),
          const SizedBox(height: 18),
          KProgress(value: today.isEmpty ? 0 : done / today.length),
          const SizedBox(height: 18),
          Expanded(
            child: ClipRect(
              child: Column(
                children: [
                  for (final c in today)
                    () {
                      final isDone = state.isDone(now, c);
                      final m = members[c.who];
                      return SizedBox(
                        height: 60,
                        child: Row(
                          children: [
                            KPress(
                              onTap: () => ref.read(choresProvider.notifier).toggle(now, c).catchError(KToast.error),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Center(
                                  child: KCheckCircle(done: isDone, size: 40, color: KColors.accent),
                                ),
                              ),
                            ),
                            Expanded(
                              child: KPress(
                                onTap: () => showTaskModal(context, chore: c, day: now),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: KText.s(
                                          22,
                                          weight: FontWeight.w500,
                                          color: isDone ? KColors.faint : KColors.ink,
                                        ).copyWith(decoration: isDone ? TextDecoration.lineThrough : null),
                                      ),
                                    ),
                                    if (m != null) KAvatar(initial: m.initial, color: m.color.color, size: 36, fontSize: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealsCard extends ConsumerWidget {
  const _MealsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchNow(ref);
    final plan = ref.watch(mealPlanProvider);
    final tomorrow = plan[mealKey(addDays(now, 1), MealType.jantar)];
    return KSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              KPress(
                onTap: () => _goTo(ref, KioskPage.meals),
                child: Text('Refeições', style: KText.cardTitle),
              ),
              const Spacer(),
              Text(
                'Hoje',
                style: KText.s(20, weight: FontWeight.w500, color: KColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final t in MealType.values)
            () {
              final m = plan[mealKey(now, t)];
              final main = t == MealType.jantar;
              final text = m == null
                  ? '+ Planear'
                  : switch (m.place) {
                      MealPlace.fora => 'Fora · ${m.dish}',
                      MealPlace.encomenda => '${m.dish} · Encomenda',
                      MealPlace.casa => m.dish,
                    };
              return Padding(
                padding: EdgeInsets.only(bottom: main ? 0 : 10),
                child: KPress(
                  onTap: () => showMealModal(context, day: now, type: t),
                  child: Container(
                    padding: main ? const EdgeInsets.symmetric(horizontal: 18, vertical: 14) : const EdgeInsets.symmetric(vertical: 12),
                    decoration: main
                        ? BoxDecoration(color: KColors.orangeTint, borderRadius: BorderRadius.circular(20))
                        : const BoxDecoration(
                            border: Border(bottom: BorderSide(color: KColors.divider, width: 1.5)),
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.caps + (main && m != null ? ' · ${m.time}' : ''),
                          style: KText.s(17, weight: FontWeight.w700, spacing: 1, color: main ? KColors.orangeInk : KColors.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.s(main ? 26 : 23, weight: main ? FontWeight.w600 : FontWeight.w500, color: m == null ? KColors.muted : KColors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }(),
          const SizedBox(height: 14),
          KPress(
            onTap: () => _goTo(ref, KioskPage.meals),
            child: Text(
              tomorrow == null ? 'Amanhã: por planear' : 'Amanhã: ${tomorrow.dish}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KText.s(20, color: KColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingCard extends ConsumerWidget {
  const _ShoppingCard();

  static const _show = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(shoppingListProvider);
    final items = list == null ? const <TodoItem>[] : (ref.watch(todoItemsProvider(list.entityId)).valueOrNull ?? const <TodoItem>[]);
    final pending = items.where((i) => !i.done).toList();
    void openLists() {
      if (list != null) ref.read(selectedListProvider.notifier).state = list.entityId;
      _goTo(ref, KioskPage.lists);
    }

    return KSection(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            title: list?.name ?? 'Compras',
            sub: list == null ? 'Sem lista' : (pending.isEmpty ? 'Tudo comprado' : '${pending.length} por comprar'),
            onTitle: openLists,
            onAdd: list == null ? null : () => showItemModal(context, list: list, existing: items),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRect(
              child: Column(
                children: [
                  for (final it in pending.take(_show))
                    SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          KPress(
                            onTap: () => ref.read(todoActionsProvider).update(list!.entityId, it, done: true).catchError(KToast.error),
                            child: const SizedBox(
                              width: 48,
                              height: 56,
                              child: Align(alignment: Alignment.centerLeft, child: KCheckCircle(done: false, size: 32)),
                            ),
                          ),
                          Expanded(
                            child: KPress(
                              onTap: () => showItemModal(context, list: list!, item: it, existing: items),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      it.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: KText.s(22, weight: FontWeight.w500),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      it.detail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: KText.s(18, color: KColors.muted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          KPress(
            onTap: openLists,
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  Text(
                    pending.length > _show ? 'Ver todos (${pending.length})' : 'Abrir lista',
                    style: KText.s(20, weight: FontWeight.w600, color: KColors.accent),
                  ),
                  const SizedBox(width: 6),
                  const KIcon(KIcons.chevronRight, size: 22, color: KColors.accent, stroke: 2.2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
