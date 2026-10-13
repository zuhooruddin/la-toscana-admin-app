import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'auth.dart';
import 'customers.dart';
import 'summary.dart';

/// Sales, best sellers, order mix and new customers over a period (owner/manager), compared with the period before.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _days = 7;
  Summary? _sum;
  Object? _error;
  String? _loadedFor;

  Future<void> _load() async {
    final s = context.read<Session>();
    final to = DateTime.now();
    final from = to.subtract(Duration(days: _days - 1));
    final f = DateFormat('yyyy-MM-dd');
    try {
      final r = await s.api.get<Map<String, dynamic>>('/api/v1/admin/analytics/summary', query: {'branchId': s.branchId, 'from': f.format(from), 'to': f.format(to)});
      if (mounted) setState(() => (_sum = Summary.fromJson(r), _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final t = S.of(context);
    final key = '${s.branchId}|$_days';
    if (_loadedFor != key) {
      _loadedFor = key;
      _sum = null;
      _load();
    }
    final sum = _sum;
    final canCustomers = s.me!.can('customers:read');
    return DefaultTabController(
      length: canCustomers ? 4 : 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.t('reports'), style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<int>(
                onSelected: (d) => setState(() => _days = d),
                itemBuilder: (_) => [
                  for (final (d, k) in [(1, 'todayRange'), (7, 'last7'), (30, 'last30')]) CheckedPopupMenuItem(value: d, checked: d == _days, child: Text(t.t(k))),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: Brand.border), borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t.t(_days == 1 ? 'todayRange' : _days == 7 ? 'last7' : 'last30'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Icon(Icons.keyboard_arrow_down, size: 20),
                  ]),
                ),
              ),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: t.t('repSales')),
            Tab(text: t.t('repProducts')),
            Tab(text: t.t('repOrders')),
            if (canCustomers) Tab(text: t.t('repCustomers')),
          ]),
        ),
        body: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorText(context, _error!), style: const TextStyle(color: Brand.tomatoDark))))
            : sum == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _Sales(sum: sum, onRefresh: _load),
                    _Products(sum: sum, onRefresh: _load),
                    _Orders(sum: sum, onRefresh: _load),
                    if (canCustomers) _Customers(sum: sum, onRefresh: _load),
                  ]),
      ),
    );
  }
}

class _Sales extends StatelessWidget {
  const _Sales({required this.sum, required this.onRefresh});
  final Summary sum;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final cmp = t.t('vsPrevious');
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            KpiCard(icon: Icons.savings_outlined, color: Brand.basil, label: t.t('totalSales'), value: eur(sum.netCents, t.lang), now: sum.netCents, before: sum.prevNetCents, compareLabel: cmp),
            KpiCard(icon: Icons.shopping_bag_outlined, color: Brand.orange, label: t.t('ordersLabel'), value: '${sum.orders}', now: sum.orders, before: sum.prevOrders, compareLabel: cmp),
            KpiCard(
                icon: Icons.receipt_outlined,
                color: Brand.amber,
                label: t.t('avgTicket'),
                value: eur(sum.averageTicketCents, t.lang),
                now: sum.averageTicketCents,
                before: sum.prevAverageTicketCents,
                compareLabel: cmp),
            if (sum.newCustomers != null) KpiCard(icon: Icons.person_add_alt, color: Brand.blue, label: t.t('newCustomers'), value: '${sum.newCustomers}'),
          ],
        ),
        if (sum.byDay.length > 1) ...[
          SectionTitle(t.t('salesByDay')),
          Panel(padding: const EdgeInsets.fromLTRB(8, 16, 12, 8), child: SizedBox(height: 210, child: _Bars(days: sum.byDay, lang: t.lang))),
        ],
      ]),
    );
  }
}

