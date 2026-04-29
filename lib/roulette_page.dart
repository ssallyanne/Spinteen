import 'dart:math' as math;
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models.dart';
import 'group_data.dart';
import 'youtube_service.dart';

class RoulettePage extends StatefulWidget {
  const RoulettePage({super.key});
  @override
  State<RoulettePage> createState() => _RoulettePageState();
}

class _RoulettePageState extends State<RoulettePage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _bgController;
  late AnimationController _pulseController;
  late PageController _cardPageController;
  
  late Animation<double> _animation;
  late Animation<Alignment> _bgBegin;
  late Animation<Alignment> _bgEnd;
  
  double _currentRotation = 0.0;
  Episode? _selectedVideo;
  int? _highlightedIndex;
  
  String? _customHubImageBase64;
  String? _selectedMemberName;

  KPopGroup currentGroup = GroupData.allGroups[0];
  final int _infiniteCount = 10000;

  final Map<String, Color> _memberColors = {
    'S.COUPS': const Color(0xFFA9B7C1),
    'JEONGHAN': const Color(0xFFA58ED4),
    'JOSHUA': const Color(0xFF9ABEC2),
    'JUN': const Color(0xFFB7ACDE),
    'HOSHI': const Color(0xFFEBE1B5),
    'WONWOO': const Color(0xFFE8DEC8),
    'WOOZI': const Color(0xFF99D1F2),
    'THE8': const Color(0xFFD5E8D9),
    'MINGYU': const Color(0xFFFBC68B),
    'DK': const Color(0xFFFF9A7B),
    'SEUNGKWAN': const Color(0xFFA9B7C1),
    'VERNON': const Color(0xFF878A8A),
    'DINO': const Color(0xFFF9BCB2),
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
    
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _bgBegin = Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.bottomLeft).animate(_bgController);
    _bgEnd = Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.topRight).animate(_bgController);

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _cardPageController = PageController(viewportFraction: 0.22, initialPage: _infiniteCount ~/ 2);

    _initApp();
  }

  Color? _getSelectedMemberColor() {
    if (_selectedMemberName != null) return _memberColors[_selectedMemberName];
    return null;
  }

  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedId = prefs.getString('last_selected_group_id');
    if (savedId != null) {
      final savedGroup = GroupData.allGroups.firstWhere((g) => g.id == savedId, orElse: () => GroupData.allGroups[0]);
      if (mounted) setState(() { currentGroup = savedGroup; });
    }

    _customHubImageBase64 = prefs.getString('custom_hub_${currentGroup.id}');
    _selectedMemberName = prefs.getString('member_${currentGroup.id}');
    
    if (_selectedMemberName != null) {
      int memberIdx = GroupData.seventeenMembers.indexOf(_selectedMemberName!);
      if (memberIdx != -1) {
        int targetPage = (_infiniteCount ~/ 2) - ((_infiniteCount ~/ 2) % GroupData.seventeenMembers.length) + memberIdx;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_cardPageController.hasClients) _cardPageController.jumpToPage(targetPage);
        });
      }
    }
    _loadInitialData();
  }

  Future<void> _updateSelectedMember(String name) async {
    if (_selectedMemberName == name) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('member_${currentGroup.id}', name);
    await prefs.remove('custom_hub_${currentGroup.id}');
    HapticFeedback.selectionClick();
    setState(() { _selectedMemberName = name; _customHubImageBase64 = null; });
  }

  void _loadInitialData() {
    YouTubeService().init(currentGroup).then((_) {
      if (mounted) { setState(() {}); _precacheThumbnails(); }
    });
  }

  void _precacheThumbnails() {
    for (var episode in YouTubeService.cachedEpisodes) {
      if (episode.thumbnailUrl.startsWith('http')) {
        precacheImage(CachedNetworkImageProvider(episode.thumbnailUrl), context).catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose(); _bgController.dispose(); _pulseController.dispose(); _cardPageController.dispose();
    super.dispose();
  }

  void _startSpin() {
    final data = YouTubeService.cachedEpisodes;
    if (_controller.isAnimating || data.isEmpty) return;
    setState(() { _selectedVideo = null; _highlightedIndex = null; });
    final picked = data[math.Random().nextInt(data.length)];
    double randomLoops = 10.0 + math.Random().nextInt(5).toDouble();
    final categories = currentGroup.playlistConfigs.keys.toList();
    int catIdx = categories.indexOf(picked.category);
    if (catIdx == -1) catIdx = 0;
    double sectorAngle = 2 * math.pi / categories.length;
    double randomOffsetInSector = (math.Random().nextDouble() * 0.7 + 0.15) * sectorAngle;
    double targetRotation = (randomLoops * math.pi) + (1.5 * math.pi) - (catIdx * sectorAngle) - randomOffsetInSector;
    _animation = Tween<double>(begin: _currentRotation % (2 * math.pi), end: targetRotation)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    _controller.forward(from: 0.0).then((_) {
      HapticFeedback.heavyImpact();
      setState(() { _currentRotation = targetRotation; _selectedVideo = picked; _highlightedIndex = catIdx; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final rouletteSize = math.min(screenWidth * 0.82, 350.0);
    final hubSize = rouletteSize * 0.28;
    final Color? activeMemberColor = _getSelectedMemberColor();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (context, _) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: _bgBegin.value, end: _bgEnd.value, colors: currentGroup.themeColors),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        Text(
                          "今天 GOING 到哪 👀",
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
                        ),
                        const SizedBox(height: 30),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, _) => Transform.rotate(
                                angle: _controller.isAnimating ? _animation.value : _currentRotation,
                                child: Container(
                                  width: rouletteSize, height: rouletteSize,
                                  decoration: const BoxDecoration(shape: BoxShape.circle),
                                  child: CustomPaint(
                                    painter: VividKaleidoscopePainter(
                                      themeColors: currentGroup.themeColors,
                                      accentColor: activeMemberColor,
                                    )
                                  ),
                                ),
                              ),
                            ),
                            if (_highlightedIndex != null)
                              IgnorePointer(child: SizedBox(width: rouletteSize, height: rouletteSize, child: CustomPaint(painter: StaticLaserPainter()))),
                            Positioned(
                              top: (rouletteSize / 2) - (hubSize / 2) - 52, 
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                child: RotatedBox(
                                  quarterTurns: 2, 
                                  child: Icon(
                                    Icons.arrow_drop_down, 
                                    size: 110,
                                    color: activeMemberColor ?? Colors.black,
                                  )
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _startSpin,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                                child: _buildCenterHub(hubSize),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        _buildCardSelector(),
                        const SizedBox(height: 25), 
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          child: _selectedVideo == null ? const SizedBox(height: 120) : _buildGlassResultCard(_selectedVideo!),
                        ),
                        const SizedBox(height: 50), 
                      ],
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

  Widget _buildCardSelector() {
    return Column(
      children: [
        SizedBox(
          height: 100,
          child: PageView.builder(
            controller: _cardPageController,
            itemCount: _infiniteCount,
            onPageChanged: (idx) {
              final realIdx = idx % GroupData.seventeenMembers.length;
              _updateSelectedMember(GroupData.seventeenMembers[realIdx]);
            },
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final realIdx = index % GroupData.seventeenMembers.length;
              final name = GroupData.seventeenMembers[realIdx];
              final assetPath = 'assets/miniteen/${name.toLowerCase().replaceAll('.', '')}.png';
              bool isSelected = _selectedMemberName == name;
              final Color activeColor = _memberColors[name] ?? Colors.white;
              return AnimatedBuilder(
                animation: _cardPageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_cardPageController.position.haveDimensions) {
                    value = _cardPageController.page! - index;
                    value = (1 - (value.abs() * 0.25)).clamp(0.0, 1.0); // 🚀 平緩縮放：0.25
                  } else {
                    value = isSelected ? 1.0 : 0.72; // 🚀 保底大小：0.72
                  }
                  return Center(
                    child: Transform.scale(
                      scale: Curves.easeOut.transform(value),
                      child: Opacity(
                        opacity: value.clamp(0.72, 1.0),
                        child: GestureDetector(
                          onTap: () {
                            _cardPageController.animateToPage(index, duration: const Duration(milliseconds: 450), curve: Curves.easeOutQuart);
                          },
                          child: Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? activeColor : Colors.white12, width: 1.5),
                              boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 10)] : [],
                            ),
                            child: ClipOval(child: Image.asset(assetPath, fit: BoxFit.cover, errorBuilder: (c,e,s) => _buildNameBadge(name))),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCenterHub(double size) {
    Widget displayImage;
    if (_selectedMemberName != null) {
      final assetPath = 'assets/miniteen/${_selectedMemberName!.toLowerCase().replaceAll('.', '')}.png';
      displayImage = Image.asset(
        assetPath, fit: BoxFit.cover, 
        errorBuilder: (context, error, stackTrace) => _buildNameBadge(_selectedMemberName!),
      );
    } else if (_customHubImageBase64 != null) {
      displayImage = Image.memory(base64Decode(_customHubImageBase64!), fit: BoxFit.cover);
    } else {
      displayImage = Image.asset(currentGroup.logoPath, fit: BoxFit.contain);
    }
    return Container(width: size, height: size, decoration: const BoxDecoration(shape: BoxShape.circle), child: ClipOval(child: displayImage));
  }

  Widget _buildNameBadge(String name) {
    String initial = name.length > 2 ? name.substring(0, 2) : name;
    final Color badgeColor = _memberColors[name] ?? currentGroup.themeColors.first;
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [badgeColor, badgeColor.withOpacity(0.7)])),
      alignment: Alignment.center,
      child: Text(initial, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1)),
    );
  }

  Widget _buildGlassResultCard(Episode video) {
    final prefixRegex = RegExp(r'^(RUN\s*BTS|GOING\s*SEVENTEEN)[!\s-]*', caseSensitive: false);
    String cleanedTitle = video.title.replaceFirst(RegExp(r'\[.*?\]\s*'), '').replaceFirst(prefixRegex, '').trim();
    String displayCategory = "GOING SEVENTEEN";
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(video.youtubeUrl)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.42), borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 42, child: AspectRatio(aspectRatio: 16 / 9, child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: CachedNetworkImage(imageUrl: video.thumbnailUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.white10), errorWidget: (context, url, error) => const Icon(Icons.error_outline, color: Colors.white24))),
                    )),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 58, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(20)), child: Text(displayCategory, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF1A1C1E), letterSpacing: 1.0))),
                      const SizedBox(height: 8),
                      Text(cleanedTitle, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, height: 1.15, color: const Color(0xFF1A1C1E)).copyWith(fontFamilyFallback: ['Apple SD Gothic Neo', 'Malgun Gothic', 'Nanum Gothic', 'Dotum', 'sans-serif']), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      _buildWatchButton(video.youtubeUrl),
                    ]),
                  ),
                ],
              ),
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), gradient: LinearGradient(colors: currentGroup.themeColors), boxShadow: [BoxShadow(color: currentGroup.themeColors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white), SizedBox(width: 4), Text("WATCH ON YOUTUBE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))]),
      ),
    );
  }
}

class StaticLaserPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 5.0;
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    final glowPaint = Paint()..color = Colors.white.withOpacity(0.95)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2 - 0.03, 0.06, true, glowPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VividKaleidoscopePainter extends CustomPainter {
  final List<Color> themeColors;
  final Color? accentColor; 
  VividKaleidoscopePainter({required this.themeColors, this.accentColor});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // 🚀 1. 繪製底盤 (磨砂白背景)，營造純淨的玻璃質感
    final diskPaint = Paint()
      ..color = Colors.white.withOpacity(0.18) // 使用純淨白
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 3.0, diskPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    if (accentColor == null) {
      rimPaint.shader = SweepGradient(colors: themeColors.length >= 2 ? [...themeColors, themeColors.first] : [themeColors.first, themeColors.first]).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      final hsl = HSLColor.fromColor(accentColor!);
      final brighter = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
      final darker = hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
      rimPaint.shader = SweepGradient(colors: [darker, accentColor!, brighter, accentColor!, darker]).createShader(Rect.fromCircle(center: center, radius: radius));
    }
    canvas.drawCircle(center, radius - 2.5, rimPaint);
    for (int i = 0; i < 120; i++) {
      final Color lineColor = accentColor ?? Colors.white;
      final linePaint = Paint()..color = lineColor.withOpacity(i % 2 == 0 ? 0.6 : 0.2)..strokeWidth = i % 2 == 0 ? 2.0 : 1.2;
      double angle = i * (2 * math.pi / 120);
      canvas.drawLine(center + Offset.fromDirection(angle, radius * 0.28), center + Offset.fromDirection(angle, radius - 8), linePaint);
    }
  }
  @override
  bool shouldRepaint(VividKaleidoscopePainter old) => old.accentColor != accentColor;
}
