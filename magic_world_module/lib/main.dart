import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic_world_module/native_ffi.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const MethodChannel _navigationChannel = MethodChannel(
    'com.magic.world/navigation',
  );

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    _navigationChannel.setMethodCallHandler((call) async {
      if (call.method == "navigateTo") {
        final String? routeName = call.arguments['routeName'];
        final Map<String, dynamic>? arguments =
            call.arguments['arguments'] != null
            ? Map<String, dynamic>.from(call.arguments['arguments'])
            : null;

        if (routeName != null) {
          debugPrint('收到原生路由请求: $routeName, 参数: $arguments');
          _navigatorKey.currentState?.pushNamed(
            routeName,
            arguments: arguments,
          );
        }
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      navigatorKey: _navigatorKey,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    debugPrint('生成路由: ${settings.name}, 参数: ${settings.arguments}');

    Widget page;
    switch (settings.name) {
      case '/':
        page = const HomePage();
        break;
      case '/detail':
        final args = settings.arguments as Map<String, dynamic>?;
        page = DetailPage(params: args);
        break;
      case '/profile':
        final args = settings.arguments as Map<String, dynamic>?;
        page = ProfilePage(params: args);
        break;
      default:
        page = Scaffold(body: SizedBox.shrink());
    }

    return MaterialPageRoute(
      builder: (context) => page,
      settings: settings,
      traversalEdgeBehavior: .closedLoop,
    );
  }
}

// 默认首页
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("首页")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Flutter首页",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/detail',
                  arguments: {'id': '123', 'title': '商品详情'},
                );
              },
              child: const Text('跳转到详情页'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/profile',
                  arguments: {'theme': 'dark', 'userId': '456'},
                );
              },
              child: const Text('跳转到个人资料页'),
            ),
          ],
        ),
      ),
    );
  }
}

// 详情页（支持参数）
class DetailPage extends StatelessWidget {
  final Map<String, dynamic>? params;
  const DetailPage({super.key, this.params});

  static const MethodChannel _navigationChannel = MethodChannel(
    'com.magic.world/navigation',
  );

  Future<void> _backToNative() async {
    try {
      await _navigationChannel.invokeMethod('popToNative');
    } catch (e) {
      debugPrint('返回原生页面失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('详情页')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "详情页",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              Text(
                "ID: ${params?['id'] ?? '无'}",
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                "标题: ${params?['title'] ?? '无'}",
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _backToNative,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('返回原生页面'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 个人资料页（支持参数）
class ProfilePage extends StatelessWidget {
  final Map<String, dynamic>? params;
  const ProfilePage({super.key, this.params});

  static const MethodChannel _navigationChannel = MethodChannel(
    'com.magic.world/navigation',
  );

  Future<void> _backToNative() async {
    try {
      await _navigationChannel.invokeMethod('popToNative');
    } catch (e) {
      debugPrint('返回原生页面失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "个人资料页",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              Text(
                "主题: ${params?['theme'] ?? '无'}",
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                "用户ID: ${params?['userId'] ?? '无'}",
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _backToNative,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('返回原生页面'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
