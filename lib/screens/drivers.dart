import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'auth.dart';
import 'orders.dart';

/// Deliveries in progress on a live map (restaurant + last driver position), and today's completed deliveries.
class DriversPage extends StatefulWidget {
  const DriversPage({super.key});
  @override
  State<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage> {
  List<StaffOrder>? _active;
  List<StaffOrder> _delivered = const [];
  Map<String, Driver> _drivers = const {};
  Object? _error;
  StreamSubscription<String>? _sub;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _sub = s.events.where((e) => e.startsWith('order.') || e == 'resync').listen((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = context.read<Session>();
    final today = DateUtils.dateOnly(DateTime.now());
    List<StaffOrder> parse(Map<String, dynamic> r) => (r['items'] as List).map((o) => StaffOrder.fromJson((o as Map).cast<String, dynamic>())).toList();
    try {
      final results = await Future.wait([
        s.api.get<Map<String, dynamic>>('/api/v1/admin/orders', query: {'status': 'out_for_delivery', 'branchId': s.branchId, 'pageSize': 100}),
        s.api.get<Map<String, dynamic>>('/api/v1/admin/orders',
            query: {'status': 'delivered', 'branchId': s.branchId, 'from': today.toUtc().toIso8601String(), 'pageSize': 100}),
        // The roster is per restaurant; with "all restaurants" ask for each one.
        for (final b in s.branchId == null ? s.branches : s.branches.where((b) => b.id == s.branchId))
          s.api.get<Map<String, dynamic>>('/api/v1/admin/staff/drivers', query: {'branchId': b.id}),
      ]);
      final drivers = <String, Driver>{
        for (final r in results.skip(2))
          for (final d in (r['items'] as List)) Driver.fromJson((d as Map).cast<String, dynamic>()).id: Driver.fromJson(d.cast<String, dynamic>()),
      };
      if (mounted) {
        setState(() => (_active = parse(results[0]), _delivered = parse(results[1]), _drivers = drivers, _error = null));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final s = context.watch<Session>();
    final active = _active;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${t.t('drivers')} · ${s.branch?.name ?? t.t('allRestaurants')}', style: const TextStyle(fontWeight: FontWeight.w800)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                height: 42,
                decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(21)),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  indicator: BoxDecoration(color: Brand.tomato, borderRadius: BorderRadius.circular(21)),
                  tabs: [Tab(text: t.t('onTheWayTab', {'n': active?.length ?? 0})), Tab(text: t.t('deliveredTab'))],
                ),
              ),
            ),
          ),
        ),
        body: Column(children: [
          if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(errorText(context, _error!), style: const TextStyle(color: Brand.tomatoDark))),
          Expanded(
            child: active == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.all(12), children: [
                        _DeliveryMap(orders: active),
                        const SizedBox(height: 12),
                        if (active.isEmpty) EmptyState(icon: Icons.delivery_dining_outlined, title: t.t('noActiveDeliveries')),
                        for (final o in active) ...[_DriverRow(order: o, driver: _drivers[o.driverId], onChanged: _load), const SizedBox(height: 10)],
                      ]),
                    ),
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.all(12), children: [
                        if (_delivered.isEmpty) EmptyState(icon: Icons.done_all, title: t.t('noDelivered')),
                        for (final o in _delivered) ...[_DriverRow(order: o, driver: _drivers[o.driverId], onChanged: _load), const SizedBox(height: 10)],
                      ]),
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _DeliveryMap extends StatelessWidget {
  const _DeliveryMap({required this.orders});
  final List<StaffOrder> orders;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final t = S.of(context);
    final branches = (s.branchId == null ? s.branches : s.branches.where((b) => b.id == s.branchId)).where((b) => b.lat != null && b.lng != null).toList();
    final drivers = orders.where((o) => o.driverLat != null && o.driverLng != null).toList();
    final points = [for (final b in branches) LatLng(b.lat!, b.lng!), for (final o in drivers) LatLng(o.driverLat!, o.driverLng!)];
    if (points.isEmpty) {
      return Row(children: [
        const Icon(Icons.map_outlined, size: 18, color: Brand.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(t.t('mapNoGeo'), style: const TextStyle(color: Brand.muted, fontSize: 13))),
      ]);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          options: points.length > 1
              ? MapOptions(initialCameraFit: CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48), maxZoom: 16))
              : MapOptions(initialCenter: points.first, initialZoom: 14),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'es.latoscana.la_toscana_admin'),
            MarkerLayer(markers: [
              for (final b in branches)
                Marker(
                  point: LatLng(b.lat!, b.lng!),
                  width: 40,
                  height: 40,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Brand.charcoal, shape: BoxShape.circle, boxShadow: Brand.softShadow),
                    child: Icon(Icons.storefront, color: Colors.white, size: 22),
                  ),
                ),
              for (final o in drivers)
                Marker(
                  point: LatLng(o.driverLat!, o.driverLng!),
                  width: 130,
                  height: 74,
                  alignment: Alignment.topCenter,
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Brand.tomato, borderRadius: BorderRadius.circular(8)),
                      child: Text(o.number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                    const SizedBox(height: 4),
                    const DecoratedBox(
                      decoration: BoxDecoration(color: Brand.tomato, shape: BoxShape.circle, boxShadow: Brand.softShadow),
                      child: Padding(padding: EdgeInsets.all(7), child: Icon(Icons.delivery_dining, color: Colors.white, size: 22)),
                    ),
                  ]),
                ),
            ]),
            const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
          ],
        ),
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.order, required this.driver, required this.onChanged});
  final StaffOrder order;
  final Driver? driver;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final o = order;
    final name = o.driverName ?? driver?.name ?? '—';
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final delivered = o.status == 'delivered';
    final since = o.pickedUpAt ?? o.createdAt;
    final seen = o.driverSeenAt == null ? null : DateTime.now().difference(o.driverSeenAt!).inMinutes;
    final phone = driver?.phone;
    return Panel(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailPage(order: o, onChanged: onChanged))),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Brand.tomato.withValues(alpha: 0.12),
          child: Text(initials, style: const TextStyle(color: Brand.tomatoDark, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text('${o.number} · ${delivered ? t.t('deliveredAtTime', {'time': o.deliveredAt == null ? '' : hhmm(o.deliveredAt!)}) : t.driverState(o.driverState ?? 'picked_up')}',
                style: TextStyle(color: delivered ? Brand.basil : Brand.muted, fontSize: 13, fontWeight: delivered ? FontWeight.w600 : FontWeight.w500)),
            if (!delivered)
              Text(seen == null ? t.t('noLocation') : t.t('lastSeen', {'n': seen}), style: const TextStyle(color: Brand.muted, fontSize: 12)),
            if (o.address != null) Text(o.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 12)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (!delivered) Pill(t.t('minutesAgo', {'n': DateTime.now().difference(since).inMinutes}), color: Brand.tomato),
          if (delivered) Pill(DateFormat.Hm().format((o.deliveredAt ?? o.createdAt).toLocal()), color: Brand.basil),
          if (phone != null)
            IconButton(
              tooltip: t.t('call'),
              onPressed: () => launchUrl(Uri.parse('tel:${phone.replaceAll(' ', '')}')),
              icon: const Icon(Icons.call, color: Brand.tomato),
            ),
        ]),
      ]),
    );
  }
}
