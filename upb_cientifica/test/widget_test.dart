// Prueba de humo: la app arranca, resuelve la sesión y muestra el login.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:upb_cientifica/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // El almacén seguro no tiene backend en las pruebas: se simula vacío.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Arranca en splash y navega al login sin sesión', (tester) async {
    await tester.pumpWidget(const UpbCientificaApp());

    // Splash inicial.
    expect(find.text('UPB Científica'), findsOneWidget);

    // Tras bootstrap() (sin sesión) debe mostrarse el inicio de sesión.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('Acceso seguro a la infraestructura UPB'), findsOneWidget);
  });
}
