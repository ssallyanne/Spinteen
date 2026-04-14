import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'group_data.dart';
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

  KPopGroup currentGroup = GroupData.allGroups[0];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
    _initApp();
  }

  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedId = prefs.getString('last_selected_group_id');
    if (savedId != null) {
      final savedGroup = GroupData.allGroups.firstWhere(
        (g) => g.id == savedId,
        orElse: () => GroupData.allGroups[0],
      );
      if (mounted) setState(() { currentGroup = savedGroup; });
    }
    _loadInitialData();
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
    // 在背景預先載入所有縮圖存入快取，讓結果卡片彈出時能瞬間顯示
    for (var episode in YouTubeService.cachedEpisodes) {
      if (episode.thumbnailUrl.startsWith('http')) {
        precacheImage(NetworkImage(episode.thumbnailUrl), context).catchError((_) {
          // 忽略個別圖片預載失敗的錯誤，避免影響主執行緒
        });
      }
    }
  }

  Future<void> _handleGroupChange(KPopGroup group) async {
    if (group.id == currentGroup.id) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_selected_group_id', group.id);
    HapticFeedback.mediumImpact();
    setState(() {
      currentGroup = group;
      _selectedVideo = null;
      _highlightedIndex = null;
      _currentRotation = 0.0;
    });
    YouTubeService().init(currentGroup).then((_) { 
      if (mounted) {
        setState(() {}); 
        _precacheThumbnails();
      }
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
    setState(() { _selectedVideo = null; _highlightedIndex = null; });
    final picked = data[math.Random().nextInt(data.length)];
    final categories = currentGroup.playlistConfigs.keys.toList();
    int catIdx = categories.indexOf(picked.category);
    double sectorAngle = 2 * math.pi / categories.length;
    double randomOffset = (math.Random().nextDouble() * 0.6 + 0.2) * sectorAngle;
    double targetRotation = (12 * math.pi) + (1.5 * math.pi) - (catIdx * sectorAngle) - randomOffset;
    _animation = Tween<double>(begin: _currentRotation % (2 * math.pi), end: targetRotation)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCirc));
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

    return Scaffold(
      backgroundColor: Colors.black, // 避免系統預設白底在邊緣露出
      extendBody: true,
      extendBodyBehindAppBar: true,
      // 🚀 關鍵修正 2：延伸背景至全螢幕（含瀏海區域）
      body: Stack(
        children: [
          // 背景層：不被 SafeArea 限制，實現全屏浸潤
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: currentGroup.themeColors,
                ),
              ),
            ),
          ),
          
          // 內容層：使用 SafeArea 保護文字與 UI
          SafeArea(
            bottom: false, // 讓背景延伸到導覽條下方
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildGroupBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 35),
                        Text(
                          currentGroup.id == 'svt' ? "今天 GOING 到哪 👀" : "今天 RUN 到哪 🏃‍♂️",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // 🚀 關鍵修正 1：整合輪盤與箭頭
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. 輪盤本體
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, _) => Transform.rotate(
                                angle: _controller.isAnimating ? _animation.value : _currentRotation,
                                child: Container(
                                  width: rouletteSize,
                                  height: rouletteSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle, // 移除 boxShadow，解決黑色陰影透出導致的「灰色蒙版」問題
                                  ),
                                  child: CustomPaint(
                                    // 🚀 關鍵修正 3：傳遞團體色用於外圈漸層
                                    painter: VividKaleidoscopePainter(themeColors: currentGroup.themeColors),
                                  ),
                                ),
                              ),
                            ),
                            
                            // 2. 指針與中心 Logo (黏著設計)
                            if (_highlightedIndex != null)
                              IgnorePointer(child: SizedBox(width: rouletteSize, height: rouletteSize, child: CustomPaint(painter: StaticLaserPainter()))),
                            
                            // 3. 箭頭：再次放大尺寸並調整位置以黏著中心 Hub
                            Positioned(
                              top: (rouletteSize / 2) - (hubSize / 2) - 46, // 配合放大的尺寸調整偏移量，保持貼合
                              child: const RotatedBox(
                                quarterTurns: 2, // 旋轉 180 度
                                child: Icon(Icons.arrow_drop_down, size: 100, color: Colors.black),
                              ),
                            ),
                            
                            GestureDetector(
                              onTap: _startSpin,
                              child: _buildCenterHub(hubSize),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 25), 
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          child: _selectedVideo == null 
                              ? const SizedBox(height: 120) 
                              : _buildGlassResultCard(_selectedVideo!),
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

  Widget _buildGroupBar() {
    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: GroupData.allGroups.length,
        itemBuilder: (context, index) {
          final group = GroupData.allGroups[index];
          bool isSelected = group.id == currentGroup.id;
          return GestureDetector(
            onTap: () => _handleGroupChange(group),
            child: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Column(
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isSelected ? 1.0 : 0.4,
                    child: CircleAvatar(radius: 28, backgroundColor: Colors.transparent, backgroundImage: AssetImage(group.logoPath)),
                  ),
                  const SizedBox(height: 4),
                  Text(group.name, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white, fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCenterHub(double size) {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(child: Image.asset(currentGroup.logoPath, fit: BoxFit.contain)),
    );
  }

  Widget _buildGlassResultCard(Episode video) {
    final prefixRegex = RegExp(r'^(RUN\s*BTS|GOING\s*SEVENTEEN)[!\s-]*', caseSensitive: false);
    String cleanedTitle = video.title.replaceFirst(RegExp(r'\[.*?\]\s*'), '').replaceFirst(prefixRegex, '').trim();
    String displayCategory = currentGroup.id == 'svt' ? "GOING SEVENTEEN" : "RUN BTS";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 21),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, 
              children: [
                Expanded(
                  flex: 40,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(video.thumbnailUrl, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 60,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayCategory, 
                        style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF37474F), letterSpacing: 0.8)),
                      const SizedBox(height: 5),
                      Text(cleanedTitle, 
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2, color: Colors.white).copyWith(
                          fontFamilyFallback: [GoogleFonts.notoSansKr().fontFamily!, 'sans-serif'],
                        ), 
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 10),
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: LinearGradient(colors: currentGroup.themeColors),
          boxShadow: [BoxShadow(color: currentGroup.themeColors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
            SizedBox(width: 4),
            Text("WATCH ON YOUTUBE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class StaticLaserPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // 外圈描邊寬度為 5，因此半徑減 5 往內縮，避開外圈
    final radius = (size.width / 2) - 5.0;
    
    // 加入裁切，確保發光的邊緣絕對不會暈染並覆蓋到輪盤的邊線
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    final glowPaint = Paint()..color = Colors.white.withOpacity(0.95)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2 - 0.03, 0.06, true, glowPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VividKaleidoscopePainter extends CustomPainter {
  final List<Color> themeColors;
  VividKaleidoscopePainter({required this.themeColors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 🚀 關鍵修正 3：繪製應援色漸層外環
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..shader = SweepGradient(
        colors: [...themeColors, themeColors.first],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawCircle(center, radius - 2.5, rimPaint);

    // 內部裝飾線
    for (int i = 0; i < 120; i++) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(i % 2 == 0 ? 0.25 : 0.05) // 降低線條不透明度，讓背景漸層更清晰
        ..strokeWidth = 1.5;
      double angle = i * (2 * math.pi / 120);
      canvas.drawLine(
        center + Offset.fromDirection(angle, radius * 0.28), 
        center + Offset.fromDirection(angle, radius - 8), 
        paint
      );
    }
  }
  @override
  bool shouldRepaint(VividKaleidoscopePainter old) => true;
}