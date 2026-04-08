import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🚀 必須引入這個
import 'package:seventeen_spinteen/main.dart'; // 🚀 必須與 pubspec 的 name 一致
void main() {
  testWidgets('SpinteenApp 啟動測試', (WidgetTester tester) async {
    // 🚀 核心修正：在測試開始前，手動塞入模擬的環境變數
    // 這樣 pumpWidget 時才不會因為找不到 API Key 而報錯
    dotenv.testLoad(fileInput: 'YOUTUBE_API_KEY=mock_api_key_for_test');

    // 現在可以安全地建立 Widget 了
    await tester.pumpWidget(const SpinteenApp());

    // 驗證標題是否存在 (這只是範例，你可以根據需求修改)
    expect(find.text('今天 GOING 到哪 👀'), findsOneWidget);
  });
}