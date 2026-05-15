import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'roulette_page.dart';
import 'theme.dart';
import 'l10n.dart';

// 🚀 1. 異步初始化
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 使用 then/catchError 以免卡死初始化
  dotenv.load(fileName: ".env").then((_) {
    debugPrint("環境變數載入成功");
  }).catchError((e) {
    debugPrint("環境變數載入失敗: $e");
  });

  runApp(const SpinteenApp());
}

// 🚀 3. 正式定義 SpinteenApp 類別 (解決測試檔報錯的關鍵)
class SpinteenApp extends StatelessWidget {
  const SpinteenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '17 Spinteen',
      debugShowCheckedModeBanner: false,
      // 使用你在 theme.dart 定義的 EditorialTheme
      theme: EditorialTheme.lightTheme, 
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', ''),
        Locale('en', ''),
        Locale('ko', ''),
        Locale('ja', ''),
      ],
      home: const RoulettePage(),
    );
  }
}
