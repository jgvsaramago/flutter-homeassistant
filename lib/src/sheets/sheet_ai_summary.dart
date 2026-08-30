import 'package:flutter/material.dart';

import '../theme/nocturne_theme.dart';

/// One text+timing row inside [SheetAiSummary]'s suggestions panel.
class SheetAiSuggestion {
  const SheetAiSuggestion({required this.text, required this.timing});
  final String text;
  final String timing;
}

/// The accent-outlined "about today" callout at the top of a sheet: a
/// sparkle-headed summary with an optional nested suggestions panel.
///
/// This app has no AI/LLM integration yet — [body]/[suggestions] are
/// caller-supplied static copy for now (the same treatment the energy
/// card gives its un-wired appliance readings), not generated content.
class SheetAiSummary extends StatelessWidget {
  const SheetAiSummary({super.key, required this.title, required this.body, this.suggestionsTitle, this.suggestions = const []});

  final String title;
  final String body;
  final String? suggestionsTitle;
  final List<SheetAiSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      padding: NocturneSpacing.cardPadding,
      decoration: BoxDecoration(
        color: NocturneColors.accent.withValues(alpha: 0.09),
        border: Border.all(color: NocturneColors.accent.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(NocturneRadii.primaryCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 22, color: NocturneColors.accent),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, decoration: TextDecoration.none, color: NocturneColors.text))),
            ],
          ),
          const SizedBox(height: 14),
          Text(body, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.normal, decoration: TextDecoration.none, height: 1.5, color: NocturneColors.text)),
          if (suggestionsTitle != null && suggestions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(color: NocturneColors.bg.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestionsTitle!.toUpperCase(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none, letterSpacing: 1.8, color: NocturneColors.neutral400),
                  ),
                  for (final suggestion in suggestions)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              suggestion.text,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.normal, decoration: TextDecoration.none, color: NocturneColors.text),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            suggestion.timing,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, decoration: TextDecoration.none, color: NocturneColors.neutral400),
                            textAlign: TextAlign.right,
                          ),
                        ],
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
