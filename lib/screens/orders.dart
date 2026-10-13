import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/media.dart';
import '../core/theme.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'auth.dart';

const _columns = [('confirmed', 'colNew'), ('preparing', 'colPreparing'), ('ready', 'colReady'), ('out_for_delivery', 'colDelivery')];

const _note = Color(0xFF8A5300);

IconData actionIcon(String to) => switch (to) {
      'preparing' => Icons.soup_kitchen,
      'ready' => Icons.check_circle,
      'out_for_delivery' => Icons.delivery_dining,
      'picked_up' => Icons.shopping_bag,
      'delivered' => Icons.done_all,
      _ => Icons.arrow_forward,
    };

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
  String _q = '';
  String? _type; // null = pickup and delivery

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

  bool _matches(StaffOrder o) {
    if (_type != null && o.type != _type) return false;
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    return o.number.toLowerCase().contains(q) || o.customerName.toLowerCase().contains(q) || o.lines.any((l) => l.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final t = S.of(context);
    if (_loadedFor != (s.branchId ?? 'all')) {
      _loadedFor = s.branchId ?? 'all';
      _load();
    }
    final orders = _orders;
    final visible = orders?.where(_matches).toList();
    return DefaultTabController(
      length: _columns.length,
      child: Column(children: [
        Material(
          color: Colors.white,
          child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            for (final c in _columns) Tab(text: '${t.t(c.$2)} (${orders?.where((o) => o.status == c.$1).length ?? 0})'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: t.t('searchOrder'), isDense: true),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: t.t('filter'),
              onSelected: (v) => setState(() => _type = v == 'all' ? null : v),
              itemBuilder: (_) => [
                for (final (v, label) in [('all', t.t('filterAll')), ('pickup', t.t('pickup')), ('delivery', t.t('delivery'))])
                  CheckedPopupMenuItem(value: v, checked: (_type ?? 'all') == v, child: Text(label)),
              ],
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _type == null ? Colors.white : Brand.tomato.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _type == null ? Brand.border : Brand.tomato),
                ),
                child: Icon(Icons.tune, color: _type == null ? Brand.charcoal : Brand.tomato),
              ),
            ),
          ]),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(errorText(context, _error!), style: const TextStyle(color: Brand.tomatoDark))),
        Expanded(
          child: visible == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: [
                  for (final c in _columns)
                    RefreshIndicator(
                      onRefresh: _load,
                      child: Builder(builder: (context) {
                        final list = visible.where((o) => o.status == c.$1).toList();
                        if (list.isEmpty) {
                          final filtered = orders!.any((o) => o.status == c.$1);
                          return ListView(children: [
                            EmptyState(
                              icon: filtered ? Icons.search_off : Icons.receipt_long_outlined,
                              title: filtered ? t.t('noMatches') : t.t('noOrders'),
                              body: filtered ? null : t.t('noOrdersBody'),
                            ),
                          ]);
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => OrderCard(order: list[i], onChanged: _load),
                        );
                      }),
                    ),
                ]),
        ),
      ]),
    );
  }
}

/// Chips shared by the card and the detail page: fulfilment, payment, restaurant.
List<Widget> orderChips(S t, StaffOrder o) => [
      o.type == 'delivery'
          ? TintChip(t.t('delivery'), icon: Icons.delivery_dining, color: Brand.tomato)
          : TintChip(t.t('pickup'), icon: Icons.shopping_bag_outlined, color: Brand.tomato),
      o.paymentMethod == 'cash'
          ? TintChip(t.t('cash'), icon: Icons.payments_outlined, color: Brand.basil)
          : TintChip('${t.t('card')}${o.simulated ? t.t('simulated') : ''}', icon: Icons.credit_card, color: Brand.blue),
      if (o.branchName.isNotEmpty) TintChip(o.branchName.replaceFirst('La Toscana ', ''), icon: Icons.place_outlined, color: Brand.muted),
    ];

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onChanged});
  final StaffOrder order;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final me = context.read<Session>().me!;
    final t = S.of(context);
    final age = DateTime.now().difference(o.createdAt).inMinutes;
    final late = age > 20 && o.scheduledFor == null;
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailPage(order: o, onChanged: onChanged)));
    return Panel(
      onTap: open,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Photo(o.imageUrl, size: 84, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(o.number, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                Pill(o.scheduledFor != null ? '⏰ ${hhmm(o.scheduledFor!)}' : t.t('minutesAgo', {'n': age}), color: late ? Brand.tomato : Brand.muted),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: orderChips(t, o)),
              const SizedBox(height: 8),
              for (final l in o.lines.take(4))
                Text('${l.quantity}× ${l.name}${l.options.isNotEmpty ? ' (${l.options.join(', ')})' : ''}', style: const TextStyle(fontSize: 14, height: 1.35)),
              if (o.lines.length > 4) Text(t.t('moreLines', {'n': o.lines.length - 4}), style: const TextStyle(color: Brand.muted)),
              if (o.notes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.edit_note, size: 18, color: _note),
                    const SizedBox(width: 4),
                    Expanded(child: Text(o.notes!, style: const TextStyle(color: _note, fontSize: 13.5))),
                  ]),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text(eur(o.totalCents, t.lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            flex: 2,
            child: TextButton(
              onPressed: open,
              style: TextButton.styleFrom(
                foregroundColor: Brand.tomato,
                backgroundColor: Brand.tomato.withValues(alpha: 0.08),
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(t.t('viewDetails'), style: const TextStyle(fontWeight: FontWeight.w700))),
            ),
          ),
          if (o.next != null && me.can('orders:update')) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: () => advance(context, o, o.next!, onChanged),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 10)),
                icon: Icon(actionIcon(o.next!), size: 20),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text(t.action(o.next!))),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

