import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import 'app.dart'; // File aplikasi utama kamu (sesuaikan import jika perlu)
import 'data/services/api_client.dart';
import 'state/session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionController()),
        // Tambahkan provider lain di sini jika ada
      ],
      child: const LocationTrackerApp(),
    ),
  );
}

class LocationTrackerApp extends StatefulWidget {
  const LocationTrackerApp({super.key});

  @override
  State<LocationTrackerApp> createState() => _LocationTrackerAppState();
}

// Gunakan WidgetsBindingObserver untuk memantau aplikasi sedang dibuka atau ditutup
class _LocationTrackerAppState extends State<LocationTrackerApp>
    with WidgetsBindingObserver {
  Timer? _locationTimer;
  bool _isActive = true; // Flag untuk mengecek aplikasi aktif

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Mulai tracking lokasi saat aplikasi pertama kali jalan
    _startForegroundLocationTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fungsi ini dipanggil otomatis oleh sistem jika user minimize aplikasi
    if (state == AppLifecycleState.resumed) {
      _isActive = true;
      debugPrint("App is Active: Location Tracking Resumed");
    } else {
      _isActive = false;
      debugPrint("App is in Background: Location Tracking Paused");
    }
  }

  void _startForegroundLocationTracking() {
    // Loop berulang setiap 30 detik
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      // JIKA APLIKASI DI BACKGROUND / DIMINIMIZE, BATALKAN PENGIRIMAN
      if (!_isActive) return;

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Kirim API Update Location ke Laravel
        await ApiClient().post(
          '/location', // <--- SUDAH DIPERBAIKI MENJADI '/location'
          body: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'battery':
                100, // Kamu bisa ganti angka ini jika menggunakan package battery_plus
          },
          requiresAuth: true,
        );

        debugPrint(
          'Location sent successfully to backend: ${position.latitude}, ${position.longitude}',
        );
      } catch (e) {
        debugPrint('Failed to get or send location: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Panggil widget utama aplikasi kamu yang ada di lib/app.dart
    return const WhereTFApp();
  }
}
