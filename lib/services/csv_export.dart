
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

/// Guarda el CSV en una carpeta temporal y abre el menú
/// de compartir/guardar del sistema.
Future<void> compartirCsv(String contenido, String nombre) async {
  final dir = await getTemporaryDirectory();
  final archivo = File('${dir.path}/$nombre');

  await archivo.writeAsString(contenido);

  await Share.shareXFiles(
    [XFile(archivo.path, mimeType: 'text/csv')],
    subject: nombre,
  );
}
