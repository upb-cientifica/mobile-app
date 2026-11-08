import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/login_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/logo_mark.dart';

/// Pantalla de inicio de sesión. Autentica contra el directorio de usuarios
/// (SOAP) a través del bus, vía [AuthController].
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginController(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  Future<void> _submit(BuildContext context) async {
    final form = context.read<LoginController>();
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.login(
        form.emailController.text,
        form.passwordController.text,
        rememberDevice: form.rememberDevice,
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.error ?? 'No se pudo iniciar sesión')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LoginController>();
    final busy = context.watch<AuthController>().busy;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: MediaQuery.of(context).size.height - 48),
            child: Column(
              children: [
                const SizedBox(height: 16),
                const LogoMark(size: 72, iconSize: 36, radius: 20),
                const SizedBox(height: 20),
                const Text(
                  'Iniciar sesión',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Acceso seguro a la infraestructura UPB',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 40),
                _FieldLabel('Correo institucional'),
                const SizedBox(height: 6),
                TextField(
                  controller: controller.emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    hintText: 'usuario@upb.edu.co',
                    prefixIcon: Icon(Icons.mail_outline, size: 18, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                _FieldLabel('Contraseña'),
                const SizedBox(height: 6),
                TextField(
                  controller: controller.passwordController,
                  obscureText: !controller.showPassword,
                  enabled: !busy,
                  onSubmitted: (_) => _submit(context),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        controller.showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: controller.toggleShowPassword,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    GestureDetector(
                      onTap: controller.toggleRememberDevice,
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: controller.rememberDevice ? AppColors.blue : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: controller.rememberDevice ? AppColors.blue : AppColors.border,
                                width: 2,
                              ),
                            ),
                            child: controller.rememberDevice
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text('Recordar dispositivo', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: busy ? null : () => _submit(context),
                  child: busy
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 40),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  // El sistema no usa TLS: viaja por la red interna del CCA en
                  // claro. Lo que sí protege la sesión es el token firmado
                  // (JWT RS256) que emite el directorio y que cada servicio
                  // verifica por su cuenta. Decir "TLS 1.3" aquí sería mentir.
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: AppColors.blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sesión con token firmado · red interna UPB',
                          style: TextStyle(fontSize: 12, color: AppColors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      ),
    );
  }
}
