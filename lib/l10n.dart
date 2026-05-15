import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      'title': '今天 GOING 到哪 ',
      'choose_group': '選擇 K-Pop 團體',
      'syncing': '正在同步最新集數...',
      'sync_failed': '⚠ 資料同步失敗，使用快取數據',
      'watch_on_youtube': 'WATCH ON YOUTUBE',
    },
    'en': {
      'title': 'Where to GOING today? ',
      'choose_group': 'Select K-Pop Group',
      'syncing': 'Syncing latest episodes...',
      'sync_failed': '⚠ Sync failed, using cached data',
      'watch_on_youtube': 'WATCH ON YOUTUBE',
    },
    'ko': {
      'title': '오늘은 어디로 GOING? ',
      'choose_group': 'K-Pop 그룹 선택',
      'syncing': '최신 에피소드 동기화 중...',
      'sync_failed': '⚠ 동기화 실패, 캐시된 데이터 사용',
      'watch_on_youtube': '유튜브에서 보기',
    },
    'ja': {
      'title': '今日はどこへ GOING? ',
      'choose_group': 'K-Popグループを選択',
      'syncing': '最新エピソードを同期中...',
      'sync_failed': '⚠ 同期失敗、キャッシュデータを使用',
      'watch_on_youtube': 'YouTubeで見る',
    },
  };

  String get title => _localizedValues[locale.languageCode]?['title'] ?? _localizedValues['en']!['title']!;
  String get chooseGroup => _localizedValues[locale.languageCode]?['choose_group'] ?? _localizedValues['en']!['choose_group']!;
  String get syncing => _localizedValues[locale.languageCode]?['syncing'] ?? _localizedValues['en']!['syncing']!;
  String get syncFailed => _localizedValues[locale.languageCode]?['sync_failed'] ?? _localizedValues['en']!['sync_failed']!;
  String get watchOnYoutube => _localizedValues[locale.languageCode]?['watch_on_youtube'] ?? _localizedValues['en']!['watch_on_youtube']!;
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['zh', 'en', 'ko', 'ja'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
