import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meals_data.dart';
import '../data/pt_dates.dart';
import '../modals/meal_modal.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_header.dart';
import '../widgets/kiosk_widgets.dart';

const _placeDot = {MealPlace.casa: KColors.green, MealPlace.fora: KColors.blue, MealPlace.encomenda: KColors.orange};

/// Refeições: the week's meal plan — a row per day, a column per meal.
class MealsPage extends ConsumerStatefulWidget {
  const MealsPage({super.key});

  @override
  ConsumerState<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends ConsumerState<MealsPage> {
  int _offset = 0;
  int _dir = 0;
  int _tick = 0;

  void _nav(int dir) => setState(() {
    _offset = dir == 0 ? 0 : _offset + dir;
    _dir = dir;
    _tick++;
  });

  @override
  Widget build(BuildContext context) {
    final now = watchNow(ref);
    final plan = ref.watch(mealPlanProvider);
    final monday = addDays(mondayOf(now), _offset * 7);
    final sunday = addDays(monday, 6);
    return KFadeUp(
      child: KSection(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Refeições', style: KText.pageTitle),
                      const SizedBox(height: 2),
                      Text(
                        'Semana ${PtDates.isoWeek(monday)} · ${PtDates.short(monday)} – ${PtDates.short(sunday)}',
                        style: KText.s(20, weight: FontWeight.w500, color: KColors.muted),
                      ),
                    ],
                  ),
                ),
                KCircleButton(icon: KIcons.chevronLeft, onTap: () => _nav(-1)),
                const SizedBox(width: 12),
                KCircleButton(icon: KIcons.chevronRight, onTap: () => _nav(1)),
                const SizedBox(width: 12),
                KButton(label: 'Hoje', onTap: () => _nav(0)),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const SizedBox(width: 162),
                  for (final t in MealType.values)
                    Expanded(
                      child: Text(
                        t.caps,
                        style: KText.s(17, weight: FontWeight.w700, color: KColors.muted, spacing: 1.2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_tick),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 340),
                curve: kEase,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: _dir == 0 ? Offset(0, 16 * (1 - t)) : Offset(48 * _dir * (1 - t), 0), child: child),
                ),
                // Its own layer: the fade only moves the week, rather than
                // redrawing the whole section every frame.
                child: RepaintBoundary(
                  child: Column(
                    children: [
                      for (var i = 0; i < 7; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        Expanded(
                          child: _DayRow(day: addDays(monday, i), now: now, plan: plan),
                        ),
                      ],
                    ],
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

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.now, required this.plan});

  final DateTime day;
  final DateTime now;
  final Map<String, Meal> plan;

  @override
  Widget build(BuildContext context) {
    final today = sameDay(day, now);
    final rel = daysBetween(now, day);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: today ? KColors.todayBg : Colors.transparent, borderRadius: BorderRadius.circular(26)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    PtDates.abbr[day.weekday - 1],
                    style: KText.s(18, weight: FontWeight.w700, spacing: 1.5, color: today ? KColors.todayInk : KColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: today ? KColors.accent : Colors.transparent, shape: BoxShape.circle),
                    child: Text('${day.day}', style: KText.d(32, color: today ? Colors.white : KColors.ink)),
                  ),
                  if (rel == 0 || rel == 1) ...[
                    const SizedBox(height: 8),
                    Text(
                      rel == 0 ? 'Hoje' : 'Amanhã',
                      style: KText.s(16, weight: FontWeight.w700, color: today ? KColors.todayInk : KColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          for (final t in MealType.values) ...[
            const SizedBox(width: 12),
            Expanded(
              child: _MealCell(day: day, type: t, meal: plan[mealKey(day, t)], today: today),
            ),
          ],
        ],
      ),
    );
  }
}

/// What a long-pressed meal carries while it's being dragged.
class _MealDrag {
  const _MealDrag(this.day, this.type, this.meal);

