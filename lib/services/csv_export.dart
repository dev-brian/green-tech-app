
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


Future<void> compartirCsv(String contenido, String nombre) async {
  final dir = await getTemporaryDirectory();
  final archivo = File('${dir.path}/$nombre');

  await archivo.writeAsString(contenido);

await SharePlus.instance.share(
  ShareParams(
    files: [
      XFile(archivo.path, mimeType: 'text/csv'),
    ],
    subject: nombre,
  ),
);
}
