import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';
import 'models.dart';
import 'youtube_service.dart';

class RoulettePage extends StatefulWidget {
  const RoulettePage({super.key});
  @override
  State<RoulettePage> createState() => _RoulettePageState();
}

class _RoulettePageState extends State<RoulettePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentRotation = 0.0;
  Episode? _selectedVideo;
  int? _highlightedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);

    YouTubeService().init().then((_) {
      if (YouTubeService.cachedEpisodes.isEmpty) {
        YouTubeService.cachedEpisodes.add(Episode(
          title: "EP.100 Labyrinth",
          category: "GOING SEVENTEEN",
          youtubeUrl: "https://www.youtube.com/watch?v=s4jHQXd-7gg",
          thumbnailUrl: "https://img.youtube.com/vi/s4jHQXd-7gg/maxresdefault.jpg",
        ));
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startSpin() {
    final data = YouTubeService.cachedEpisodes;
    if (_controller.isAnimating || data.isEmpty) return;

    setState(() { 
      _selectedVideo = null; 
      _highlightedIndex = null; 
    });

    final picked = data[math.Random().nextInt(data.length)];
    final categories = YouTubeService.playlistConfigs.keys.toList();
    int catIdx = categories.indexOf(picked.category);

    double sectorAngle = 2 * math.pi / categories.length;
    double randomOffset = (math.Random().nextDouble() * 0.6 + 0.2) * sectorAngle;
    double targetRotation = (12 * math.pi) + (1.5 * math.pi) - (catIdx * sectorAngle) - randomOffset;

    _animation = Tween<double>(begin: _currentRotation % (2 * math.pi), end: targetRotation)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCirc));

    _controller.forward(from: 0.0).then((_) {
      setState(() {
        _currentRotation = targetRotation;
        _selectedVideo = picked;
        _highlightedIndex = catIdx;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7CAC9), Color(0xFF92A8D1)],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 200), 
                Center(
                  child: Text(
                    "今天 GOING 到哪 👀",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: const Color(0xFF785655),
                    ),
                  ),
                ),
                const SizedBox(height: 0), 
                
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // 1. 會旋轉的輪盤層
                        AnimatedBuilder(
                          animation: _animation,
                          builder: (context, _) => Transform.rotate(
                            angle: _controller.isAnimating ? _animation.value : _currentRotation,
                            child: Container(
                              width: 346, height: 346,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF785655).withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 20)),
                                ],
                              ),
                              child: CustomPaint(
                                painter: VividKaleidoscopePainter(),
                              ),
                            ),
                          ),
                        ),
                        
                        // 2. 🚀 固定不動的發光雷射層 (只有停止時顯示，且固定在正上方)
                        if (_highlightedIndex != null)
                          IgnorePointer(
                            child: SizedBox(
                              width: 346, height: 346,
                              child: CustomPaint(
                                painter: StaticLaserPainter(),
                              ),
                            ),
                          ),

                        // 3. 定位圖標 (黑色指標)
                        Positioned(
                          top: 88, 
                          child: const Icon(Icons.arrow_drop_up, size: 80, color: Colors.black),
                        ),

                        // 4. 中心按鈕 (Logo)
                        GestureDetector(
                          onTap: _startSpin,
                          behavior: HitTestBehavior.opaque, 
                          child: _buildCenterHub(),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Transform.translate(
                    offset: const Offset(0, -40), 
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: _selectedVideo == null ? const SizedBox() : _buildGlassResultCard(_selectedVideo!),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterHub() {
    return Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        color: Colors.white, 
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: const Color(0xFF785655).withOpacity(0.15), blurRadius: 30)],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/svt_logo.jpg', 
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.favorite, color: Color(0xFFF7CAC9))),
        ),
      ),
    );
  }

  Widget _buildGlassResultCard(Episode video) {
    final cleanedTitle = video.title.replaceFirst(RegExp(r'\[.*?\]\s*'), '').trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 45,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(video.thumbnailUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 55,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(video.category.toUpperCase(), 
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF785655))),
                      const SizedBox(height: 6),
                      Text(cleanedTitle, 
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, height: 1.2, color: Colors.black87), 
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      _buildWatchButton(video.youtubeUrl),
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

  Widget _buildWatchButton(String url) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: const LinearGradient(colors: [Color(0xFF785655), Color(0xFF495F84)]),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_filled, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            const Text("WATCH ON YOUTUBE", 
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// 🚀 獨立繪圖器：負責在 0 度位置繪製固定不動的 2 度極細雷射光束
class StaticLaserPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    const glowWidthRadians = 2.0 * (math.pi / 180); // 精確 2 度
    // Flutter 坐標系中，正上方 (12點鐘方向) 為 -math.pi / 2
    const startAngle = -math.pi / 2 - (glowWidthRadians / 2);

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.98)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6) 
      ..style = PaintingStyle.fill;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      glowWidthRadians,
      true,
      glowPaint
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VividKaleidoscopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    const Color roseQuartz = Color(0xFFF7CAC9);
    const Color serenity = Color(0xFF92A8D1);

    final List<Color> vividPalette = [
      const Color(0xFFFF8A80), const Color(0xFF80CBC4), const Color(0xFFFFD54F),
      const Color(0xFF4FC3F7), const Color(0xFFBA68C8),
    ];

    // 輪盤邊框
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const SweepGradient(
        colors: [roseQuartz, serenity, roseQuartz],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 1, borderPaint);

    // 放射線條
    double innerStart = 45.0; 
    for (int i = 0; i < 120; i++) {
      final paint = Paint()
        ..color = vividPalette[i % vividPalette.length].withOpacity(0.7)
        ..strokeWidth = 2.0;
      double angle = i * (2 * math.pi / 120);
      canvas.drawLine(
        center + Offset.fromDirection(angle, innerStart), 
        center + Offset.fromDirection(angle, radius - 4), 
        paint
      );
    }
  }

  @override
  bool shouldRepaint(VividKaleidoscopePainter old) => true;
}