/// Ayudas para leer lo que devuelve el bus.
///
/// El bus normaliza la envoltura, pero no puede normalizar la forma: el
/// Servicio de Usuarios habla SOAP, y en XML **un elemento que aparece una sola
/// vez es indistinguible de una lista de un elemento**. El traductor del bus lo
/// refleja con honestidad: devuelve un arreglo cuando hay varios y un valor
/// suelto cuando hay uno. Estas funciones absorben esa diferencia para que
/// ningún modelo de la app tenga que conocerla.
library;

/// Interpreta [v] como lista de objetos, venga como arreglo, como objeto suelto
/// o como null.
List<Map<String, dynamic>> comoLista(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  if (v is Map) return [Map<String, dynamic>.from(v)];
  return const [];
}

/// Interpreta [v] como objeto; devuelve un mapa vacío si no lo es.
Map<String, dynamic> comoMapa(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Extrae de [d] la lista que vive bajo alguna de [claves].
///
/// El traductor del bus destapa el envoltorio cuando la respuesta trae un único
/// elemento con contenido. Eso ayuda casi siempre, pero en una colección de un
/// solo elemento el envoltorio *es* ese elemento: la respuesta llega como el
/// objeto suelto y ninguna de las claves aparece. Cuando eso pasa, lo correcto
/// es leerlo como una lista de uno, no como una lista vacía.
List<Map<String, dynamic>> listaDesde(dynamic d, List<String> claves) {
  if (d is List) return comoLista(d);
  if (d is! Map) return const [];
  for (final k in claves) {
    if (d.containsKey(k)) return comoLista(d[k]);
  }
  return d.isEmpty ? const [] : [Map<String, dynamic>.from(d)];
}

/// Interpreta [v] como lista de cadenas (etiquetas, códigos de servicio…).
List<String> comoTextos(dynamic v) {
  if (v is List) return v.map((e) => '$e').where((s) => s.isNotEmpty).toList();
  if (v == null) return const [];
  final s = '$v';
  return s.isEmpty ? const [] : [s];
}

/// Entero tolerante: el traductor SOAP entrega los números como texto.
int comoEntero(dynamic v, [int porDefecto = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? porDefecto;
  return porDefecto;
}

/// Decimal tolerante, con el mismo criterio que [comoEntero].
double comoDecimal(dynamic v, [double porDefecto = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? porDefecto;
  return porDefecto;
}

/// Booleano tolerante: acepta `true`, `"true"` y `"1"`.
bool comoBool(dynamic v) {
  if (v is bool) return v;
  final s = '$v'.trim().toLowerCase();
  return s == 'true' || s == '1';
}
