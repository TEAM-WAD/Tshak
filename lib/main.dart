import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadDiscountFromStorage();
  await loadUpdateInfoFromStorage();
  await loadNotificationsFromStorage();
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
      title: '𝖿᥆𝗅𝗅ᥕ𝖾𝗋 ꪎ 𝗉𝗋᥆',
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

// Global State Variables & Helpers
double globalDiscount = 0.0;
bool hasNewUpdateBadge = false;
String globalUpdateMsg = '';
String globalUpdateUrl = '';

class AppNotification {
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
        isRead: json['isRead'] ?? false,
      );
}

List<AppNotification> appNotificationsList = [];

Future<void> saveDiscountToStorage(double val) async {
  globalDiscount = val;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('global_discount_val', val);
}

Future<void> loadDiscountFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  globalDiscount = prefs.getDouble('global_discount_val') ?? 0.0;
}

Future<void> saveUpdateInfoToStorage(String msg, String url, bool badge) async {
  globalUpdateMsg = msg;
  globalUpdateUrl = url;
  hasNewUpdateBadge = badge;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('update_msg', msg);
  await prefs.setString('update_url', url);
  await prefs.setBool('has_new_update', badge);
}

Future<void> loadUpdateInfoFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  globalUpdateMsg = prefs.getString('update_msg') ?? '';
  globalUpdateUrl = prefs.getString('update_url') ?? '';
  hasNewUpdateBadge = prefs.getBool('has_new_update') ?? false;
}

Future<void> saveNotificationsToStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String> encoded = appNotificationsList.map((n) => json.encode(n.toJson())).toList();
  await prefs.setStringList('app_notifications_key', encoded);
}

Future<void> loadNotificationsFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String>? encoded = prefs.getStringList('app_notifications_key');
  if (encoded != null) {
    appNotificationsList = encoded.map((item) => AppNotification.fromJson(json.decode(item))).toList();
  }
}

void addAppNotification(String title, String body, BuildContext? context) {
  final newNotif = AppNotification(
    title: title,
    body: body,
    timestamp: DateTime.now(),
  );
  appNotificationsList.insert(0, newNotif);
  saveNotificationsToStorage();
  if (context != null) {
    showRgbNotificationOverlay(context, '$title\n$body');
  }
}

// User Account Model & Per-User Persistence
class UserAccountModel {
  final String username;
  final String email;
  final String password;

  UserAccountModel({required this.username, required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'password': password,
      };

  factory UserAccountModel.fromJson(Map<String, dynamic> json) => UserAccountModel(
        username: json['username'] ?? '',
        email: json['email'] ?? '',
        password: json['password'] ?? '',
      );
}

Future<List<UserAccountModel>> getUsersFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String>? encoded = prefs.getStringList('app_users_list');
  if (encoded != null) {
    return encoded.map((item) => UserAccountModel.fromJson(json.decode(item))).toList();
  }
  return [];
}

Future<void> saveUserAccount(UserAccountModel user) async {
  final prefs = await SharedPreferences.getInstance();
  List<UserAccountModel> users = await getUsersFromStorage();
  users.add(user);
  final List<String> encoded = users.map((u) => json.encode(u.toJson())).toList();
  await prefs.setStringList('app_users_list', encoded);
  await prefs.setString('active_logged_username', user.username);
  await setUserBalance(user.username, 0.0);
  await setUserSpending(user.username, 0.0);
}

Future<String?> getActiveLoggedUser() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('active_logged_username');
}

Future<void> logoutActiveUser() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('active_logged_username');
}

// Per-User Storage Helpers
Future<double> getUserBalance(String username) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getDouble('user_balance_$username') ?? 0.0;
}

Future<void> setUserBalance(String username, double val) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('user_balance_$username', val);
}

Future<double> getUserSpending(String username) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getDouble('user_spending_$username') ?? 0.0;
}

Future<void> setUserSpending(String username, double val) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('user_spending_$username', val);
}

Future<List<OrderModel>> getUserOrders(String username) async {
  final prefs = await SharedPreferences.getInstance();
  final List<String>? encoded = prefs.getStringList('user_orders_$username');
  if (encoded != null) {
    return encoded.map((item) => OrderModel.fromJson(json.decode(item))).toList();
  }
  return [];
}

Future<void> saveUserOrders(String username, List<OrderModel> orders) async {
  final prefs = await SharedPreferences.getInstance();
  final List<String> encoded = orders.map((o) => json.encode(o.toJson())).toList();
  await prefs.setStringList('user_orders_$username', encoded);
}

// Service & Order Models
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
  final DateTime createdAt;

  OrderModel({
    required this.order,
    required this.status,
    required this.charge,
    required this.startCount,
    required this.remains,
    required this.link,
    required this.serviceName,
    required this.date,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'order': order,
        'status': status,
        'charge': charge,
        'startCount': startCount,
        'remains': remains,
        'link': link,
        'serviceName': serviceName,
        'date': date,
        'createdAt': createdAt.toIso8601String(),
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
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : DateTime.now(),
      );
}

// API Network Fetch Function
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

// App Logo Widget
class AppLogoWidget extends StatelessWidget {
  final double size;
  const AppLogoWidget({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF00A2FF), Color(0xFF0055FF)],
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Image.network(
        'https://img.icons8.com/color/144/instagram-new.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.bolt, size: size * 0.6, color: Colors.white),
      ),
    );
  }
}

