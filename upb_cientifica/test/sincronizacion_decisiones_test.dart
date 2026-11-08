import 'package:flutter_test/flutter_test.dart';
import 'package:upb_cientifica/data/sincronizacion/decisiones.dart';

void main() {
  test('Sube archivos nuevos y modificados; no sube ausentes o iguales', () {
    expect(debeSubir('nuevo', null), isTrue);
    expect(debeSubir('nuevo', 'viejo'), isTrue);
    expect(debeSubir('igual', 'igual'), isFalse);
    expect(debeSubir(null, 'viejo'), isFalse);
  });
  bool bajar({
    bool sinCopia = false,
    String? local,
    String? previo,
    int base = 0,
    int version = 2,
    String remoto = 'servidor',
  }) => debeBajar(
    sinCopiaLocal: sinCopia,
    local: local,
    previo: previo,
    base: base,
    version: version,
    remoto: remoto,
  );
  test(
    'Copia completa descarga nuevos; modo selectivo solo los existentes',
    () {
      expect(bajar(), isTrue);
      expect(bajar(sinCopia: true), isFalse);
      expect(bajar(sinCopia: true, local: 'viejo', previo: 'viejo'), isTrue);
    },
  );
  test('Nunca pisa cambios sin subir, incluso archivos desconocidos', () {
    expect(bajar(local: 'nuevo', previo: 'viejo'), isFalse);
    expect(bajar(local: 'nuevo'), isFalse);
    expect(bajar(local: 'servidor'), isTrue);
  });
  test('No restaura un borrado local pendiente ni retrocede de versión', () {
    expect(bajar(previo: 'viejo'), isFalse);
    expect(bajar(local: 'viejo', previo: 'viejo', base: 2), isFalse);
    expect(bajar(local: 'viejo', previo: 'viejo', base: 3), isFalse);
  });
  test('Una tumba solo borra una copia conocida sin cambios', () {
    expect(debeBorrarLocal('igual', 'igual'), isTrue);
    expect(debeBorrarLocal('nuevo', 'viejo'), isFalse);
    expect(debeBorrarLocal('nuevo', null), isFalse);
    expect(debeBorrarLocal(null, 'viejo'), isFalse);
  });
  test('Las rutas no pueden escapar de la carpeta sincronizada', () {
    expect(rutaSegura('carpeta/archivo.txt'), isTrue);
    for (final ruta in [
      '',
      '/etc/passwd',
      '../archivo',
      'a/../b',
      'a//b',
      'a/./b',
      r'a\b',
      'C:/archivo',
    ]) {
      expect(rutaSegura(ruta), isFalse, reason: ruta);
    }
  });
}
