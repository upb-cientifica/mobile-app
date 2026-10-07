import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upb_cientifica/data/api_client.dart';
import 'package:upb_cientifica/data/token_store.dart';
import 'package:upb_cientifica/data/servicios/fotos.dart';

class _TokensVacios extends TokenStore {
  @override
  Future<String?> get accessToken async => null;
}

void main() {
  test('PATCH envía los tres campos vacíos para borrar detalles', () async {
    final cliente = ApiClient(
      tokenStore: _TokensVacios(),
      httpClient: MockClient((peticion) async {
        expect(peticion.method, 'PATCH');
        expect(peticion.url.path, endsWith('/imagenes/42'));
        expect(peticion.url.queryParameters, {
          'titulo': '',
          'descripcion': '',
          'etiquetas': '',
        });
        return http.Response(jsonEncode({'id': 42, 'etiquetas': []}), 200);
      }),
    );
    addTearDown(cliente.close);
    final foto = await ServicioFotos(
      cliente,
    ).actualizar('42', titulo: '', descripcion: '', etiquetas: []);
    expect(foto['favorito'], isFalse);
  });

  test('Filtra título, descripción y etiquetas dentro del álbum', () async {
    final cliente = ApiClient(
      tokenStore: _TokensVacios(),
      httpClient: MockClient((peticion) async {
        expect(peticion.url.path, endsWith('/albums/7/imagenes'));
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'titulo': 'CIENCIA',
              'etiquetas': ['favorito'],
            },
            {
              'id': 2,
              'descripcion': 'Ciencia aplicada',
              'etiquetas': ['favorito'],
            },
            {
              'id': 3,
              'etiquetas': ['ciencia', 'favorito'],
            },
            {'id': 4, 'titulo': 'Ciencia', 'etiquetas': []},
            {
              'id': 5,
              'titulo': 'Otro',
              'etiquetas': ['favorito'],
            },
          ]),
          200,
        );
      }),
    );
    addTearDown(cliente.close);
    final fotos = await ServicioFotos(
      cliente,
    ).fotos(albumId: '7', q: ' ciencia ', etiqueta: 'favorito');
    expect(fotos.map((f) => f['id']), ['1', '2', '3']);
  });

  test(
    'Compartir normaliza el correo y mapea los permisos devueltos',
    () async {
      final cliente = ApiClient(
        tokenStore: _TokensVacios(),
        httpClient: MockClient((peticion) async {
          expect(peticion.method, 'POST');
          expect(peticion.url.queryParameters, {
            'correo': 'ana@upb.edu.co',
            'accion': 'grant',
          });
          return http.Response(
            jsonEncode({
              'id': 7,
              'titulo': 'Ensayo',
              'miRol': 'admin',
              'publico': true,
              'urlPublica': 'https://ejemplo.com/album',
              'compartidoCon': ['ana@upb.edu.co'],
            }),
            200,
          );
        }),
      );
      addTearDown(cliente.close);
      final album = await ServicioFotos(
        cliente,
      ).compartir('7', ' ANA ', conceder: true);
      expect(album['rol'], 'admin');
      expect(album['publico'], isTrue);
      expect(album['compartidoCon'], ['ana@upb.edu.co']);
      expect(album['urlPublica'], 'https://ejemplo.com/album');
    },
  );
}
