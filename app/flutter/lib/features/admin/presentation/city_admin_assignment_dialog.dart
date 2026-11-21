import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/community/providers/city_providers.dart';
import '../../../l10n/app_localizations.dart';

class CityAdminAssignmentDialog extends ConsumerStatefulWidget {
  const CityAdminAssignmentDialog({
    super.key,
    required this.userLabel,
    this.initialCityIds = const [],
  });

  final String userLabel;
  final List<String> initialCityIds;

  @override
  ConsumerState<CityAdminAssignmentDialog> createState() =>
      _CityAdminAssignmentDialogState();
}

class _CityAdminAssignmentDialogState
    extends ConsumerState<CityAdminAssignmentDialog> {
  late final Set<String> _selectedCityIds = widget.initialCityIds.toSet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final cities = ref.watch(cityCatalogueProvider(languageCode));
    final availableCityIds = cities.maybeWhen(
      data: (items) => items.map((city) => city.id).toSet(),
      orElse: () => <String>{},
    );
    final selectedCityIds = _selectedCityIds.intersection(availableCityIds).toList()..sort();

    return AlertDialog(
      title: Text(l10n.adminAssignCityAdmin),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.adminCityAssignmentFor(widget.userLabel)),
            const SizedBox(height: 8),
            Expanded(
              child: cities.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Text(l10n.communityCityCatalogueError),
                ),
                data: (items) => ListView(
                  children: [
                    for (final city in items)
                      CheckboxListTile(
                        key: ValueKey('city_assignment_${city.id}'),
                        value: _selectedCityIds.contains(city.id),
                        title: Text(city.name),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (selected) => setState(() {
                          if (selected == true) {
                            _selectedCityIds.add(city.id);
                          } else {
                            _selectedCityIds.remove(city.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: selectedCityIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(selectedCityIds),
          child: Text(l10n.adminCityAssignmentSave),
        ),
      ],
    );
  }
}
