import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../session.dart';
import 'availability.dart';
import 'bookings.dart';
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
    final tabs = <({String label, IconData icon, Widget page})>[
      if (me.can('orders:read')) (label: 'Pedidos', icon: Icons.receipt_long, page: const OrdersPage()),
      if (me.can('menu:availability')) (label: 'Agotados', icon: Icons.toggle_on_outlined, page: const AvailabilityPage()),
      if (me.can('reservations:read')) (label: 'Reservas', icon: Icons.event_seat_outlined, page: const BookingsPage()),
      (label: 'Hoy', icon: Icons.insights_outlined, page: const SummaryPage()),
    ];
    final index = _tab.clamp(0, tabs.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: s.branches.length > 1
            ? DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: s.branchId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos los restaurantes')),
                    for (final b in s.branches) DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: s.selectBranch,
                ),
              )
            : Text(s.branch?.name ?? 'La Toscana'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: s.live ? 'Recibiendo pedidos en directo' : 'Sin conexión en directo',
              child: Icon(Icons.circle, size: 12, color: s.live ? Colors.green : Brand.muted),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') s.logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(me.name ?? me.email)),
              const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: index, children: [for (final t in tabs) t.page]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (tabs[i].label == 'Pedidos') s.clearNewOrders();
        },
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: t.label == 'Pedidos' && s.newOrders > 0 ? Badge(label: Text('${s.newOrders}'), child: Icon(t.icon)) : Icon(t.icon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
