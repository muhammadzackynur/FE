import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/services/circle_service.dart';
import 'invite_code_screen.dart';

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final TextEditingController circleNameController = TextEditingController();
  final CircleService _circleService = CircleService();

  bool _isLoading = false;

  final Color darkBrown = const Color(0xFF5B4D41);
  final Color bgCream = const Color(0xFFFFF8F0);
  final Color cardCream = const Color(0xFFFFF3E6);
  final Color textLight = const Color(0xFF9E8E78);
  final Color gold = const Color(0xFFD8B36A);

  @override
  void initState() {
    super.initState();
    circleNameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    circleNameController.dispose();
    super.dispose();
  }

  // --- FUNGSI CREATE CIRCLE YANG SUDAH DIPERBAIKI ---
  Future<void> createCircle() async {
    final circleName = circleNameController.text.trim();

    if (circleName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Circle name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Panggil API ke backend
      final result = await _circleService.createCircle(circleName);

      if (!mounted) return;

      // 2. Ambil referal_code asli dari backend dan pindah halaman
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => InviteCodeScreen(
                circleName: result.circle.name ?? circleName,
                inviteCode: result.circle.referalCode, // Code dari database
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat circle: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkBrown,
            size: 20,
          ),
        ),
        title: Text(
          'New Circle',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Circle name',
              style: GoogleFonts.inter(
                color: darkBrown,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: circleNameController,
              maxLength: 25,
              enabled: !_isLoading,
              style: GoogleFonts.inter(color: darkBrown, fontSize: 14),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'e.g. Family, Work Team, Close Friends...',
                hintStyle: GoogleFonts.inter(
                  color: textLight.withOpacity(0.7),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: cardCream,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFE6D3BC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide(color: darkBrown),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'This name will be visible to all circle members',
                    style: GoogleFonts.inter(color: textLight, fontSize: 11),
                  ),
                ),
                Text(
                  '${circleNameController.text.length}/25',
                  style: GoogleFonts.inter(color: textLight, fontSize: 11),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF1E2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.help_outline_rounded,
                      color: gold,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Create a space to stay\nconnected with your favorite\npeople',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: textLight,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : createCircle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkBrown,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          'Create Circle',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
