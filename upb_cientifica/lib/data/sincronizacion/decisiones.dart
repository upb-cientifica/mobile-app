bool debeSubir(String? local, String? previo) =>
    local != null && local != previo;

bool debeBajar({
  required bool sinCopiaLocal,
  required String? local,
  required String? previo,
  required int base,
  required int version,
  required String remoto,
}) =>
    (!sinCopiaLocal || local != null) &&
    version > base &&
    (local == null ? previo == null : local == previo || local == remoto);

bool debeBorrarLocal(String? local, String? previo) =>
    local != null && previo != null && local == previo;

bool rutaSegura(String ruta) =>
    ruta.isNotEmpty &&
    !ruta.contains('\\') &&
    !ruta.contains(':') &&
    ruta.split('/').every((p) => p.isNotEmpty && p != '.' && p != '..');
