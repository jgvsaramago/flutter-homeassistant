import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/on_screen_keyboard_controller.dart';
import '../data/meals_data.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';

Future<void> showMealModal(BuildContext context, {required DateTime day, required MealType type}) =>
    showKModal(context, (_) => MealModal(day: day, type: type));

/// Plan or edit one meal (the design's "Modal de refeição"): the dish
/// (typed or picked from favourites), where, when, and a note. Opened from
/// the Refeições grid and from Início's "Refeições" card.
class MealModal extends ConsumerStatefulWidget {
  const MealModal({super.key, required this.day, required this.type});

  final DateTime day;
  final MealType type;

  @override
  ConsumerState<MealModal> createState() => _MealModalState();
}

class _MealModalState extends ConsumerState<MealModal> {
  late final Meal? _existing = ref.read(mealPlanProvider)[mealKey(widget.day, widget.type)];
  late final _dish = TextEditingController(text: _existing?.dish ?? '');
  late final _note = TextEditingController(text: _existing?.note ?? '');
  final _dishFocus = FocusNode();
  final _noteFocus = FocusNode();
  late MealPlace _place = _existing?.place ?? MealPlace.casa;
  late int _time = _existing == null ? widget.type.defaultMinutes : PtDates.toMinutes(_existing.time);

  @override
  void initState() {
    super.initState();
    _dish.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dish.dispose();
    _note.dispose();
    _dishFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _put(Meal? meal) async {
    try {
      OnScreenKeyboardController.instance.close();
      Navigator.of(context).pop();
      await ref.read(mealPlanProvider.notifier).put(widget.day, widget.type, meal);
    } catch (e) {
      KToast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = mealFavorites(ref.watch(mealPlanProvider), widget.type);
    final hasDish = _dish.text.trim().isNotEmpty;
    return KModal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KModalHeader(title: widget.type.label, subtitle: PtDates.cap(PtDates.longLower(widget.day))),
          const SizedBox(height: 24),
          const KFieldLabel('PRATO'),
          const SizedBox(height: 12),
          KTextField(
            controller: _dish,
            focusNode: _dishFocus,
            hint: 'Ex.: Sopa de legumes',
            autofocus: _existing == null,
            options: KeyboardOptions(
              suggestions: (t) {
                final q = t.trim().toLowerCase();
                return q.isEmpty ? const [] : favorites.where((f) => f.toLowerCase().startsWith(q) && f != t).toList();
              },
              doneLabel: 'Seguinte',
              onDone: () => _noteFocus.requestFocus(),
              onSuggest: (s) {
                _dish.text = s;
                _noteFocus.requestFocus();
              },
            ),
          ),
          const SizedBox(height: 24),
          const KFieldLabel('FAVORITOS'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final f in favorites)
                KChip(
                  label: f,
                  on: _dish.text == f,
                  padX: 26,
                  onTap: () {
                    _dish.text = f;
                    OnScreenKeyboardController.instance.close();
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KFieldLabel('ONDE'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [for (final p in MealPlace.values) KChip(label: p.label, on: _place == p, padX: 26, onTap: () => setState(() => _place = p))],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KFieldLabel('HORA'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 8, 10, 8),
                      decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(26)),
                      child: Row(
                        children: [
                          Expanded(child: Text(PtDates.minutes(_time), style: KText.d(40))),
                          KStepButton(plus: false, onTap: () => setState(() => _time = (_time - 15).clamp(0, 23 * 60 + 45))),
                          const SizedBox(width: 10),
                          KStepButton(plus: true, onTap: () => setState(() => _time = (_time + 15).clamp(0, 23 * 60 + 45))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const KFieldLabel('NOTAS', optional: true),
          const SizedBox(height: 12),
          KTextField(controller: _note, focusNode: _noteFocus, hint: 'Ex.: descongelar de manhã', height: 80, fontSize: 24),
          const SizedBox(height: 24),
          KModalFooter(
            saveLabel: 'Guardar',
            canSave: hasDish,
            deleteLabel: 'Remover',
            onDelete: _existing == null ? null : () => _put(null),
            onSave: () => _put(Meal(dish: _dish.text.trim(), place: _place, time: PtDates.minutes(_time), note: _note.text.trim())),
          ),
        ],
      ),
    );
  }
}
