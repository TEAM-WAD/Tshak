import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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
      service: json['service'].toString(),
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      category: json['category'] ?? '',
      rate: json['rate'].toString(),
      min: json['min'].toString(),
      max: json['max'].toString(),
    );
  }
}

class OrderModel {
  final String order;
  final String status;
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
}

// App-wide Store for Local Orders Tracking
List<OrderModel> userOrdersStore = [];

// Base Scaffold Wrapper with Custom AppBar
class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Function(bool) toggleTheme;
  final bool isDark;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.toggleTheme,
    required this.isDark,
  });

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
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
                        value: isDark,
                        activeColor: const Color(0xFF00A2FF),
                        onChanged: (val) {
                          toggleTheme(val);
                          Navigator.pop(ctx);
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
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 22),
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, size: 24),
              onPressed: () => _showSettingsSheet(context),
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
                leading: const Icon(Icons.settings, color: Color(0xFF00A2FF)),
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

  void _handleLogin() {
    if (_usernameController.text == 'admin' && _passwordController.text == 'admin') {
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
  int myOrdersCount = 0;
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
          myOrdersCount = userOrdersStore.length;
          isLoadingStats = false;
        });
      }
    } catch (_) {
      setState(() => isLoadingStats = false);
    }
  }

  Future<void> _fetchAllServices() async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {'key': apiKey, 'action': 'services'},
      );
      if (response.statusCode == 200) {
        final List list = json.decode(response.body);
        setState(() {
          allServices = list.map((item) => ServiceModel.fromJson(item)).toList();
        });
      }
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
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Stat Cards Grid
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

            // Navigation Header Buttons
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
                            allServices: allServices,
                          ),
                        ),
                      );
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
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Field
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
                        );
                      },
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 25),

            // Platforms Platform Selector Title
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'اختر المنصة أولاً',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00A2FF)),
              ),
            ),
            const SizedBox(height: 15),

            // Platform Icons Grid Layout
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
              platformName: platform['name'],
              platformKey: platform['key'],
            ),
          ),
        );
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
              child: Icon(platform['icon'], color: platform['color'], size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              platform['name'],
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

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {'key': apiKey, 'action': 'services'},
      );
      if (response.statusCode == 200) {
        final List list = json.decode(response.body);
        final all = list.map((item) => ServiceModel.fromJson(item)).toList();

        setState(() {
          services = all.where((s) {
            final cat = s.category.toLowerCase();
            final name = s.name.toLowerCase();
            final key = widget.platformKey.toLowerCase();
            return cat.contains(key) || name.contains(key);
          }).toList();
          isLoading = false;
        });
      }
    } catch (_) {
      setState(() => isLoading = false);
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
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          child: Text('ID: ${item.service} | الحد الأدنى: ${item.min} - الأقصى: ${item.max}'),
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
  final List<ServiceModel> allServices;

  const FreeServicesScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
    required this.allServices,
  });

  @override
  State<FreeServicesScreen> createState() => _FreeServicesScreenState();
}

