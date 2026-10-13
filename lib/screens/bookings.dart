import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'auth.dart';

Color bookingColor(String status) => switch (status) {
      'confirmed' => Brand.basil,
      'seated' => Brand.blue,
      'cancelled' => Brand.tomatoDark,
      _ => Brand.muted,
    };

/// Table bookings for one day, picked from a week strip: mark seated / no-show.
class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});
  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  List<Booking>? _items;
  Object? _error;
  String? _loadedFor;

  String get _date => DateFormat('yyyy-MM-dd').format(_day);

  Future<void> _load() async {
    final s = context.read<Session>();
    try {
      final r = await s.api.get<Map<String, dynamic>>('/api/v1/admin/reservations', query: {'date': _date, 'branchId': s.branchId});
      if (mounted) setState(() => (_items = (r['items'] as List).map((x) => Booking.fromJson((x as Map).cast<String, dynamic>())).toList(), _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _set(Booking b, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = S.of(context);
    try {
      await context.read<Session>().api.post('/api/v1/admin/reservations/${b.id}/status', body: {'status': status});
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.error(e)), backgroundColor: Brand.tomatoDark));
    }
  }

  void _open(Booking b) {
    final t = S.of(context);
    final canWrite = context.read<Session>().me!.can('reservations:write');
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(t.t('bookingFor', {'time': b.time}), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              Pill(t.booking(b.status), color: bookingColor(b.status)),
            ]),
            const SizedBox(height: 4),
            Text('${b.name} · ${b.partySize == 1 ? t.t('guest') : t.t('guests', {'n': b.partySize})}', style: const TextStyle(color: Brand.muted, fontSize: 15)),
            if (b.notes != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(b.notes!, style: const TextStyle(color: Color(0xFF8A5300)))),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:${b.phone.replaceAll(' ', '')}')),
              icon: const Icon(Icons.call),
              label: Text('${t.t('call')} · ${b.phone}'),
            ),
            if (b.status == 'confirmed' && canWrite) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _set(b, 'no_show');
                    },
                    child: Text(t.t('markNoShow')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _set(b, 'seated');
                    },
                    child: Text(t.t('markSeated')),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final t = S.of(context);
    final key = '${s.branchId}|$_date';
    if (_loadedFor != key) {
      _loadedFor = key;
      _load();
    }
    final items = _items ?? const <Booking>[];
    final covers = items.where((b) => b.status != 'cancelled').fold(0, (n, b) => n + b.partySize);
    final monday = _day.subtract(Duration(days: _day.weekday - 1));
    final today = DateUtils.dateOnly(DateTime.now());
    return Column(children: [
      Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left), tooltip: t.t('prevDay')),
              Expanded(
                child: Column(children: [
                  Text(DateFormat.yMMMM(t.lang).format(_day), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  if (items.isNotEmpty) Text(t.t('guests', {'n': covers}), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                ]),
              ),
              IconButton(onPressed: () => setState(() => _day = _day.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right), tooltip: t.t('nextDay')),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(child: _DayCell(day: monday.add(Duration(days: i)), selected: DateUtils.isSameDay(monday.add(Duration(days: i)), _day), today: today, lang: t.lang,
                    onTap: () => setState(() => _day = monday.add(Duration(days: i))))),
            ]),
          ]),
        ),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(errorText(context, _error!), style: const TextStyle(color: Brand.tomatoDark))),
      Expanded(
        child: _items == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: items.isEmpty
                    ? ListView(children: [
                        EmptyState(
                          icon: Icons.table_restaurant_outlined,
                          title: t.t('noBookings'),
                          body: t.t('noBookingsBody', {'date': DateFormat.yMMMMd(t.lang).format(_day)}),
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final b = items[i];
                          return Panel(
                            onTap: () => _open(b),
                            child: IntrinsicHeight(
                              child: Row(children: [
                                SizedBox(width: 58, child: Text(b.time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                                const VerticalDivider(width: 20, color: Brand.border),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Text(b.partySize == 1 ? t.t('guest') : t.t('guests', {'n': b.partySize}), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                    Text(b.name, style: const TextStyle(color: Brand.muted)),
                                    if (b.notes != null) Text(b.notes!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8A5300), fontSize: 12.5)),
                                  ]),
                                ),
                                Pill(t.booking(b.status), color: bookingColor(b.status)),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
      ),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.selected, required this.today, required this.lang, required this.onTap});
  final DateTime day;
  final bool selected;
  final DateTime today;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(day, today);
    final fg = selected ? Colors.white : Brand.charcoal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: selected ? Brand.tomato : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              Text(DateFormat.E(lang).format(day).replaceAll('.', ''), style: TextStyle(fontSize: 12, color: selected ? Colors.white : Brand.muted)),
              const SizedBox(height: 2),
              Text('${day.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
              const SizedBox(height: 2),
              Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: isToday && !selected ? Brand.tomato : Colors.transparent)),
            ]),
          ),
        ),
      ),
    );
  }
}
