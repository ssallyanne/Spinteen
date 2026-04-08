import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models.dart';

class YouTubeService {
  static final YouTubeService _instance = YouTubeService._internal();
  factory YouTubeService() => _instance;
  YouTubeService._internal();

  // 🚀 已更新為最新的 GOING SEVENTEEN 播放清單 ID
  static final Map<String, String> playlistConfigs = {
    "GOING SEVENTEEN (ALL)": "PLk_UmMfvZDx21Z9eEQ9DcIlUfZp1uwEup",
    "GOING SEVENTEEN 2019": "PLk_UmMfvZDx2-r7Kt-k2GjtQcTecKAB6p",
    "GOING SEVENTEEN 2020": "PLk_UmMfvZDx1Ug2GQ5NCijKz7Q3pmZLlT",
  };

  static List<Episode> cachedEpisodes = [];

  String get _apiKey => dotenv.get('YOUTUBE_API_KEY', fallback: "");

  Future<void> init() async {
    if (cachedEpisodes.isNotEmpty) return;
    
    // 🚀 保底機制：確保即使 API 請求失敗，輪盤依然有資料可以旋轉
    cachedEpisodes.add(Episode(
      title: "[GOING SEVENTEEN] 測試影片 (API 加載失敗時顯示)",
      category: "GOING SEVENTEEN",
      youtubeUrl: "https://www.youtube.com/watch?v=s4jHQXd-7gg",
      thumbnailUrl: "https://img.youtube.com/vi/s4jHQXd-7gg/maxresdefault.jpg",
    ));

    for (var entry in playlistConfigs.entries) {
      try {
        final episodes = await fetchFullPlaylist(entry.value, entry.key);
        cachedEpisodes.addAll(episodes);
      } catch (e) { 
        // 妳可以在除錯時開啟這行查看錯誤原因
        // print("抓取播放清單 ${entry.key} 失敗: $e"); 
      }
    }
  }

  Future<List<Episode>> fetchFullPlaylist(String playlistId, String categoryName) async {
    List<Episode> results = [];
    if (_apiKey.isEmpty) return [];

    final url = 'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=50&playlistId=$playlistId&key=$_apiKey';
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      for (var item in data['items']) {
        final snippet = item['snippet'];
        
        // 過濾掉標題中可能包含 "Private video" 或 "Deleted video" 的項目
        if (snippet['title'] == 'Private video' || snippet['title'] == 'Deleted video') continue;

        results.add(Episode(
          title: snippet['title'],
          category: categoryName,
          youtubeUrl: 'https://www.youtube.com/watch?v=${snippet['resourceId']['videoId']}',
          thumbnailUrl: snippet['thumbnails']['high']?['url'] ?? '',
        ));
      }
    }
    return results;
  }
}