class _FreeServicesScreenState extends State<FreeServicesScreen> {
  List<ServiceModel> freeServices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _filterFreeServices();
  }

  void _filterFreeServices() {
    setState(() {
      freeServices = widget.allServices.where((s) {
        final rateNum = double.tryParse(s.rate) ?? 1.0;
        return rateNum == 0.0 || s.rate == "0.00" || s.rate == "0" || s.name.contains("مجاني") || s.name.contains("Free");
      }).toList();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Follower X',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'الخدمات المجانية بالتطبيق',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00A2FF)),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: isLoading
                  ? const Center(child: RainbowSpinner())
                  : freeServices.isEmpty
                      ? const Center(child: Text('لا توجد خدمات مجانية متوفرة الآن'))
                      : ListView.builder(
                          itemCount: freeServices.length,
                          itemBuilder: (context, index) {
                            final item = freeServices[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: ListTile(
                                title: Center(
                                  child: Text(
                                    item.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                subtitle: Center(
                                  child: Text(
                                    'السعر: 0.00\$',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
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
            ),
          ],
        ),
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

  String? quantityError;
  double calculatedCost = 0.0;
  bool isSubmitting = false;

  void _onQuantityChanged(String val) {
    final qty = int.tryParse(val);
    final min = int.tryParse(widget.service.min) ?? 1;
    final max = int.tryParse(widget.service.max) ?? 1000000;
    final rate = double.tryParse(widget.service.rate) ?? 0.0;

    if (qty == null) {
      setState(() {
        quantityError = null;
        calculatedCost = 0.0;
      });
      return;
    }

    if (qty < min) {
      setState(() {
        quantityError = 'الكمية أقل من الحد الأدنى المسموح ($min)';
        calculatedCost = (qty * rate) / 1000;
      });
    } else if (qty > max) {
      setState(() {
        quantityError = 'الكمية أكبر من الحد الأقصى المسموح ($max)';
        calculatedCost = (qty * rate) / 1000;
      });
    } else {
      setState(() {
        quantityError = null;
        calculatedCost = (qty * rate) / 1000;
      });
    }
  }

  Future<void> _submitOrder() async {
    if (_linkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال الرابط')));
      return;
    }
    if (_quantityController.text.trim().isEmpty || quantityError != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى التأكد من الكمية المدخلة')));
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
          'link': _linkController.text.trim(),
          'quantity': _quantityController.text.trim(),
        },
      );

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        if (resData['order'] != null) {
          final newOrder = OrderModel(
            order: resData['order'].toString(),
            status: 'قيد الانتظار',
            charge: calculatedCost.toStringAsFixed(2),
            startCount: '-',
            remains: _quantityController.text.trim(),
            link: _linkController.text.trim(),
            serviceName: widget.service.name,
            date: DateTime.now().toString().split(' ')[0],
          );
          userOrdersStore.insert(0, newOrder);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم ارسال طلبك بنجاح'), backgroundColor: Colors.green),
            );
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        } else {
          final err = resData['error'] ?? 'فشل إرسال الطلب';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ في الاتصال بالخادم')));
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'طلب جديد',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الخدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                '${widget.service.service} - ${widget.service.name} - \$${widget.service.rate}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A2FF)),
              ),
            ),
            const SizedBox(height: 20),

            const Text('الرابط', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                hintText: 'ضع الرابط هنا',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            const Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              onChanged: _onQuantityChanged,
              decoration: InputDecoration(
                hintText: 'ادخل الكمية',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: quantityError != null ? Colors.red : const Color(0xFF00A2FF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: quantityError != null ? Colors.red : Colors.transparent),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'الحد الأدنى: ${widget.service.min} - الحد الأقصى: ${widget.service.max}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (quantityError != null) ...[
              const SizedBox(height: 6),
              Text(quantityError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ],

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('التكلفة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    '\$${calculatedCost.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00A2FF)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
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
                    : const Text('إرسال', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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

  @override
  void initState() {
    super.initState();
    _refreshOrderStatuses();
  }

  Future<void> _refreshOrderStatuses() async {
    if (userOrdersStore.isEmpty) return;
    setState(() => isRefreshing = true);

    for (int i = 0; i < userOrdersStore.length; i++) {
      try {
        final res = await http.post(
          Uri.parse(apiUrl),
          body: {
            'key': apiKey,
            'action': 'status',
            'order': userOrdersStore[i].order,
          },
        );
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] != null) {
            final st = data['status'].toString();
            String statusAr = st;
            if (st.toLowerCase() == 'pending') statusAr = 'قيد الانتظار';
            if (st.toLowerCase() == 'processing' || st.toLowerCase() == 'in progress') statusAr = 'قيد التنفيذ';
            if (st.toLowerCase() == 'completed') statusAr = 'مكتمل';
            if (st.toLowerCase() == 'canceled') statusAr = 'ملغى';

            userOrdersStore[i] = OrderModel(
              order: userOrdersStore[i].order,
              status: statusAr,
              charge: data['charge']?.toString() ?? userOrdersStore[i].charge,
              startCount: data['start_count']?.toString() ?? userOrdersStore[i].startCount,
              remains: data['remains']?.toString() ?? userOrdersStore[i].remains,
              link: userOrdersStore[i].link,
              serviceName: userOrdersStore[i].serviceName,
              date: userOrdersStore[i].date,
            );
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'سجل الطلبات',
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
      body: userOrdersStore.isEmpty
          ? const Center(child: Text('لا توجد طلبات سابقة'))
          : RefreshIndicator(
              onRefresh: _refreshOrderStatuses,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: userOrdersStore.length,
                itemBuilder: (context, index) {
                  final order = userOrdersStore[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00A2FF).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  order.order,
                                  style: const TextStyle(color: Color(0xFF00A2FF), fontWeight: FontWeight.bold),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(order.date, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.calendar_month, color: Color(0xFF00A2FF), size: 18),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            order.serviceName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),

                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: order.status == 'مكتمل'
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: order.status == 'مكتمل' ? Colors.green : Colors.orange,
                              ),
                            ),
                            child: Text(
                              order.status,
                              style: TextStyle(
                                color: order.status == 'مكتمل' ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Link Bar
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.link, color: Color(0xFF00A2FF)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.link,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Metrics Grid
                          Row(
                            children: [
                              Expanded(child: _buildMetricTile('التكلفة:', order.charge, Icons.sell)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildMetricTile('الكمية:', order.remains, Icons.list)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildMetricTile('عدد البدء:', order.startCount, Icons.format_list_numbered)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildMetricTile('المتبقي:', order.remains, Icons.timer)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF00A2FF)),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
