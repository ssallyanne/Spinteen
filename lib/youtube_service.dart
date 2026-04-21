import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class YouTubeService {
  static final YouTubeService _instance = YouTubeService._internal();
  factory YouTubeService() => _instance;
  YouTubeService._internal();

  static String get _apiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';
  static List<Episode> cachedEpisodes = [];
  
  /// 初始化數據：優先讀取快取，再從背景同步最新數據
  Future<void> init(KPopGroup group) async {
    // 🚀 1. 嘗試載入本地快取，讓使用者能秒開
    await _loadFromLocal(group.id);
    
    // 🚀 2. 背景更新數據 (不會阻礙 UI 渲染)
    _syncFromApi(group);
  }

  Future<void> _loadFromLocal(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? localData = prefs.getString('cache_$groupId');
    if (localData != null) {
      final List<dynamic> decoded = json.decode(localData);
      cachedEpisodes = decoded.map((item) => Episode.fromJson(item)).toList();
    }
  }

  Future<void> _syncFromApi(KPopGroup group) async {
    List<Episode> newEpisodes = [];
    
    for (var entry in group.playlistConfigs.entries) {
      String category = entry.key;
      List<String> playlistIds = entry.value;

      for (String playlistId in playlistIds) {
        final episodes = await fetchPlaylist(playlistId, category);
        newEpisodes.addAll(episodes);
      }
    }

    if (newEpisodes.isNotEmpty) {
      cachedEpisodes = newEpisodes;
      // 🚀 3. 儲存到本地，供下次使用
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_${group.id}', json.encode(newEpisodes.map((e) => e.toJson()).toList()));
    }
  }

  /// 抓取播放清單內容 (實作翻頁邏輯，抓取全部影片)
  Future<List<Episode>> fetchPlaylist(String playlistId, String category) async {
    String cleanId = playlistId.trim();
    final regExp = RegExp(r'list=([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(cleanId);
    if (match != null) cleanId = match.group(1)!;
    cleanId = cleanId.split('&').first.split('#').first;

    if (cleanId.isEmpty) return [];

    List<Episode> allItems = [];
    String? nextPageToken;

    // 🚀 4. 使用迴圈處理 nextPageToken，抓取該清單的所有影片 (不再限 50 筆)
    do {
      final queryParams = {
        'part': 'snippet',
        'maxResults': '50',
        'playlistId': cleanId,
        'key': _apiKey,
      };
      if (nextPageToken != null) queryParams['pageToken'] = nextPageToken;

      final uri = Uri.https('www.googleapis.com', '/youtube/v3/playlistItems', queryParams);

      try {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          nextPageToken = data['nextPageToken'];
          final List items = data['items'] ?? [];

          final mapped = items.map((item) {
            final snippet = item['snippet'];
            final thumbnails = snippet['thumbnails'];
            final videoId = snippet['resourceId']['videoId'];
            
            String bestThumbnail = thumbnails['high']?['url'] ?? 
                                  thumbnails['medium']?['url'] ?? 
                                  thumbnails['maxres']?['url'] ?? 
                                  thumbnails['standard']?['url'] ?? 
                                  thumbnails['default']?['url'] ?? '';

            return Episode(
              title: snippet['title'],
              category: category,
              youtubeUrl: 'https://www.youtube.com/watch?v=$videoId',
              thumbnailUrl: bestThumbnail,
            );
          }).toList();
          
          allItems.addAll(mapped);
        } else {
          print('❌ YouTube API Error [${response.statusCode}] for ID: $cleanId');
          nextPageToken = null; // 發生錯誤時停止迴圈
        }
      } catch (e) {
        print('🌐 Network Error in fetchPlaylist: $e');
        nextPageToken = null;
      }
    } while (nextPageToken != null);

    return allItems;
  }
}
