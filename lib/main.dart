import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(const FollowerXApp());
}

class FollowerXApp extends StatefulWidget {
  const FollowerXApp({super.key});

  @override
  State<FollowerXApp> createState() => _FollowerXAppState();
}

class _FollowerXAppState extends State<FollowerXApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Follower X',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        primaryColor: const Color(0xFF00A2FF),
        cardColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF00A2FF),
          surface: Colors.white,
          onSurface: Colors.black,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121214),
        primaryColor: const Color(0xFF00A2FF),
        cardColor: const Color(0xFF1E1E24),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00A2FF),
          surface: Color(0xFF1E1E24),
          onSurface: Colors.white,
        ),
      ),
      home: SplashScreen(toggleTheme: toggleTheme, isDark: _themeMode == ThemeMode.dark),
    );
  }
}

// Global API Configs
const String apiUrl = 'https://ylafollow.com/api/v2';
const String apiKey = '2ff0c9c3dbf8db742196dd1d4215bbe2';

// Models
class ServiceModel {
  final String service;
  final String name;
  final String type;
  final String category;
  final String rate;
  final String min;
  final String max;

  ServiceModel({
    required this.service,
    required this.name,
    required this.type,
    required this.category,
    required this.rate,
    required this.min,
    required this.max,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      service: json['service']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      rate: json['rate']?.toString() ?? '0',
      min: json['min']?.toString() ?? '0',
      max: json['max']?.toString() ?? '0',
    );
  }
}

class OrderModel {
  final String order;
  String status;
  final String charge;
  final String startCount;
  final String remains;
  final String link;
  final String serviceName;
  final String date;

  OrderModel({
    required this.order,
    required this.status,
    required this.charge,
    required this.startCount,
    required this.remains,
    required this.link,
    required this.serviceName,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'order': order,
        'status': status,
        'charge': charge,
        'startCount': startCount,
        'remains': remains,
        'link': link,
        'serviceName': serviceName,
        'date': date,
      };

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        order: json['order'] ?? '',
        status: json['status'] ?? 'قيد الانتظار',
        charge: json['charge'] ?? '0.00',
        startCount: json['startCount'] ?? '0',
        remains: json['remains'] ?? '0',
        link: json['link'] ?? '',
        serviceName: json['serviceName'] ?? '',
        date: json['date'] ?? '',
      );
}

// Global Network Helper Function
Future<List<ServiceModel>> fetchServicesFromApi() async {
  final response = await http.post(
    Uri.parse(apiUrl),
    headers: {
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    },
    body: {
      'key': apiKey,
      'action': 'services',
    },
  );

  if (response.statusCode == 200) {
    final dynamic decodedData = json.decode(response.body);
    List<ServiceModel> fetchedList = [];

    if (decodedData is List) {
      fetchedList = decodedData.map((item) => ServiceModel.fromJson(item)).toList();
    } else if (decodedData is Map<String, dynamic>) {
      if (decodedData.containsKey('error')) {
        throw Exception(decodedData['error']);
      }
      decodedData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          fetchedList.add(ServiceModel.fromJson(value));
        }
      });
    }
    return fetchedList;
  } else {
    throw Exception('خطأ في السيرفر: ${response.statusCode}');
  }
}

// App-wide Store & Persistence for Local Orders Tracking
List<OrderModel> userOrdersStore = [];

Future<void> saveOrdersToStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String> encoded = userOrdersStore.map((o) => json.encode(o.toJson())).toList();
  await prefs.setStringList('user_orders_key', encoded);
}

Future<void> loadOrdersFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String>? encoded = prefs.getStringList('user_orders_key');
  if (encoded != null) {
    userOrdersStore = encoded.map((item) => OrderModel.fromJson(json.decode(item))).toList();
  }
}

// Custom Rotating Emoji Settings Button Component
class RotatingSettingsEmoji extends StatefulWidget {
  final VoidCallback onTap;
  const RotatingSettingsEmoji({super.key, required this.onTap});

  @override
  State<RotatingSettingsEmoji> createState() => _RotatingSettingsEmojiState();
}

class _RotatingSettingsEmojiState extends State<RotatingSettingsEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: RotationTransition(
        turns: _rotationController,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '⚙️',
            style: TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }
}

