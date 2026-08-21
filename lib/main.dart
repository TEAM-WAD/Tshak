import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

void main() {
  runApp(const FollowerXApp());
}

class FollowerXApp extends StatelessWidget {
  const FollowerXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Follower X',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121214),
        primaryColor: const Color(0xFF1E88E5),
      ),
      home: const SplashScreen(),
    );
  }
}

// ----------------------------------------------------
// 1. شاشة التحميل (Splash Screen)
// ----------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final List<IconData> _socialIcons = [
    FontAwesomeIcons.facebook,
    FontAwesomeIcons.tiktok,
    FontAwesomeIcons.instagram,
    FontAwesomeIcons.spotify,
    FontAwesomeIcons.youtube,
  ];

  int _currentIconIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      setState(() {
        _currentIconIndex = (_currentIconIndex + 1) % _socialIcons.length;
      });
    });

    Future.delayed(const Duration(seconds: 4), () {
      _timer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
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
              child: FaIcon(
                _socialIcons[_currentIconIndex],
                key: ValueKey<int>(_currentIconIndex),
                size: 80,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Loading...',
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 15),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blueAccent,
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 2. شاشة تسجيل الدخول الاحترافية (Login Screen)
// ----------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
        MaterialPageRoute(builder: (_) => const HomeScreen()),
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
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF1E1E24),
                  child: Icon(Icons.lock_outline, size: 50, color: Colors.blueAccent),
                ),
                const SizedBox(height: 20),
                Text(
                  'تسجيل الدخول',
                  style: GoogleFonts.cairo(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'اسم المستخدم',
                    labelStyle: GoogleFonts.cairo(color: Colors.grey),
                    prefixIcon: const Icon(Icons.person, color: Colors.blueAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E1E24),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    labelStyle: GoogleFonts.cairo(color: Colors.grey),
                    prefixIcon: const Icon(Icons.lock, color: Colors.blueAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E1E24),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A2FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'دخول',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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

// ----------------------------------------------------
// 3. الشاشة الرئيسية والتصميم المطابق للصور (Home Screen)
// ----------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF121214),
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, size: 30, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: const Color(0xFF1A1A1E),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                  ),
                ),
                child: const Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 15),
              Text(
                'follwer X',
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Divider(color: Colors.grey, height: 40),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          child: Column(
            children: [
              // سطر الأزرار العلوية
              Row(
                children: [
                  Expanded(
                    child: _buildHeaderButton(
                      icon: Icons.card_giftcard,
                      title: 'خدمات مجانية',
                      color: const Color(0xFF1E1E24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHeaderButton(
                      icon: Icons.history,
                      title: 'سجل الطلبات',
                      color: const Color(0xFF1E1E24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // زر طلباتي المستطيل
              SizedBox(
                width: double.infinity,
                child: _buildHeaderButton(
                  icon: Icons.shopping_cart,
                  title: 'طلباتي',
                  color: const Color(0xFF1E1E24),
                ),
              ),
              const SizedBox(height: 25),

              // القسم الأول: اختر الفئة (مطابق للفيجوال)
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'اختر الفئة',
                      style: GoogleFonts.cairo(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF29B6F6),
                      ),
                    ),
                    CustomPaint(
                      size: const Size(140, 20),
                      painter: ArrowPainter(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              _buildCategoryGrid(),

              const SizedBox(height: 35),

              // القسم الثاني: طرق دفع متعددة (مطابق للفيجوال)
              Column(
                children: [
                  Text(
                    'طرق دفع متعددة',
                    style: GoogleFonts.cairo(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF29B6F6),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 4,
                    margin: const EdgeInsets.only(top: 4, bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A2FF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _buildPaymentGrid(),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // كروت الأزرار العلوية
  Widget _buildHeaderButton({required IconData icon, required String title, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF00A2FF), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // شبكة الفئات المتطابقة مع الصورة الأولى
  Widget _buildCategoryGrid() {
    final List<Map<String, dynamic>> categories = [
      {'icon': FontAwesomeIcons.tiktok, 'color': const Color(0xFFFF004F)},
      {'icon': FontAwesomeIcons.facebookF, 'color': const Color(0xFF1877F2)},
      {'icon': FontAwesomeIcons.youtube, 'color': const Color(0xFFFF0000)},
      {'icon': FontAwesomeIcons.twitter, 'color': const Color(0xFF1DA1F2)},
      {'icon': FontAwesomeIcons.instagram, 'color': const Color(0xFFE1306C)},
      {'icon': FontAwesomeIcons.kickstarter, 'color': const Color(0xFF05CE78)},
      {'icon': FontAwesomeIcons.soundcloud, 'color': const Color(0xFFFF5500)},
      {'icon': FontAwesomeIcons.spotify, 'color': const Color(0xFF1DB954)},
      {'icon': FontAwesomeIcons.telegram, 'color': const Color(0xFF0088CC)},
      {'icon': FontAwesomeIcons.twitch, 'color': const Color(0xFF9146FF)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: categories[index]['color'],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: FaIcon(categories[index]['icon'], color: Colors.white, size: 28),
          ),
        );
      },
    );
  }

  // شبكة الدفع المتطابقة مع الصورة الثانية
  Widget _buildPaymentGrid() {
    final List<Map<String, dynamic>> payments = [
      {'name': 'VISA', 'color': Colors.blue, 'isText': true},
      {'icon': FontAwesomeIcons.mastercard, 'color': Colors.orangeAccent},
      {'name': 'USDT', 'color': Colors.teal, 'isText': true},
      {'name': 'PAYTR', 'color': Colors.lightBlue, 'isText': true},
      {'name': 'cryptomus', 'color': Colors.white, 'isText': true},
      {'name': 'PAYEER', 'color': Colors.cyan, 'isText': true},
      {'icon': FontAwesomeIcons.bitcoin, 'color': Colors.amber},
      {'name': 'stripe', 'color': Colors.purpleAccent, 'isText': true},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.1,
      ),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final item = payments[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Center(
            child: item['isText'] == true
                ? Text(
                    item['name'],
                    style: TextStyle(
                      color: item['color'],
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : FaIcon(item['icon'], color: item['color'], size: 32),
          ),
        );
      },
    );
  }
}

// رسم السهم الأزرق المنحني لمطابقة كلمة "اختر الفئة"
class ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF29B6F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width, 0);
    path.quadraticBezierTo(size.width * 0.5, size.height * 1.2, 0, size.height * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
