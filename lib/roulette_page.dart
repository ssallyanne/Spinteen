import 'dart:math' as math;
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
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
  
  late Animation<double> _animation;
  late Animation<Alignment> _bgBegin;
  late Animation<Alignment> _bgEnd;
  
  double _currentRotation = 0.0;
  Episode? _selectedVideo;
  int? _highlightedIndex;
  
  String? _customHubImageBase64; // 用於存放上傳的照片
  String? _selectedMemberName; // 🚀 用於存放選中的 MINITEEN 名字

  KPopGroup currentGroup = GroupData.allGroups[0];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
    
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _bgBegin = Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.bottomLeft).animate(_bgController);
    _bgEnd = Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.topRight).animate(_bgController);

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);

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

    _customHubImageBase64 = prefs.getString('custom_hub_${currentGroup.id}');
    _selectedMemberName = prefs.getString('member_${currentGroup.id}');
    
    _loadInitialData();
  }

  // 🚀 彈出成員選擇面板 (僅限 SEVENTEEN)
  void _showMemberPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C1E).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text("選擇守護成員", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("選一位成員為您轉動輪盤吧！", style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 15, mainAxisSpacing: 20, childAspectRatio: 0.85,
                ),
                itemCount: GroupData.seventeenMembers.length,
                itemBuilder: (context, index) {
                  final name = GroupData.seventeenMembers[index];
                  // 圖片路徑假設為 assets/miniteen/name.png
                  final assetPath = 'assets/miniteen/${name.toLowerCase().replaceAll('.', '')}.png';
                  bool isSelected = _selectedMemberName == name;

                  return GestureDetector(
                    onTap: () => _updateSelectedMember(name),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 65, height: 65,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? const Color(0xFFF7CAC9) : Colors.transparent, width: 3),
                            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFF7CAC9).withOpacity(0.3), blurRadius: 10)] : [],
                          ),
                          child: ClipOval(
                            child: Image.asset(assetPath, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.white10, child: const Icon(Icons.face, color: Colors.white24))),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(name, style: GoogleFonts.plusJakartaSans(color: isSelected ? Colors.white : Colors.white60, fontSize: 10, fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateSelectedMember(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('member_${currentGroup.id}', name);
    await prefs.remove('custom_hub_${currentGroup.id}'); // 切換成員時清除自定義照片
    
    setState(() {
      _selectedMemberName = name;
      _customHubImageBase64 = null;
    });
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  // 原始的上傳照片功能 (保留給其他用途或 BTS)
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final String base64Image = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_hub_${currentGroup.id}', base64Image);
      await prefs.remove('member_${currentGroup.id}');
      setState(() { _customHubImageBase64 = base64Image; _selectedMemberName = null; });
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _clearCustom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_hub_${currentGroup.id}');
    await prefs.remove('member_${currentGroup.id}');
    setState(() { _customHubImageBase64 = null; _selectedMemberName = null; });
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

  Future<void> _handleGroupChange(KPopGroup group) async {
    if (group.id == currentGroup.id) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_selected_group_id', group.id);
    final String? savedAvatar = prefs.getString('custom_hub_${group.id}');
    final String? savedMember = prefs.getString('member_${group.id}');
    
    HapticFeedback.mediumImpact();
    setState(() {
      currentGroup = group;
      _customHubImageBase64 = savedAvatar;
      _selectedMemberName = savedMember;
      _selectedVideo = null;
      _highlightedIndex = null;
      _currentRotation = 0.0;
    });
    YouTubeService().init(currentGroup).then((_) { 
      if (mounted) { setState(() {}); _precacheThumbnails(); }
    });
  }

  @override
  void dispose() {
    _controller.dispose(); _bgController.dispose(); _pulseController.dispose();
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
                                  child: CustomPaint(painter: VividKaleidoscopePainter(themeColors: currentGroup.themeColors)),
                                ),
                              ),
                            ),
                            if (_highlightedIndex != null)
                              IgnorePointer(child: SizedBox(width: rouletteSize, height: rouletteSize, child: CustomPaint(painter: StaticLaserPainter()))),
                            Positioned(
                              top: (rouletteSize / 2) - (hubSize / 2) - 46,
                              child: const RotatedBox(quarterTurns: 2, child: Icon(Icons.arrow_drop_down, size: 100, color: Colors.black)),
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

                        // 🚀 新版工具列：SEVENTEEN 顯示選取器，其餘顯示上傳
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: currentGroup.id == 'svt' ? _showMemberPicker : _pickImage,
                                icon: Icon(currentGroup.id == 'svt' ? Icons.pets_rounded : Icons.add_a_photo_rounded, color: Colors.white70, size: 16),
                                label: Text(currentGroup.id == 'svt' ? "更換 MINITEEN" : "更換中心頭像", style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12)),
                              ),
                              if (_customHubImageBase64 != null || _selectedMemberName != null)
                                IconButton(onPressed: _clearCustom, icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 16)),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 15), 
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

  Widget _buildGroupBar() {
    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    duration: const Duration(milliseconds: 300), opacity: isSelected ? 1.0 : 0.4,
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
    Widget displayImage;
    
    if (_selectedMemberName != null) {
      // 🚀 顯示 MINITEEN 角色
      final assetPath = 'assets/miniteen/${_selectedMemberName!.toLowerCase().replaceAll('.', '')}.png';
      displayImage = Image.asset(assetPath, fit: BoxFit.cover, errorBuilder: (c, e, s) => Image.asset(currentGroup.logoPath));
    } else if (_customHubImageBase64 != null) {
      // 🚀 顯示使用者上傳照片
      displayImage = Image.memory(base64Decode(_customHubImageBase64!), fit: BoxFit.cover);
    } else {
      // 🚀 顯示預設 Logo
      displayImage = Image.asset(currentGroup.logoPath, fit: BoxFit.contain);
    }

    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(child: displayImage),
    );
  }

  Widget _buildGlassResultCard(Episode video) {
    final prefixRegex = RegExp(r'^(RUN\s*BTS|GOING\s*SEVENTEEN)[!\s-]*', caseSensitive: false);
    String cleanedTitle = video.title.replaceFirst(RegExp(r'\[.*?\]\s*'), '').replaceFirst(prefixRegex, '').trim();
    String displayCategory = currentGroup.id == 'svt' ? "GOING SEVENTEEN" : "RUN BTS";
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
  VividKaleidoscopePainter({required this.themeColors});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rimPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 5.0..shader = SweepGradient(colors: themeColors.length >= 2 ? [...themeColors, themeColors.first] : [themeColors.first, themeColors.first]).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 2.5, rimPaint);
    for (int i = 0; i < 120; i++) {
      final linePaint = Paint()..color = Colors.white.withOpacity(i % 2 == 0 ? 0.25 : 0.05)..strokeWidth = 1.5;
      double angle = i * (2 * math.pi / 120);
      canvas.drawLine(center + Offset.fromDirection(angle, radius * 0.28), center + Offset.fromDirection(angle, radius - 8), linePaint);
    }
  }
  @override
  bool shouldRepaint(VividKaleidoscopePainter old) => true;
}
