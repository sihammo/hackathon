import 'package:flutter_test/flutter_test.dart';
import 'package:solvex_alert/core/constants.dart';
import 'package:solvex_alert/core/l10n.dart';
import 'package:solvex_alert/core/wilayas.dart';

void main() {
  test('Arabic and French define the same strings', () {
    expect(AppStrings.arKeys, equals(AppStrings.frKeys));
  });

  test('58 wilayas with consecutive codes', () {
    expect(Wilayas.all.length, 58);
    for (var i = 0; i < Wilayas.all.length; i++) {
      expect(Wilayas.all[i].code, i + 1);
    }
  });

  test('nearest wilaya and name matching', () {
    expect(Wilayas.nearest(36.75, 3.06).code, 16); // Alger
    expect(Wilayas.nearest(35.70, -0.63).code, 31); // Oran
    expect(Wilayas.matchName("Wilaya de Béjaïa")?.code, 6);
    expect(Wilayas.matchName('ولاية وهران')?.code, 31);
  });

  test('status flow', () {
    expect(AlertStatus.next(AlertStatus.sent), AlertStatus.received);
    expect(AlertStatus.next(AlertStatus.arrived), AlertStatus.resolved);
    expect(AlertStatus.next(AlertStatus.resolved), isNull);
  });
}
