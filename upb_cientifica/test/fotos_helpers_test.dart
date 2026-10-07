import 'package:flutter_test/flutter_test.dart';
import 'package:upb_cientifica/data/servicios/fotos.dart';

void main() {
  test(
    'Normaliza usuarios y valida exclusivamente el dominio institucional',
    () {
      expect(normalizarCorreo('  ANA.PEREZ '), 'ana.perez@upb.edu.co');
      expect(normalizarCorreo(' ANA@UPB.EDU.CO '), 'ana@upb.edu.co');
      expect(normalizarCorreo(''), '');
      expect(correoInstitucionalValido('ana'), isTrue);
      expect(correoInstitucionalValido('ana@otro.co'), isFalse);
      expect(correoInstitucionalValido('ana@upb.edu.co.ejemplo.com'), isFalse);
      expect(correoInstitucionalValido('ana perez'), isFalse);
      expect(correoInstitucionalValido(''), isFalse);
    },
  );
  test(
    'Limpia etiquetas, elimina vacías y duplicadas y permite borrar todas',
    () {
      expect(analizarEtiquetas(' Ciencia, favorito,CIENCIA, , Laboratorio '), [
        'ciencia',
        'favorito',
        'laboratorio',
      ]);
      expect(analizarEtiquetas(' , '), isEmpty);
    },
  );
}
