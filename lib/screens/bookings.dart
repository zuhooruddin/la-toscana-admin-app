import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models.dart';
import '../session.dart';
import 'auth.dart';

/// Today's (or another day's) table bookings: mark seated / no-show / cancelled.
class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});
  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  DateTime _day = DateTime.now();
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
    try {
      await context.read<Session>().api.post('/api/v1/admin/reservations/${b.id}/status', body: {'status': status});
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e)), backgroundColor: Brand.tomatoDark));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final key = '${s.branchId}|$_date';
    if (_loadedFor != key) {
      _loadedFor = key;
      _load();
    }
    final items = _items ?? const <Booking>[];
    final covers = items.where((b) => b.status != 'cancelled').fold(0, (n, b) => n + b.partySize);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          IconButton(onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left), tooltip: 'Día anterior'),
          Expanded(child: Text('${DateFormat.MMMEd('es').format(_day)} · $covers comensales', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
          IconButton(onPressed: () => setState(() => _day = _day.add(const Duration(days: 1))), icon: const Icon(Icons.chevron_right), tooltip: 'Día siguiente'),
        ]),
      ),
      if (_error != null) Text(errorText(_error!), style: const TextStyle(color: Brand.tomatoDark)),
      Expanded(
        child: _items == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: items.isEmpty
                    ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Sin reservas este día', style: TextStyle(color: Brand.muted)))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final b = items[i];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(b.time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text('${b.name} · ${b.partySize} pers.', style: const TextStyle(fontWeight: FontWeight.w700))),
                                  Text(const {'confirmed': 'Confirmada', 'seated': 'Sentados', 'no_show': 'No vino', 'cancelled': 'Cancelada'}[b.status] ?? b.status,
                                      style: const TextStyle(color: Brand.muted)),
                                ]),
                                if (b.notes != null) Text(b.notes!, style: const TextStyle(color: Color(0xFF7A4500))),
                                Wrap(spacing: 6, children: [
                                  TextButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${b.phone.replaceAll(' ', '')}')), icon: const Icon(Icons.call, size: 18), label: Text(b.phone)),
                                  if (b.status == 'confirmed' && s.me!.can('reservations:write')) ...[
                                    FilledButton(onPressed: () => _set(b, 'seated'), child: const Text('Sentados')),
                                    OutlinedButton(onPressed: () => _set(b, 'no_show'), child: const Text('No vino')),
                                  ],
                                ]),
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
