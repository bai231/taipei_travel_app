import 'package:flutter/material.dart';
import 'register_screen.dart';
import '../theme/app_theme.dart'; // 引入色彩系統

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  // ==========================================
  // 🎨 顏色配置區（未來隨時在此更換主題色）
  // ==========================================
  static const Color backgroundColor = Color(0xFFB5D5C5); // 頁面底色
  static const Color textPrimaryColor = Color(0xFF2D5A46); // 主標題/Logo 深文字色
  static const Color textSecondaryColor = Color(0xFF386652); // 副標題/小文字色
  static const Color inputFillColor = Color(0xFF72B095); // 輸入框填色
  static const Color inputTextColor = Color(0xFF1E3F31); // 輸入框內文字顏色
  static const Color buttonColor = Color(0xFF356852); // 登入按鈕主色
  static const Color buttonTextColor = Colors.white; // 登入按鈕文字顏色

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      // 處理登入邏輯
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登入中...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 1. 頂部兩側裝飾點點
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Icon(Icons.more_horiz, color: textPrimaryColor, size: 28),
                      Icon(Icons.more_horiz, color: textPrimaryColor, size: 28),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // 2. 頂部 Logo 區塊
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: textPrimaryColor, width: 2),
                  ),
                  child: const Icon(
                    Icons.face_3_outlined, // 暫代 Logo 圖示，之後可換 Image.asset
                    size: 54,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Wardiere Inc.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                    letterSpacing: 0.5,
                  ),
                ),

                const Spacer(flex: 2),

                // 3. 標題與副標題
                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 36),

                // 4. Name 輸入框（全圓角膠囊造型）
                TextFormField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: inputTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _buildCapsuleInputDecoration(hint: 'Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入使用者名稱';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // 5. Password 輸入框
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: inputTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _buildCapsuleInputDecoration(hint: 'Password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '請輸入密碼';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // 6. Log In 按鈕
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: buttonTextColor,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // 7. 註冊按鈕 與 忘記密碼（並列排版）
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 左側：註冊按鈕
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        '註冊帳號',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                    ),

                    // 中間分隔線
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        '|',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),

                    // 右側：忘記密碼按鈕
                    GestureDetector(
                      onTap: () {
                        // TODO: 導航至忘記密碼頁面
                      },
                      child: const Text(
                        'Forgot Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                    ),
                  ],
                ),


                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 封裝膠囊狀（Stadium）輸入框樣式
  InputDecoration _buildCapsuleInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: inputTextColor.withValues(alpha: 0.7),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: inputFillColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}