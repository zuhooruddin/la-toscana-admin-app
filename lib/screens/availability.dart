import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/media.dart';
import '../core/theme.dart';
import '../models.dart';
import '../session.dart';
import 'auth.dart';
import 'branches.dart';

/// Mark dishes sold out for today (staff may do this; turning dishes on/off for good is done in the web dashboard).
class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({super.key});
  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  List<AvailabilityRow>? _rows;
  List<MenuCategory> _categories = const [];
  Object? _error;
  String _q = '';
  String? _loadedFor;

  Future<void> _load(String branchId) async {
    final lang = context.read<Session>().lang;
    try {
      final r = await context.read<Session>().api.get<Map<String, dynamic>>('/api/v1/admin/branches/$branchId/menu');
      final rows = (r['items'] as List).map((x) => AvailabilityRow.fromJson((x as Map).cast<String, dynamic>(), lang)).where((x) => x.available).toList();
      final used = rows.map((x) => x.categoryKey).toSet();
      final cats = (r['categories'] as List? ?? const []).map((c) => MenuCategory.fromJson((c as Map).cast<String, dynamic>(), lang)).where((c) => used.contains(c.key)).toList();
      if (mounted) setState(() => (_rows = rows, _categories = cats, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggle(String branchId, AvailabilityRow row) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = S.of(context);
    final next = !row.soldOut;
    setState(() => row.soldOut = next);
    try {
      await context.read<Session>().api.patch('/api/v1/admin/branches/$branchId/menu/${row.itemId}', body: {'soldOut': next});
      messenger.showSnackBar(SnackBar(content: Text(t.t(next ? 'nowSoldOut' : 'nowAvailable', {'name': row.name}))));
    } catch (e) {
      setState(() => row.soldOut = !next);
      messenger.showSnackBar(SnackBar(content: Text(t.error(e)), backgroundColor: Brand.tomatoDark));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final t = S.of(context);
    final branchId = s.branchId;
    if (branchId == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Text(t.t('chooseRestaurant'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        Expanded(child: BranchList(allowAll: false, selected: null, onPick: s.selectBranch)),
      ]);
    }
    final key = '$branchId|${s.lang}';
    if (_loadedFor != key) {
      _loadedFor = key;
      _rows = null;
      _load(branchId);
    }
    final q = _q.toLowerCase();
    final rows = (_rows ?? const <AvailabilityRow>[]).where((r) => q.isEmpty || r.name.toLowerCase().contains(q)).toList();
    // Categories without names (older API) fall back to one list.
    final tabs = <(String?, String)>[(null, t.t('allCategories')), for (final c in _categories) (c.key, c.name)];
    return DefaultTabController(
      key: ValueKey('$key|${tabs.length}'),
      length: tabs.length,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: t.t('searchDishOrDrink'), isDense: true),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        if (tabs.length > 1) TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final c in tabs) Tab(text: c.$2)]),
        if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(errorText(context, _error!), style: const TextStyle(color: Brand.tomatoDark))),
        Expanded(
          child: _rows == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: [
                  for (final c in tabs)
                    RefreshIndicator(
                      onRefresh: () => _load(branchId),
                      child: Builder(builder: (context) {
                        final list = c.$1 == null ? rows : rows.where((r) => r.categoryKey == c.$1).toList();
                        if (list.isEmpty) return ListView(children: [const SizedBox(height: 100), Center(child: Text(t.t('noDishes'), style: const TextStyle(color: Brand.muted)))]);
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 82, color: Color(0x14000000)),
                          itemBuilder: (context, i) => _Row(row: list[i], lang: t.lang, onToggle: () => _toggle(branchId, list[i])),
                        );
                      }),
                    ),
                ]),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.lang, required this.onToggle});
  final AvailabilityRow row;
  final String lang;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Opacity(opacity: row.soldOut ? 0.45 : 1, child: Photo(row.imageUrl, size: 52, radius: 12)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (row.priceCents > 0) Text(eur(row.priceCents, lang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(t.t(row.soldOut ? 'soldOut' : 'available'),
                  style: TextStyle(color: row.soldOut ? Brand.tomatoDark : Brand.basil, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ]),
          ),
          Switch(value: !row.soldOut, onChanged: (_) => onToggle()),
        ]),
      ),
    );
  }
}
