import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_settings_menu.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/admin_causes_providers.dart';

class CityContentPage extends ConsumerStatefulWidget {
  const CityContentPage({super.key, required this.kind});
  final String kind;

  @override
  ConsumerState<CityContentPage> createState() => _CityContentPageState();
}

class _CityContentPageState extends ConsumerState<CityContentPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  bool get _isActivity => widget.kind == 'activities';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = ref.read(authProvider).user;
      final cityId = user?.isCityAdmin == true && user!.cityIds.length == 1
          ? user.cityIds.single : null;
      final items = await ref.read(adminApiClientProvider)
          .getAdminCityContent(widget.kind, cityId: cityId);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error; _loading = false; });
    }
  }

  Future<void> _create([Map<String, dynamic>? existing]) async {
    final user = ref.read(authProvider).user;
    final title = TextEditingController(text: existing?['title'] as String? ?? '');
    final description = TextEditingController(text: existing?['description'] as String? ?? '');
    final city = TextEditingController(text: existing?['cityId'] as String? ?? (user?.isCityAdmin == true && user!.cityIds.length == 1 ? user.cityIds.single : ''));
    final date = TextEditingController(text: (existing?[_isActivity ? 'startsAt' : 'achievedAt'] as String?) ?? '');
    final endDate = TextEditingController(text: existing?['endsAt'] as String? ?? '');
    final affiliates = TextEditingController(text: ((existing?['organisationIds'] as List<dynamic>?) ?? const []).join(', '));
    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context)!;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? (_isActivity ? l10n.adminActivities : l10n.adminAccomplishments) : l10n.cityContentEdit),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(controller: title, decoration: InputDecoration(labelText: l10n.cityContentTitle), validator: (v) => v == null || v.trim().isEmpty ? l10n.fieldRequired(l10n.cityContentTitle) : null),
                TextFormField(controller: description, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: l10n.cityContentDescription), validator: (v) => v == null || v.trim().isEmpty ? l10n.fieldRequired(l10n.cityContentDescription) : null),
                if (existing == null && user?.isCityAdmin != true)
                  TextFormField(controller: city, decoration: InputDecoration(labelText: l10n.cityContentCity), validator: (v) => v == null || v.trim().isEmpty ? l10n.fieldRequired(l10n.cityContentCity) : null),
                if (existing == null && user?.isCityAdmin == true && user!.cityIds.length > 1)
                  DropdownButtonFormField<String>(
                    value: null,
                    decoration: InputDecoration(labelText: l10n.cityContentCity),
                    items: user.cityIds.map((id) => DropdownMenuItem(value: id, child: Text(id))).toList(),
                    onChanged: (value) => city.text = value ?? '',
                    validator: (value) => city.text.isEmpty && value == null ? l10n.fieldRequired(l10n.cityContentCity) : null,
                  ),
                TextFormField(controller: date, decoration: InputDecoration(labelText: _isActivity ? l10n.cityContentStartDate : l10n.cityContentAchievedAt), validator: (v) => DateTime.tryParse(v ?? '') == null ? l10n.cityContentInvalidDate : null),
                if (_isActivity)
                  TextFormField(controller: endDate, decoration: InputDecoration(labelText: l10n.cityContentEndDate), validator: (v) => v == null || v.trim().isEmpty || DateTime.tryParse(v) != null ? null : l10n.cityContentInvalidDate),
                TextFormField(controller: affiliates, decoration: InputDecoration(labelText: l10n.cityContentAffiliates, helperText: l10n.cityContentAffiliatesHint)),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.close)),
          FilledButton(onPressed: () {
            if (!formKey.currentState!.validate()) return;
            final selectedCity = city.text.trim();
            final selectedDate = DateTime.parse(date.text.trim()).toUtc().toIso8601String();
            final ids = affiliates.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
            Navigator.pop(dialogContext, {
              'title': title.text.trim(), 'description': description.text.trim(),
              if (existing == null) 'cityId': selectedCity,
              if (_isActivity) 'startsAt': selectedDate else 'achievedAt': selectedDate,
              if (_isActivity && endDate.text.trim().isNotEmpty) 'endsAt': DateTime.parse(endDate.text.trim()).toUtc().toIso8601String(),
              'organisationIds': ids,
            });
          }, child: Text(l10n.cityContentSave)),
        ],
      ),
    );
    title.dispose();
    description.dispose();
    city.dispose();
    date.dispose();
    endDate.dispose();
    affiliates.dispose();
    if (payload == null || !mounted) return;
    setState(() => _saving = true);
    try {
      if (existing == null) {
        await ref.read(adminApiClientProvider).createAdminCityContent(widget.kind, payload);
      } else {
        await ref.read(adminApiClientProvider).updateAdminCityContent(widget.kind, existing['id'] as String, payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cityContentSaved)));
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.cityContentSaveFailed}: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish(Map<String, dynamic> item) async {
    try {
      await ref.read(adminApiClientProvider).updateAdminCityContent(widget.kind, item['id'] as String, {'status': 'PUBLISHED'});
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.cityContentSaveFailed}: $error')));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(l10n.cityContentDeleteTitle),
      content: Text(l10n.cityContentDeleteConfirmation(item['title'] as String? ?? '')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.close)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.deleteApplication)),
      ],
    ));
    if (confirm != true) return;
    try {
      await ref.read(adminApiClientProvider).deleteAdminCityContent(widget.kind, item['id'] as String);
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.cityContentSaveFailed}: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _isActivity ? l10n.adminActivities : l10n.adminAccomplishments;
    return AppPageScaffold(
      title: Text(title),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _create,
        icon: const Icon(Icons.add),
        label: Text(l10n.cityContentCreate),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(l10n.cityContentLoadError),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: Text(l10n.retry)),
                ]))
              : _items.isEmpty
                  ? Center(child: Text(l10n.cityContentEmpty))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final status = item['status'] as String? ?? 'DRAFT';
                          return Card(
                            child: ListTile(
                              title: Text(item['title'] as String? ?? ''),
                              subtitle: Text('${item['cityId']} · $status\n${item['description']}'),
                              isThreeLine: true,
                              onTap: () => _create(item),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) => action == 'publish' ? _publish(item) : _delete(item),
                                itemBuilder: (_) => [
                                  if (status != 'PUBLISHED') PopupMenuItem(value: 'publish', child: Text(l10n.cityContentPublish)),
                                  PopupMenuItem(value: 'delete', child: Text(l10n.deleteApplication)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
