import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_settings_menu.dart';
import '../../auth/providers/auth_providers.dart';
import '../../causes/models/cause.dart';
import '../../causes/providers/causes_providers.dart';
import '../data/donation_history_repository.dart';
import '../models/donation_history.dart';
import '../providers/donation_history_providers.dart';
import '../../../l10n/app_localizations.dart';

class DonationHistoryPage extends ConsumerWidget {
  const DonationHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.donationHistoryTitle),
        actions: const [AppSettingsMenu()],
      ),
      body: auth.isLoading
          ? const Center(child: CircularProgressIndicator())
          : !auth.isAuthenticated
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 44),
                        const SizedBox(height: 16),
                        Text(
                          l10n.donationHistorySignInPrompt,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
                          icon: const Icon(Icons.login_rounded),
                          label: Text(l10n.donationHistorySignIn),
                        ),
                      ],
                    ),
                  ),
                )
              : ref.watch(myDonationsProvider).when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => _HistoryMessage(
                      message: l10n.donationHistoryLoadError,
                      actionLabel: l10n.donationHistoryRetry,
                      onRetry: () => ref.invalidate(myDonationsProvider),
                    ),
                    data: (donations) => donations.isEmpty
                        ? _HistoryMessage(message: l10n.donationHistoryEmpty)
                        : RefreshIndicator(
                            onRefresh: () => ref.refresh(myDonationsProvider.future),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: donations.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final donation = donations[index];
                                final date = DateFormat.yMMMd(
                                  Localizations.localeOf(context).languageCode,
                                ).format(donation.createdAt);
                                return Card(
                                  child: ListTile(
                                    key: ValueKey('donation_history_${donation.id}'),
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.volunteer_activism_rounded),
                                    ),
                                    title: Text('₹${donation.amount}'),
                                    subtitle: Text(
                                      '${_donationStatusLabel(l10n, donation.status)} · $date',
                                    ),
                                    trailing: const Icon(Icons.chevron_right_rounded),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => DonationDetailPage(donationId: donation.id),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
    );
  }
}

class DonationDetailPage extends ConsumerStatefulWidget {
  const DonationDetailPage({super.key, required this.donationId});

  final String donationId;

  @override
  ConsumerState<DonationDetailPage> createState() => _DonationDetailPageState();
}

class _DonationDetailPageState extends ConsumerState<DonationDetailPage> {
  DonationReceipt? _receipt;
  bool _issuingReceipt = false;

  Future<void> _issueReceipt() async {
    setState(() => _issuingReceipt = true);
    try {
      final language = Localizations.localeOf(context).languageCode;
      final receipt = await ref.read(donationHistoryRepositoryProvider).issueReceipt(
            widget.donationId,
            language,
          );
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _issuingReceipt = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _issuingReceipt = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.donationHistoryReceiptError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final language = Localizations.localeOf(context).languageCode;
    final causesAsync = ref.watch(causesProvider(language));
    final donationAsync = ref.watch(myDonationProvider(widget.donationId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.donationHistoryDetails),
        actions: const [AppSettingsMenu()],
      ),
      body: donationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _HistoryMessage(
          message: l10n.donationHistoryLoadError,
          actionLabel: l10n.donationHistoryRetry,
          onRetry: () => ref.invalidate(myDonationProvider(widget.donationId)),
        ),
        data: (donation) {
          final causeNames = causesAsync.maybeWhen(
            data: (causes) => _causeNames(causes),
            orElse: () => <String, String>{},
          );
          final date = DateFormat.yMMMd(language).format(donation.createdAt);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.donationHistoryAmount),
                      const SizedBox(height: 4),
                      Text(
                        '₹${donation.amount}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Text('${l10n.donationHistoryStatus}: ${_donationStatusLabel(l10n, donation.status)}'),
                      const SizedBox(height: 6),
                      Text('${l10n.donationHistoryDate}: $date'),
                      const SizedBox(height: 6),
                      Text('${l10n.donationHistoryReference}: ${donation.id}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(l10n.donationHistoryAllocation, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (donation.allocations.isEmpty)
                Text(l10n.donationHistoryNoAllocations)
              else
                ...donation.allocations.map((allocation) => Card(
                      child: ListTile(
                        title: Text(causeNames[allocation.causeId] ?? allocation.causeId),
                        trailing: Text('₹${allocation.amount}'),
                      ),
                    )),
              const SizedBox(height: 20),
              if (donation.isSuccessful) ...[
                Text(l10n.donationHistoryReceipt, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (_receipt == null)
                  FilledButton.icon(
                    onPressed: _issuingReceipt ? null : _issueReceipt,
                    icon: _issuingReceipt
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.receipt_long_rounded),
                    label: Text(l10n.donationHistoryGenerateReceipt),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.donationHistoryReceiptIssued),
                          const SizedBox(height: 8),
                          SelectableText(_receipt!.receiptNumber),
                          const SizedBox(height: 6),
                          Text('₹${_receipt!.amount}'),
                          Text('${l10n.donationHistoryReceiptLanguage}: ${_receipt!.language.toUpperCase()}'),
                          Text(DateFormat.yMMMd(language).format(_receipt!.issuedAt)),
                        ],
                      ),
                    ),
                  ),
              ] else
                Text(l10n.donationHistoryReceiptNotAvailable),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.message,
    this.actionLabel,
    this.onRetry,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

Map<String, String> _causeNames(List<Cause> causes) {
  return {
    for (final cause in causes.expand((item) => item.leafCauses)) cause.id: cause.name,
  };
}

String _donationStatusLabel(AppLocalizations l10n, String status) {
  return switch (status.toUpperCase()) {
    'SUCCESS' => l10n.donationStatusSuccessful,
    'FAILED' => l10n.donationStatusFailed,
    'CANCELLED' => l10n.donationStatusCancelled,
    _ => l10n.donationStatusPending,
  };
}