// RGB Animated Flow Header Container Title
class RgbAnimatedHeaderTitle extends StatefulWidget {
  const RgbAnimatedHeaderTitle({super.key});

  @override
  State<RgbAnimatedHeaderTitle> createState() => _RgbAnimatedHeaderTitleState();
}

class _RgbAnimatedHeaderTitleState extends State<RgbAnimatedHeaderTitle> with TickerProviderStateMixin {
  late AnimationController _colorController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _colorController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorController,
      builder: (context, child) {
        final value = _colorController.value;
        final c1 = HSLColor.fromAHSL(1.0, (value * 360) % 360, 0.9, 0.5).toColor();
        final c2 = HSLColor.fromAHSL(1.0, ((value + 0.33) * 360) % 360, 0.9, 0.5).toColor();
        final c3 = HSLColor.fromAHSL(1.0, ((value + 0.66) * 360) % 360, 0.9, 0.5).toColor();

        return ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [c1, c2, c3],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: c1.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ],
            ),
            child: const Text(
              'Follower X - فالوير اكـس',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Base Scaffold Wrapper with Custom AppBar
class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Function(bool) toggleTheme;
  final bool isDark;
  final bool showAnimatedTitle;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.toggleTheme,
    required this.isDark,
    this.showAnimatedTitle = false,
  });

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        bool currentMode = isDark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: minAxisSize,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'تفعيل الوضع الداكن',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Switch(
                        value: currentMode,
                        activeColor: const Color(0xFF00A2FF),
                        onChanged: (val) {
                          setModalState(() {
                            currentMode = val;
                          });
                          toggleTheme(val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: true,
          title: showAnimatedTitle
              ? const RgbAnimatedHeaderTitle()
              : Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 22),
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            RotatingSettingsEmoji(
              onTap: () => _showSettingsSheet(context),
            ),
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, size: 28),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: Theme.of(context).cardColor,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF00A2FF)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Follower X',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home, color: Color(0xFF00A2FF)),
                title: const Text('الرئيسية'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Text('⚙️', style: TextStyle(fontSize: 20)),
                title: const Text('الإعدادات'),
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsSheet(context);
                },
              ),
            ],
          ),
        ),
        body: body,
      ),
    );
  }

  static get minAxisSize => MainAxisSize.min;
}

// Multi-color Rotating Loading Spinner
class RainbowSpinner extends StatefulWidget {
  const RainbowSpinner({super.key});

  @override
  State<RainbowSpinner> createState() => _RainbowSpinnerState();
}

class _RainbowSpinnerState extends State<RainbowSpinner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(tween: ColorTween(begin: Colors.blue, end: Colors.purple), weight: 1),
      TweenSequenceItem(tween: ColorTween(begin: Colors.purple, end: Colors.red), weight: 1),
      TweenSequenceItem(tween: ColorTween(begin: Colors.red, end: Colors.orange), weight: 1),
      TweenSequenceItem(tween: ColorTween(begin: Colors.orange, end: Colors.green), weight: 1),
      TweenSequenceItem(tween: ColorTween(begin: Colors.green, end: Colors.blue), weight: 1),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CircularProgressIndicator(
          valueColor: _colorAnimation,
          strokeWidth: 3.5,
        );
      },
    );
  }
}

// Global RGB Top Success Notification Popup Overlay
void showRgbNotificationOverlay(BuildContext context, String message) {
  final overlayState = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) {
      return _RgbNotificationWidget(
        message: message,
        onDismiss: () {
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        },
      );
    },
  );

  overlayState.insert(overlayEntry);
}

class _RgbNotificationWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _RgbNotificationWidget({required this.message, required this.onDismiss});

  @override
  State<_RgbNotificationWidget> createState() => _RgbNotificationWidgetState();
}

