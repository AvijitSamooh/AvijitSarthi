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
    final initialCityIds = widget.initialCityIds.toSet().intersection(availableCityIds).toList()..sort();
    final hasChanges = selectedCityIds.join('|') != initialCityIds.join('|');

    final viewportSize = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: viewportSize.height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.all(
            viewportSize.width < 400 || viewportSize.height < 560 ? 16 : 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Text(
                      l10n.adminAssignCityAdmin,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.adminCityAssignmentFor(widget.userLabel)),
                    const SizedBox(height: 8),
                    cities.when(
                      loading: () => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Semantics(
                            container: true,
                            liveRegion: true,
                            label: l10n.adminCityAssignmentLoadingCities,
                            child: const ExcludeSemantics(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                      ),
                      error: (_, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            container: true,
                            liveRegion: true,
                            label: l10n.adminCityAssignmentLoadError,
                            child: ExcludeSemantics(
                              child: Text(l10n.adminCityAssignmentLoadError),
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref.invalidate(
                              cityCatalogueProvider(languageCode),
                            ),
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                      data: (items) => items.isEmpty
                          ? Center(
                              child: Semantics(
                                container: true,
                                liveRegion: true,
                                label: l10n.adminCityAssignmentNoCities,
                                child: ExcludeSemantics(
                                  child: Text(l10n.adminCityAssignmentNoCities),
                                ),
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final city in items)
                                  CheckboxListTile(
                                    key: ValueKey('city_assignment_${city.id}'),
                                    value: _selectedCityIds.contains(city.id),
                                    title: Text(city.name),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
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
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: selectedCityIds.isEmpty || !hasChanges
                        ? null
                        : () => Navigator.of(context).pop(selectedCityIds),
                    child: Text(l10n.adminCityAssignmentSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
