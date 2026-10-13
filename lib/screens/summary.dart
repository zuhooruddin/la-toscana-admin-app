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

/// Today's figures (real orders only) and pause / resume online ordering per restaurant.
class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});
  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  Summary? _sum;
  int? _bookings;
  Object? _error;
  String? _loadedFor;

  Future<void> _load() async {
    final s = context.read<Session>();
    try {
      final r = await s.api.get<Map<String, dynamic>>('/api/v1/admin/analytics/summary', query: {'branchId': s.branchId});
      int? bookings;
      if (s.me!.can('reservations:read')) {
        final b = await s.api.get<Map<String, dynamic>>('/api/v1/admin/reservations',
            query: {'date': DateFormat('yyyy-MM-dd').format(DateTime.now()), 'branchId': s.branchId});
        bookings = (b['items'] as List).where((x) => (x as Map)['status'] != 'cancelled').length;
      }
      await s.loadBranches();
      if (mounted) setState(() => (_sum = Summary.fromJson(r), _bookings = bookings, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pause(StaffBranch b, bool paused, {int? minutes}) async {
    final s = context.read<Session>();
    final messenger = ScaffoldMessenger.of(context);
    final t = S.of(context);
    try {
      await s.api.post('/api/v1/admin/branches/${b.id}/pause', body: {'paused': paused, 'minutes': ?minutes});
      await s.loadBranches();
      messenger.showSnackBar(SnackBar(content: Text(t.t(paused ? 'pausedAt' : 'resumedAt', {'name': b.name}))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.error(e)), backgroundColor: Brand.tomatoDark));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final t = S.of(context);
    if (_loadedFor != (s.branchId ?? 'all')) {
      _loadedFor = s.branchId ?? 'all';
      _load();
    }
    final sum = _sum;
    final branches = s.branchId == null ? s.branches : s.branches.where((b) => b.id == s.branchId).toList();
    // Cumulative series up to the last hour with sales. Hours are business-local (Madrid), so the device clock
    // (possibly another timezone) cannot be used to cut the day.
    final lastHour = sum == null ? -1 : sum.byHour.lastIndexWhere((h) => h.orders > 0);
    final hours = lastHour < 0 ? <HourStat>[] : sum!.byHour.sublist(0, lastHour + 1);
    List<double> running(num Function(HourStat) f) {
      var acc = 0.0;
      return [for (final h in hours) acc += f(h)];
    }
    final ordersSeries = running((h) => h.orders);
    final salesSeries = running((h) => h.netCents);
    final ticketSeries = [for (var i = 0; i < hours.length; i++) ordersSeries[i] == 0 ? 0.0 : salesSeries[i] / ordersSeries[i]];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 24), children: [
        Text(toBeginningOfSentenceCase(DateFormat.yMMMMEEEEd(t.lang).format(sum?.day ?? DateTime.now())), style: const TextStyle(color: Brand.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(errorText(context, _error!), style: const TextStyle(color: Brand.tomatoDark))),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            KpiCard(icon: Icons.shopping_bag_outlined, color: Brand.blue, label: t.t('ordersToday'), value: sum == null ? '—' : '${sum.orders}',
                now: sum?.orders, before: sum?.prevOrders, series: ordersSeries),
            KpiCard(icon: Icons.savings_outlined, color: Brand.orange, label: t.t('salesToday'), value: sum == null ? '—' : eur(sum.netCents, t.lang),
                now: sum?.netCents, before: sum?.prevNetCents, series: salesSeries),
            KpiCard(icon: Icons.bar_chart, color: Brand.blue, label: t.t('avgTicket'), value: sum == null ? '—' : eur(sum.averageTicketCents, t.lang),
                now: sum?.averageTicketCents, before: sum?.prevAverageTicketCents, series: ticketSeries),
            if (_bookings != null) KpiCard(icon: Icons.event_note_outlined, color: Brand.tomato, label: t.t('bookingsToday'), value: '$_bookings'),
          ],
        ),
        if ((sum?.simulatedCents ?? 0) > 0)
          Padding(padding: const EdgeInsets.only(top: 10), child: Text(t.t('simulatedSales', {'amount': eur(sum!.simulatedCents, t.lang)}), style: const TextStyle(color: Color(0xFF8A5300)))),
        if (sum != null && sum.byHour.isNotEmpty) ...[
          SectionTitle(t.t('salesByHour')),
          Panel(
            padding: const EdgeInsets.fromLTRB(8, 16, 14, 8),
            child: hours.isEmpty
                ? SizedBox(height: 120, child: Center(child: Text(t.t('noSalesYet'), style: const TextStyle(color: Brand.muted))))
                : SizedBox(height: 190, child: _SalesChart(hours: hours, total: sum.netCents, lang: t.lang)),
          ),
        ],
        if (sum != null) ...[
          SectionTitle(t.t('ordersByStatus')),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [
              for (final (status, label, color) in [
                ('confirmed', t.t('colNew'), Brand.tomato),
                ('preparing', t.t('colPreparing'), Brand.orange),
                ('ready', t.t('colReady'), Brand.blue),
                ('out_for_delivery', t.t('colDelivery'), Brand.basil),
                ('picked_up', t.status('picked_up'), Brand.muted),
                ('delivered', t.status('delivered'), Brand.muted),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${sum.byStatus[status] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
            ]),
          ),
        ],
        SectionTitle(t.t('onlineOrders')),
        for (final b in branches)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(!b.enabled ? t.t('orderingOff') : b.isPaused ? (b.pausedUntil != null ? t.t('pausedUntil', {'time': hhmm(b.pausedUntil!)}) : t.t('paused')) : t.t('accepting'),
                        style: TextStyle(color: !b.enabled ? Brand.muted : b.isPaused ? Brand.orange : Brand.basil, fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (b.enabled && s.me!.can('branch:pause'))
                  b.isPaused
                      ? FilledButton(onPressed: () => _pause(b, false), style: FilledButton.styleFrom(minimumSize: const Size(0, 42)), child: Text(t.t('resume')))
                      : PopupMenuButton<int>(
                          tooltip: t.t('pause'),
                          onSelected: (m) => _pause(b, true, minutes: m == 0 ? null : m),
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 15, child: Text(t.t('pause15'))),
                            PopupMenuItem(value: 30, child: Text(t.t('pause30'))),
                            PopupMenuItem(value: 60, child: Text(t.t('pause60'))),
                            PopupMenuItem(value: 0, child: Text(t.t('pauseOpen'))),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.pause_circle_outline, size: 20, color: Brand.charcoal),
                              const SizedBox(width: 4),
                              Text(t.t('pause'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// KPI card: icon, label, value, change against yesterday up to the same hour and a sparkline.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.icon, required this.color, required this.label, required this.value, this.now, this.before, this.series = const [], this.compareLabel});
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final num? now;
  final num? before;
  final List<double> series;
  final String? compareLabel;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final change = now != null && before != null && before! > 0 ? (now! - before!) / before! * 100 : null;
    final up = (change ?? 0) >= 0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: Brand.softShadow,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.alphaBlend(color.withValues(alpha: 0.07), Colors.white), Colors.white]),
      ),
      padding: const EdgeInsets.all(14),
      child: Stack(children: [
        if (series.length > 1)
          Positioned(right: 0, top: 2, width: 76, height: 36, child: CustomPaint(painter: _Spark(series, color))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 26),
          const Spacer(),
          Text(label, style: const TextStyle(color: Brand.charcoal, fontSize: 13)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          if (change != null)
            Tooltip(
              message: compareLabel ?? t.t('vsYesterday'),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(up ? Icons.trending_up : Icons.trending_down, size: 15, color: up ? Brand.basil : Brand.tomatoDark),
                const SizedBox(width: 3),
                Text('${up ? '+' : ''}${change.round()}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: up ? Brand.basil : Brand.tomatoDark)),
              ]),
            ),
        ]),
      ]),
    );
  }
}

