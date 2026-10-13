// Shapes of the admin API (contract 1.3.0) used by the staff app.

typedef Json = Map<String, dynamic>;

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _s(Object? v) => v == null ? '' : '$v';
String? _sn(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
List<Json> _l(Object? v) => v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
Json _m(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
String _loc(Object? v) => v is Map ? '${v['es'] ?? v['en'] ?? ''}' : _s(v);

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
  StaffBranch(this.id, this.name, this.enabled, this.paused, this.pausedUntil);
  factory StaffBranch.fromJson(Json j) {
    final o = _m(j['ordering']);
    return StaffBranch(_s(j['id']), _s(j['name']), o['enabled'] == true, o['paused'] == true, o['pausedUntil'] == null ? null : DateTime.tryParse('${o['pausedUntil']}'));
  }
  final String id;
  final String name;
  final bool enabled;
  final bool paused;
  final DateTime? pausedUntil;
  bool get isPaused => paused && (pausedUntil == null || pausedUntil!.isAfter(DateTime.now()));
}

class OrderLine {
  OrderLine(this.name, this.quantity, this.options, this.notes, this.lineTotalCents, this.warnings);
  final String name;
  final int quantity;
  final List<String> options;
  final String? notes;
  final int lineTotalCents;
  final List<String> warnings;
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
              (l['warnings'] as List? ?? const []).map((w) => '$w').toList()))
          .toList(),
      totalCents: _i(_m(j['totals'])['totalCents']),
      paymentMethod: _s(p['method']),
      paymentStatus: _s(p['status']),
      simulated: p['simulated'] == true,
      notes: _sn(j['notes']),
      ifSoldOut: _s(j['ifSoldOut']).isEmpty ? 'contact' : _s(j['ifSoldOut']),
      driverName: _sn(d['name']),
      driverState: _sn(d['state']),
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
  AvailabilityRow(this.itemId, this.name, this.categoryKey, this.available, this.soldOut);
  factory AvailabilityRow.fromJson(Json j) => AvailabilityRow(_s(j['itemId']), _loc(j['name']), _s(j['categoryKey']), j['available'] == true, j['soldOut'] == true);
  final String itemId;
  final String name;
  final String categoryKey;
  final bool available;
  bool soldOut;
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

class Summary {
  Summary(this.orders, this.netCents, this.averageTicketCents, this.simulatedCents);
  factory Summary.fromJson(Json j) => Summary(_i(j['orders']), _i(j['netCents']), _i(j['averageTicketCents']), _i(j['simulatedCents']));
  final int orders;
  final int netCents;
  final int averageTicketCents;
  final int simulatedCents;
}

const statusLabel = {
  'pending_payment': 'Pendiente de pago',
  'confirmed': 'Nuevo',
  'preparing': 'En preparación',
  'ready': 'Listo',
  'out_for_delivery': 'En reparto',
  'picked_up': 'Recogido',
  'delivered': 'Entregado',
  'cancelled': 'Cancelado',
  'refunded': 'Reembolsado',
};
const actionLabel = {
  'preparing': 'Empezar a preparar',
  'ready': 'Marcar listo',
  'picked_up': 'Entregado al cliente',
  'out_for_delivery': 'Salió a reparto',
  'delivered': 'Marcar entregado',
};
const ifSoldOutLabel = {
  'contact': 'Contactar con el cliente',
  'substitute': 'Seguir la recomendación del restaurante',
  'refund_item': 'Quitar ese producto',
  'cancel_order': 'Cancelar todo el pedido',
};
