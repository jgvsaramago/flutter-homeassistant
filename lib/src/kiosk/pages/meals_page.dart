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
    return KSection(
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
        ],
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

class _MealCell extends StatelessWidget {
  const _MealCell({required this.day, required this.type, required this.meal, required this.today});

  final DateTime day;
  final MealType type;
  final Meal? meal;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final m = meal;
    void open() => showMealModal(context, day: day, type: type);
    if (m == null) {
      return KPress(
        onTap: open,
        child: KDashedBox(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KIcon(KIcons.plus, size: 26, color: KColors.muted, stroke: 2.2),
                const SizedBox(width: 8),
                Text(
                  'Planear',
                  style: KText.s(21, weight: FontWeight.w600, color: KColors.muted),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return KPress(
      onTap: open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: today ? Colors.white : KColors.sub, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                m.dish,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KText.s(24, weight: FontWeight.w600, height: 1.25),
              ),
            ),
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
          ],
        ),
      ),
    );
  }
}
