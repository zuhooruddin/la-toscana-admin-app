// Shapes of the admin API (contract 1.3.0) used by the staff app.

typedef Json = Map<String, dynamic>;

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _s(Object? v) => v == null ? '' : '$v';
String? _sn(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
List<Json> _l(Object? v) => v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
Json _m(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
String _loc(Object? v, [String lang = 'es']) => v is Map ? '${v[lang] ?? v['es'] ?? v['en'] ?? ''}' : _s(v);

class Me {
  Me(this.id, this.email, this.name, this.role, this.branchIds, this.mustChangePassword, this.permissions);
  final String id;
  final String email;
  final String? name;
  final String role;
  final List<String> branchIds;
  final bool mustChangePassword;
  final List<String> permissions;
  bool can(String p) => permissions.contains(p);
}

class StaffBranch {
  StaffBranch(this.id, this.name, this.enabled, this.paused, this.pausedUntil,
      {this.imageUrl, this.address = '', this.pickup = true, this.delivery = false, this.lat, this.lng, this.phone});
  factory StaffBranch.fromJson(Json j) {
    final o = _m(j['ordering']);
    final a = _m(j['address']);
    final sv = _m(j['services']);
    return StaffBranch(_s(j['id']), _s(j['name']), o['enabled'] == true, o['paused'] == true, o['pausedUntil'] == null ? null : DateTime.tryParse('${o['pausedUntil']}'),
        imageUrl: _sn(j['imageUrl']),
        address: [a['line1'], [a['postcode'], a['city']].where((x) => x != null && '$x'.isNotEmpty).join(' ')].where((x) => x != null && '$x'.isNotEmpty).join(', '),
        pickup: sv['pickup'] != false,
        delivery: sv['delivery'] == true,
        lat: (_m(j['geo'])['lat'] as num?)?.toDouble(),
        lng: (_m(j['geo'])['lng'] as num?)?.toDouble(),
        phone: _sn(_m(j['contact'])['phone']));
  }
  final String id;
  final String name;
  final bool enabled;
  final bool paused;
  final DateTime? pausedUntil;
  final String? imageUrl;
  final String address;
  final bool pickup;
  final bool delivery;
  final double? lat;
  final double? lng;
  final String? phone;
  bool get isPaused => paused && (pausedUntil == null || pausedUntil!.isAfter(DateTime.now()));
}

class OrderLine {
  OrderLine(this.name, this.quantity, this.options, this.notes, this.lineTotalCents, this.warnings, [this.imageUrl]);
  final String name;
  final int quantity;
  final List<String> options;
  final String? notes;
  final int lineTotalCents;
  final List<String> warnings;
  final String? imageUrl;
}

class OrderEvent {
  OrderEvent(this.status, this.at, this.byRole, this.note);
  final String status;
  final DateTime at;
  final String? byRole;
  final String? note;
}

class StaffOrder {
  StaffOrder({
    required this.id,
    required this.number,
    required this.branchId,
    required this.branchName,
    required this.status,
    required this.type,
    required this.address,
    required this.scheduledFor,
    required this.estimatedReadyAt,
    required this.customerName,
    required this.customerPhone,
    required this.lines,
    required this.totalCents,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.simulated,
    required this.notes,
    required this.ifSoldOut,
    required this.driverName,
    required this.driverState,
    required this.createdAt,
    this.subtotalCents = 0,
    this.discountCents = 0,
    this.deliveryFeeCents = 0,
    this.taxCents = 0,
    this.history = const [],
    this.driverId,
    this.driverLat,
    this.driverLng,
    this.driverSeenAt,
    this.deliveredAt,
    this.pickedUpAt,
  });
  factory StaffOrder.fromJson(Json j) {
    final f = _m(j['fulfilment']);
    final a = _m(f['address']);
    final c = _m(j['customer']);
    final p = _m(j['payment']);
    final d = _m(j['driver']);
    return StaffOrder(
      id: _s(j['id']),
      number: _s(j['number']),
      branchId: _s(j['branchId']),
      branchName: _s(j['branchName']),
      status: _s(j['status']),
      type: _s(f['type']),
      address: a.isEmpty ? null : [a['line1'], a['line2'], [a['postcode'], a['city']].where((x) => x != null).join(' '), a['notes']].where((x) => x != null && '$x'.isNotEmpty).join(', '),
      scheduledFor: f['scheduledFor'] == null ? null : DateTime.tryParse('${f['scheduledFor']}'),
      estimatedReadyAt: f['estimatedReadyAt'] == null ? null : DateTime.tryParse('${f['estimatedReadyAt']}'),
      customerName: _s(c['name']),
      customerPhone: _sn(c['phone']),
      lines: _l(j['lines'])
          .map((l) => OrderLine(_s(l['name']), _i(l['quantity']), _l(l['options']).map((o) => _s(o['choiceName'])).toList(), _sn(l['notes']), _i(l['lineTotalCents']),
              (l['warnings'] as List? ?? const []).map((w) => '$w').toList(), _sn(l['imageUrl'])))
          .toList(),
      totalCents: _i(_m(j['totals'])['totalCents']),
      subtotalCents: _i(_m(j['totals'])['subtotalCents']),
      discountCents: _i(_m(j['totals'])['discountCents']),
      deliveryFeeCents: _i(_m(j['totals'])['deliveryFeeCents']),
      taxCents: _i(_m(j['totals'])['taxCents']),
      history: _l(j['history'])
          .map((h) => OrderEvent(_s(h['status']), DateTime.tryParse(_s(h['at'])) ?? DateTime.now(), _sn(h['byRole']), _sn(h['note'])))
          .toList(),
      paymentMethod: _s(p['method']),
      paymentStatus: _s(p['status']),
      simulated: p['simulated'] == true,
      notes: _sn(j['notes']),
      ifSoldOut: _s(j['ifSoldOut']).isEmpty ? 'contact' : _s(j['ifSoldOut']),
      driverName: _sn(d['name']),
      driverState: _sn(d['state']),
      driverId: _sn(d['userId']),
      driverLat: (_m(d['lastLocation'])['lat'] as num?)?.toDouble(),
      driverLng: (_m(d['lastLocation'])['lng'] as num?)?.toDouble(),
      driverSeenAt: DateTime.tryParse(_s(_m(d['lastLocation'])['at'])),
      deliveredAt: DateTime.tryParse(_s(d['deliveredAt'])),
      pickedUpAt: DateTime.tryParse(_s(d['pickedUpAt'])),
      createdAt: DateTime.tryParse(_s(j['createdAt'])) ?? DateTime.now(),
    );
  }
  final String id;
  final String number;
  final String branchId;
  final String branchName;
  final String status;
  final String type;
  final String? address;
  final DateTime? scheduledFor;
  final DateTime? estimatedReadyAt;
  final String customerName;
  final String? customerPhone;
  final List<OrderLine> lines;
  final int totalCents;
  final String paymentMethod;
  final String paymentStatus;
  final bool simulated;
  final String? notes;
  final String ifSoldOut;
  final String? driverName;
  final String? driverState;
  final DateTime createdAt;
  final int subtotalCents;
  final int discountCents;
  final int deliveryFeeCents;
  final int taxCents;
  final List<OrderEvent> history;
  final String? driverId;
  final double? driverLat;
  final double? driverLng;
  final DateTime? driverSeenAt;
  final DateTime? deliveredAt;
  final DateTime? pickedUpAt;

  /// First dish photo, for the ticket thumbnail.
  String? get imageUrl => lines.map((l) => l.imageUrl).whereType<String>().firstOrNull;

  /// Next step for the kitchen (mirrors the API transition rules).
  String? get next => switch (status) {
        'confirmed' => 'preparing',
        'preparing' => 'ready',
        'ready' => type == 'delivery' ? 'out_for_delivery' : 'picked_up',
        'out_for_delivery' => 'delivered',
        _ => null,
      };
  bool get cancellable => const ['confirmed', 'preparing', 'ready'].contains(status);
}

class AvailabilityRow {
  AvailabilityRow(this.itemId, this.name, this.categoryKey, this.available, this.soldOut, {this.priceCents = 0, this.imageUrl});
  factory AvailabilityRow.fromJson(Json j, String lang) => AvailabilityRow(_s(j['itemId']), _loc(j['name'], lang), _s(j['categoryKey']), j['available'] == true, j['soldOut'] == true,
      priceCents: j['priceCentsOverride'] == null ? _i(j['basePriceCents']) : _i(j['priceCentsOverride']), imageUrl: _sn(j['imageUrl']));
  final String itemId;
  final String name;
  final String categoryKey;
  final bool available;
  bool soldOut;
  final int priceCents;
  final String? imageUrl;
}

class MenuCategory {
  MenuCategory(this.key, this.name);
  factory MenuCategory.fromJson(Json j, String lang) => MenuCategory(_s(j['key']), _loc(j['name'], lang));
  final String key;
  final String name;
}

class Booking {
  Booking(this.id, this.time, this.partySize, this.name, this.phone, this.notes, this.status);
  factory Booking.fromJson(Json j) => Booking(_s(j['_id']), _s(j['time']), _i(j['partySize']), _s(j['name']), _s(j['phone']), _sn(j['notes']), _s(j['status']));
  final String id;
  final String time;
  final int partySize;
  final String name;
  final String phone;
  final String? notes;
  final String status;
}

class HourStat {
  HourStat(this.hour, this.orders, this.netCents);
  final int hour;
  final int orders;
  final int netCents;
}

class DayStat {
  DayStat(this.date, this.orders, this.netCents);
  final DateTime date;
  final int orders;
  final int netCents;
}

class TopItem {
  TopItem(this.name, this.quantity, this.revenueCents);
  final String name;
  final int quantity;
  final int revenueCents;
}

class Driver {
  Driver(this.id, this.name, this.phone);
  factory Driver.fromJson(Json j) => Driver(_s(j['id']), _s(j['name']), _sn(j['phone']));
  final String id;
  final String name;
  final String? phone;
}

class Customer {
  Customer(this.id, this.name, this.email, this.phone, this.orders, this.totalCents, this.lastOrderAt, this.status);
  factory Customer.fromJson(Json j) {
    final o = _m(j['orders']);
    return Customer(_s(j['id']), _s(j['name']), _s(j['email']), _sn(j['phone']), _i(o['count']), _i(o['totalCents']), DateTime.tryParse(_s(o['lastAt'])), _s(j['status']));
  }
  final String id;
  final String name;
  final String email;
  final String? phone;
  final int orders;
  final int totalCents;
  final DateTime? lastOrderAt;
  final String status;
}

class Summary {
  Summary(this.orders, this.netCents, this.averageTicketCents, this.simulatedCents,
      {this.day,
      this.byStatus = const {},
      this.byHour = const [],
      this.byDay = const [],
      this.topItems = const [],
      this.byPayment = const [],
      this.deliveryShare = 0,
      this.newCustomers,
      this.prevOrders,
      this.prevNetCents,
      this.prevAverageTicketCents});
  factory Summary.fromJson(Json j) {
    final p = j['previous'] is Map ? _m(j['previous']) : null;
    return Summary(_i(j['orders']), _i(j['netCents']), _i(j['averageTicketCents']), _i(j['simulatedCents']),
        day: DateTime.tryParse(_s(_m(j['range'])['from'])),
        byStatus: _m(j['byStatus']).map((k, v) => MapEntry(k, _i(v))),
        byHour: _l(j['byHour']).map((h) => HourStat(_i(h['hour']), _i(h['orders']), _i(h['netCents']))).toList(),
        byDay: _l(j['byDay']).map((d) => DayStat(DateTime.tryParse(_s(d['date'])) ?? DateTime.now(), _i(d['orders']), _i(d['netCents']))).toList(),
        topItems: _l(j['topItems']).map((i) => TopItem(_s(i['name']), _i(i['quantity']), _i(i['revenueCents']))).toList(),
        byPayment: _l(j['byPayment']).map((p) => (method: _s(p['method']), count: _i(p['count']), cents: _i(p['cents']))).toList(),
        deliveryShare: (j['deliveryShare'] as num?)?.toDouble() ?? 0,
        newCustomers: j['newCustomers'] == null ? null : _i(j['newCustomers']),
        prevOrders: p == null ? null : _i(p['orders']),
        prevNetCents: p == null ? null : _i(p['netCents']),
        prevAverageTicketCents: p == null ? null : _i(p['averageTicketCents']));
  }
  final int orders;
  final int netCents;
  final int averageTicketCents;
  final int simulatedCents;
  /// Business day (Europe/Madrid) the figures belong to; may differ from the device's date.
  final DateTime? day;
  final Map<String, int> byStatus;
  /// Empty when the API predates hourly figures.
  final List<HourStat> byHour;
  final List<DayStat> byDay;
  final List<TopItem> topItems;
  final List<({String method, int count, int cents})> byPayment;
  final double deliveryShare;
  /// Only for roles that may read customers.
  final int? newCustomers;
  /// Same span yesterday up to this time of day; null when the API predates comparisons.
  final int? prevOrders;
  final int? prevNetCents;
  final int? prevAverageTicketCents;
}
