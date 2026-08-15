import 'package:flutter/material.dart';
import 'guide_overlay_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 藍色系色彩直接參照（亦可引入 AppColors）
  static const Color backgroundColor = Color(0xFFF2F6F9);
  static const Color primaryDark = Color(0xFF1B435A);
  static const Color textSecondary = Color(0xFF6C8796);
  static const Color inputFill = Color(0xFFD6E6F0);
  static const Color inputTextColor = Color(0xFF1E3340);
  static const Color buttonColor = Color(0xFF2E6B8E);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('註冊成功！準備開始你的旅程 ✈️')),
      );
      // 註冊成功後返回或跳轉
      // 註冊成功後：
      Navigator.pop(context); // 關閉註冊頁
      showUserGuide(context); // 立即跳出使用指南疊層
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 1. 頂部列（左側返回，右側裝飾）
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: primaryDark, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.more_horiz, color: primaryDark, size: 28),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // 2. 陪伴風格圓形 Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryDark, width: 2),
                  ),
                  child: const Icon(
                    Icons.explore_outlined,
                    size: 46,
                    color: primaryDark,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Travel Companion',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryDark,
                    letterSpacing: 0.5,
                  ),
                ),

                const Spacer(flex: 1),

                // 3. 標題區
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '加入我們，開啟你的下一趟探索',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // 4. 輸入表單群 (膠囊置中對齊)
                TextFormField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: inputTextColor, fontSize: 15),
                  decoration: _buildInputDeco(hint: 'Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入姓名' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: inputTextColor, fontSize: 15),
                  decoration: _buildInputDeco(hint: 'Email'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '請輸入電子郵件';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                      return '請輸入有效的電子信箱格式';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: inputTextColor, fontSize: 15),
                  decoration: _buildInputDeco(hint: 'Password'),
                  validator: (v) => (v == null || v.length < 6) ? '密碼至少需 6 碼' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: inputTextColor, fontSize: 15),
                  decoration: _buildInputDeco(hint: 'Confirm Password'),
                  validator: (v) {
                    if (v != _passwordController.text) return '兩次密碼輸入不一致';
                    return null;
                  },
                ),
                const SizedBox(height: 22),

                // 5. Sign Up 按鈕
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // 6. 已有帳號？返回登入
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '已經有帳號了嗎？',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        ' 立即登入',
                        style: TextStyle(
                          color: primaryDark,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
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

  InputDecoration _buildInputDeco({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textSecondary, fontSize: 15),
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: buttonColor, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }
}