import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/causes/models/organisation.dart';
import '../../../features/causes/presentation/organisation_detail_page.dart';
import '../../../l10n/app_localizations.dart';
import '../models/city_content.dart';
import '../providers/city_providers.dart';

class CityContentDetailPage extends ConsumerWidget {
  const CityContentDetailPage({
    super.key,
    required this.kind,
    required this.contentId,
    required this.cityName,
  });

  final String kind;
  final String contentId;
  final String cityName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final query = (kind: kind, id: contentId);
    final detail = ref.watch(cityContentDetailProvider(query));
    final organisations = ref.watch(cityOrganisationsProvider(languageCode));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityDetailTitle)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _DetailErrorState(
          message: l10n.communityContentLoadError,
          retryLabel: l10n.retry,
          onRetry: () => ref.invalidate(cityContentDetailProvider(query)),
        ),
        data: (item) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(cityContentDetailProvider(query));
            ref.invalidate(cityOrganisationsProvider(languageCode));
            await ref.read(cityContentDetailProvider(query).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Row(
                children: [
                  Icon(
                    kind == 'activities'
                        ? Icons.event_available_rounded
                        : Icons.emoji_events_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cityName,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (item.displayDate != null)
                    Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(item.displayDate!.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(item.description, style: Theme.of(context).textTheme.bodyLarge),
              if (item.endsAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.communityActivityUntil(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(item.endsAt!.toLocal()),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (item.organisationIds.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  l10n.communityAffiliatedOrganisations,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                organisations.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Row(
                    children: [
                      Expanded(child: Text(l10n.communityAffiliateLoadError)),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(cityOrganisationsProvider(languageCode)),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                  data: (items) {
                    final linked = items
                        .where((organisation) =>
                            item.organisationIds.contains(organisation.id))
                        .toList(growable: false);
                    if (linked.isEmpty) {
                      return Text(l10n.communityNoAffiliates);
                    }
                    return Column(
                      children: [
                        for (final organisation in linked)
                          Card(
                            child: ListTile(
                              leading: _OrganisationAvatar(organisation: organisation),
                              title: Text(organisation.name),
                              subtitle: organisation.city?.isNotEmpty == true
                                  ? Text(organisation.city!)
                                  : null,
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OrganisationDetailPage(
                                    organisation: organisation,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganisationAvatar extends StatelessWidget {
  const _OrganisationAvatar({required this.organisation});

  final Organisation organisation;

  @override
  Widget build(BuildContext context) {
    final logo = organisation.logoUrl;
    if (logo == null || logo.trim().isEmpty) {
      return const CircleAvatar(child: Icon(Icons.account_balance_rounded));
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(logo),
      onBackgroundImageError: (_, _) {},
      child: const SizedBox.shrink(),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ),
        ),
      );
}
