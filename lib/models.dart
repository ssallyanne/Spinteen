import 'package:flutter/material.dart';

class Episode {
  final String title;
  final String category;
  final String youtubeUrl;
  final String thumbnailUrl;

  Episode({
    required this.title,
    required this.category,
    required this.youtubeUrl,
    required this.thumbnailUrl,
  });
}

// 🚀 新增這個 KPopGroup 類別
class KPopGroup {
  final String id;
  final String name;
  final String logoPath;
  final List<Color> themeColors; 
  final Map<String, List<String>> playlistConfigs; // 類別名稱 : 播放清單 ID 清單
  final String shareTag;

  KPopGroup({
    required this.id,
    required this.name,
    required this.logoPath,
    required this.themeColors,
    required this.playlistConfigs,
    required this.shareTag,
  });
}