// Price Display Widget
Widget buildPriceDisplay(String originalRateStr) {
  final double originalRate = double.tryParse(originalRateStr) ?? 0.0;
  if (globalDiscount > 0) {
    final double discountedRate = math.max(0.0, originalRate - globalDiscount);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '\$${originalRate.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.red,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '\$${discountedRate.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  } else {
    return Text(
      '\$${originalRate.toStringAsFixed(2)}',
      style: const TextStyle(
        color: Color(0xFF00A2FF),
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}

// Swinging Bell Icon Component
class SwingingBellIcon extends StatefulWidget {
  final VoidCallback onTap;
  final int badgeCount;

  const SwingingBellIcon({super.key, required this.onTap, required this.badgeCount});

  @override
  State<SwingingBellIcon> createState() => _SwingingBellIconState();
}

class _SwingingBellIconState extends State<SwingingBellIcon> with SingleTickerProviderStateMixin {
  late AnimationController _bellController;
  late Animation<double> _bellAnimation;

  @override
  void initState() {
    super.initState();
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bellAnimation = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(parent: _bellController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bellController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: _bellAnimation,
              child: const Icon(
                Icons.notifications_active,
                color: Colors.amber,
                size: 26,
              ),
            ),
            if (widget.badgeCount > 0)
              Positioned(
                top: 8,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${widget.badgeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Captcha Dialog Widget
class PuzzleCaptchaDialog extends StatefulWidget {
  final String imageUrl;
  final VoidCallback onSuccess;

  const PuzzleCaptchaDialog({
    super.key,
    this.imageUrl = 'https://picsum.photos/400/200',
    required this.onSuccess,
  });

  static void show(BuildContext context, {required VoidCallback onSuccess}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PuzzleCaptchaDialog(onSuccess: onSuccess),
    );
  }

  @override
  State<PuzzleCaptchaDialog> createState() => _PuzzleCaptchaDialogState();
}

class _PuzzleCaptchaDialogState extends State<PuzzleCaptchaDialog> {
  double _sliderValue = 0.0;
  late double _targetX;
  late double _targetY;
  final double _pieceSize = 50.0;
  bool _isError = false;
  bool _isSuccess = false;
  String _message = 'اسحب الشريط لوضع المثلث في المكان الصحيح';

  @override
  void initState() {
    super.initState();
    _generateRandomTarget();
  }

  void _generateRandomTarget() {
    final random = math.Random();
    _targetX = 0.45 + random.nextDouble() * 0.4;
    _targetY = 0.2 + random.nextDouble() * 0.5;
    _sliderValue = 0.0;
    _isError = false;
    _isSuccess = false;
  }

  void _checkVerification() {
    const double tolerance = 0.05;
    final double diff = (_sliderValue - _targetX).abs();

    if (diff <= tolerance) {
      setState(() {
        _isSuccess = true;
        _isError = false;
        _message = 'تم التحقق بنجاح! ✔️';
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        Navigator.pop(context);
        widget.onSuccess();
      });
    } else {
      setState(() {
        _isError = true;
        _message = 'خطأ! أعد المحاولة ❌';
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _sliderValue = 0.0;
            _isError = false;
            _message = 'اسحب الشريط لوضع المثلث في المكان الصحيح';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'أكمل اختبار الأمان',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = width * 0.5;

                final targetXPx = _targetX * (width - _pieceSize);
                final targetYPx = _targetY * (height - _pieceSize);
                final currentXPx = _sliderValue * (width - _pieceSize);

                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.imageUrl,
                        width: width,
                        height: height,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: width,
                          height: height,
                          color: Colors.blueGrey,
                          child: const Icon(Icons.image, size: 50, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      left: targetXPx,
                      top: targetYPx,
                      child: ClipPath(
                        clipper: TriangleClipper(),
                        child: Container(
                          width: _pieceSize,
                          height: _pieceSize,
                          color: Colors.black.withOpacity(0.65),
                        ),
                      ),
                    ),
                    Positioned(
                      left: currentXPx,
                      top: targetYPx,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: _isError ? Colors.red : (_isSuccess ? Colors.green : Colors.black45),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: ClipPath(
                          clipper: TriangleClipper(),
                          child: Container(
                            width: _pieceSize,
                            height: _pieceSize,
                            color: Colors.white,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: -targetXPx,
                                  top: -targetYPx,
                                  child: Image.network(
                                    widget.imageUrl,
                                    width: width,
                                    height: height,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: width,
                                      height: height,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 15),
            Text(
              _message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _isError ? Colors.red : (_isSuccess ? Colors.green : Colors.grey[700]),
              ),
            ),
            const SizedBox(height: 10),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _isError ? Colors.red : (_isSuccess ? Colors.green : const Color(0xFF00A2FF)),
                thumbColor: _isError ? Colors.red : (_isSuccess ? Colors.green : const Color(0xFF00A2FF)),
                overlayColor: const Color(0xFF00A2FF).withOpacity(0.2),
              ),
              child: Slider(
                value: _sliderValue,
                onChanged: (_isError || _isSuccess)
                    ? null
                    : (val) {
                        setState(() {
                          _sliderValue = val;
                        });
                      },
                onChangeEnd: (_) {
                  if (!_isSuccess && !_isError) {
                    _checkVerification();
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00A2FF)),
            onPressed: _generateRandomTarget,
          )
        ],
      ),
    );
  }
}

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Rotating Settings Button
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
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.settings, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

// Dynamic Title Box
class DynamicBorderTitleBox extends StatefulWidget {
  final String text;
  final bool isLarge;

  const DynamicBorderTitleBox({super.key, required this.text, this.isLarge = false});

  @override
  State<DynamicBorderTitleBox> createState() => _DynamicBorderTitleBoxState();
}

class _DynamicBorderTitleBoxState extends State<DynamicBorderTitleBox> with TickerProviderStateMixin {
  late AnimationController _colorController;
  late AnimationController _floatController;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: const Offset(0, 0.04),
    ).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _colorController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorController,
      builder: (context, child) {
        final val = _colorController.value;
        final borderColor = HSLColor.fromAHSL(1.0, (val * 360) % 360, 0.9, 0.6).toColor();

        return SlideTransition(
          position: _floatAnimation,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isLarge ? 20 : 14,
              vertical: widget.isLarge ? 10 : 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ],
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.isLarge ? 17 : 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Wave Loading Widget
class WaveLoadingWidget extends StatefulWidget {
  const WaveLoadingWidget({super.key});

  @override
  State<WaveLoadingWidget> createState() => _WaveLoadingWidgetState();
}

class _WaveLoadingWidgetState extends State<WaveLoadingWidget> with TickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Loding',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Row(
                  children: List.generate(3, (index) {
                    double delay = index * 0.2;
                    double value = math.sin((_waveController.value * 2 * math.pi) - delay);
                    return Transform.translate(
                      offset: Offset(0, value * 6),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00A2FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 25),
        const RainbowSpinner(),
      ],
    );
  }
}

// Rainbow Spinner Component
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

// Top Overlay RGB Notification
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
  late AnimationController _borderController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
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
    _borderController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: AnimatedBuilder(
                animation: _borderController,
                builder: (context, child) {
                  final val = _borderController.value;
                  final animatedColor = HSLColor.fromAHSL(1.0, (val * 360) % 360, 0.9, 0.6).toColor();

                  return Material(
                    color: Colors.transparent,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: animatedColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: animatedColor.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const AppLogoWidget(size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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

// Animated Yellow Warning Box Component
class AnimatedYellowWarningBox extends StatefulWidget {
  final String text;
  const AnimatedYellowWarningBox({super.key, required this.text});

  @override
  State<AnimatedYellowWarningBox> createState() => _AnimatedYellowWarningBoxState();
}

class _AnimatedYellowWarningBoxState extends State<AnimatedYellowWarningBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacityAnim = Tween<double>(begin: 0.65, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnim,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber, width: 1.8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'يرجى القراءة بتمهل ⚠️',
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.text,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.amberAccent, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog Helpers
void showCustomAlertDialog(BuildContext context, {required String title, required String message, IconData icon = Icons.info_outline, Color iconColor = Colors.orangeAccent}) {
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A2FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}

void showInsufficientFundsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('رصيدك غير كافي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'عذراً عزيزي المستخدم، لا تمتلك رصيد كافي في حسابك بالتطبيق لطلب هذه الخدمة.\n\nيرجى إعادة شحن حسابك عبر طرق الدفع المتاحة لكي تتمكن من الاستمرار في تنفيذ طلبك بنجاح.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A2FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddFundsScreen(
                    toggleTheme: (bool val) {},
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              );
            },
            child: const Text('شحن الحساب الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    ),
  );
}

void showAboutUsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            AppLogoWidget(size: 26),
            SizedBox(width: 10),
            Text('من نحن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أهلاً بك في تطبيق 𝖿᥆𝗅𝗅ᥕ𝖾𝗋 ꪎ 𝗉𝗋᥆!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00A2FF)),
              ),
              SizedBox(height: 10),
              Text(
                'نحن المنصة الأولى والأسرع في تقديم خدمات تسويق وتنمية حسابات مواقع التواصل الاجتماعي بأعلى جودة وأفضل الأسعار المنافسة.\n\nنهدف دائماً إلى توفير أفضل تجربة للمستخدم مع ضمان السرعة في التنفيذ والدعم الفني المستمر على مدار الساعة لخدمتكم بشكل ممتاز.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(color: Color(0xFF00A2FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}

// Base Scaffold Component
class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Function(bool) toggleTheme;
  final bool isDark;
  final bool showHeaderTitle;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.toggleTheme,
    required this.isDark,
    this.showHeaderTitle = false,
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
                mainAxisSize: MainAxisSize.min,
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
    int unreadCount = appNotificationsList.where((n) => !n.isRead).length;
    if (hasNewUpdateBadge) unreadCount += 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: true,
          title: showHeaderTitle
              ? const DynamicBorderTitleBox(text: '𝖿᥆𝗅𝗅ᥕ𝖾𝗋 ꪎ 𝗉𝗋᥆', isLarge: true)
              : DynamicBorderTitleBox(text: title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 22),
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            SwingingBellIcon(
              badgeCount: unreadCount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsListScreen(toggleTheme: toggleTheme, isDark: isDark),
                  ),
                );
              },
            ),
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
                      child: AppLogoWidget(size: 40),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '𝖿᥆𝗅𝗅ᥕ𝖾𝗋 ꪎ 𝗉𝗋᥆',
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
                leading: Stack(
                  children: [
                    const Icon(Icons.system_update, color: Color(0xFF00A2FF)),
                    if (hasNewUpdateBadge)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    const Text('التحديثات'),
                    if (hasNewUpdateBadge) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '1',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UpdatesScreen(toggleTheme: toggleTheme, isDark: isDark),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info, color: Color(0xFF00A2FF)),
                title: const Text('من نحن'),
                onTap: () {
                  Navigator.pop(context);
                  showAboutUsDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.headset_mic, color: Color(0xFF00A2FF)),
                title: const Text('الدعم الفني'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (c) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: AlertDialog(
                        title: const Text('الدعم الفني'),
                        content: const Text('للحصول على المساعدة تواصل معنا عبر واتساب أو تليجرام الدعم الفني المباشر.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c), child: const Text('تم')),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Color(0xFF00A2FF)),
                title: const Text('الإعدادات'),
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsSheet(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(context);
                  await logoutActiveUser();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(toggleTheme: toggleTheme, isDark: isDark),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        body: body,
      ),
    );
  }
}

// Notifications List Screen
class NotificationsListScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const NotificationsListScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<NotificationsListScreen> createState() => _NotificationsListScreenState();
}

class _NotificationsListScreenState extends State<NotificationsListScreen> {
  @override
  void initState() {
    super.initState();
    for (var n in appNotificationsList) {
      n.isRead = true;
    }
    saveNotificationsToStorage();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'الإشعارات',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: appNotificationsList.isEmpty
          ? const Center(child: Text('لا توجد إشعارات حالياً'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: appNotificationsList.length,
              itemBuilder: (context, index) {
                final item = appNotificationsList[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: const AppLogoWidget(size: 28),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(item.body, style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          item.timestamp.toString().split('.')[0],
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// Updates Screen
class UpdatesScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const UpdatesScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  @override
  void initState() {
    super.initState();
    saveUpdateInfoToStorage(globalUpdateMsg, globalUpdateUrl, false);
  }

  void _downloadUpdate() async {
    if (globalUpdateUrl.isNotEmpty) {
      final uri = Uri.parse(globalUpdateUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } else {
      showCustomAlertDialog(
        context,
        title: 'تنبيه',
        message: 'لا يوجد رابط تحديث مباشر متوفر حالياً.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'التحديثات',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update_rounded, size: 80, color: Color(0xFF00A2FF)),
              const SizedBox(height: 20),
              const Text(
                'هناك اصدار جديد متاح للتثبيت',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00A2FF)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  globalUpdateMsg.isNotEmpty ? globalUpdateMsg : 'يرجى تنزيل الإصدار الجديد للحصول على أحدث الميزات والخدمات المتاحة داخل التطبيق.',
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _downloadUpdate,
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text('تحميل التحديث', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ],
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
  final List<String> _socialAppLogos = [
    'https://img.icons8.com/color/144/instagram-new.png',
    'https://img.icons8.com/color/144/tiktok.png',
    'https://img.icons8.com/color/144/facebook-new.png',
    'https://img.icons8.com/color/144/twitterx.png',
    'https://img.icons8.com/color/144/telegram-app.png',
    'https://img.icons8.com/color/144/whatsapp.png',
    'https://img.icons8.com/color/144/spotify.png',
  ];

  int _currentIconIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  void _checkInitialState() async {
    _timer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (mounted) {
        setState(() {
          _currentIconIndex = (_currentIconIndex + 1) % _socialAppLogos.length;
        });
      }
    });

    final activeUser = await getActiveLoggedUser();

    Future.delayed(const Duration(seconds: 3), () {
      _timer?.cancel();
      if (!mounted) return;

      if (activeUser != null && activeUser.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
          ),
        );
      }
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
              duration: const Duration(milliseconds: 400),
              child: Image.network(
                _socialAppLogos[_currentIconIndex],
                key: ValueKey<int>(_currentIconIndex),
                width: 85,
                height: 85,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const AppLogoWidget(size: 85),
              ),
            ),
            const SizedBox(height: 35),
            const WaveLoadingWidget(),
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
  final _inputController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() async {
    final input = _inputController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      showCustomAlertDialog(
        context,
        title: 'تنبيه',
        message: 'يرجى إدخال اسم المستخدم أو البريد الإلكتروني وكلمة المرور.',
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.amber,
      );
      return;
    }

    if (input == 'admin' && password == 'admin') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
        ),
      );
      return;
    }

    final users = await getUsersFromStorage();

    UserAccountModel? matchedUser;
    for (var u in users) {
      if (u.username.toLowerCase() == input.toLowerCase() || u.email.toLowerCase() == input.toLowerCase()) {
        matchedUser = u;
        break;
      }
    }

    if (matchedUser == null) {
      if (!mounted) return;
      showCustomAlertDialog(
        context,
        title: 'الحساب غير موجود',
        message: 'عذراً عزيزي المستخدم، لا يوجد حساب مسجل بهذه البيانات (اسم المستخدم أو البريد الإلكتروني).\n\nيرجى التأكد من كتابة البيانات بشكل صحيح أو الضغط على "إنشاء حساب" للبدء.',
        icon: Icons.person_off_outlined,
        iconColor: Colors.redAccent,
      );
    } else if (matchedUser.password != password) {
      if (!mounted) return;
      showCustomAlertDialog(
        context,
        title: 'كلمة المرور خاطئة',
        message: 'كلمة المرور التي أدخلتها غير صحيحة للحساب ($input).\n\nيرجى إعادة المحاولة والتأكد من الأحرف والأرقام المدخلة.',
        icon: Icons.lock_reset,
        iconColor: Colors.orangeAccent,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_logged_username', matchedUser.username);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
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
                          child: const AppLogoWidget(size: 60),
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          'تسجيل الدخول',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 30),
                        TextField(
                          controller: _inputController,
                          decoration: InputDecoration(
                            labelText: 'اسم المستخدم أو البريد الإلكتروني',
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
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('ليس لديك حساب ؟ ', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RegisterScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
                                  ),
                                );
                              },
                              child: const Text(
                                'إنشاء حساب',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00A2FF),
                                ),
                              ),
                            ),
                          ],
                        ),
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
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'جميع الحقوق محفوظة لدى @Mohammed Al-Hussein',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 2.1 Register Screen
class RegisterScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const RegisterScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isUsernameArabic = false;
  bool _isEmailInvalid = false;

  bool get _isPasswordMatching {
    final p = _passwordController.text;
    final cp = _confirmPasswordController.text;
    return p.isNotEmpty && cp.isNotEmpty && p == cp;
  }

  bool get _hasLettersAndNumbers {
    final p = _passwordController.text;
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(p);
    final hasNumber = RegExp(r'[0-9]').hasMatch(p);
    return hasLetter && hasNumber;
  }

  bool get _isPasswordLengthValid {
    final p = _passwordController.text;
    return p.length >= 8 && _hasLettersAndNumbers;
  }

  void _checkUsername(String val) {
    final arabicReg = RegExp(r'[\u0600-\u06FF]');
    setState(() {
      _isUsernameArabic = arabicReg.hasMatch(val);
    });
  }

  void _checkEmail(String val) {
    final trimmed = val.trim().toLowerCase();
    setState(() {
      if (trimmed.isEmpty) {
        _isEmailInvalid = false;
      } else {
        _isEmailInvalid = !trimmed.endsWith('@gmail.com');
      }
    });
  }

  void _onRegisterPressed() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      showCustomAlertDialog(
        context,
        title: 'تنبيه',
        message: 'يرجى ملء جميع الحقول المطلوبة للتسجيل.',
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.amber,
      );
      return;
    }

    if (_isUsernameArabic || RegExp(r'[\u0600-\u06FF]').hasMatch(username)) {
      showCustomAlertDialog(
        context,
        title: 'خطأ في اسم المستخدم',
        message: 'اسم المستخدم يجب أن يتكون من أحرف إنجليزية فقط دون استخدام اللغة العربية.',
        icon: Icons.error_outline,
        iconColor: Colors.redAccent,
      );
      return;
    }

    if (!email.toLowerCase().endsWith('@gmail.com')) {
      showCustomAlertDialog(
        context,
        title: 'خطأ في البريد الإلكتروني',
        message: 'يرجى استخدام بريد إلكتروني صحيح وينتهي بالنطاق @gmail.com حصراً.',
        icon: Icons.mark_email_unread_outlined,
        iconColor: Colors.redAccent,
      );
      return;
    }

    List<String> failedRules = [];
    if (!_isPasswordMatching) {
      failedRules.add('• مربع "كلمة المرور متطابقة": كلمة المرور غير متطابقة مع حقل الإعادة.');
    }
    if (!_hasLettersAndNumbers) {
      failedRules.add('• مربع "استخدم حروف وارقام": يجب تضمين أرقام وأحرف إنجليزية معاً.');
    }
    if (!_isPasswordLengthValid) {
      failedRules.add('• مربع "تستوفي الشروط": يجب أن تكون كلمة المرور 8 خانات أو أكثر وتتضمن حروف وأرقام.');
    }

    if (failedRules.isNotEmpty) {
      showCustomAlertDialog(
        context,
        title: 'تنبيه شروط الحساب',
        message: 'تعذر التسجيل للأسباب التالية:\n\n${failedRules.join("\n\n")}\n\nيرجى تصحيح الأخطاء لكي تصبح العلامات صح للبدء.',
        icon: Icons.rule,
        iconColor: Colors.redAccent,
      );
      return;
    }

    PuzzleCaptchaDialog.show(
      context,
      onSuccess: () async {
        final newUser = UserAccountModel(
          username: username,
          email: email,
          password: password,
        );
        await saveUserAccount(newUser);

        if (!mounted) return;
        addAppNotification('𝖿᥆𝗅𝗅ᥕ𝖾𝗋 ꪎ 𝗉𝗋᥆', 'تم إنشاء حسابك بنجاح! أهلاً بك 🎉', context);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
          ),
          (route) => false,
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
          title: const Text('إنشاء حساب جديد'),
          centerTitle: true,
          elevation: 0,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اسم المستخدم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                TextField(
                  controller: _usernameController,
                  onChanged: _checkUsername,
                  decoration: InputDecoration(
                    hintText: 'اكتب اسم المستخدم بالإنجليزي',
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF00A2FF)),
                    filled: true,
                    fillColor: _isUsernameArabic ? Colors.red.withOpacity(0.12) : Theme.of(context).cardColor,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: _isUsernameArabic ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: _isUsernameArabic ? const BorderSide(color: Colors.red, width: 2) : const BorderSide(color: Color(0xFF00A2FF), width: 2),
                    ),
                  ),
                ),
                if (_isUsernameArabic) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'استخدم اللغة انكليزي فقط',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('البريد الإلكتروني', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  onChanged: _checkEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'example@gmail.com',
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00A2FF)),
                    filled: true,
                    fillColor: _isEmailInvalid ? Colors.red.withOpacity(0.12) : Theme.of(context).cardColor,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: _isEmailInvalid ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: _isEmailInvalid ? const BorderSide(color: Colors.red, width: 2) : const BorderSide(color: Color(0xFF00A2FF), width: 2),
                    ),
                  ),
                ),
                if (_isEmailInvalid) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'استخدم فقط ايميل حقيقي من نطاق gmail.com',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'أدخل كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00A2FF)),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('إعادة كتابة كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'أعد كتابة كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_reset, color: Color(0xFF00A2FF)),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      _buildConditionRow('كلمة المرور متطابقة', _isPasswordMatching),
                      const Divider(height: 16),
                      _buildConditionRow('تستوفي الشروط (8 خانات فأكثر)', _isPasswordLengthValid),
                      const Divider(height: 16),
                      _buildConditionRow('استخدم حروف وارقام', _hasLettersAndNumbers),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _onRegisterPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A2FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('تسجيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionRow(String title, bool isPassed) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isPassed ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isPassed ? Colors.green : Colors.red, width: 1.5),
          ),
          child: Icon(
            isPassed ? Icons.check : Icons.close,
            size: 16,
            color: isPassed ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isPassed ? Colors.green : Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }
}

// 3. Admin Dashboard Screen
class AdminDashboardScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const AdminDashboardScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int registeredUsersCount = 0;
  String apiBalance = '0.00';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final users = await getUsersFromStorage();
    String fetchedBal = '0.00';
    try {
      final res = await http.post(
        Uri.parse(apiUrl),
        body: {'key': apiKey, 'action': 'balance'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        fetchedBal = data['balance']?.toString() ?? '0.00';
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        registeredUsersCount = users.length;
        apiBalance = fetchedBal;
        isLoading = false;
      });
    }
  }

  void _showNewUpdateDialog() {
    final msgController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('رفع تحديث جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: msgController,
                decoration: InputDecoration(
                  labelText: 'كليشة الإرسال / تفاصيل التحديث',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: 'رابط التحديث الجديد',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A2FF)),
              onPressed: () {
                final msg = msgController.text.trim();
                final url = urlController.text.trim();
                if (msg.isEmpty || url.isEmpty) return;

                Navigator.pop(ctx);
                addAppNotification('𝖿᥆𝗅𝗅ᥕ𝖾𝗋 ꪎ 𝗉𝗋᥆', 'هناك اصدار جديد من التطبيق الان متوفر', context);

                saveUpdateInfoToStorage(msg, url, true);
              },
              child: const Text('إرسال', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscountsDialog() {
    final discountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إضافة خصومات جديدة'),
          content: TextField(
            controller: discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'قيمة الخصم (مثلاً 0.01)',
              hintText: '0.01',
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A2FF)),
              onPressed: () async {
                final val = double.tryParse(discountController.text.trim()) ?? 0.0;
                await saveDiscountToStorage(val);
                if (!mounted) return;
                Navigator.pop(ctx);
                addAppNotification('𝖿᥆𝗅𝗅ᥕ𝖾𝗋 ꪎ 𝗉𝗋᥆', 'هناك خصومات جديدة بالتطبيق سارع بالشراء', context);
              },
              child: const Text('تطبيق الخصم', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _resetPrices() async {
    await saveDiscountToStorage(0.0);
    if (!mounted) return;
    showRgbNotificationOverlay(context, 'تم إلغاء جميع الخصومات وإرجاع الأسعار الأساسية.');
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'لوحة التحكم Admin',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: isLoading
          ? const Center(child: RainbowSpinner())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      _buildAdminCard('مثبتين التطبيق', '1,280', Icons.download_done, Colors.blue),
                      _buildAdminCard('النشطين الآن', '42', Icons.wifi_tethering, Colors.green),
                      _buildAdminCard('الحسابات المسجلة', '$registeredUsersCount', Icons.email, Colors.orange),
                      _buildAdminCard('رصيدك بالموقع الرئيسي', '\$$apiBalance', Icons.account_balance_wallet, Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _showNewUpdateDialog,
                      icon: const Icon(Icons.system_update_alt, color: Colors.white),
                      label: const Text('رفع تحديث جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A2FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _showDiscountsDialog,
                      icon: const Icon(Icons.local_offer, color: Colors.white),
                      label: const Text('خصومات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _resetPrices,
                      icon: const Icon(Icons.restore, color: Colors.white),
                      label: const Text('إرجاع الأسعار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => HomeScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
                        ),
                      );
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('الانتقال للواجهة الرئيسية'),
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildAdminCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// 4. Home Screen
class HomeScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const HomeScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String currentUser = '';
  double userBalance = 0.0;
  double userSpending = 0.0;
  List<OrderModel> userOrders = [];
  int totalOrdersCount = 1885;

  List<ServiceModel> allServices = [];
  List<ServiceModel> searchResults = [];
  ServiceModel? mostRequestedService;
  
  Timer? _totalOrdersTimer;
  Timer? _mostRequestedTimer;

  late AnimationController _borderAnimController;

  @override
  void initState() {
    super.initState();
    _borderAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _loadUserData();
    _fetchAllServices();

    // Increment total orders count dynamically online
    _totalOrdersTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          totalOrdersCount += math.Random().nextInt(2) + 1;
        });
      }
    });

    // Rotate most requested service every 3 minutes
    _mostRequestedTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _pickRandomMostRequestedService();
    });
  }

  @override
  void dispose() {
    _borderAnimController.dispose();
    _totalOrdersTimer?.cancel();
    _mostRequestedTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final active = await getActiveLoggedUser() ?? 'guest';
    final bal = await getUserBalance(active);
    final sp = await getUserSpending(active);
    final ords = await getUserOrders(active);

    if (mounted) {
      setState(() {
        currentUser = active;
        userBalance = bal;
        userSpending = sp;
        userOrders = ords;
      });
    }
  }

  Future<void> _fetchAllServices() async {
    try {
      final list = await fetchServicesFromApi();
      if (mounted) {
        setState(() {
          allServices = list;
        });
        _pickRandomMostRequestedService();
      }
    } catch (_) {}
  }

  void _pickRandomMostRequestedService() {
    if (allServices.isNotEmpty && mounted) {
      final random = math.Random();
      setState(() {
        mostRequestedService = allServices[random.nextInt(allServices.length)];
      });
    }
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
      title: '𝖿᥆𝗅𝗅ᥕ𝖾𝗋 ꪎ 𝗉𝗋᥆',
      showHeaderTitle: true,
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                  _buildStatCard('رصيدك', '\$${userBalance.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.blueAccent),
                  _buildStatCard('إنفاقك', '\$${userSpending.toStringAsFixed(2)}', Icons.receipt_long, Colors.orangeAccent),
                  _buildStatCard('طلباتك', '${userOrders.length}', Icons.emoji_events, Colors.redAccent),
                  _buildStatCard('إجمالي الطلبات', '$totalOrdersCount', Icons.show_chart, Colors.greenAccent),
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
                              currentUser: currentUser,
                              userBalance: userBalance,
                            ),
                          ),
                        ).then((_) => _loadUserData());
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
                              currentUser: currentUser,
                            ),
                          ),
                        ).then((_) => _loadUserData());
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                icon: Icons.add_card,
                title: 'شحن الحساب (إضافة أموال)',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddFundsScreen(
                        toggleTheme: widget.toggleTheme,
                        isDark: widget.isDark,
                      ),
                    ),
                  );
                },
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
                    controller: TextEditingController(text: searchResults.isNotEmpty ? null : null),
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
                        leading: const AppLogoWidget(size: 24),
                        title: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('الفئة: ${s.category}'),
                        trailing: buildPriceDisplay(s.rate),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderFormScreen(
                                toggleTheme: widget.toggleTheme,
                                isDark: widget.isDark,
                                service: s,
                                currentUser: currentUser,
                                userBalance: userBalance,
                              ),
                            ),
                          ).then((_) => _loadUserData());
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
              const SizedBox(height: 20),
              if (mostRequestedService != null) _buildMostRequestedCard(),
              const SizedBox(height: 25),
            ],
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
      {'name': 'انستكرام', 'iconUrl': 'https://img.icons8.com/color/144/instagram-new.png', 'key': 'instagram'},
      {'name': 'تيك توك', 'iconUrl': 'https://img.icons8.com/color/144/tiktok.png', 'key': 'tiktok'},
      {'name': 'فيسبوك', 'iconUrl': 'https://img.icons8.com/color/144/facebook-new.png', 'key': 'facebook'},
      {'name': 'تويتر', 'iconUrl': 'https://img.icons8.com/color/144/twitterx.png', 'key': 'twitter'},
      {'name': 'سبوتفاي', 'iconUrl': 'https://img.icons8.com/color/144/spotify.png', 'key': 'spotify'},
      {'name': 'تليكرام', 'iconUrl': 'https://img.icons8.com/color/144/telegram-app.png', 'key': 'telegram'},
      {'name': 'واتساب', 'iconUrl': 'https://img.icons8.com/color/144/whatsapp.png', 'key': 'whatsapp'},
      {'name': 'ثريدز', 'iconUrl': 'https://img.icons8.com/color/144/threads.png', 'key': 'threads'},
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
            Expanded(child: _buildPlatformTile(platforms[7])),
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
              currentUser: currentUser,
              userBalance: userBalance,
            ),
          ),
        ).then((_) => _loadUserData());
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                platform['iconUrl'] as String,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.apps, size: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                platform['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMostRequestedCard() {
    final s = mostRequestedService!;
    return AnimatedBuilder(
      animation: _borderAnimController,
      builder: (context, child) {
        final val = _borderAnimController.value;
        final animatedBorderColor = HSLColor.fromAHSL(1.0, (val * 360) % 360, 0.85, 0.55).toColor();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: animatedBorderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: animatedBorderColor.withOpacity(0.25),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: animatedBorderColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'الأكثر طلباً بالتطبيق 🔥',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  buildPriceDisplay(s.rate),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'الفئة: ${s.category}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الحد الأدنى: ${s.min} | الأقصى: ${s.max}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A2FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderFormScreen(
                            toggleTheme: widget.toggleTheme,
                            isDark: widget.isDark,
                            service: s,
                            currentUser: currentUser,
                            userBalance: userBalance,
                          ),
                        ),
                      ).then((_) => _loadUserData());
                    },
                    child: const Text('طلب الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// 5. Add Funds Screen
class AddFundsScreen extends StatelessWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const AddFundsScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'شحن الحساب',
      toggleTheme: toggleTheme,
      isDark: isDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              'طرق الدفع المتوفرة داخل التطبيق حالياً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00A2FF)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            _buildPaymentTile(
              context: context,
              title: 'ماستر كارد / Mastercard',
              subtitle: 'دفع مباشر عبر البطاقات البنكية',
              icon: Icons.credit_card,
              iconColor: Colors.orange,
              onTap: () => _navigateToDetail(context, 'ماستر كارد', '07700000000'),
            ),
            const SizedBox(height: 15),
            _buildPaymentTile(
              context: context,
              title: 'آسيا سيل / AsiaCell',
              subtitle: 'تحويل رصيد أو كارتات شحن',
              icon: Icons.phone_android,
              iconColor: Colors.redAccent,
              onTap: () => _navigateToDetail(context, 'آسيا سيل', '07701234567'),
            ),
            const SizedBox(height: 15),
            _buildPaymentTile(
              context: context,
              title: 'زين كاش / Zain Cash',
              subtitle: 'الدفع المباشر عبر محفظة زين كاش',
              icon: Icons.account_balance_wallet,
              iconColor: Colors.pink,
              onTap: () => _navigateToDetail(context, 'زين كاش', '07801234567'),
            ),
            const SizedBox(height: 15),
            _buildPaymentTile(
              context: context,
              title: 'زين العراق / Zain Iraq',
              subtitle: 'تحويل رصيد عبر خطوط زين العراق',
              icon: Icons.cell_tower,
              iconColor: Colors.purple,
              onTap: () => _navigateToDetail(context, 'زين العراق', '07809876543'),
            ),
            const SizedBox(height: 15),
            _buildPaymentTile(
              context: context,
              title: 'آسيا حواله / Asia Hawala',
              subtitle: 'تحويل أموال مباشر عبر آسيا حوالة',
              icon: Icons.send_to_mobile,
              iconColor: Colors.teal,
              onTap: () => _navigateToDetail(context, 'آسيا حواله', '07709876543'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, String methodName, String number) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentDetailScreen(
          toggleTheme: toggleTheme,
          isDark: isDark,
          methodName: methodName,
          accountNumber: number,
        ),
      ),
    );
  }

  Widget _buildPaymentTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// 5.1 Payment Detail Screen
class PaymentDetailScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;
  final String methodName;
  final String accountNumber;

  const PaymentDetailScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
    required this.methodName,
    required this.accountNumber,
  });

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  final _senderNumberController = TextEditingController();
  final _amountController = TextEditingController();

  void _submitPaymentProof() {
    final sender = _senderNumberController.text.trim();
    final amount = _amountController.text.trim();

    if (sender.isEmpty || amount.isEmpty) {
      showCustomAlertDialog(
        context,
        title: 'تنبيه',
        message: 'يرجى إدخال رقم المرسل أو الرقم المرجعي للتحويل والمبلغ المحول.',
      );
      return;
    }

    addAppNotification(
      '𝖿᥆𝗅𝗅ᥕ𝖾𝗋 ꪎ 𝗉𝗋᥆',
      'تم إرسال طلب شحن الحساب عبر ${widget.methodName} بنجاح! سيتم مراجعة إثبات التحويل وإضافة الرصيد فوراً.',
      context,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '𝖿᥆𝗅𝗅ᥕ𝖾𝗋 ꪎ 𝗉𝗋᥆',
      showHeaderTitle: true,
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00A2FF), Color(0xFF0055FF)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  '1$=1$ سد بسد بدون عموله زايده',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'حول المبلغ عبر ${widget.methodName}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00A2FF)),
            ),
            const SizedBox(height: 15),
            const AnimatedYellowWarningBox(
              text: 'لازم ترسل اثبات التحويل اموال لاي تحويل مالي لدينا لتأكيد عملية الشحن بنجاح.',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Text('طريقة الدفع عبر ${widget.methodName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  const Text('حول إلى الرقم التابع للمنصة:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.accountNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00A2FF))),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Color(0xFF00A2FF)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.accountNumber));
                          showRgbNotificationOverlay(context, 'تم نسخ الرقم بنجاح');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _senderNumberController,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف المرسل أو رقم العملية المرجعي',
                prefixIcon: const Icon(Icons.numbers, color: Color(0xFF00A2FF)),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'المبلغ المحول ($)',
                prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF00A2FF)),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _submitPaymentProof,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('تأكيد وإرسال التحويل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 6. Platform Services Screen
class PlatformServicesScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;
  final String platformName;
  final String platformKey;
  final String currentUser;
  final double userBalance;

  const PlatformServicesScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
    required this.platformName,
    required this.platformKey,
    required this.currentUser,
    required this.userBalance,
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
        if (cat.contains('facebook') || cat.contains('tiktok') || cat.contains('telegram') || cat.contains('twitter') || cat.contains('youtube')) return false;
        return cat.contains('instagram') || name.contains('instagram') || cat.contains('انستجرام') || name.contains('انستغرام') || cat.contains('انستغرام') || cat.contains('انستكرام') || name.contains('انستكرام') || cat.contains('انستا');
      case 'facebook':
        if (cat.contains('instagram') || cat.contains('tiktok') || cat.contains('telegram')) return false;
        return cat.contains('facebook') || name.contains('facebook') || cat.contains('فيسبوك') || name.contains('فيس بوك');
      case 'tiktok':
        if (cat.contains('instagram') || cat.contains('facebook') || cat.contains('telegram')) return false;
        return cat.contains('tiktok') || name.contains('tiktok') || cat.contains('تيكتوك') || name.contains('تيك توك');
      case 'telegram':
        if (cat.contains('instagram') || cat.contains('facebook') || cat.contains('tiktok')) return false;
        return cat.contains('telegram') || name.contains('telegram') || cat.contains('تليكرام') || name.contains('تليجرام');
      case 'twitter':
        return cat.contains('twitter') || name.contains('twitter') || cat.contains('تويتر');
      case 'whatsapp':
        return cat.contains('whatsapp') || name.contains('whatsapp') || cat.contains('واتساب');
      case 'spotify':
        return cat.contains('spotify') || name.contains('spotify') || cat.contains('سبوت');
      case 'threads':
        return cat.contains('threads') || name.contains('threads') || cat.contains('ثريدز');
      default:
        return cat.contains(pKey) || name.contains(pKey);
    }
  }

  Future<void> _fetchServices() async {
    try {
      final all = await fetchServicesFromApi();
      final filtered = all.where((s) => _isServiceForPlatform(s, widget.platformKey)).toList();
      if (mounted) {
        setState(() {
          services = filtered.isNotEmpty ? filtered : all.take(15).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: widget.platformName,
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: isLoading
          ? const Center(child: RainbowSpinner())
          : errorMessage != null
              ? Center(child: Text('حدث خطأ: $errorMessage'))
              : services.isEmpty
                  ? const Center(child: Text('لا توجد خدمات متاحة حالياً لهذه المنصة'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        final s = services[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: const AppLogoWidget(size: 26),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('الحد الأدنى: ${s.min} | الأقصى: ${s.max}', style: const TextStyle(fontSize: 12)),
                            trailing: buildPriceDisplay(s.rate),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderFormScreen(
                                    toggleTheme: widget.toggleTheme,
                                    isDark: widget.isDark,
                                    service: s,
                                    currentUser: widget.currentUser,
                                    userBalance: widget.userBalance,
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

// 7. Order Form Screen
class OrderFormScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;
  final ServiceModel service;
  final String currentUser;
  final double userBalance;

  const OrderFormScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
    required this.service,
    required this.currentUser,
    required this.userBalance,
  });

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _linkController = TextEditingController();
  final _quantityController = TextEditingController();
  double calculatedCost = 0.0;
  bool isSubmitting = false;

  void _calculateCost(String val) {
    final qty = double.tryParse(val) ?? 0.0;
    final rate = double.tryParse(widget.service.rate) ?? 0.0;
    double actualRate = rate;
    if (globalDiscount > 0) {
      actualRate = math.max(0.0, rate - globalDiscount);
    }
    setState(() {
      calculatedCost = (qty / 1000) * actualRate;
    });
  }

  void _submitOrder() async {
    final link = _linkController.text.trim();
    final qtyStr = _quantityController.text.trim();
    final qty = int.tryParse(qtyStr) ?? 0;
    final min = int.tryParse(widget.service.min) ?? 0;
    final max = int.tryParse(widget.service.max) ?? 100000;

    if (link.isEmpty || qty <= 0) {
      showCustomAlertDialog(context, title: 'تنبيه', message: 'يرجى كتابة الرابط والكمية المطلوبة بشكل صحيح.');
      return;
    }

    if (qty < min || qty > max) {
      showCustomAlertDialog(context, title: 'تنبيه', message: 'الكمية يجب أن تكون بين $min و $max.');
      return;
    }

    if (widget.userBalance < calculatedCost) {
      showInsufficientFundsDialog(context);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final res = await http.post(
        Uri.parse(apiUrl),
        body: {
          'key': apiKey,
          'action': 'add',
          'service': widget.service.service,
          'link': link,
          'quantity': '$qty',
        },
      );

      final data = json.decode(res.body);

      if (res.statusCode == 200 && data.containsKey('order')) {
        final orderId = data['order'].toString();

        // Deduct from APP balance for this user
        final newBal = math.max(0.0, widget.userBalance - calculatedCost);
        await setUserBalance(widget.currentUser, newBal);

        final curSp = await getUserSpending(widget.currentUser);
        await setUserSpending(widget.currentUser, curSp + calculatedCost);

        // Store Order locally under this user
        final newOrder = OrderModel(
          order: orderId,
          status: 'قيد الانتظار',
          charge: calculatedCost.toStringAsFixed(2),
          startCount: '0',
          remains: '$qty',
          link: link,
          serviceName: widget.service.name,
          date: DateTime.now().toString().split('.')[0],
        );

        final userOrds = await getUserOrders(widget.currentUser);
        userOrds.insert(0, newOrder);
        await saveUserOrders(widget.currentUser, userOrds);

        if (!mounted) return;
        addAppNotification(
          '𝖿᥆𝗅𝗅ᥕ𝖾𝗋 ꪎ 𝗉𝗋᥆',
          'تم إرسال طلبك بنجاح! رقم الطلب: $orderId',
          context,
        );

        Navigator.pop(context);
      } else {
        if (!mounted) return;
        showCustomAlertDialog(context, title: 'خطأ', message: data['error'] ?? 'تعذر إرسال الطلب، يرجى المحاولة لاحقاً.');
      }
    } catch (e) {
      if (mounted) {
        showCustomAlertDialog(context, title: 'خطأ', message: 'حدث خطأ في الاتصال بالسيرفر.');
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'طلب الخدمة',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppLogoWidget(size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.service.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('الفئة: ${widget.service.category}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('السعر لكل 1000:', style: TextStyle(fontSize: 13)),
                      buildPriceDisplay(widget.service.rate),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('رابط الحساب أو المنشور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                hintText: 'https://...',
                prefixIcon: const Icon(Icons.link, color: Color(0xFF00A2FF)),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            const Text('الكمية المطلوبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              onChanged: _calculateCost,
              decoration: InputDecoration(
                hintText: 'الحد الأدنى ${widget.service.min} - الأقصى ${widget.service.max}',
                prefixIcon: const Icon(Icons.format_number_09, color: Color(0xFF00A2FF)),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00A2FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('التكلفة الإجمالية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '\$${calculatedCost.toStringAsFixed(3)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF00A2FF)),
                  ),
                ],
              ),
            ),
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
                    : const Text('تأكيد وإرسال الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 8. Order History Screen
class OrderHistoryScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;
  final String currentUser;

  const OrderHistoryScreen({super.key, required this.toggleTheme, required this.isDark, required this.currentUser});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<OrderModel> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserOrders();
  }

  Future<void> _loadUserOrders() async {
    final userOrds = await getUserOrders(widget.currentUser);
    if (mounted) {
      setState(() {
        orders = userOrds;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'سجل الطلبات',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: isLoading
          ? const Center(child: RainbowSpinner())
          : orders.isEmpty
              ? const Center(child: Text('لا توجد طلبات سابقة لهذا الحساب'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final o = orders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('طلب #${o.order}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A2FF))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(o.status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(o.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 6),
                            Text('الرابط: ${o.link}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('التكلفة: \$${o.charge}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text(o.date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// 9. Free Services Screen
class FreeServicesScreen extends StatelessWidget {
  final Function(bool) toggleTheme;
  final bool isDark;
  final String currentUser;
  final double userBalance;

  const FreeServicesScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
    required this.currentUser,
    required this.userBalance,
  });

  @override
  Widget build(BuildContext context) {
    final freeServices = [
      ServiceModel(service: '101', name: '🎁 100 مشاهدة انستكرام مجاناً', type: 'Default', category: 'خدمات مجانية', rate: '0.00', min: '100', max: '100'),
      ServiceModel(service: '102', name: '🎁 50 لايك تيك توك تجريبي', type: 'Default', category: 'خدمات مجانية', rate: '0.00', min: '50', max: '50'),
      ServiceModel(service: '103', name: '🎁 100 مشاهدة فيديو تليجرام', type: 'Default', category: 'خدمات مجانية', rate: '0.00', min: '100', max: '100'),
    ];

    return BaseScaffold(
      title: 'خدمات مجانية',
      toggleTheme: toggleTheme,
      isDark: isDark,
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: freeServices.length,
        itemBuilder: (context, index) {
          final s = freeServices[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const AppLogoWidget(size: 26),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('مجاني بالكامل بدون خصم رصيد', style: TextStyle(color: Colors.green, fontSize: 12)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderFormScreen(
                        toggleTheme: toggleTheme,
                        isDark: isDark,
                        service: s,
                        currentUser: currentUser,
                        userBalance: userBalance,
                      ),
                    ),
                  );
                },
                child: const Text('احصل الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          );
        },
      ),
    );
  }
}
