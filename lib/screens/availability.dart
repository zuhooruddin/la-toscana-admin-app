import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models.dart';
import '../session.dart';
import 'auth.dart';

/// Mark dishes sold out for today (staff may do this; turning dishes on/off for good is done in the web dashboard).
class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({super.key});
  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  List<AvailabilityRow>? _rows;
  Object? _error;
  String _q = '';
  String? _loadedFor;

  Future<void> _load(String branchId) async {
    try {
      final r = await context.read<Session>().api.get<Map<String, dynamic>>('/api/v1/admin/branches/$branchId/menu');
      if (mounted) setState(() => (_rows = (r['items'] as List).map((x) => AvailabilityRow.fromJson((x as Map).cast<String, dynamic>())).where((x) => x.available).toList(), _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggle(String branchId, AvailabilityRow row) async {
    final messenger = ScaffoldMessenger.of(context);
    final next = !row.soldOut;
    setState(() => row.soldOut = next);
    try {
      await context.read<Session>().api.patch('/api/v1/admin/branches/$branchId/menu/${row.itemId}', body: {'soldOut': next});
      messenger.showSnackBar(SnackBar(content: Text('${row.name}: ${next ? 'agotado' : 'disponible de nuevo'}')));
    } catch (e) {
      setState(() => row.soldOut = !next);
      messenger.showSnackBar(SnackBar(content: Text(errorText(e)), backgroundColor: Brand.tomatoDark));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final branchId = s.branchId;
    if (branchId == null) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Elige un restaurante', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final b in s.branches) Card(child: ListTile(title: Text(b.name), trailing: const Icon(Icons.chevron_right), onTap: () => s.selectBranch(b.id))),
      ]);
    }
    if (_loadedFor != branchId) {
      _loadedFor = branchId;
      _rows = null;
      _load(branchId);
    }
    final rows = (_rows ?? const <AvailabilityRow>[]).where((r) => _q.isEmpty || r.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar plato…', isDense: true), onChanged: (v) => setState(() => _q = v)),
      ),
      if (_error != null) Text(errorText(_error!), style: const TextStyle(color: Brand.tomatoDark)),
      Expanded(
        child: _rows == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _load(branchId),
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return SwitchListTile(
                      title: Text(r.name),
                      subtitle: Text(r.soldOut ? 'Agotado' : 'Disponible', style: TextStyle(color: r.soldOut ? Brand.tomatoDark : Brand.basil, fontWeight: FontWeight.w600)),
                      value: !r.soldOut,
                      onChanged: (_) => _toggle(branchId, r),
                    );
                  },
                ),
              ),
      ),
    ]);
  }
}
