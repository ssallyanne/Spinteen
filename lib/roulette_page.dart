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
import 'l10n.dart';

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
    if (_selectedMemberName != null) return currentGroup.memberColors[_selectedMemberName];
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
      int memberIdx = currentGroup.members.indexOf(_selectedMemberName!);
      if (memberIdx != -1) {
        int targetPage = (_infiniteCount ~/ 2) - ((_infiniteCount ~/ 2) % currentGroup.members.length) + memberIdx;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_cardPageController.hasClients) _cardPageController.jumpToPage(targetPage);
        });
      }
    }
    _loadInitialData();
  }

  void _switchGroup(KPopGroup newGroup) async {
    if (newGroup.id == currentGroup.id) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_selected_group_id', newGroup.id);
    
    setState(() {
      currentGroup = newGroup;
      _selectedVideo = null;
      _highlightedIndex = null;
      _currentRotation = 0.0;
    });
    
    _initApp(); 
  }

  Future<void> _updateSelectedMember(String name) async {
    if (_selectedMemberName == name) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('member_${currentGroup.id}', name);
    await prefs.remove('custom_hub_${currentGroup.id}');
    HapticFeedback.selectionClick();
    
    setState(() { 
      _selectedMemberName = name; 
      _customHubImageBase64 = null;
      // 🚀 1. 當用戶點擊新成員時，自動收起之前的抽獎結果，清空舞台
      _selectedVideo = null;
      _highlightedIndex = null;
    });
  }

  void _loadInitialData() {
    YouTubeService().init(currentGroup).then((_) {
      if (mounted) { 
        setState(() {}); 
        _precacheThumbnails(); 
      }
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

    // 🚀 保留「噠噠噠」的觸覺反饋監聽，但動畫曲線已改為平滑減速
    int lastSector = -1;
    final sectors = currentGroup.playlistConfigs.keys.length;
    final sweep = 2 * math.pi / sectors;
    
    _controller.addListener(() {
      if (_controller.isAnimating) {
        int currentSector = (_animation.value / sweep).floor();
        if (currentSector != lastSector) {
          HapticFeedback.selectionClick();
          lastSector = currentSector;
        }
      }
    });

    _controller.forward(from: 0.0).then((_) {
      HapticFeedback.heavyImpact();
      setState(() { _currentRotation = targetRotation; _selectedVideo = picked; _highlightedIndex = catIdx; });
    });
  }

  void _showGroupSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context).chooseGroup, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            ...GroupData.allGroups.map((group) => ListTile(
              leading: Container(
                width: 45, height: 45,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
                child: ClipOval(child: Image.asset(group.logoPath, fit: BoxFit.cover)),
              ),
              title: Text(group.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              trailing: currentGroup.id == group.id ? const Icon(Icons.check_circle, color: Colors.green) : null,
              onTap: () {
                Navigator.pop(context);
                _switchGroup(group);
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        
        // 根據螢幕寬度與高度，動態計算輪盤大小，確保在不同比例的螢幕上都能正確顯示
        final rouletteSize = math.min(screenWidth * 0.85, screenHeight * 0.4).clamp(200.0, 400.0);
        final hubSize = rouletteSize * 0.28;
        final Color? activeMemberColor = _getSelectedMemberColor();

        return Scaffold(
          backgroundColor: Colors.black,
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800), 
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, 
                      end: Alignment.bottomRight, 
                      colors: currentGroup.themeColors
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.05), // 🚀 再將 UI 下移一點，確保充足的頂部留白
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.05, 
                        vertical: math.max(10, screenHeight * 0.015)
                      ),
                      child: Center(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: AppLocalizations.of(context).title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: screenWidth > 400 ? 24 : 20,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "👀",
                                style: TextStyle(
                                  fontSize: screenWidth > 400 ? 24 : 20,
                                  fontFamilyFallback: const ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            SizedBox(height: screenHeight * 0.02),
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
                                  top: (rouletteSize / 2) - (hubSize / 2) - (rouletteSize * 0.15), 
                                  child: RotatedBox(
                                    quarterTurns: 2, 
                                    child: Icon(
                                      Icons.arrow_drop_down, 
                                      size: rouletteSize * 0.32,
                                      color: activeMemberColor ?? Colors.black,
                                    )
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
                            SizedBox(height: screenHeight * 0.03),
                            _buildCardSelector(screenWidth),
                            SizedBox(height: screenHeight * 0.03), 
                            _buildStatusIndicator(), // 🚀 新增載入/錯誤狀態指示器
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 800),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                                    child: child,
                                  ),
                                );
                              },
                              child: _selectedVideo == null 
                                ? SizedBox(height: screenHeight * 0.15) 
                                : _buildGlassResultCard(_selectedVideo!, screenWidth),
                            ),
                            SizedBox(height: screenHeight * 0.05), 
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
      },
    );
  }

  // 🚀 優化 4: 載入與錯誤狀態指示器
  Widget _buildStatusIndicator() {
    if (YouTubeService.isSyncing) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white70)),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).syncing, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11)),
          ],
        ),
      );
    }
    if (YouTubeService.errorMessage != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
        child: Text(AppLocalizations.of(context).syncFailed, style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 10)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCardSelector(double screenWidth) {
    return Column(
      children: [
        SizedBox(
          height: screenWidth > 400 ? 100 : 80,
          child: PageView.builder(
            controller: _cardPageController,
            itemCount: _infiniteCount,
            onPageChanged: (idx) {
              final realIdx = idx % currentGroup.members.length;
              _updateSelectedMember(currentGroup.members[realIdx]);
            },
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final realIdx = index % currentGroup.members.length;
              final name = currentGroup.members[realIdx];
              final assetPath = '${currentGroup.memberAssetPrefix}${name.toLowerCase().replaceAll('.', '')}.png';
              bool isSelected = _selectedMemberName == name;
              final Color activeColor = currentGroup.memberColors[name] ?? Colors.white;
              return AnimatedBuilder(
                animation: _cardPageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_cardPageController.position.haveDimensions) {
                    value = _cardPageController.page! - index;
                    value = (1 - (value.abs() * 0.25)).clamp(0.0, 1.0); 
                  } else {
                    value = isSelected ? 1.0 : 0.72; 
                  }
                  
                  final cardSize = screenWidth > 400 ? 60.0 : 50.0;

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
                            width: cardSize, height: cardSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? activeColor : Colors.white12, width: 1.5),
                              boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 10)] : [],
                            ),
                            child: ClipOval(
                              child: currentGroup.memberAssetPrefix.isNotEmpty 
                                ? Image.asset(assetPath, fit: BoxFit.cover, errorBuilder: (c,e,s) => _buildNameBadge(name))
                                : _buildNameBadge(name),
                            ),
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
      final assetPath = '${currentGroup.memberAssetPrefix}${_selectedMemberName!.toLowerCase().replaceAll('.', '')}.png';
      displayImage = currentGroup.memberAssetPrefix.isNotEmpty 
        ? Image.asset(assetPath, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildNameBadge(_selectedMemberName!))
        : _buildNameBadge(_selectedMemberName!);
    } else if (_customHubImageBase64 != null) {
      displayImage = Image.memory(base64Decode(_customHubImageBase64!), fit: BoxFit.cover);
    } else {
      displayImage = Image.asset(currentGroup.logoPath, fit: BoxFit.contain);
    }
    return Container(width: size, height: size, decoration: const BoxDecoration(shape: BoxShape.circle), child: ClipOval(child: displayImage));
  }

  Widget _buildNameBadge(String name) {
    String initial = name.length > 2 ? name.substring(0, 2) : name;
    final Color badgeColor = currentGroup.memberColors[name] ?? currentGroup.themeColors.first;
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [badgeColor, badgeColor.withOpacity(0.7)])),
      alignment: Alignment.center,
      child: Text(initial, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1)),
    );
  }

  Widget _buildGlassResultCard(Episode video, double screenWidth) {
    final prefixRegex = RegExp(r'^(GOING\s*SEVENTEEN)[!\s-]*', caseSensitive: false);
    String cleanedTitle = video.title.replaceFirst(RegExp(r'\[.*?\]\s*'), '').replaceFirst(prefixRegex, '').trim();
    String displayCategory = "GOING SEVENTEEN";
    final screenHeight = MediaQuery.of(context).size.height;
    
    return GestureDetector(
      key: ValueKey(video.youtubeUrl), // 🚀 確保 AnimatedSwitcher 識別不同影片
      onTap: () => launchUrl(Uri.parse(video.youtubeUrl)),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: EdgeInsets.all(screenWidth > 400 ? 18 : 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.42), 
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5), // 🚀 加粗邊框強化精品感
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10)),
                  BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 0, spreadRadius: -2, offset: const Offset(0, -2)), // 🚀 頂部高光
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 42, child: AspectRatio(aspectRatio: 16 / 9, child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16), 
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))]
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16), 
                        child: CachedNetworkImage(
                          imageUrl: video.thumbnailUrl, 
                          fit: BoxFit.cover, 
                          placeholder: (context, url) => Container(color: Colors.white10), 
                          errorWidget: (context, url, error) => Container(
                            color: Colors.black12,
                            child: const Icon(Icons.play_circle_outline, color: Colors.white38, size: 30),
                          ),
                        )
                      ),
                    )),
                  ),
                  SizedBox(width: screenWidth > 400 ? 18 : 12),
                  Expanded(
                    flex: 58, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.08), borderRadius: BorderRadius.circular(20)), child: Text(displayCategory, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF1A1C1E), letterSpacing: 1.0))),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        cleanedTitle, 
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: screenWidth > 400 ? 15 : 13, 
                          fontWeight: FontWeight.bold, 
                          height: 1.15, 
                          color: const Color(0xFF1A1C1E)
                        ).copyWith(fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji', 'Apple SD Gothic Neo', 'Malgun Gothic', 'Nanum Gothic', 'Dotum', 'sans-serif']), 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      _buildWatchButton(video.youtubeUrl, screenWidth),
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

  Widget _buildWatchButton(String url, double screenWidth) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), gradient: LinearGradient(colors: currentGroup.themeColors), boxShadow: [BoxShadow(color: currentGroup.themeColors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white), const SizedBox(width: 4), Text(AppLocalizations.of(context).watchOnYoutube, style: TextStyle(color: Colors.white, fontSize: screenWidth > 400 ? 8 : 7, fontWeight: FontWeight.bold))]),
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
    
    final diskPaint = Paint()
      ..color = Colors.white.withOpacity(0.18) 
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
