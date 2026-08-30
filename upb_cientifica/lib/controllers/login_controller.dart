import 'package:flutter/material.dart';

/// Controlador de la pantalla de inicio de sesión.
class LoginController extends ChangeNotifier {
  final TextEditingController emailController =
      TextEditingController(text: 'stiven.pabon@upb.edu.co');
  final TextEditingController passwordController = TextEditingController();

  bool _showPassword = false;
  bool _rememberDevice = false;

  bool get showPassword => _showPassword;
  bool get rememberDevice => _rememberDevice;

  void toggleShowPassword() {
    _showPassword = !_showPassword;
    notifyListeners();
  }

  void toggleRememberDevice() {
    _rememberDevice = !_rememberDevice;
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
