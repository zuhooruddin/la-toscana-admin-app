import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/media.dart';
import '../core/theme.dart';
import '../session.dart';
import 'availability.dart';
import 'bookings.dart';
import 'branches.dart';
import 'more.dart';
import 'orders.dart';
import 'summary.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final me = s.me!;
    final t = S.of(context);
    final tabs = <({String key, String label, IconData icon, IconData selected, Widget page})>[
      if (me.can('orders:read'))
        (key: 'orders', label: t.t('tabOrders'), icon: Icons.receipt_long_outlined, selected: Icons.receipt_long, page: const OrdersPage()),
      if (me.can('menu:availability'))
        (key: 'soldOut', label: t.t('tabSoldOut'), icon: Icons.room_service_outlined, selected: Icons.room_service, page: const AvailabilityPage()),
      if (me.can('reservations:read'))
        (key: 'bookings', label: t.t('tabBookings'), icon: Icons.event_note_outlined, selected: Icons.event_note, page: const BookingsPage()),
      (key: 'today', label: t.t('tabToday'), icon: Icons.bar_chart_outlined, selected: Icons.bar_chart, page: const SummaryPage()),
    ];
    final index = _tab.clamp(0, tabs.length - 1);
    final ordersIndex = tabs.indexWhere((x) => x.key == 'orders');
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: _Header(
          onBell: ordersIndex < 0
              ? null
              : () {
                  setState(() => _tab = ordersIndex);
                  s.clearNewOrders();
                },
        ),
      ),
      body: IndexedStack(index: index, children: [for (final tab in tabs) tab.page]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        height: 68,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (tabs[i].key == 'orders') s.clearNewOrders();
        },
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: tab.key == 'orders' && s.newOrders > 0 ? Badge(label: Text('${s.newOrders}'), child: Icon(tab.icon)) : Icon(tab.icon),
              selectedIcon: Icon(tab.selected),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

/// Restaurant photo and name (tap to switch), live status and role, new-order bell and the "More" page.
class _Header extends StatelessWidget {
  const _Header({this.onBell});
  final VoidCallback? onBell;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final t = S.of(context);
    final branch = s.branch;
    final photo = branch?.imageUrl ?? s.branches.map((b) => b.imageUrl).whereType<String>().firstOrNull;
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          child: Row(children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: s.branches.length > 1 ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BranchPickerPage())) : null,
                child: Row(children: [
                  Photo(photo, size: 50, radius: 14, icon: Icons.storefront),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        Flexible(
                          child: Text(branch?.name ?? (s.branches.length > 1 ? t.t('allRestaurants') : 'La Toscana'),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        ),
                        if (s.branches.length > 1) const Icon(Icons.keyboard_arrow_down, color: Brand.charcoal),
                      ]),
                      const SizedBox(height: 2),
                      Tooltip(
                        message: t.t(s.live ? 'liveOn' : 'liveOff'),
                        child: Row(children: [
                          Icon(Icons.circle, size: 9, color: s.live ? Brand.basil : Brand.muted),
                          const SizedBox(width: 5),
                          Text('${t.t(s.live ? 'online' : 'offline')} · ${t.t('role.${s.me!.role}')}',
                              style: TextStyle(fontSize: 13, color: s.live ? Brand.basil : Brand.muted, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            if (onBell != null)
              IconButton(
                tooltip: t.t('newOrdersTip'),
                onPressed: onBell,
                icon: Badge(isLabelVisible: s.newOrders > 0, label: Text('${s.newOrders}'), child: const Icon(Icons.notifications_none_rounded, size: 28)),
              ),
            IconButton(
              tooltip: t.t('more'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MorePage())),
              icon: const Icon(Icons.more_vert),
            ),
          ]),
        ),
      ),
    );
  }
}
