import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/user_avatar.dart';
import '../../data/models/app_user.dart';
import '../../data/models/circle_member.dart';
import '../../data/models/circle_summary.dart';
import '../../data/services/circle_service.dart';
import '../../state/session_controller.dart';
import '../circle/join_circle_screen.dart';
import '../profile/profile_screen.dart';
import 'member_today_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  int? _lastRequestedCircleId;

  final CircleService _circleService = CircleService();
  Timer? _locationTimer;
  Map<int, dynamic> _membersLocationData = {};

  final Color darkBrown = const Color(0xFF5B4D41);
  final Color lightCream = const Color(0xFFF7F2EB);
  final Color backgroundCream = const Color(0xFFFAF4ED);
  final Color textLight = const Color(0xFF9E8E78);

  LatLng _myCurrentLocation = const LatLng(-6.2088, 106.8456);

  @override
  void initState() {
    super.initState();

    _sendMyLocation();
    _fetchCircleLocations();

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _sendMyLocation();
      _fetchCircleLocations();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _sendMyLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('GPS mati, tidak bisa mengirim lokasi.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Izin lokasi ditolak.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Izin lokasi ditolak permanen.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _myCurrentLocation = LatLng(position.latitude, position.longitude);
        });
      }

      await _circleService.updateMyLocation(
        position.latitude,
        position.longitude,
        100,
      );

      debugPrint(
        'Berhasil kirim lokasi ke DB: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('Gagal mengirim lokasi ke database: $e');
    }
  }

  Future<void> _fetchCircleLocations() async {
    final session = context.read<SessionController>();
    final circleId = session.currentCircle?.id;
    if (circleId == null) return;

    try {
      final locations = await _circleService.getCircleLocations(circleId);

      if (mounted) {
        setState(() {
          _membersLocationData = {
            for (var loc in locations)
              int.parse(loc['user_id'].toString()): loc,
          };
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat lokasi real-time: $e');
    }
  }

  void _showCreateUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create circle belum tersedia di backend.')),
    );
  }

  Future<void> _goToJoinCircle() async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const JoinCircleScreen()),
    );

    if (!mounted || message == null || message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyInviteCode(CircleSummary circle) {
    return _copyInviteCodeText(circle.referalCode);
  }

  Future<void> _copyInviteCodeText(String code) {
    return _copyText(
      code,
      'Kode invite berhasil disalin.',
    );
  }

  Future<void> _copyInviteMessageText(String message) {
    return _copyText(
      message,
      'Teks undangan berhasil disalin.',
    );
  }

  Future<void> _copyText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showInviteShareSheet(CircleSummary circle) {
    _showInviteShareSheetContent(_inviteMessage(circle));
  }

  void _showInviteShareSheetForCode({
    required String name,
    required String code,
  }) {
    _showInviteShareSheetContent(_inviteMessageForCode(name, code));
  }

  void _showInviteShareSheetContent(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: lightCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2BFA9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Bagikan Circle',
                style: GoogleFonts.inter(
                  color: darkBrown,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.58),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE4D6C7),
                  ),
                ),
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    color: darkBrown,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _copyInviteMessageText(message);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Salin Teks Undangan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBrown,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _inviteMessage(CircleSummary circle) {
    return _inviteMessageForCode(circle.displayName, circle.referalCode);
  }

  String _inviteMessageForCode(String name, String code) {
    return 'Yuk join circle $name di WhereTF?. Masukkan kode invite: $code';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final currentCircle = session.currentCircle;
    final members = session.circleMembers;
    final myUserId = session.currentUser?.id;

    _requestMembersIfNeeded(session);

    // --- Pemrosesan Data List Marker ---
    final List<Marker> liveMarkers = [];
    for (var member in members) {
      // Lewati diri sendiri — hanya tampilkan marker anggota LAIN
      if (member.userId == myUserId) continue;

      // Mencari data lokasi berdasarkan userId member
      final loc = _membersLocationData[member.userId];

      if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
        final double lat = double.tryParse(loc['latitude'].toString()) ?? 0.0;
        final double lng = double.tryParse(loc['longitude'].toString()) ?? 0.0;
        final bool isOnline = loc['status'] == 'online';

        if (isOnline) {
          // Jika ONLINE: Tampilkan ikon foto profil / UserAvatar
          liveMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 50,
              height: 60,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () => _openMemberHistory(member),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(
                            0xFF67A843,
                          ), // Hijau penanda online
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: UserAvatar(
                        user: member.user,
                        radius: 18,
                        backgroundColor:
                            member.hasOwnerRole
                                ? const Color(0xFFD8B36A)
                                : const Color(0xFF8FC7D4),
                        foregroundColor: darkBrown,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.black87,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          // Jika OFFLINE: Ikon avatar menghilang, diganti titik abu-abu penanda lokasi terakhir
          liveMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 14,
              height: 14,
              child: GestureDetector(
                onTap: () => _openMemberHistory(member),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: backgroundCream,
      body: Stack(
        children: [
          // --- Peta Full Screen ---
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _myCurrentLocation,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.wheretf.app',
                  maxZoom: 19,
                ),
                // --- MarkerLayer wajib ada agar marker anggota muncul ---
                MarkerLayer(markers: liveMarkers),
              ],
            ),
          ),
          Positioned(top: 50, left: 16, right: 16, child: _buildTopBar()),
          Positioned(right: 16, bottom: 245, child: _buildMyLocationButton()),
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.23,
            maxChildSize: 0.78,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: lightCream,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD2BFA9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    currentCircle == null
                        ? _buildEmptyCircleCard(session.currentUser)
                        : _buildCurrentCircleCard(currentCircle),
                    const SizedBox(height: 22),
                    _buildPeopleSection(session),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _requestMembersIfNeeded(SessionController session) {
    final circleId = session.currentCircle?.id;
    if (circleId == null) {
      _lastRequestedCircleId = null;
      return;
    }

    if (session.isLoadingCircleMembers ||
        session.hasCircleMembersForCurrentCircle) {
      _lastRequestedCircleId = circleId;
      return;
    }

    if (_lastRequestedCircleId == circleId) {
      return;
    }

    _lastRequestedCircleId = circleId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<SessionController>().refreshCircleMembers(
        allowFailure: true,
      );
    });
  }

  void _openMemberHistory(CircleMember member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberTodayHistoryScreen(member: member),
      ),
    );
  }

  Widget _buildTopBar() {
    final session = context.watch<SessionController>();
    final user = session.currentUser;
    final currentCircle = session.currentCircle;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: lightCream,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            currentCircle?.displayName ?? 'No Circle Yet',
            style: GoogleFonts.inter(
              color: darkBrown,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, color: darkBrown, size: 22),
          const Spacer(),
          Icon(Icons.notifications, color: darkBrown, size: 22),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(showBackButton: true),
                ),
              );
            },
            child: UserAvatar(
              user: user,
              radius: 17,
              backgroundColor: const Color(0xFFCDA87C),
              foregroundColor: darkBrown,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyLocationButton() {
    return GestureDetector(
      onTap: () {
        _mapController.move(_myCurrentLocation, 14.5);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF67A843),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.my_location, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildEmptyCircleCard(AppUser? user) {
    final userInviteCode = user?.referalCode?.trim();
    if (userInviteCode != null && userInviteCode.isNotEmpty) {
      return _buildUserInviteFallbackCard(user!, userInviteCode);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
      decoration: BoxDecoration(
        color: lightCream,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD7B58C), width: 1.3),
            ),
            child: Center(
              child: SizedBox(
                width: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(left: 0, child: _smallEmptyAvatar()),
                    Positioned(left: 14, child: _smallEmptyAvatar()),
                    Positioned(left: 28, child: _smallEmptyAvatar()),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No one in your circle yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: darkBrown,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite friends and family to start tracking\nlocations together',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: textLight,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _showCreateUnavailable,
              style: ElevatedButton.styleFrom(
                backgroundColor: darkBrown,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Create a Circle',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _goToJoinCircle,
            child: Text(
              'Join with invite code',
              style: GoogleFonts.inter(
                color: const Color(0xFFC59D74),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInviteFallbackCard(AppUser user, String inviteCode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: lightCream,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Circle kamu',
            style: GoogleFonts.inter(
              color: darkBrown,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kode invite sudah tersedia. Data anggota akan muncul setelah circle tersinkron dari backend.',
            style: GoogleFonts.inter(
              color: textLight,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.56),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE4D6C7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kode invite kamu',
                  style: GoogleFonts.inter(
                    color: textLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        inviteCode,
                        style: GoogleFonts.inter(
                          color: darkBrown,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyInviteCodeText(inviteCode),
                      icon: Icon(
                        Icons.copy_rounded,
                        color: darkBrown,
                        size: 20,
                      ),
                      tooltip: 'Salin kode',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyInviteCodeText(inviteCode),
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text('Salin'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: darkBrown,
                          side: BorderSide(color: darkBrown.withOpacity(0.28)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showInviteShareSheetForCode(
                          name: user.name,
                          code: inviteCode,
                        ),
                        icon: const Icon(Icons.ios_share_rounded, size: 17),
                        label: const Text('Bagikan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkBrown,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _goToJoinCircle,
              style: ElevatedButton.styleFrom(
                backgroundColor: darkBrown,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Join circle lain',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCircleCard(CircleSummary currentCircle) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: lightCream,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentCircle.displayName,
            style: GoogleFonts.inter(
              color: darkBrown,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentCircle.isOwnedBy(
                  context.read<SessionController>().currentUser?.id,
                )
                ? 'This is your default circle.'
                : "You are active in another member's circle.",
            style: GoogleFonts.inter(color: textLight, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.56),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE4D6C7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kode invite circle',
                  style: GoogleFonts.inter(
                    color: textLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        currentCircle.referalCode,
                        style: GoogleFonts.inter(
                          color: darkBrown,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyInviteCode(currentCircle),
                      icon: Icon(
                        Icons.copy_rounded,
                        color: darkBrown,
                        size: 20,
                      ),
                      tooltip: 'Salin kode',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyInviteCode(currentCircle),
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text('Salin'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: darkBrown,
                          side: BorderSide(color: darkBrown.withOpacity(0.28)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showInviteShareSheet(currentCircle),
                        icon: const Icon(Icons.ios_share_rounded, size: 17),
                        label: const Text('Bagikan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkBrown,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _goToJoinCircle,
              style: ElevatedButton.styleFrom(
                backgroundColor: darkBrown,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Join another circle',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallEmptyAvatar() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFFD8D0C6),
        shape: BoxShape.circle,
        border: Border.all(color: lightCream, width: 2),
      ),
    );
  }

  Widget _buildPeopleSection(SessionController session) {
    final currentCircle = session.currentCircle;
    final members = session.circleMembers;
    final error = session.circleMembersError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Orang-orang',
                style: GoogleFonts.inter(
                  color: darkBrown,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (currentCircle != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed:
                    session.isLoadingCircleMembers
                        ? null
                        : () => context
                            .read<SessionController>()
                            .refreshCircleMembers(allowFailure: true),
                icon: Icon(Icons.refresh_rounded, color: textLight, size: 20),
                tooltip: 'Refresh anggota',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4D6C7), width: 1),
          ),
          child:
              currentCircle == null
                  ? _buildPeopleMessage('No synced circle yet')
                  : session.isLoadingCircleMembers && members.isEmpty
                  ? _buildPeopleLoading()
                  : error != null
                  ? _buildPeopleError(error)
                  : members.isEmpty
                  ? _buildPeopleMessage('Belum ada anggota di circle ini')
                  : Column(
                    children: [
                      for (int index = 0; index < members.length; index++) ...[
                        _buildMemberRow(members[index]),
                        if (index != members.length - 1)
                          const Divider(
                            height: 1,
                            indent: 74,
                            color: Color(0xFFE4D6C7),
                          ),
                      ],
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildPeopleLoading() {
    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Memuat anggota...',
            style: GoogleFonts.inter(color: textLight, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleError(String message) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tidak bisa memuat anggota',
            style: GoogleFonts.inter(
              color: darkBrown,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: GoogleFonts.inter(
              color: textLight,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleMessage(String message) {
    return SizedBox(
      height: 62,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: const Color(0xFFC2B3A4),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberRow(CircleMember member) {
    return InkWell(
      onTap: () => _openMemberHistory(member),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            UserAvatar(
              user: member.user,
              initials: member.initials,
              radius: 26,
              backgroundColor:
                  member.hasOwnerRole
                      ? const Color(0xFFD8B36A)
                      : const Color(0xFF8FC7D4),
              foregroundColor: darkBrown,
              fontSize: 18,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: darkBrown,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _memberSubtitle(member),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: textLight,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: textLight, size: 22),
          ],
        ),
      ),
    );
  }

  String _memberSubtitle(CircleMember member) {
    final status = member.displayStatus;
    final contact = member.contactLabel;
    if (contact != null && contact.isNotEmpty) {
      return '$status - $contact';
    }

    return status;
  }
}