Future<bool> advance(BuildContext context, StaffOrder o, String to, VoidCallback onChanged, {String? note}) async {
  final api = context.read<Session>().api;
  final messenger = ScaffoldMessenger.of(context);
  final t = S.of(context);
  try {
    await api.post('/api/v1/admin/orders/${o.id}/status', body: {'status': to, 'note': ?note});
    messenger.showSnackBar(SnackBar(content: Text('${o.number}: ${t.status(to)}')));
    onChanged();
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(t.error(e)), backgroundColor: Brand.tomatoDark));
    return false;
  }
}

/// Full order: progress, lines with photos, totals, payment, customer; actions in the bottom bar.
class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key, required this.order, required this.onChanged});
  final StaffOrder order;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final me = context.read<Session>().me!;
    final t = S.of(context);
    final canUpdate = me.can('orders:update');
    Future<void> call() => launchUrl(Uri.parse('tel:${o.customerPhone!.replaceAll(' ', '')}'));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(t.t('order', {'number': o.number}), style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            if (o.cancellable && canUpdate)
              PopupMenuButton<String>(
                onSelected: (_) async {
                  final reason = await _askReason(context);
                  if (reason == null || !context.mounted) return;
                  if (await advance(context, o, 'cancelled', onChanged, note: reason) && context.mounted) Navigator.pop(context);
                },
                itemBuilder: (_) => [PopupMenuItem(value: 'cancel', child: Text(t.t('cancelOrder'), style: const TextStyle(color: Brand.tomatoDark)))],
              ),
          ],
        ),
        body: Column(children: [
          _Progress(o),
          TabBar(tabs: [Tab(text: t.t('tabInfo')), Tab(text: t.t('tabHistory'))], indicatorSize: TabBarIndicatorSize.tab),
          Expanded(child: TabBarView(children: [_Info(o), _History(o)])),
        ]),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            if (o.customerPhone != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: call,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50), side: BorderSide(color: Brand.tomato.withValues(alpha: 0.4))),
                  icon: const Icon(Icons.call),
                  label: Text(t.t('call'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            if (o.customerPhone != null && o.next != null && canUpdate) const SizedBox(width: 10),
            if (o.next != null && canUpdate)
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () async {
                    if (await advance(context, o, o.next!, onChanged) && context.mounted) Navigator.pop(context);
                  },
                  icon: Icon(actionIcon(o.next!)),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(t.action(o.next!))),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Future<String?> _askReason(BuildContext context) {
    final c = TextEditingController();
    final t = S.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('cancelReason')),
        content: TextField(controller: c, autofocus: true, maxLength: 300, decoration: InputDecoration(hintText: t.t('cancelReasonHint'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.t('back'))),
          FilledButton(onPressed: () => c.text.trim().length >= 3 ? Navigator.pop(ctx, c.text.trim()) : null, child: Text(t.t('cancelOrder'))),
        ],
      ),
    );
  }
}

