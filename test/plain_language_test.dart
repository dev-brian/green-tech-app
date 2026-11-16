import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/config/plain_language.dart';
import 'package:greentech_app/models/zone_status.dart';

void main() {
  test('elige el texto "alto" o "bajo" según la banda ideal', () {
    expect(consejoPara(HydroVariable.ph, 7.2).titulo,
        'El agua está demasiado alcalina');
    expect(consejoPara(HydroVariable.ph, 4.9).titulo,
        'El agua está demasiado ácida');
    expect(consejoPara(HydroVariable.tankLevel, 20).titulo,
        'Queda poca agua en el tanque');
  });

  test('todas las variables tienen nombre y qué hacer', () {
    for (final v in HydroVariable.values) {
      expect(nombreSimple(v), isNotEmpty);
      expect(consejoPara(v, 0).hacesTu, isNotEmpty);
      expect(consejoPara(v, 1e9).hacesTu, isNotEmpty);
    }
  });
}
