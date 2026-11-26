import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Guarda el CSV en una carpeta temporal y abre el menú de compartir/guardar
/// del sistema (solo Android/iOS).
Future<void> compartirCsv(String contenido, String nombre) async {
  final dir = await getTemporaryDirectory();
  final archivo = File('${dir.path}/$nombre');
  await archivo.writeAsString(contenido);
  await Share.shareFiles(
    [archivo.path],
    mimeTypes: ['text/csv'],
    subject: nombre,
  );
}