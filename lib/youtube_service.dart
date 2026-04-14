import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class YouTubeService {
  static final YouTubeService _instance = YouTubeService._internal();
  factory YouTubeService() => _instance;
  YouTubeService._internal();

  // 🚀 妳的 YouTube Data API Key
  static const String _apiKey = 'AIzaSyBd7uiSlXvDPFYdMH0J9FBhleU2ZN1Fb7w';
  
  static List<Episode> cachedEpisodes = [];
  
  /// 初始化指定團體的數據
  Future<void> init(KPopGroup group) async {
    cachedEpisodes.clear();
    
    for (var entry in group.playlistConfigs.entries) {
      String category = entry.key;
      List<String> playlistIds = entry.value;

      for (String playlistId in playlistIds) {
        final episodes = await fetchPlaylist(playlistId, category);
        cachedEpisodes.addAll(episodes);
      }
    }
    
    // 如果最終緩存是空的，加入絕對不會 404 的 Base64 數據保底
    if (cachedEpisodes.isEmpty) {
      cachedEpisodes.add(Episode(
        title: "暫無影片資料 (請確認 API 配額或 ID)",
        category: group.name,
        youtubeUrl: "https://www.youtube.com",
        thumbnailUrl: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=", 
      ));
    }
  }

  /// 抓取單一播放清單的內容
  Future<List<Episode>> fetchPlaylist(String playlistId, String category) async {
    // 🚀 1. 極致清洗與解析邏輯 (精準過濾 &si= 等參數)
    String cleanId = playlistId.trim();
    
    if (cleanId.contains("list=")) {
      // 先取 list= 之後的部分，再遇到 & 就切斷，確保只拿 ID
      cleanId = cleanId.split("list=").last.split("&").first;
    }
    
    // 強力過濾：只保留 A-Z, a-z, 0-9, 底線, 橫線
    cleanId = cleanId.replaceAll(RegExp(r'[^\w-]'), '');

    if (cleanId.isEmpty) return [];

    // 🚀 2. 使用 Uri 構建，並帶入隨機時間戳防止 404 被快取
    final uri = Uri.https('www.googleapis.com', '/youtube/v3/playlistItems', {
      'part': 'snippet',
      'maxResults': '50',
      'playlistId': cleanId,
      'key': _apiKey,
      '_t': DateTime.now().millisecondsSinceEpoch.toString(), 
    });

    try {
      print('🚀 Requesting YouTube API: $cleanId');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['items'] ?? [];

        return items.map((item) {
          final snippet = item['snippet'];
          final thumbnails = snippet['thumbnails'];
          final videoId = snippet['resourceId']['videoId'];
          
          // 層級式縮圖抓取，確保不論新舊影片都有圖顯示
          String bestThumbnail = thumbnails['maxres']?['url'] ?? 
                                thumbnails['high']?['url'] ?? 
                                thumbnails['medium']?['url'] ?? 
                                thumbnails['standard']?['url'] ?? 
                                thumbnails['default']?['url'] ?? '';

          return Episode(
            title: snippet['title'],
            category: category,
            youtubeUrl: 'https://www.youtube.com/watch?v=$videoId',
            thumbnailUrl: bestThumbnail,
          );
        }).toList();
      } else {
        // 如果報錯，在控制台印出具體原因方便排錯
        print('❌ YouTube API Error [${response.statusCode}] for ID: $cleanId');
        print('Error Reason: ${response.body}');
      }
    } catch (e) {
      print('🌐 Network Error in fetchPlaylist: $e');
    }
    return [];
  }
}