/// Stepper: New → Preparing → Ready → (On the way →) Picked up / Delivered.
class _Progress extends StatelessWidget {
  const _Progress(this.o);
  final StaffOrder o;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final steps = o.type == 'delivery'
        ? const ['confirmed', 'preparing', 'ready', 'out_for_delivery', 'delivered']
        : const ['confirmed', 'preparing', 'ready', 'picked_up'];
    const icons = {
      'confirmed': Icons.receipt_long,
      'preparing': Icons.soup_kitchen,
      'ready': Icons.room_service,
      'out_for_delivery': Icons.delivery_dining,
      'picked_up': Icons.shopping_bag,
      'delivered': Icons.done_all,
    };
    final current = steps.indexOf(o.status);
    if (current < 0) {
      return Padding(padding: const EdgeInsets.all(16), child: Pill(t.status(o.status), color: Brand.tomatoDark));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == current ? Brand.tomato : Colors.white,
                  border: Border.all(color: i <= current ? Brand.tomato : Brand.border, width: 1.6),
                ),
                child: Icon(icons[steps[i]], size: 18, color: i == current ? Colors.white : i < current ? Brand.tomato : Brand.muted.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 4),
              Text(t.t('step.${steps[i]}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                      color: i == current ? Brand.tomato : i < current ? Brand.charcoal : Brand.muted.withValues(alpha: 0.6))),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.o);
  final StaffOrder o;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final paid = o.paymentStatus == 'paid';
    Widget money(String label, int cents, {bool bold = false, bool minus = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Text(label, style: TextStyle(color: bold ? Brand.charcoal : Brand.muted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 18 : 14)),
            const Spacer(),
            Text('${minus ? '−' : ''}${eur(cents, t.lang)}', style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 18 : 14)),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        ...orderChips(t, o),
        if (o.scheduledFor != null) TintChip(t.t('scheduled', {'at': dateTime(o.scheduledFor!, t.lang)}), icon: Icons.schedule, color: Brand.orange),
      ]),
      const SizedBox(height: 12),
      for (final l in o.lines)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Photo(l.imageUrl, size: 54, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l.quantity}× ${l.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (l.options.isNotEmpty) Text(l.options.join(' · '), style: const TextStyle(color: Brand.muted, fontSize: 13)),
                if (l.notes != null) Text(t.t('lineNote', {'note': l.notes}), style: const TextStyle(color: _note, fontSize: 13)),
                for (final w in l.warnings) Text('⚠ $w', style: const TextStyle(color: Brand.tomatoDark, fontSize: 12)),
              ]),
            ),
            Text(eur(l.lineTotalCents, t.lang), style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      const Divider(height: 24),
      if (o.subtotalCents > 0) money(t.t('subtotal'), o.subtotalCents),
      if (o.discountCents > 0) money(t.t('discount'), o.discountCents, minus: true),
      if (o.deliveryFeeCents > 0) money(t.t('deliveryFee'), o.deliveryFeeCents),
      if (o.taxCents > 0) money(t.t('taxIncluded'), o.taxCents),
      const SizedBox(height: 6),
      money(t.t('total'), o.totalCents, bold: true),
      const SizedBox(height: 12),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Icon(o.paymentMethod == 'cash' ? Icons.payments_outlined : Icons.credit_card, color: o.paymentMethod == 'cash' ? Brand.basil : Brand.blue),
          const SizedBox(width: 10),
          Expanded(child: Text('${t.t(o.paymentMethod == 'cash' ? 'cash' : 'card')}${o.simulated ? t.t('simulatedPayment') : ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
          Pill(t.payment(o.paymentStatus), color: paid ? Brand.basil : Brand.tomato),
        ]),
      ),
      if (o.notes != null) ...[const SizedBox(height: 12), Text(t.t('comments', {'notes': o.notes}), style: const TextStyle(color: _note))],
      const SizedBox(height: 6),
      Text(t.t('ifSoldOutLine', {'choice': t.ifSoldOut(o.ifSoldOut)}), style: const TextStyle(color: Brand.muted, fontSize: 13)),
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 18, backgroundColor: Brand.blue.withValues(alpha: 0.12), child: const Icon(Icons.person, color: Brand.blue, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          ]),
          if (o.customerPhone != null) _line(Icons.call_outlined, o.customerPhone!),
          if (o.address != null) _line(Icons.place_outlined, o.address!),
          if (o.driverName != null)
            _line(Icons.delivery_dining_outlined, t.t('driverLine', {'name': o.driverName, 'state': o.driverState == null ? '' : t.driverState(o.driverState!)})),
        ]),
      ),
    ]);
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Brand.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Brand.muted))),
        ]),
      );
}

class _History extends StatelessWidget {
  const _History(this.o);
  final StaffOrder o;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final events = o.history.reversed.toList();
    if (events.isEmpty) return Center(child: Text(t.t('noHistory'), style: const TextStyle(color: Brand.muted)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, i) {
        final e = events[i];
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              Container(width: 12, height: 12, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: i == 0 ? Brand.tomato : Brand.border)),
              if (i < events.length - 1) Expanded(child: Container(width: 2, color: Brand.border)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.status(e.status), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${dateTime(e.at, t.lang)}${e.byRole == null ? '' : ' · ${t.t('by.${e.byRole}')}'}', style: const TextStyle(color: Brand.muted, fontSize: 13)),
                  if (e.note != null) Text(e.note!, style: const TextStyle(color: _note, fontSize: 13)),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}
