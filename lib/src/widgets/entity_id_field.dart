import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ha_providers.dart';
import '../theme/nocturne_theme.dart';
import 'on_screen_keyboard_controller.dart';

/// A text field for picking a Home Assistant entity id — autocompletes
/// against the live entity list (id and friendly name both searched) as you
/// type, while still accepting anything typed directly (an id that isn't in
/// the current entity snapshot yet, for instance). Wired into the on-screen
/// keyboard the same way `KeyboardTextField` is, since `RawAutocomplete`
/// needs its own field/focus wiring that a generic wrapper can't reach into.
class EntityIdField extends ConsumerStatefulWidget {
  const EntityIdField({
    super.key,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
    this.domainFilter,
  });

  final String label;
  final String hint;
  final String? initialValue;
  final ValueChanged<String> onChanged;

  /// Restricts suggestions to entities of one domain, e.g. `'calendar'` —
  /// unset (the default) searches every entity, as every other settings
  /// field already does.
  final String? domainFilter;

  @override
  ConsumerState<EntityIdField> createState() => _EntityIdFieldState();
}

class _EntityIdFieldState extends ConsumerState<EntityIdField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => widget.onChanged(_controller.text));
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      OnScreenKeyboardController.instance.attach(_controller);
    } else {
      OnScreenKeyboardController.instance.detach(_controller);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entities = ref.watch(entitiesProvider).value ?? const {};
    final allIds = ref.watch(entityIdsProvider(widget.domainFilter));

    return RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (query) {
        final needle = query.text.trim().toLowerCase();
        if (needle.isEmpty) return const Iterable<String>.empty();
        return allIds
            .where((id) => id.toLowerCase().contains(needle) || (entities[id]?.friendlyName.toLowerCase() ?? '').contains(needle))
            .take(30);
      },
      displayStringForOption: (id) => id,
      onSelected: (id) => _controller.text = id,
      fieldViewBuilder: (context, fieldController, fieldFocusNode, onFieldSubmitted) {
        return TextField(
          controller: fieldController,
          focusNode: fieldFocusNode,
          style: const TextStyle(fontSize: 17),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: const TextStyle(fontSize: 16),
            hintText: widget.hint,
            hintStyle: const TextStyle(fontSize: 15),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: const OutlineInputBorder(),
          ),
          // onTapOutside left at its default (unfocus-on-outside-tap on
          // this app's Linux target) so tapping away from the field closes
          // the on-screen keyboard. The keyboard panel is wrapped in a
          // TextFieldTapRegion (see on_screen_keyboard.dart) so a key tap
          // doesn't count as "outside" and drop the keystroke; the options
          // dropdown below is already wrapped in one too by RawAutocomplete
          // itself, so picking a suggestion doesn't blur the field either.
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final matches = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: NocturneColors.surface,
            borderRadius: BorderRadius.circular(NocturneRadii.chip),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 640),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final id = matches[index];
                  final friendly = entities[id]?.friendlyName;
                  return ListTile(
                    title: Text(id, style: const TextStyle(fontSize: 16)),
                    subtitle: friendly == null ? null : Text(friendly, style: const TextStyle(fontSize: 14)),
                    onTap: () => onSelected(id),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
