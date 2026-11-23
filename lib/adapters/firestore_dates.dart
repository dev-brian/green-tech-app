import 'package:cloud_firestore/cloud_firestore.dart';

/// Fechas de Firestore: el backend escribe `Timestamp`, pero algunos campos
/// viejos (y la caché local de la app) vienen como texto ISO 8601.
DateTime? parseFecha(Object? raw) => switch (raw) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      String s => DateTime.tryParse(s)?.toLocal(),
      _ => null,
    };
