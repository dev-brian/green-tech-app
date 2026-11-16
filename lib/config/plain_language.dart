import '../models/zone_status.dart';

/// Textos en lenguaje de productor para el inicio "sencillo primero"
/// (SKILL.md de la PWA, skill greentech-invernadero-ui). Son los mismos que
/// usa la PWA en src/lib/plainLanguage.ts; si cambian, cambian en ambos.
///
/// La app NO decide si un valor está bien o mal: el nivel lo manda el
/// backend. La banda ideal por defecto solo sirve para elegir el texto "alto" o "bajo".
class Consejo {
  const Consejo({
    required this.titulo,
    required this.significa,
    required this.hacesTu,
    this.sistema,
  });

  final String titulo;
  final String significa;
  final String hacesTu;

  /// Lo que el sistema hace solo, si aplica.
  final String? sistema;
}

class _VariableTexto {
  const _VariableTexto({
    required this.nombre,
    required this.idealMin,
    required this.idealMax,
    required this.alto,
    required this.bajo,
  });

  /// Nombre simple, p. ej. "Acidez (pH)".
  final String nombre;

  /// Banda ideal por defecto (la misma de la PWA), solo para elegir texto.
  final double idealMin;
  final double idealMax;
  final Consejo alto;
  final Consejo bajo;
}

const Map<HydroVariable, _VariableTexto> _textos = {
  HydroVariable.airTemp: _VariableTexto(
    nombre: 'Temperatura',
    idealMin: 18,
    idealMax: 28,
    alto: Consejo(
      titulo: 'Hace demasiado calor',
      significa:
          'Con calor las plantas se estresan y gastan más agua; la lechuga puede espigarse.',
      sistema: 'La ventilación se enciende sola para refrescar.',
      hacesTu: 'Abre ventilas o pon sombra en las horas de más sol.',
    ),
    bajo: Consejo(
      titulo: 'Hace demasiado frío',
      significa: 'Con frío las plantas crecen más lento.',
      hacesTu:
          'Cierra ventilas, sobre todo en la noche, y revisa que no entren corrientes.',
    ),
  ),
  HydroVariable.humidity: _VariableTexto(
    nombre: 'Humedad',
    idealMin: 55,
    idealMax: 80,
    alto: Consejo(
      titulo: 'Hay demasiada humedad en el aire',
      significa: 'Con tanta humedad aparecen hongos en las hojas.',
      sistema: 'La ventilación ayuda a sacar el aire húmedo.',
      hacesTu: 'Ventila el invernadero y evita mojar el piso.',
    ),
    bajo: Consejo(
      titulo: 'El aire está muy seco',
      significa: 'Las plantas pierden agua más rápido y se marchitan.',
      hacesTu: 'Moja los pasillos o usa nebulización si la hay.',
    ),
  ),
  HydroVariable.light: _VariableTexto(
    nombre: 'Luz',
    idealMin: 8000,
    idealMax: 35000,
    alto: Consejo(
      titulo: 'Hay demasiada luz',
      significa: 'El exceso de sol puede quemar las hojas.',
      hacesTu: 'Pon malla sombra en las horas de más sol.',
    ),
    bajo: Consejo(
      titulo: 'Hay poca luz',
      significa: 'Con poca luz las plantas crecen débiles y alargadas.',
      hacesTu: 'Revisa que nada tape el techo y limpia los plásticos.',
    ),
  ),
  HydroVariable.ph: _VariableTexto(
    nombre: 'Acidez (pH)',
    idealMin: 5.5,
    idealMax: 6.5,
    alto: Consejo(
      titulo: 'El agua está demasiado alcalina',
      significa:
          'Las raíces absorben menos hierro y otros nutrientes; las hojas nuevas pueden ponerse amarillas.',
      sistema: 'La dosificadora de pH lo corrige sola.',
      hacesTu:
          'Revisa en 30 minutos. Si no baja, mide el pH a mano y revisa que quede ácido en el depósito.',
    ),
    bajo: Consejo(
      titulo: 'El agua está demasiado ácida',
      significa: 'Las raíces se dañan y absorben mal el calcio y el magnesio.',
      sistema: 'La dosificadora de pH lo corrige sola.',
      hacesTu:
          'Revisa en 30 minutos. Si no sube, mide el pH a mano y revisa el depósito de regulador.',
    ),
  ),
  HydroVariable.ec: _VariableTexto(
    nombre: 'Nutrientes (EC)',
    idealMin: 1.2,
    idealMax: 2.4,
    alto: Consejo(
      titulo: 'El agua lleva demasiados nutrientes',
      significa: 'El exceso de sales quema las puntas de las hojas.',
      hacesTu: 'Agrega agua limpia al tanque para diluir la solución.',
    ),
    bajo: Consejo(
      titulo: 'El agua lleva pocos nutrientes',
      significa: 'Las plantas no tienen suficiente alimento y se ven pálidas.',
      sistema: 'La dosificadora de nutrientes agrega solución sola.',
      hacesTu:
          'Si no sube en una hora, revisa que quede nutriente en el depósito.',
    ),
  ),
  HydroVariable.solutionTemp: _VariableTexto(
    nombre: 'Temperatura del agua',
    idealMin: 18,
    idealMax: 24,
    alto: Consejo(
      titulo: 'El agua está muy caliente',
      significa:
          'El agua caliente lleva menos oxígeno y las raíces se pueden pudrir.',
      hacesTu: 'Pon sombra sobre el tanque o agrega agua fresca.',
    ),
    bajo: Consejo(
      titulo: 'El agua está muy fría',
      significa: 'Las raíces absorben los nutrientes más despacio.',
      hacesTu: 'Tapa o aísla el tanque.',
    ),
  ),
  HydroVariable.tankLevel: _VariableTexto(
    nombre: 'Agua en el tanque',
    idealMin: 40,
    idealMax: 100,
    alto: Consejo(
      titulo: 'El tanque está demasiado lleno',
      significa: 'Se puede desbordar y perder solución.',
      hacesTu: 'Revisa que el relleno no se haya quedado abierto.',
    ),
    bajo: Consejo(
      titulo: 'Queda poca agua en el tanque',
      significa:
          'Si baja más, la bomba puede quedarse sin agua y las raíces se secan.',
      hacesTu: 'Rellena el tanque con solución preparada.',
    ),
  ),
};

/// Nombre simple de la variable ("Acidez (pH)", "Agua en el tanque").
String nombreSimple(HydroVariable v) => _textos[v]!.nombre;

/// Consejo para [v] con lectura [value]: "alto" o "bajo" según la banda
/// ideal por defecto.
Consejo consejoPara(HydroVariable v, double value) {
  final t = _textos[v]!;
  final bool alto;
  if (value > t.idealMax) {
    alto = true;
  } else if (value < t.idealMin) {
    alto = false;
  } else {
    alto = value >= (t.idealMin + t.idealMax) / 2;
  }
  return alto ? t.alto : t.bajo;
}
