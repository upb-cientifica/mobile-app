import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upb_cientifica/data/api_client.dart';
import 'package:upb_cientifica/data/api_exception.dart';
import 'package:upb_cientifica/data/servicios/archivos.dart';
import 'package:upb_cientifica/data/token_store.dart';

class _Tokens extends TokenStore {
  @override
  Future<String?> get accessToken async => 'tok-prueba';
}

ServicioArchivos _servicio(Future<http.Response> Function(http.Request) responder) {
  final cliente = ApiClient(tokenStore: _Tokens(), httpClient: MockClient(responder));
  addTearDown(cliente.close);
  return ServicioArchivos(cliente);
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('upb-descarga'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('Descargar guarda el cuerpo completo (un ZIP de carpeta) con el token y sin propietario vacío', () async {
    final zip = List<int>.generate(300000, (i) => i % 251);
    late http.Request vista;
    final destino = File('${tmp.path}/Proyecto.zip');
    await _servicio((peticion) async {
      vista = peticion;
      return http.Response.bytes(zip, 200, headers: {'content-type': 'application/zip'});
    }).descargar('/Ñandú/Proyecto', destino);

    expect(vista.method, 'GET');
    expect(vista.url.path, endsWith('/files/download'));
    expect(vista.url.queryParameters, {'ruta': '/Ñandú/Proyecto'});
    expect(vista.headers['authorization'], 'Bearer tok-prueba');
    expect(await destino.readAsBytes(), zip);
  });

  test('Descargar de un archivo compartido pide el Home de su propietario', () async {
    late Map<String, String> consulta;
    await _servicio((peticion) async {
      consulta = peticion.url.queryParameters;
      return http.Response('hola', 200);
    }).descargar('/datos.csv', File('${tmp.path}/datos.csv'), propietario: 'luis@upb.edu.co');
    expect(consulta, {'ruta': '/datos.csv', 'propietario': 'luis@upb.edu.co'});
  });

  test('Si el servicio rechaza la descarga, el error trae su mensaje y no queda archivo a medias', () async {
    final destino = File('${tmp.path}/x.bin');
    await expectLater(
      _servicio((_) async => http.Response(
            jsonEncode({'error': {'codigo': 'PROHIBIDO', 'mensaje': 'sin permiso de lectura'}}),
            403,
          )).descargar('/x.bin', destino),
      throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje', 'sin permiso de lectura')),
    );
    expect(destino.existsSync(), isFalse);
  });

  test('Eliminar definitivamente manda definitivo=true; mover a la papelera no', () async {
    final consultas = <Map<String, String>>[];
    final servicio = _servicio((peticion) async {
      expect(peticion.method, 'DELETE');
      consultas.add(peticion.url.queryParameters);
      return http.Response(jsonEncode({'data': {'ok': true}}), 200);
    });
    await servicio.eliminar('/Viejo');
    await servicio.eliminar('/Viejo', definitivo: true);
    expect(consultas, [
      {'ruta': '/Viejo'},
      {'ruta': '/Viejo', 'definitivo': 'true'},
    ]);
  });

  test('La papelera se lista con seccion=papelera y trae las carpetas con su ruta', () async {
    final servicio = _servicio((peticion) async {
      if (peticion.url.path.contains('/file_sync/')) return http.Response('[]', 200);
      expect(peticion.url.queryParameters, {'seccion': 'papelera'});
      return http.Response(
        jsonEncode({
          'data': {
            'carpetas': [
              {'ruta': '/Viejo', 'nombre': 'Viejo', 'esCarpeta': true, 'enPapelera': true},
            ],
            'archivos': [
              {'ruta': '/a.txt', 'nombre': 'a.txt', 'tipo': 'documento', 'tamanoBytes': 3, 'enPapelera': true},
            ],
          },
        }),
        200,
      );
    });
    final c = await servicio.seccion('papelera');
    expect(c.carpetas.map((f) => f['ruta']), ['/Viejo']);
    expect(c.archivos.map((f) => f['id']), ['/a.txt']);
  });

  test('Restaurar llama a /files/restaurar con la ruta', () async {
    late http.Request vista;
    await _servicio((peticion) async {
      vista = peticion;
      return http.Response(jsonEncode({'data': {}}), 200);
    }).restaurar('/Viejo');
    expect(vista.method, 'POST');
    expect(vista.url.path, endsWith('/files/restaurar'));
    expect(vista.url.queryParameters, {'ruta': '/Viejo'});
  });
}
