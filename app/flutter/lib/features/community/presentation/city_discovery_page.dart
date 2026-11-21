import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../models/city_content.dart';
import '../providers/city_providers.dart';
import 'city_content_detail_page.dart';

class CityDiscoveryPage extends ConsumerStatefulWidget {
  const CityDiscoveryPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<CityDiscoveryPage> createState() => _CityDiscoveryPageState();
}

class _CityDiscoveryPageState extends ConsumerState<CityDiscoveryPage> {
  String? _selectedCityId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final cities = ref.watch(cityCatalogueProvider(languageCode));

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab < 0 ? 0 : (widget.initialTab > 1 ? 1 : widget.initialTab),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.communityDiscoveryTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.communityActivitiesTab),
              Tab(text: l10n.communityAccomplishmentsTab),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: cities.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Row(
                  children: [
                    Expanded(child: Text(l10n.communityCityCatalogueError)),
                    TextButton(
                      onPressed: () => ref.invalidate(cityCatalogueProvider(languageCode)),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
                data: (items) => DropdownButtonFormField<String?>(
                  key: const ValueKey('city_filter'),
                  initialValue: _selectedCityId,
                  decoration: InputDecoration(
                    labelText: l10n.communityFilterCity,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.communityAllCities),
                    ),
                    ...items.map(
                      (city) => DropdownMenuItem<String?>(
                        value: city.id,
                        child: Text(city.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedCityId = value),
                ),
              ),
            ),
            Expanded(
              child: cities.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Text(l10n.communityCityCatalogueError),
                ),
                data: (items) {
                  final cityNames = {
                    for (final city in items) city.id: city.name,
                  };
                  return TabBarView(
                    children: [
                      _CityContentList(
                        kind: 'activities',
                        cityId: _selectedCityId,
                        cityNames: cityNames,
                      ),
                      _CityContentList(
                        kind: 'accomplishments',
                        cityId: _selectedCityId,
                        cityNames: cityNames,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityContentList extends ConsumerWidget {
  const _CityContentList({
    required this.kind,
    required this.cityId,
    required this.cityNames,
  });

  final String kind;
  final String? cityId;
  final Map<String, String> cityNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final query = (kind: kind, cityId: cityId);
    final content = ref.watch(cityContentProvider(query));
    final emptyMessage = kind == 'activities'
        ? l10n.communityNoActivities
        : l10n.communityNoAccomplishments;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(cityContentProvider(query).future),
      child: content.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (_, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 12),
            Center(child: Text(l10n.communityContentLoadError)),
            Center(
              child: TextButton(
                onPressed: () => ref.invalidate(cityContentProvider(query)),
                child: Text(l10n.retry),
              ),
            ),
          ],
        ),
        data: (items) => items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Center(child: Icon(
                    kind == 'activities' ? Icons.event_available_rounded : Icons.emoji_events_rounded,
                    size: 44,
                  )),
                  const SizedBox(height: 12),
                  Center(child: Text(emptyMessage)),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _CityContentCard(
                  kind: kind,
                  item: items[index],
                  cityName: cityNames[items[index].cityId] ?? items[index].cityId,
                ),
              ),
      ),
    );
  }
}

class _CityContentCard extends StatelessWidget {
  const _CityContentCard({
    required this.kind,
    required this.item,
    required this.cityName,
  });

  final String kind;
  final CityContent item;
  final String cityName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date = item.displayDate;
    final formattedDate = date == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(date.toLocal());

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CityContentDetailPage(
              kind: kind,
              contentId: item.id,
              cityName: cityName,
            ),
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.startsAt != null
                      ? Icons.event_available_rounded
                      : Icons.emoji_events_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(cityName, style: Theme.of(context).textTheme.labelLarge),
                ),
                if (formattedDate != null)
                  Text(formattedDate, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(item.description),
            if (item.endsAt != null) ...[
              const SizedBox(height: 6),
              Text(
                l10n.communityActivityUntil(
                  MaterialLocalizations.of(context).formatMediumDate(item.endsAt!.toLocal()),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
