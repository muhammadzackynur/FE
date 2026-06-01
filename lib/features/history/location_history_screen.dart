import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../../state/session_controller.dart';
import '../premium/premium_screen.dart';
import '../../data/services/api_client.dart';

class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  final Color darkBrown = const Color(0xFF5B4D41);
  final Color bgCream = const Color(0xFFFFF8F0);
  final Color cardCream = const Color(0xFFF5EEE6);
  final Color textLight = const Color(0xFF9E8E78);

  int selectedDateIndex = 6; // Default: Hari ini
  bool isLoading = false;
  List<LatLng> routePoints = [];

  // State untuk daftar anggota circle
  List<dynamic> circleMembers = [];
  int? selectedUserId; // Menyimpan ID user yang sedang dilihat history-nya

  @override
  void initState() {
    super.initState();
    // Fetch daftar anggota dan history saat layar pertama kali dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    await _fetchCircleMembers();
  }

  // Fungsi untuk mengambil daftar teman 1 circle
  Future<void> _fetchCircleMembers() async {
    final session = context.read<SessionController>();
    final currentCircle = session.currentCircle;

    // Perbaikan error session.currentUser
    final currentUser = session.currentUser;

    if (currentCircle == null) return;

    try {
      final response = await ApiClient().get(
        '/circles/${currentCircle.id}/members', // Mengambil list anggota circle
        requiresAuth: true,
      );

      final List<dynamic> data = response['data'] ?? [];

      setState(() {
        circleMembers = data;
        if (circleMembers.isNotEmpty) {
          // Default: Pilih diri kita sendiri jika ada di list, jika tidak pilih orang pertama
          final me = circleMembers.firstWhere(
            (m) => m['user_id'] == currentUser?.id,
            orElse: () => circleMembers.first,
          );
          selectedUserId = me['user_id'];
        }
      });

      // Setelah dapet user_id-nya, baru jalankan fetch history
      _fetchLocationHistory(selectedDateIndex);
    } catch (e) {
      debugPrint('Gagal mengambil daftar anggota circle: $e');
      // Fallback jika gagal ambil list user
      _fetchLocationHistory(selectedDateIndex);
    }
  }

  // Fungsi untuk hit API history berdasarkan tanggal dan user_id
  Future<void> _fetchLocationHistory(int index) async {
    final session = context.read<SessionController>();
    final currentCircle = session.currentCircle;

    if (currentCircle == null) return;

    setState(() {
      isLoading = true;
      routePoints = [];
    });

    final now = DateTime.now();
    final date = now.subtract(Duration(days: 6 - index));
    final dateString = DateFormat('yyyy-MM-dd').format(date);

    try {
      // URL ditambahkan query user_id untuk filter history milik siapa
      String url = '/circles/${currentCircle.id}/history?date=$dateString';
      if (selectedUserId != null) {
        url += '&user_id=$selectedUserId';
      }

      final response = await ApiClient().get(url, requiresAuth: true);
      final List<dynamic> data = response['data'] ?? [];

      setState(() {
        routePoints =
            data.map((item) {
              return LatLng(
                double.parse(item['latitude'].toString()),
                double.parse(item['longitude'].toString()),
              );
            }).toList();
      });
    } catch (e) {
      debugPrint('Gagal mengambil history: $e');
      setState(() {
        routePoints = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final currentCircle = session.currentCircle;
    final isPremium = session.isPremium;

    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          children: [
            Text(
              'Location History',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              currentCircle?.displayName ?? 'No active circle',
              style: GoogleFonts.inter(color: textLight, fontSize: 11),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isPremium) _buildUpgradeCard(),
            if (!isPremium) const SizedBox(height: 18),

            // 1. Widget Daftar Anggota Circle
            _buildMemberSelector(),
            const SizedBox(height: 16),

            // 2. Widget Pilihan Tanggal
            _buildDateSelector(isPremium),
            const SizedBox(height: 18),

            // 3. Widget Peta Route History
            Expanded(child: _buildMapArea(isPremium)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: darkBrown,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium,
            color: Color(0xFFD8B36A),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock 7-Day\nHistory',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'See where your circle has been',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF8E8D2),
              foregroundColor: darkBrown,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Upgrade Rp19.900/mo',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET BARU: Menampilkan list anggota circle (Bisa digeser ke samping)
  Widget _buildMemberSelector() {
    if (circleMembers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who are you looking for?',
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: circleMembers.length,
            itemBuilder: (context, index) {
              final member = circleMembers[index];
              final user = member['user'] ?? {};
              final userId = member['user_id'];
              final isSelected = userId == selectedUserId;

              final name = user['name']?.toString() ?? 'User';
              final photoUrl = user['photo']?.toString();

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedUserId = userId;
                  });
                  _fetchLocationHistory(
                    selectedDateIndex,
                  ); // Refresh peta milik target
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 18),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? darkBrown : Colors.transparent,
                            width: 2, // Highlight avatar jika dipilih
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFE8D4BD),
                          backgroundImage:
                              photoUrl != null && photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                          child:
                              photoUrl == null || photoUrl.isEmpty
                                  ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.inter(
                                      color: darkBrown,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name.split(' ')[0], // Tampilkan nama depan saja
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? darkBrown : textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector(bool isPremium) {
    final now = DateTime.now();

    final dates = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      final dayName =
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

      return {'day': dayName, 'date': date.day.toString()};
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(dates.length, (index) {
        final item = dates[index];
        final bool isSelected = selectedDateIndex == index;
        final bool isLocked = !isPremium && index < 6;

        return GestureDetector(
          onTap: () {
            if (isLocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Upgrade to premium to see past days'),
                ),
              );
              return;
            }
            setState(() {
              selectedDateIndex = index;
            });
            _fetchLocationHistory(index);
          },
          child: Container(
            width: 39,
            height: 52,
            decoration: BoxDecoration(
              color: isSelected ? darkBrown : const Color(0xFFFFF4E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? darkBrown : const Color(0xFFE8D4BD),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLocked)
                  const Icon(Icons.lock, size: 10, color: Colors.black26)
                else
                  Text(
                    item['day'].toString(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isSelected ? Colors.white70 : textLight,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  item['date'].toString(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color:
                        isSelected
                            ? Colors.white
                            : (isLocked ? Colors.black26 : Colors.black),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMapArea(bool isPremium) {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF5B4D41)),
        ),
      );
    }

    if (routePoints.isEmpty) {
      return _buildEmptyHistory(isPremium);
    }

    // 1. Dapatkan data foto dan nama dari user yang sedang dipilih
    String? photoUrl;
    String initial = '?';
    if (circleMembers.isNotEmpty && selectedUserId != null) {
      final userSelected = circleMembers.firstWhere(
        (m) => m['user_id'] == selectedUserId,
        orElse: () => null,
      );
      if (userSelected != null) {
        photoUrl = userSelected['user']['photo']?.toString();
        String name = userSelected['user']['name']?.toString() ?? '?';
        if (name.isNotEmpty) initial = name[0].toUpperCase();
      }
    }

    // 2. Gambar peta dan gunakan foto sebagai marker
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: routePoints.first,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.wheretf',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 4.0,
                    color: const Color(0xFFD8B36A), // Warna emas rute
                  ),
                ],
              ),
              MarkerLayer(
                // 3. Ubah child Marker menjadi foto profil
                markers:
                    routePoints
                        .map(
                          (point) => Marker(
                            point: point,
                            width: 36, // Ukuran marker avatar
                            height: 36,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: darkBrown,
                                  width: 2.5,
                                ),
                                color: const Color(0xFFE8D4BD),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child:
                                    photoUrl != null && photoUrl.isNotEmpty
                                        ? Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Center(
                                                    child: Text(
                                                      initial,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: darkBrown,
                                                      ),
                                                    ),
                                                  ),
                                        )
                                        : Center(
                                          child: Text(
                                            initial,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: darkBrown,
                                            ),
                                          ),
                                        ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory(bool isPremium) {
    // Dapatkan nama user yg sedang dipilih untuk pesan error yg lebih personal
    String targetName = 'This user';
    if (circleMembers.isNotEmpty && selectedUserId != null) {
      final userSelected = circleMembers.firstWhere(
        (m) => m['user_id'] == selectedUserId,
        orElse: () => null,
      );
      if (userSelected != null) {
        targetName = userSelected['user']['name']?.split(' ')[0] ?? 'This user';
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardCream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded, color: Color(0xFFD8B36A), size: 40),
          const SizedBox(height: 16),
          Text(
            '$targetName has no routes recorded',
            style: GoogleFonts.inter(
              color: textLight,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPremium
                ? 'Check another day or user'
                : 'Stay active to record routes',
            style: GoogleFonts.inter(
              color: textLight.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
