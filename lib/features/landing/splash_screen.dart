import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart'; // Tambahkan ini
import 'package:permission_handler/permission_handler.dart'; // Tambahkan ini

import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_widgets.dart';
import '../../state/session_controller.dart';
import '../main/main_navigation_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapSession();
    });
  }

  // Fungsi untuk meminta izin lokasi
  Future<void> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Jika GPS mati, minta user menyalakan
      await Geolocator.openLocationSettings();
      // Tunggu user menyalakan, atau beri jeda
      await Future.delayed(const Duration(seconds: 3));
    }

    PermissionStatus permission = await Permission.location.request();
    if (permission.isDenied || permission.isPermanentlyDenied) {
      // Jika ditolak, Anda bisa menampilkan dialog penjelasan di sini
      debugPrint("Izin lokasi ditolak oleh user");
    }
  }

  Future<void> _bootstrapSession() async {
    // 1. Minta Izin Lokasi dulu sebelum memproses sesi login
    await _checkPermissions();

    await Future<void>.delayed(const Duration(seconds: 1));

    if (!mounted) {
      return;
    }

    final session = context.read<SessionController>();
    final isLoggedIn = await session.bootstrap();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) =>
                isLoggedIn
                    ? const MainNavigationScreen()
                    : const WelcomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'WhereToFind',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share live locations with your trusted circle',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 150,
              child: CustomPaint(painter: ConstellationPainter()),
            ),
          ),
        ],
      ),
    );
  }
}
