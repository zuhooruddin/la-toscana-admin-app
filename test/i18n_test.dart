import 'package:flutter_test/flutter_test.dart';
import 'package:la_toscana_admin/core/i18n.dart';

void main() {
  test('every Spanish string has an English translation', () {
    expect(S.missingEnglish, isEmpty);
  });

  test('fills placeholders and translates API codes', () {
    final en = S('en');
    expect(en.t('minutesAgo', {'n': 12}), '12 min ago');
    expect(S('es').t('minutesAgo', {'n': 12}), 'hace 12 min');
    expect(en.payment('unpaid'), 'not paid');
    expect(en.driverState('picked_up'), 'on the way');
    expect(en.status('something_new'), 'something_new');
  });
}
