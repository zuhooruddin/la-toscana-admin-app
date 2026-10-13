import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models.dart';
import '../session.dart';
import 'auth.dart';

/// Today's figures (real orders only) and pause / resume online ordering per restaurant.
class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});
  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  Summary? _sum;
  Object? _error;
  String? _loadedFor;

  Future<void> _load() async {
    final s = context.read<Session>();
    try {
      final r = await s.api.get<Map<String, dynamic>>('/api/v1/admin/analytics/summary', query: {'branchId': s.branchId});
      await s.loadBranches();
      if (mounted) setState(() => (_sum = Summary.fromJson(r), _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pause(StaffBranch b, bool paused, {int? minutes}) async {
    final s = context.read<Session>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await s.api.post('/api/v1/admin/branches/${b.id}/pause', body: {'paused': paused, 'minutes': ?minutes});
      await s.loadBranches();
      messenger.showSnackBar(SnackBar(content: Text(paused ? 'Pedidos online en pausa en ${b.name}' : '${b.name} vuelve a aceptar pedidos')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e)), backgroundColor: Brand.tomatoDark));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    if (_loadedFor != (s.branchId ?? 'all')) {
      _loadedFor = s.branchId ?? 'all';
      _load();
    }
    final sum = _sum;
    final branches = s.branchId == null ? s.branches : s.branches.where((b) => b.id == s.branchId).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_error != null) Text(errorText(_error!), style: const TextStyle(color: Brand.tomatoDark)),
        Row(children: [
          _Stat('Pedidos hoy', sum == null ? '—' : '${sum.orders}'),
          const SizedBox(width: 10),
          _Stat('Ventas', sum == null ? '—' : eur(sum.netCents)),
        ]),
        const SizedBox(height: 10),
        Row(children: [_Stat('Ticket medio', sum == null ? '—' : eur(sum.averageTicketCents)), const SizedBox(width: 10), const Expanded(child: SizedBox())]),
        if ((sum?.simulatedCents ?? 0) > 0)
          Padding(padding: const EdgeInsets.only(top: 10), child: Text('${eur(sum!.simulatedCents)} son pagos con tarjeta simulados (modo de pruebas).', style: const TextStyle(color: Color(0xFF7A4500)))),
        const SizedBox(height: 20),
        const Text('Pedidos online', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        for (final b in branches)
          Card(
            margin: const EdgeInsets.only(top: 10),
            child: ListTile(
              title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(!b.enabled ? 'Desactivados' : b.isPaused ? 'En pausa${b.pausedUntil != null ? ' hasta ${hhmm(b.pausedUntil!)}' : ''}' : 'Aceptando pedidos',
                  style: TextStyle(color: !b.enabled ? Brand.muted : b.isPaused ? const Color(0xFFA15C00) : Brand.basil, fontWeight: FontWeight.w600)),
              trailing: !b.enabled || !s.me!.can('branch:pause')
                  ? null
                  : b.isPaused
                      ? FilledButton(onPressed: () => _pause(b, false), child: const Text('Reanudar'))
                      : PopupMenuButton<int>(
                          tooltip: 'Pausar',
                          onSelected: (m) => _pause(b, true, minutes: m == 0 ? null : m),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 15, child: Text('Pausar 15 min')),
                            PopupMenuItem(value: 30, child: Text('Pausar 30 min')),
                            PopupMenuItem(value: 60, child: Text('Pausar 1 hora')),
                            PopupMenuItem(value: 0, child: Text('Pausar hasta reanudar')),
                          ],
                          child: const Padding(padding: EdgeInsets.all(8), child: Text('Pausar', style: TextStyle(fontWeight: FontWeight.w700))),
                        ),
            ),
          ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Brand.muted)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}
