import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/media.dart';
import '../core/theme.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';

/// Full-screen restaurant switcher: search, photo cards, confirm.
class BranchPickerPage extends StatefulWidget {
  const BranchPickerPage({super.key, this.allowAll = true});
  final bool allowAll;
  @override
  State<BranchPickerPage> createState() => _BranchPickerPageState();
}

class _BranchPickerPageState extends State<BranchPickerPage> {
  late String? _picked = context.read<Session>().branchId;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('chooseRestaurant'), style: const TextStyle(fontWeight: FontWeight.w800)), centerTitle: true),
      body: BranchList(allowAll: widget.allowAll, selected: _picked, onPick: (id) => setState(() => _picked = id)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: () {
            context.read<Session>().selectBranch(_picked);
            Navigator.pop(context);
          },
          child: Text(t.t('selectRestaurant')),
        ),
      ),
    );
  }
}

/// Searchable list of the user's restaurants with photo, address and online-ordering state.
class BranchList extends StatefulWidget {
  const BranchList({super.key, required this.selected, required this.onPick, this.allowAll = true});
  final String? selected;
  final ValueChanged<String?> onPick;
  final bool allowAll;
  @override
  State<BranchList> createState() => _BranchListState();
}

class _BranchListState extends State<BranchList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final t = S.of(context);
    final q = _q.toLowerCase();
    final branches = s.branches.where((b) => q.isEmpty || b.name.toLowerCase().contains(q) || b.address.toLowerCase().contains(q)).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
      TextField(
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: t.t('searchRestaurant'), isDense: true),
        onChanged: (v) => setState(() => _q = v),
      ),
      const SizedBox(height: 12),
      if (widget.allowAll && s.branches.length > 1 && q.isEmpty)
        _Row(
          selected: widget.selected == null,
          onTap: () => widget.onPick(null),
          leading: const Photo(null, size: 58, icon: Icons.store_mall_directory_outlined),
          title: t.t('allRestaurants'),
          subtitle: t.t('allRestaurantsBody'),
          status: Text(t.t('restaurantsCount', {'n': s.branches.length}), style: const TextStyle(fontSize: 12.5, color: Brand.muted)),
        ),
      for (final b in branches)
        _Row(
          selected: widget.selected == b.id,
          onTap: () => widget.onPick(b.id),
          leading: Photo(b.imageUrl, size: 58, icon: Icons.storefront),
          title: b.name,
          subtitle: b.address,
          status: _OrderingState(b),
        ),
    ]);
  }
}

class _OrderingState extends StatelessWidget {
  const _OrderingState(this.b);
  final StaffBranch b;
  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final (color, label) = !b.enabled
        ? (Brand.amber, t.t('orderingSoon'))
        : b.isPaused
            ? (Brand.orange, t.t('orderingPaused'))
            : (Brand.basil, t.t('orderingOn'));
    final services = [if (b.pickup) t.t('pickup'), if (b.delivery) t.t('delivery')].join('/');
    return Row(children: [
      Icon(Icons.circle, size: 9, color: color),
      const SizedBox(width: 5),
      Flexible(
        child: Text(b.enabled && services.isNotEmpty ? '$label · $services' : label,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.selected, required this.onTap, required this.leading, required this.title, required this.subtitle, required this.status});
  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget status;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          onTap: onTap,
          padding: const EdgeInsets.all(10),
          border: selected ? Brand.tomato : null,
          color: selected ? const Color(0xFFFFF7F6) : Colors.white,
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 13)),
                const SizedBox(height: 3),
                status,
              ]),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? Brand.tomato : Brand.border),
          ]),
        ),
      );
}