class _Products extends StatelessWidget {
  const _Products({required this.sum, required this.onRefresh});
  final Summary sum;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final top = sum.topItems;
    final maxQ = top.isEmpty ? 1 : top.map((i) => i.quantity).reduce(math.max);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        if (top.isEmpty) EmptyState(icon: Icons.local_pizza_outlined, title: t.t('noData')),
        if (top.isNotEmpty) SectionTitle(t.t('topProducts')),
        for (final (i, item) in top.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: i < 3 ? Brand.tomato : Brand.border,
                  child: Text('${i + 1}', style: TextStyle(color: i < 3 ? Colors.white : Brand.charcoal, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: item.quantity / maxQ, minHeight: 6, backgroundColor: Brand.cream, color: Brand.tomato.withValues(alpha: 0.75)),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(t.t('units', {'n': item.quantity}), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(eur(item.revenueCents, t.lang), style: const TextStyle(color: Brand.muted, fontSize: 13)),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Orders extends StatelessWidget {
  const _Orders({required this.sum, required this.onRefresh});
  final Summary sum;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final statuses = sum.byStatus.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        if (statuses.isEmpty) EmptyState(icon: Icons.receipt_long_outlined, title: t.t('noData')),
        if (statuses.isNotEmpty) ...[
          SectionTitle(t.t('ordersByStatus')),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [
              for (final e in statuses)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [Expanded(child: Text(t.status(e.key), style: const TextStyle(fontWeight: FontWeight.w600))), Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800))]),
                ),
            ]),
          ),
          SectionTitle(t.t('byPayment')),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [
              for (final p in sum.byPayment)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Icon(p.method == 'cash' ? Icons.payments_outlined : Icons.credit_card, color: p.method == 'cash' ? Brand.basil : Brand.blue),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.t(p.method == 'cash' ? 'cash' : 'card'), style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${p.count} · ${eur(p.cents, t.lang)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const Icon(Icons.delivery_dining, color: Brand.tomato),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.t('deliveryShare'), style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text('${(sum.deliveryShare * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Customers extends StatelessWidget {
  const _Customers({required this.sum, required this.onRefresh});
  final Summary sum;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        SizedBox(height: 130, child: KpiCard(icon: Icons.person_add_alt, color: Brand.blue, label: t.t('newCustomers'), value: '${sum.newCustomers ?? 0}')),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomersPage())),
          icon: const Icon(Icons.people_outline),
          label: Text(t.t('seeCustomers')),
        ),
      ]),
    );
  }
}

/// One bar per day; the last (most recent) highlighted with its total.
class _Bars extends StatelessWidget {
  const _Bars({required this.days, required this.lang});
  final List<DayStat> days;
  final String lang;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BarsPainter(days, lang), size: Size.infinite);
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.days, this.lang);
  final List<DayStat> days;
  final String lang;

  TextPainter _text(String s, {Color color = Brand.muted, double size = 10.5, FontWeight weight = FontWeight.w500}) =>
      TextPainter(text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: weight)), textDirection: TextDirection.ltr)..layout();

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0, bottom = 22.0, top = 30.0;
    final w = size.width - left;
    final h = size.height - bottom - top;
    final maxEur = math.max(1.0, days.map((d) => d.netCents / 100).reduce(math.max));
    final rawStep = maxEur / 3;
    final mag = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final f = rawStep / mag;
    final step = (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * mag;
    final topV = (maxEur / step).ceil() * step;
    final grid = Paint()..color = Brand.border.withValues(alpha: 0.7);
    for (var v = 0.0; v <= topV + 0.001; v += step) {
      final y = top + h * (1 - v / topV);
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      final tp = _text(NumberFormat.compact().format(v));
      tp.paint(canvas, Offset(left - tp.width - 6, y - tp.height / 2));
    }
    final n = days.length;
    final slot = w / n;
    final barW = math.min(26.0, slot * 0.62);
    final labelEvery = (n / 7).ceil();
    for (var i = 0; i < n; i++) {
      final d = days[i];
      final x = left + slot * i + slot / 2;
      final bh = h * (d.netCents / 100 / topV);
      final last = i == n - 1;
      final rect = RRect.fromRectAndCorners(Rect.fromLTWH(x - barW / 2, top + h - bh, barW, bh), topLeft: const Radius.circular(6), topRight: const Radius.circular(6));
      canvas.drawRRect(rect, Paint()..color = last ? Brand.tomato : Brand.tomato.withValues(alpha: 0.45));
      if (i % labelEvery == 0 || last) {
        final tp = _text(DateFormat.MMMd(lang).format(d.date));
        tp.paint(canvas, Offset((x - tp.width / 2).clamp(left - 8, size.width - tp.width), size.height - tp.height));
      }
      if (last && d.netCents > 0) {
        final tp = _text(eur(d.netCents, lang), color: Colors.white, size: 11.5, weight: FontWeight.w800);
        final box = Rect.fromCenter(center: Offset(math.min(x, size.width - tp.width / 2 - 8), math.max(top + h - bh - 16, tp.height)), width: tp.width + 14, height: tp.height + 6);
        canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(8)), Paint()..color = Brand.tomato);
        tp.paint(canvas, box.topLeft + const Offset(7, 3));
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.days != days || old.lang != lang;
}