class _Spark extends CustomPainter {
  _Spark(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce(math.max);
    if (maxV <= 0) return;
    final pts = [for (var i = 0; i < values.length; i++) Offset(size.width * i / (values.length - 1), size.height * (1 - values[i] / maxV))];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)]).createShader(Offset.zero & size));
    canvas.drawPath(path, Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_Spark old) => old.values != values;
}

/// Cumulative sales through the day so far, with gridlines and the running total at the last point.
class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.hours, required this.total, required this.lang});
  final List<HourStat> hours;
  final int total;
  final String lang;

  @override
  Widget build(BuildContext context) {
    // Start the axis at the first hour with sales (restaurants open around noon), keep at least 6 hours visible.
    final first = hours.indexWhere((h) => h.netCents > 0);
    final start = math.max(0, math.min(first < 0 ? 0 : first - 1, hours.length - 6));
    var acc = 0;
    final points = [for (final h in hours) acc += h.netCents].sublist(start);
    return CustomPaint(painter: _ChartPainter(points, start, eur(total, lang)), size: Size.infinite);
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.cents, this.firstHour, this.label);
  final List<int> cents;
  final int firstHour;
  final String label;

  static const _left = 40.0;
  static const _bottom = 20.0;
  static const _top = 26.0;

  TextPainter _text(String s, {Color color = Brand.muted, double size = 10.5, FontWeight weight = FontWeight.w500}) =>
      TextPainter(text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: weight)), textDirection: TextDirection.ltr)..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _left;
    final h = size.height - _bottom - _top;
    final maxEur = cents.reduce(math.max) / 100;
    final step = _niceStep(maxEur / 3);
    final top = math.max(step, (maxEur / step).ceil() * step);
    final grid = Paint()..color = Brand.border.withValues(alpha: 0.7);
    for (var v = 0.0; v <= top + 0.001; v += step) {
      final y = _top + h * (1 - v / top);
      canvas.drawLine(Offset(_left, y), Offset(size.width, y), grid);
      final tp = _text(NumberFormat.compact().format(v));
      tp.paint(canvas, Offset(_left - tp.width - 6, y - tp.height / 2));
    }
    final n = cents.length;
    Offset at(int i) => Offset(_left + (n == 1 ? w / 2 : w * i / (n - 1)), _top + h * (1 - cents[i] / 100 / top));
    final labelEvery = (n / 6).ceil();
    for (var i = 0; i < n; i += labelEvery) {
      final tp = _text('${firstHour + i}h');
      tp.paint(canvas, Offset(at(i).dx - tp.width / 2, size.height - tp.height));
    }
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < n; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(at(n - 1).dx, _top + h)
      ..lineTo(at(0).dx, _top + h)
      ..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Brand.tomato.withValues(alpha: 0.18), Brand.tomato.withValues(alpha: 0)]).createShader(Rect.fromLTWH(0, _top, size.width, h)));
    canvas.drawPath(line, Paint()
      ..color = Brand.tomato
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(at(i), 3.2, Paint()..color = Brand.tomato);
    }
    // Running total bubble over the last point.
    final last = at(n - 1);
    final tp = _text(label, color: Brand.tomatoDark, size: 12, weight: FontWeight.w800);
    final box = Rect.fromCenter(center: Offset(math.min(last.dx, size.width - tp.width / 2 - 8), last.dy - 18), width: tp.width + 14, height: tp.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(box.shift(Offset(0, box.top < 0 ? -box.top : 0)), const Radius.circular(8)), Paint()..color = const Color(0xFFFDE8E6));
    tp.paint(canvas, box.topLeft + Offset(7, 3 + (box.top < 0 ? -box.top : 0)));
  }

  static double _niceStep(double raw) {
    if (raw <= 0) return 1;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / mag;
    return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * mag;
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.cents != cents || old.label != label;
}
