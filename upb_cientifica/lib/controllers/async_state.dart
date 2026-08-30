import 'package:flutter/foundation.dart';

import '../data/api_exception.dart';

/// Estado de carga compartido por los controladores que leen del BFF.
mixin AsyncState on ChangeNotifier {
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;

  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;

  /// Ejecuta [action] gestionando `loading`/`error` y notificando a la vista.
  Future<void> run(Future<void> Function() action, {bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      await action();
    } on ApiException catch (e) {
      _error = e.mensaje;
    } catch (e) {
      _error = 'Ocurrió un error inesperado.';
    } finally {
      _loading = false;
      _loadedOnce = true;
      notifyListeners();
    }
  }
}
