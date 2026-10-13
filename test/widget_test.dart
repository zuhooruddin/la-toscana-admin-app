import 'package:flutter_test/flutter_test.dart';
import 'package:la_toscana_admin/models.dart';

StaffOrder _order(String status, String type) => StaffOrder.fromJson({
      'id': 'o1',
      'number': 'BAR-261013-001',
      'branchId': 'b1',
      'status': status,
      'fulfilment': {'type': type, 'address': type == 'delivery' ? {'line1': 'Calle Mayor 1', 'postcode': '22300', 'city': 'Barbastro'} : null},
      'customer': {'name': 'Laura', 'phone': '+34 600 000 000'},
      'lines': [
        {
          'name': 'Salmonera',
          'quantity': 1,
          'options': [
            {'choiceName': 'Gambas'},
          ],
          'lineTotalCents': 1690,
        },
      ],
      'totals': {'totalCents': 1690},
      'payment': {'method': 'cash', 'status': 'unpaid'},
      'createdAt': '2026-10-13T12:00:00Z',
    });

void main() {
  test('kitchen flow mirrors the API transitions (pickup vs delivery)', () {
    expect(_order('confirmed', 'pickup').next, 'preparing');
    expect(_order('preparing', 'pickup').next, 'ready');
    expect(_order('ready', 'pickup').next, 'picked_up');
    expect(_order('ready', 'delivery').next, 'out_for_delivery');
    expect(_order('out_for_delivery', 'delivery').next, 'delivered');
    expect(_order('picked_up', 'pickup').next, isNull);
    expect(_order('ready', 'pickup').cancellable, isTrue);
    expect(_order('out_for_delivery', 'delivery').cancellable, isFalse);
  });

  test('parses the staff order view', () {
    final o = _order('confirmed', 'delivery');
    expect(o.lines.single.options, ['Gambas']);
    expect(o.address, 'Calle Mayor 1, 22300 Barbastro');
    expect(o.ifSoldOut, 'contact');
  });
}