class _RgbNotificationWidgetState extends State<_RgbNotificationWidget> with TickerProviderStateMixin {
  late AnimationController _rgbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _rgbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack));

    _fadeController.forward();

    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _fadeController.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _rgbController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: AnimatedBuilder(
                animation: _rgbController,
                builder: (context, child) {
                  final val = _rgbController.value;
                  final color1 = HSLColor.fromAHSL(1.0, (val * 360) % 360, 0.85, 0.5).toColor();
                  final color2 = HSLColor.fromAHSL(1.0, ((val + 0.5) * 360) % 360, 0.85, 0.5).toColor();

                  return Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [color1, color2],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color1.withOpacity(0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.green, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 1. Splash Screen
class SplashScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const SplashScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final List<IconData> _socialIcons = [
    Icons.camera_alt,
    Icons.video_library,
    Icons.facebook,
    Icons.flutter_dash,
    Icons.music_note,
    Icons.send,
  ];

  int _currentIconIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loadOrdersFromStorage();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _currentIconIndex = (_currentIconIndex + 1) % _socialIcons.length;
      });
    });

    Future.delayed(const Duration(seconds: 3), () {
      _timer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _socialIcons[_currentIconIndex],
                key: ValueKey<int>(_currentIconIndex),
                size: 85,
                color: const Color(0xFF00A2FF),
              ),
            ),
            const SizedBox(height: 35),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'جاري التحميل...',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 15),
                RainbowSpinner(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 2. Login Screen
class LoginScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const LoginScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  void _handleLogin() async {
    if (_usernameController.text == 'admin' && _passwordController.text == 'admin') {
      await loadOrdersFromStorage();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
        ),
      );
    } else {
      setState(() {
        _errorMessage = 'اسم المستخدم أو كلمة المرور غير صحيحة';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00A2FF).withOpacity(0.15),
                  ),
                  child: const Icon(Icons.lock_outline, size: 60, color: Color(0xFF00A2FF)),
                ),
                const SizedBox(height: 25),
                const Text(
                  'تسجيل الدخول',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'اسم المستخدم',
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF00A2FF)),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFF00A2FF)),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                ],
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A2FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('دخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 3. Home Screen
class HomeScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const HomeScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String balance = '0.00';
  String spending = '0';
  bool isLoadingStats = true;

  List<ServiceModel> allServices = [];
  List<ServiceModel> searchResults = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAccountStats();
    _fetchAllServices();
  }

  Future<void> _fetchAccountStats() async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {'key': apiKey, 'action': 'balance'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          balance = data['balance']?.toString() ?? '0.00';
          spending = '0';
          isLoadingStats = false;
        });
      }
    } catch (_) {
      setState(() => isLoadingStats = false);
    }
  }

  Future<void> _fetchAllServices() async {
    try {
      final list = await fetchServicesFromApi();
      setState(() {
        allServices = list;
      });
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => searchResults = []);
      return;
    }
    setState(() {
      searchResults = allServices
          .where((s) => s.name.toLowerCase().contains(query.toLowerCase()) || s.category.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Follower X',
      showAnimatedTitle: true,
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _buildStatCard('رصيدك', '\$$balance', Icons.account_balance_wallet, Colors.blueAccent),
                _buildStatCard('إنفاقك', '\$$spending', Icons.receipt_long, Colors.orangeAccent),
                _buildStatCard('طلباتك', '${userOrdersStore.length}', Icons.emoji_events, Colors.redAccent),
                _buildStatCard('إجمالي الطلبات', '1885', Icons.show_chart, Colors.greenAccent),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.card_giftcard,
                    title: 'خدمات مجانية',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FreeServicesScreen(
                            toggleTheme: widget.toggleTheme,
                            isDark: widget.isDark,
                          ),
                        ),
                      ).then((_) => setState(() {}));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.history,
                    title: 'سجل الطلبات',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderHistoryScreen(
                            toggleTheme: widget.toggleTheme,
                            isDark: widget.isDark,
                          ),
                        ),
                      ).then((_) => setState(() {}));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00A2FF), Color(0xFF0066FF)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00A2FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'بحث في خدمات التطبيق...',
                    prefixIcon: Icon(Icons.search, color: Color(0xFF00A2FF)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            if (searchResults.isNotEmpty) ...[
              const SizedBox(height: 15),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: searchResults.length,
                itemBuilder: (ctx, idx) {
                  final s = searchResults[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text('الفئة: ${s.category}'),
                      trailing: Text('\$${s.rate}', style: const TextStyle(color: Color(0xFF00A2FF), fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderFormScreen(
                              toggleTheme: widget.toggleTheme,
                              isDark: widget.isDark,
                              service: s,
                            ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 25),

            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'اختر المنصة أولاً',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00A2FF)),
              ),
            ),
            const SizedBox(height: 15),

            _buildPlatformGrid(),

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF00A2FF).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF00A2FF), size: 22),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformGrid() {
    final platforms = [
      {'name': 'انستكرام', 'icon': Icons.camera_alt, 'color': const Color(0xFFE1306C), 'key': 'instagram'},
      {'name': 'تيك توك', 'icon': Icons.video_library, 'color': const Color(0xFF000000), 'key': 'tiktok'},
      {'name': 'فيسبوك', 'icon': Icons.facebook, 'color': const Color(0xFF1877F2), 'key': 'facebook'},
      {'name': 'تويتر', 'icon': Icons.flutter_dash, 'color': const Color(0xFF1DA1F2), 'key': 'twitter'},
      {'name': 'سبوتفاي', 'icon': Icons.music_note, 'color': const Color(0xFF1DB954), 'key': 'spotify'},
      {'name': 'تليكرام', 'icon': Icons.send, 'color': const Color(0xFF0088CC), 'key': 'telegram'},
      {'name': 'واتساب', 'icon': Icons.chat, 'color': const Color(0xFF25D366), 'key': 'whatsapp'},
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildPlatformTile(platforms[0])),
            const SizedBox(width: 12),
            Expanded(child: _buildPlatformTile(platforms[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildPlatformTile(platforms[2])),
            const SizedBox(width: 12),
            Expanded(child: _buildPlatformTile(platforms[3])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildPlatformTile(platforms[4])),
            const SizedBox(width: 12),
            Expanded(child: _buildPlatformTile(platforms[5])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildPlatformTile(platforms[6])),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPlatformTile({
                'name': 'ثريدز',
                'icon': Icons.alternate_email,
                'color': const Color(0xFF000000),
                'key': 'threads',
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlatformTile(Map<String, dynamic> platform) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlatformServicesScreen(
              toggleTheme: widget.toggleTheme,
              isDark: widget.isDark,
              platformName: platform['name'] as String,
              platformKey: platform['key'] as String,
            ),
          ),
        ).then((_) => setState(() {}));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (platform['color'] as Color).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(platform['icon'] as IconData, color: platform['color'] as Color, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              platform['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. Platform Services Screen
class PlatformServicesScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;
  final String platformName;
  final String platformKey;

  const PlatformServicesScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
    required this.platformName,
    required this.platformKey,
  });

  @override
  State<PlatformServicesScreen> createState() => _PlatformServicesScreenState();
}

class _PlatformServicesScreenState extends State<PlatformServicesScreen> {
  List<ServiceModel> services = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  bool _isServiceForPlatform(ServiceModel s, String pKey) {
    final cat = s.category.toLowerCase();
    final name = s.name.toLowerCase();

    switch (pKey) {
      case 'instagram':
        if (cat.contains('facebook') || cat.contains('tiktok') || cat.contains('telegram') || cat.contains('twitter') || cat.contains('youtube') || cat.contains('فيسبوك')) return false;
        return cat.contains('instagram') || name.contains('instagram') || cat.contains('انستجرام') || name.contains('انستغرام') || cat.contains('انستغرام');
      case 'facebook':
        if (cat.contains('instagram') || cat.contains('tiktok') || cat.contains('telegram') || cat.contains('twitter')) return false;
        return cat.contains('facebook') || name.contains('facebook') || cat.contains('فيسبوك') || name.contains('فيس بوك');
      case 'tiktok':
        if (cat.contains('instagram') || cat.contains('facebook') || cat.contains('telegram')) return false;
        return cat.contains('tiktok') || name.contains('tiktok') || cat.contains('تيكتوك') || name.contains('تيك توك');
      case 'telegram':
        if (cat.contains('instagram') || cat.contains('facebook') || cat.contains('tiktok')) return false;
        return cat.contains('telegram') || name.contains('telegram') || cat.contains('تليكرام') || name.contains('تليجرام') || cat.contains('تلغ');
      case 'twitter':
        if (cat.contains('instagram') || cat.contains('facebook')) return false;
        return cat.contains('twitter') || name.contains('twitter') || cat.contains('تويتر') || name.contains('تويتر');
      case 'whatsapp':
        return cat.contains('whatsapp') || name.contains('whatsapp') || cat.contains('واتساب') || name.contains('وتساب');
      case 'spotify':
        return cat.contains('spotify') || name.contains('spotify') || cat.contains('سبوت') || name.contains('سبوت');
      case 'threads':
        return cat.contains('threads') || name.contains('threads') || cat.contains('ثريدز') || name.contains('ثريد');
      default:
        return cat.contains(pKey) || name.contains(pKey);
    }
  }

  Future<void> _fetchServices() async {
    try {
      final all = await fetchServicesFromApi();
      setState(() {
        services = all.where((s) => _isServiceForPlatform(s, widget.platformKey.toLowerCase())).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'خدمات ${widget.platformName}',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: isLoading
          ? const Center(child: RainbowSpinner())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'حدث خطأ في جلب البيانات:\n$errorMessage',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                    ),
                  ),
                )
              : services.isEmpty
                  ? const Center(child: Text('لا توجد خدمات متاحة حالياً لهذه المنصة'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        final item = services[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'ID: ${item.service} | أدنى: ${item.min} - أقصى: ${item.max}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${item.rate}',
                                  style: const TextStyle(color: Color(0xFF00A2FF), fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const Text('لكل 1000', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderFormScreen(
                                    toggleTheme: widget.toggleTheme,
                                    isDark: widget.isDark,
                                    service: item,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}

// 5. Free Services Screen
class FreeServicesScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const FreeServicesScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
  });

  @override
  State<FreeServicesScreen> createState() => _FreeServicesScreenState();
}

class _FreeServicesScreenState extends State<FreeServicesScreen> {
  List<ServiceModel> freeServicesList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFreeServices();
  }

  Future<void> _fetchFreeServices() async {
    try {
      final all = await fetchServicesFromApi();
      setState(() {
        freeServicesList = all.where((s) {
          final rateNum = double.tryParse(s.rate) ?? 0.0;
          final name = s.name.toLowerCase();
          final cat = s.category.toLowerCase();

          return rateNum == 0.0 ||
              s.rate == '0' ||
              s.rate == '0.00' ||
              name.contains('مجاني') ||
              name.contains('free') ||
              cat.contains('مجانيه') ||
              cat.contains('مجانية');
        }).toList();

        if (freeServicesList.isEmpty) {
          freeServicesList = all..sort((a, b) => (double.tryParse(a.rate) ?? 0).compareTo(double.tryParse(b.rate) ?? 0));
        }

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'الخدمات المجانية',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: isLoading
          ? const Center(child: RainbowSpinner())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'حدث خطأ في الاتصال:\n$errorMessage',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                    ),
                  ),
                )
              : freeServicesList.isEmpty
                  ? const Center(child: Text('لا توجد خدمات مجانية متاحة حالياً'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: freeServicesList.length,
                      itemBuilder: (context, index) {
                        final item = freeServicesList[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('ID: ${item.service} | السعر: \$${item.rate}'),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderFormScreen(
                                      toggleTheme: widget.toggleTheme,
                                      isDark: widget.isDark,
                                      service: item,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A2FF)),
                              child: const Text('طلب', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

// 6. Order Form Screen
class OrderFormScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;
  final ServiceModel service;

  const OrderFormScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
    required this.service,
  });

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _linkController = TextEditingController();
  final _quantityController = TextEditingController();
  bool isSubmitting = false;

  bool isLinkInvalid = false;
  bool isQuantityInvalid = false;
  String? validationErrorMsg;

  Future<void> _submitOrder() async {
    setState(() {
      isLinkInvalid = false;
      isQuantityInvalid = false;
      validationErrorMsg = null;
    });

    final link = _linkController.text.trim();
    final quantityStr = _quantityController.text.trim();
    final minVal = int.tryParse(widget.service.min) ?? 0;
    final maxVal = int.tryParse(widget.service.max) ?? 9999999;
    final parsedQty = int.tryParse(quantityStr);

    bool hasError = false;

    if (link.isEmpty) {
      isLinkInvalid = true;
      hasError = true;
    }

    if (quantityStr.isEmpty) {
      isQuantityInvalid = true;
      hasError = true;
    }

    if (hasError) {
      setState(() {
        validationErrorMsg = 'مطلوب ملء الحقول المطلوبة';
      });
      return;
    }

    if (parsedQty == null || parsedQty < minVal || parsedQty > maxVal) {
      setState(() {
        isQuantityInvalid = true;
        validationErrorMsg = 'طلبك اقل أو اعلى من الكمية المحددة';
      });
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'key': apiKey,
          'action': 'add',
          'service': widget.service.service,
          'link': link,
          'quantity': quantityStr,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['order'] != null) {
          final newOrder = OrderModel(
            order: data['order'].toString(),
            status: 'قيد الانتظار',
            charge: '0.00',
            startCount: '0',
            remains: quantityStr,
            link: link,
            serviceName: widget.service.name,
            date: DateTime.now().toString().split('.')[0],
          );

          userOrdersStore.insert(0, newOrder);
          await saveOrdersToStorage();

          if (!mounted) return;
          showRgbNotificationOverlay(context, 'تم ارسال طلبك الان بنجاح .');
          Navigator.pop(context);
        } else {
          final err = data['error'] ?? 'حدث خطأ أثناء تنفيذ الطلب';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل الاتصال بالسيرفر')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'إنشاء طلب جديد',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.service.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('السعر لكل 1000: \$${widget.service.rate}', style: const TextStyle(color: Color(0xFF00A2FF))),
                    Text('الحد الأدنى: ${widget.service.min} | الحد الأقصى: ${widget.service.max}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                labelText: 'رابط الحساب / المنشور',
                prefixIcon: const Icon(Icons.link, color: Color(0xFF00A2FF)),
                filled: true,
                fillColor: isLinkInvalid ? Colors.red.withOpacity(0.15) : Theme.of(context).cardColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: isLinkInvalid ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: isLinkInvalid ? const BorderSide(color: Colors.red, width: 2) : const BorderSide(color: Color(0xFF00A2FF), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'الكمية',
                prefixIcon: const Icon(Icons.numbers, color: Color(0xFF00A2FF)),
                filled: true,
                fillColor: isQuantityInvalid ? Colors.red.withOpacity(0.15) : Theme.of(context).cardColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: isQuantityInvalid ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: isQuantityInvalid ? const BorderSide(color: Colors.red, width: 2) : const BorderSide(color: Color(0xFF00A2FF), width: 2),
                ),
              ),
            ),
            if (validationErrorMsg != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  validationErrorMsg!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: isSubmitting
                    ? const RainbowSpinner()
                    : const Text('تأكيد الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 7. Order History Screen
class OrderHistoryScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const OrderHistoryScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  bool isRefreshing = false;

  String _translateStatus(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('pending')) return 'قيد الانتظار';
    if (lower.contains('processing') || lower.contains('in progress')) return 'قيد التنفيذ';
    if (lower.contains('completed')) return 'مكتمل';
    if (lower.contains('partial')) return 'مكتمل جزئياً';
    if (lower.contains('canceled') || lower.contains('cancelled')) return 'ملغى';
    return status;
  }

  Color _getStatusColor(String status) {
    final translated = _translateStatus(status);
    if (translated == 'قيد الانتظار') return Colors.orange;
    if (translated == 'قيد التنفيذ') return Colors.blue;
    if (translated == 'مكتمل') return Colors.green;
    if (translated == 'ملغى') return Colors.red;
    return Colors.purple;
  }

  Future<void> _refreshOrders() async {
    setState(() => isRefreshing = true);

    try {
      for (var order in userOrdersStore) {
        final res = await http.post(
          Uri.parse(apiUrl),
          body: {
            'key': apiKey,
            'action': 'status',
            'order': order.order,
          },
        );

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] != null) {
            order.status = data['status'].toString();
          }
        }
      }
      await saveOrdersToStorage();
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'سجل الطلبات',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        color: const Color(0xFF00A2FF),
        child: userOrdersStore.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('لا توجد طلبات سابقة')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: userOrdersStore.length,
                itemBuilder: (context, index) {
                  final order = userOrdersStore[index];
                  final statusTxt = _translateStatus(order.status);
                  final statusCol = _getStatusColor(order.status);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      title: Text(order.serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('رقم الطلب: ${order.order}'),
                          Text('الرابط: ${order.link}'),
                          Text('التاريخ: ${order.date}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusCol.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusCol.withOpacity(0.4)),
                        ),
                        child: Text(
                          statusTxt,
                          style: TextStyle(color: statusCol, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
