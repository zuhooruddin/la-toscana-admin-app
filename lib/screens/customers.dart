import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'auth.dart';

const _avatarColors = [Color(0xFF6A55B5), Brand.blue, Brand.basil, Brand.orange, Brand.tomatoDark, Color(0xFF0E8C8C)];

/// Customer accounts (owner/manager): search by name, e-mail or phone; order count and spend.
class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  List<Customer>? _items;
  Object? _error;
  String _q = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final q = _q;
    try {
      final r = await context.read<Session>().api.get<Map<String, dynamic>>('/api/v1/admin/customers', query: {'q': q.isEmpty ? null : q, 'limit': 100});
      if (mounted && q == _q) {
        setState(() => (_items = (r['items'] as List).map((c) => Customer.fromJson((c as Map).cast<String, dynamic>())).toList(), _error = null));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _open(Customer c) {
    final t = S.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(c.name.isEmpty ? c.email : c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              if (c.status == 'disabled') Pill(t.t('blocked'), color: Brand.tomatoDark),
            ]),
            const SizedBox(height: 8),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.mail_outline), title: Text(c.email)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(c.orders == 1 ? t.t('oneOrder') : t.t('ordersCount', {'n': c.orders})),
              subtitle: Text(t.t('spent', {'amount': eur(c.totalCents, t.lang)})),
            ),
            if (c.lastOrderAt != null)
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.schedule), title: Text(t.t('lastOrder', {'date': dateTime(c.lastOrderAt!, t.lang)}))),
            if (c.phone != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:${c.phone!.replaceAll(' ', '')}')),
                icon: const Icon(Icons.call),
                label: Text('${t.t('call')} · ${c.phone}'),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text(t.t('customers'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: t.t('searchCustomer'), isDense: true),
            onChanged: (v) {
              _q = v.trim();
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _load);
            },
          ),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(errorText(context, _error!), style: const TextStyle(color: Brand.tomatoDark))),
        Expanded(
          child: items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(children: [EmptyState(icon: Icons.people_outline, title: t.t('noCustomers'))])
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 76, color: Color(0x14000000)),
                          itemBuilder: (context, i) {
                            final c = items[i];
                            final name = c.name.isEmpty ? c.email : c.name;
                            final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
                            final color = _avatarColors[name.hashCode.abs() % _avatarColors.length];
                            return ListTile(
                              onTap: () => _open(c),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: color.withValues(alpha: 0.14),
                                child: Text(initials, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(c.phone ?? c.email, style: const TextStyle(color: Brand.muted)),
                              trailing: Text(c.orders == 1 ? t.t('oneOrder') : t.t('ordersCount', {'n': c.orders}),
                                  style: const TextStyle(color: Brand.muted, fontWeight: FontWeight.w600)),
                            );
                          },
                        ),
                ),
        ),
      ]),
    );
  }
}
