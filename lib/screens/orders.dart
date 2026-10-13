import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models.dart';
import '../session.dart';
import 'auth.dart';

const _columns = [('confirmed', 'Nuevos'), ('preparing', 'Preparando'), ('ready', 'Listos'), ('out_for_delivery', 'Reparto')];

/// Live kitchen board: updates on every order event, plus a 30 s resync.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<StaffOrder>? _orders;
  Object? _error;
  StreamSubscription<String>? _sub;
  Timer? _timer;
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    // Order events, plus a resync after every (re)connection so nothing missed while offline is lost.
    _sub = s.events.where((e) => e.startsWith('order.') || e == 'resync').listen((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = context.read<Session>();
    try {
      final r = await s.api.get<Map<String, dynamic>>('/api/v1/admin/orders', query: {'active': 'true', 'branchId': s.branchId, 'pageSize': 100});
      final list = (r['items'] as List).map((o) => StaffOrder.fromJson((o as Map).cast<String, dynamic>())).toList()
        ..sort((a, b) => (a.scheduledFor ?? a.createdAt).compareTo(b.scheduledFor ?? b.createdAt));
      if (mounted) setState(() => (_orders = list, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    if (_loadedFor != (s.branchId ?? 'all')) {
      _loadedFor = s.branchId ?? 'all';
      _load();
    }
    final orders = _orders;
    return DefaultTabController(
      length: _columns.length,
      child: Column(children: [
        TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
          for (final c in _columns) Tab(text: '${c.$2} (${orders?.where((o) => o.status == c.$1).length ?? 0})'),
        ]),
        if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(errorText(_error!), style: const TextStyle(color: Brand.tomatoDark))),
        Expanded(
          child: orders == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: [
                  for (final c in _columns)
                    RefreshIndicator(
                      onRefresh: _load,
                      child: Builder(builder: (context) {
                        final list = orders.where((o) => o.status == c.$1).toList();
                        if (list.isEmpty) return ListView(children: const [SizedBox(height: 120), Center(child: Text('Sin pedidos', style: TextStyle(color: Brand.muted)))]);
                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _Ticket(order: list[i], onChanged: _load),
                        );
                      }),
                    ),
                ]),
        ),
      ]),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({required this.order, required this.onChanged});
  final StaffOrder order;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final me = context.read<Session>().me!;
    final age = DateTime.now().difference(o.createdAt).inMinutes;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => OrderSheet(order: o, onChanged: onChanged)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(o.number, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              Text(o.scheduledFor != null ? '⏰ ${hhmm(o.scheduledFor!)}' : 'hace $age min', style: TextStyle(color: age > 20 && o.scheduledFor == null ? Brand.tomatoDark : Brand.muted, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              Chip(label: Text(o.type == 'delivery' ? 'Reparto' : 'Recogida'), visualDensity: VisualDensity.compact),
              Chip(label: Text('${o.paymentMethod == 'cash' ? 'Efectivo' : 'Tarjeta'}${o.simulated ? ' (simulado)' : ''}'), visualDensity: VisualDensity.compact),
              if (o.branchName.isNotEmpty) Chip(label: Text(o.branchName.replaceFirst('La Toscana ', '')), visualDensity: VisualDensity.compact),
            ]),
            for (final l in o.lines.take(5)) Text('${l.quantity}× ${l.name}${l.options.isNotEmpty ? ' (${l.options.join(', ')})' : ''}', style: const TextStyle(fontSize: 14)),
            if (o.lines.length > 5) Text('+${o.lines.length - 5} más…', style: const TextStyle(color: Brand.muted)),
            if (o.notes != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('📝 ${o.notes}', style: const TextStyle(color: Color(0xFF7A4500)))),
            const SizedBox(height: 8),
            Row(children: [
              Text(eur(o.totalCents), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              if (o.next != null && me.can('orders:update')) FilledButton(onPressed: () => advance(context, o, o.next!, onChanged), child: Text(actionLabel[o.next] ?? o.next!)),
            ]),
          ]),
        ),
      ),
    );
  }
}

Future<void> advance(BuildContext context, StaffOrder o, String to, VoidCallback onChanged, {String? note}) async {
  final api = context.read<Session>().api;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await api.post('/api/v1/admin/orders/${o.id}/status', body: {'status': to, 'note': ?note});
    messenger.showSnackBar(SnackBar(content: Text('${o.number}: ${statusLabel[to]}')));
    onChanged();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(e)), backgroundColor: Brand.tomatoDark));
  }
}

class OrderSheet extends StatelessWidget {
  const OrderSheet({super.key, required this.order, required this.onChanged});
  final StaffOrder order;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final me = context.read<Session>().me!;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
        Text('Pedido ${o.number}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text('${statusLabel[o.status]} · ${o.type == 'delivery' ? 'Reparto a domicilio' : 'Recogida en el local'}', style: const TextStyle(color: Brand.muted)),
        if (o.scheduledFor != null) Text('Programado: ${dateTime(o.scheduledFor!, 'es')}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const Divider(height: 24),
        for (final l in o.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${l.quantity}× ${l.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  if (l.options.isNotEmpty) Text(l.options.join(' · ')),
                  if (l.notes != null) Text('Nota: ${l.notes}', style: const TextStyle(color: Color(0xFF7A4500))),
                  for (final w in l.warnings) Text('⚠ $w', style: const TextStyle(color: Brand.tomatoDark, fontSize: 12)),
                ]),
              ),
              Text(eur(l.lineTotalCents)),
            ]),
          ),
        const Divider(height: 24),
        Row(children: [const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), const Spacer(), Text(eur(o.totalCents), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))]),
        Text('${o.paymentMethod == 'cash' ? 'Efectivo' : 'Tarjeta'} · ${o.paymentStatus}${o.simulated ? ' · pago simulado (pruebas)' : ''}', style: const TextStyle(color: Brand.muted)),
        if (o.notes != null) ...[const SizedBox(height: 10), Text('Comentarios: ${o.notes}', style: const TextStyle(color: Color(0xFF7A4500)))],
        Text('Si se agota: ${ifSoldOutLabel[o.ifSoldOut]}', style: const TextStyle(color: Brand.muted)),
        const Divider(height: 24),
        Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (o.address != null) Text(o.address!),
        if (o.driverName != null) Text('Repartidor: ${o.driverName} (${o.driverState ?? ''})'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (o.customerPhone != null) OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${o.customerPhone!.replaceAll(' ', '')}')), icon: const Icon(Icons.call), label: const Text('Llamar al cliente')),
          if (o.next != null && me.can('orders:update'))
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await advance(context, o, o.next!, onChanged);
              },
              child: Text(actionLabel[o.next] ?? o.next!),
            ),
          if (o.cancellable && me.can('orders:update'))
            TextButton(
              onPressed: () async {
                final reason = await _askReason(context);
                if (reason == null || !context.mounted) return;
                Navigator.pop(context);
                await advance(context, o, 'cancelled', onChanged, note: reason);
              },
              child: const Text('Cancelar pedido', style: TextStyle(color: Brand.tomatoDark)),
            ),
        ]),
      ]),
    );
  }

  Future<String?> _askReason(BuildContext context) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo de la cancelación'),
        content: TextField(controller: c, autofocus: true, maxLength: 300, decoration: const InputDecoration(hintText: 'Producto agotado, el cliente llamó…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Volver')),
          FilledButton(onPressed: () => c.text.trim().length >= 3 ? Navigator.pop(ctx, c.text.trim()) : null, child: const Text('Cancelar pedido')),
        ],
      ),
    );
  }
}
