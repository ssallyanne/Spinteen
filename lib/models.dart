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

  // 🚀 加入 JSON 轉換，以便本地快取
  Map<String, dynamic> toJson() => {
    'title': title,
    'category': category,
    'youtubeUrl': youtubeUrl,
    'thumbnailUrl': thumbnailUrl,
  };

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    title: json['title'] ?? '',
    category: json['category'] ?? '',
    youtubeUrl: json['youtubeUrl'] ?? '',
    thumbnailUrl: json['thumbnailUrl'] ?? '',
  );
}

class KPopGroup {
  final String id;
  final String name;
  final String logoPath;
  final List<Color> themeColors; 
  final Map<String, List<String>> playlistConfigs; 
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