  final DateTime day;
  final MealType type;
  final Meal meal;
}

String _slotLabel(DateTime day, MealType type) => '${type.label.toLowerCase()} de ${PtDates.weekdays[day.weekday - 1].split('-').first}, ${day.day}';

/// One day/meal slot. Tapping plans or edits it; long-pressing a planned
/// meal picks it up, and dropping it on another slot copies it there (the
/// original stays) — with "Desfazer" on the toast in case it replaced
/// something.
class _MealCell extends ConsumerWidget {
  const _MealCell({required this.day, required this.type, required this.meal, required this.today});

  final DateTime day;
  final MealType type;
  final Meal? meal;
  final bool today;

  bool _isSelf(_MealDrag d) => sameDay(d.day, day) && d.type == type;

  Future<void> _copy(WidgetRef ref, _MealDrag d) async {
    final notifier = ref.read(mealPlanProvider.notifier);
    final previous = meal;
    final copy = Meal(dish: d.meal.dish, place: d.meal.place, time: d.type == type ? d.meal.time : PtDates.minutes(type.defaultMinutes), note: d.meal.note);
    try {
      await notifier.put(day, type, copy);
      KToast.show(
        '${d.meal.dish} copiado para o ${_slotLabel(day, type)}',
        actionLabel: 'Desfazer',
        onAction: () => notifier.put(day, type, previous).catchError(KToast.error),
      );
    } catch (e) {
      KToast.error(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = meal;
    void open() => showMealModal(context, day: day, type: type);
    return DragTarget<_MealDrag>(
      onWillAcceptWithDetails: (details) => !_isSelf(details.data),
      onAcceptWithDetails: (details) => _copy(ref, details.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final Widget cell = m == null
            ? KPress(
                onTap: open,
                child: KDashedBox(
                  color: hovering ? KColors.accent : KColors.dashed,
                  width: hovering ? 3 : 2,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KIcon(hovering ? KIcons.check : KIcons.plus, size: 26, color: hovering ? KColors.accent : KColors.muted, stroke: 2.2),
                        const SizedBox(width: 8),
                        Text(
                          hovering ? 'Copiar para aqui' : 'Planear',
                          style: KText.s(21, weight: FontWeight.w600, color: hovering ? KColors.accent : KColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, box) {
                  final card = _MealCard(meal: m, today: today, highlight: hovering);
                  return LongPressDraggable<_MealDrag>(
                    data: _MealDrag(day, type, m),
                    delay: const Duration(milliseconds: 400),
                    feedback: SizedBox(
                      width: box.maxWidth,
                      height: box.maxHeight,
                      child: Transform.scale(
                        scale: 1.04,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [BoxShadow(color: Color(0x4017191C), blurRadius: 30, offset: Offset(0, 12))],
                          ),
                          child: _MealCard(meal: m, today: true, highlight: false),
                        ),
                      ),
                    ),
                    // Copy, not move: the original stays put, just dimmed
                    // while its copy is being carried.
                    childWhenDragging: Opacity(opacity: 0.45, child: card),
                    child: KPress(onTap: open, child: card),
                  );
                },
              );
        return cell;
      },
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, required this.today, required this.highlight});

  final Meal meal;
  final bool today;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final m = meal;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: today ? Colors.white : KColors.sub,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: highlight ? KColors.accent : Colors.transparent, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              m.dish,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KText.s(24, weight: FontWeight.w600, height: 1.25),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: _placeDot[m.place], shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.time + (m.place != MealPlace.casa ? ' · ${m.place.label}' : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.s(18, color: KColors.muted),
                ),
              ),
            ],
          ),
          if (m.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            // The note, so "descongelar de manhã" is seen without opening
            // the meal (design update).
            Flexible(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: KIcon(KIcons.note, size: 16, color: KColors.amberInk, stroke: 2),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KText.s(16, color: KColors.amberInk, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
