import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/network_controller.dart';
import 'core/navigation/navigation_controller.dart';
import 'core/navigation/screen.dart';
import 'core/theme/app_theme.dart';
import 'views/screens/admin_screen.dart';
import 'views/screens/alerts_screen.dart';
import 'views/screens/create_job_screen.dart';
import 'views/screens/dashboard_screen.dart';
import 'views/screens/file_detail_screen.dart';
import 'views/screens/files_screen.dart';
import 'views/screens/hpc_jobs_screen.dart';
import 'views/screens/job_detail_screen.dart';
import 'views/screens/login_screen.dart';
import 'views/screens/mfa_screen.dart';
import 'views/screens/photo_album_screen.dart';
import 'views/screens/profile_screen.dart';
import 'views/screens/splash_screen.dart';
import 'views/screens/streaming_screen.dart';
import 'views/screens/sync_screen.dart';
import 'views/screens/video_player_screen.dart';
import 'views/widgets/bottom_nav.dart';
import 'views/widgets/top_bar.dart';

/// Raíz de la aplicación UPB Científica. La etapa de autenticación decide entre
/// splash / login / MFA / shell; dentro del shell, `NavigationController`
/// gobierna la pantalla activa.
class UpbCientificaApp extends StatelessWidget {
  const UpbCientificaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()..bootstrap()),
        ChangeNotifierProvider(create: (_) => NavigationController()),
        ChangeNotifierProxyProvider<AuthController, NetworkController>(
          create: (ctx) => NetworkController(
              Provider.of<AuthController>(ctx, listen: false).api)
            ..start(),
          update: (_, _, prev) => prev!,
        ),
      ],
      child: MaterialApp(
        title: 'UPB Científica',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<AuthController>().stage;
    return switch (stage) {
      AuthStage.comprobando => const SplashScreen(),
      AuthStage.desconectado => const LoginScreen(),
      AuthStage.mfaPendiente => const MfaScreen(),
      AuthStage.conectado => const _RootShell(),
    };
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  @override
  void initState() {
    super.initState();
    // Al entrar al shell, la pantalla activa es el dashboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = context.read<NavigationController>();
      if (noChromeScreens.contains(nav.screen)) {
        nav.navigate(AppScreen.dashboard);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final screen =
        noChromeScreens.contains(nav.screen) ? AppScreen.dashboard : nav.screen;
    final showChrome = !noChromeScreens.contains(screen);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (showChrome) const TopBar(),
            Expanded(child: _buildScreen(screen)),
          ],
        ),
      ),
      bottomNavigationBar: showChrome ? const BottomNav() : null,
    );
  }

  Widget _buildScreen(AppScreen screen) {
    return switch (screen) {
      AppScreen.splash || AppScreen.login || AppScreen.mfa || AppScreen.dashboard =>
        const DashboardScreen(),
      AppScreen.files => const FilesScreen(),
      AppScreen.fileDetail => const FileDetailScreen(),
      AppScreen.sync => const SyncScreen(),
      AppScreen.photos => const PhotoAlbumScreen(),
      AppScreen.streaming => const StreamingScreen(),
      AppScreen.videoPlayer => const VideoPlayerScreen(),
      AppScreen.hpc => const HpcJobsScreen(),
      AppScreen.createJob => const CreateJobScreen(),
      AppScreen.jobDetail => const JobDetailScreen(),
      AppScreen.alerts => const AlertsScreen(),
      AppScreen.profile => const ProfileScreen(),
      AppScreen.admin => const AdminScreen(),
    };
  }
}
