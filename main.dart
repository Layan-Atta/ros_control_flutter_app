import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert'; // لإرسال البيانات بصيغة JSON

void main() {
  runApp(const RosControlApp());
}

class RosControlApp extends StatelessWidget {
  const RosControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROS Control Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // استخدام تصميم داكن (Tech Theme)
        brightness: Brightness.dark,
        primaryColor: Colors.tealAccent, // لون مميز
        scaffoldBackgroundColor: const Color(0xFF121212), // خلفية داكنة جداً
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B1B1B), // لون شريط علوي
          elevation: 4,
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      home: const ControlScreen(),
    );
  }
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  // تذكير: يجب استبداله بالـ IP الحقيقي عند التشغيل الفعلي
  // بما أنك تستخدم الحل البديل، سيبقى هذا العنوان وهمياً
  final String _rosBridgeUrl = 'ws://YOUR_ROS_IP_HERE:9090';
  WebSocketChannel? _channel;
  String _connectionStatus = "Connecting...";
  Color _statusColor = Colors.orange;

  // هذه الحالة ستتبع أي زر مضغوط حالياً
  String? _pressedDirection;

  @override
  void initState() {
    super.initState();
    _connectToRos();
  }

  void _connectToRos() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_rosBridgeUrl));
      
      // تحديث الحالة فوراً إلى "جاري المحاولة"
      if (mounted) {
        setState(() {
          _connectionStatus = "Attempting to Connect...";
          _statusColor = Colors.orange;
        });
      }

      _channel!.stream.listen(
        (message) {
          debugPrint("Received: $message");
          if (mounted) {
            setState(() {
              _connectionStatus = "Connected";
              _statusColor = Colors.green;
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _connectionStatus = "Disconnected";
              _statusColor = Colors.grey;
            });
          }
        },
        onError: (error) {
          debugPrint("Error: $error");
          if (mounted) {
            setState(() {
              // هذا ما سيظهر لك غالباً
              _connectionStatus = "Connection Error";
              _statusColor = Colors.red;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = "Failed to connect (Invalid URL?)";
          _statusColor = Colors.red;
        });
      }
    }
  }

  // --- دالة إرسال الأوامر ---
  void _sendRosCommand(double linearX, double angularZ) {
    // التأكد من أن الاتصال موجود (على الرغم من أنه لن يكون كذلك في حالتك)
    if (_channel == null || _channel!.closeCode != null) {
      debugPrint("Not connected. Attempting to reconnect...");
      // محاولة إعادة الاتصال إذا فشل الإرسال
      _connectToRos();
      return; // لا ترسل الأمر هذه المرة
    }

    // هذه هي الصيغة التي يفهمها rosbridge
    final message = {
      'op': 'publish',
      'topic': '/turtle1/cmd_vel', // كما ظهر في الفيديو [00:16:23]
      'msg': {
        'linear': {'x': linearX, 'y': 0.0, 'z': 0.0},
        'angular': {'x': 0.0, 'y': 0.0, 'z': angularZ}
      }
    };

    // إرسال الأمر بصيغة JSON
    _channel!.sink.add(jsonEncode(message));
  }

  // --- دوال التحكم الجديدة (اضغط باستمرار واترك) ---

  // عند الضغط على زر
  void _handlePress(String direction, double linear, double angular) {
    setState(() {
      _pressedDirection = direction; // لتحديث الواجهة (الأنيميشن)
    });
    _sendRosCommand(linear, angular); // إرسال أمر الحركة
  }

  // عند رفع الإصبع عن الزر
  void _handleRelease() {
    setState(() {
      _pressedDirection = null; // إزالة علامة الضغط
    });
    _sendRosCommand(0.0, 0.0); // !!! إرسال أمر التوقف
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ROS Control Panel'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // --- 1. مؤشر حالة الاتصال ---
            _buildStatusIndicator(),

            // --- 2. لوحة التحكم (D-Pad) ---
            _buildControlPad(),

            // مساحة فارغة صغيرة
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- ويدجت مساعد لمؤشر الحالة ---
  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.2), // لون خلفية شفاف
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _statusColor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: _statusColor, size: 16),
          const SizedBox(width: 10),
          Text(
            _connectionStatus,
            style: TextStyle(
              color: _statusColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- ويدجت مساعد للوحة التحكم ---
  Widget _buildControlPad() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // --- زر الأعلى ---
        _buildButton(
          icon: Icons.keyboard_arrow_up,
          direction: "up",
          linear: 2.0, // سرعة للأمام
          angular: 0.0,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- زر اليسار ---
            _buildButton(
              icon: Icons.keyboard_arrow_left,
              direction: "left",
              linear: 0.0,
              angular: 2.0, // سرعة دوران لليسار
            ),
            const SizedBox(width: 80), // مساحة لزر التوقف

            // --- زر اليمين ---
            _buildButton(
              icon: Icons.keyboard_arrow_right,
              direction: "right",
              linear: 0.0,
              angular: -2.0, // سرعة دوران لليمين
            ),
          ],
        ),
        const SizedBox(height: 10),
        // --- زر الأسفل ---
        _buildButton(
          icon: Icons.keyboard_arrow_down,
          direction: "down",
          linear: -2.0, // سرعة للخلف
          angular: 0.0,
        ),
        
        // --- زر التوقف (احتياطي) ---
        const SizedBox(height: 30),
        _buildStopButton(),
      ],
    );
  }

  // --- ويدجت مساعد لإنشاء أزرار الحركة ---
  Widget _buildButton({
    required IconData icon,
    required String direction,
    double linear = 0.0,
    double angular = 0.0,
  }) {
    // تحديد إذا كان هذا الزر هو المضغوط حالياً
    final bool isPressed = (_pressedDirection == direction);

    return GestureDetector(
      // عند بدء اللمس
      onTapDown: (_) => _handlePress(direction, linear, angular),
      // عند رفع اللمس (سواء حرك إصبعه أو رفعه)
      onTapUp: (_) => _handleRelease(),
      onTapCancel: () => _handleRelease(),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100), // مدة الأنيميشن
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPressed
              ? Colors.tealAccent // لون الزر عند الضغط
              : const Color(0xFF2A2A2A), // لون الزر الافتراضي
          shape: BoxShape.circle,
          boxShadow: isPressed
              ? [
                  // لا يوجد ظل عند الضغط (يعطي إحساس "الغرق")
                ]
              : [
                  // ظل افتراضي ليعطي بروز
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(5, 5),
                  ),
                ],
        ),
        child: Icon(
          icon,
          size: 44,
          color: isPressed ? Colors.black : Colors.white, // لون الأيقونة
        ),
      ),
    );
  }
  
  // --- ويدجت مساعد لزر التوقف ---
  Widget _buildStopButton() {
     return GestureDetector(
      onTap: _handleRelease, // أي ضغطة عليه توقف كل شيء
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          shape: BoxShape.circle,
           boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(5, 5),
                  ),
                ],
        ),
        child: const Icon(
          Icons.stop,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }
}