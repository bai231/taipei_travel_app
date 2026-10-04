import 'package:flutter/material.dart';
import '../services/language_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import '../services/auth_service.dart';
import 'guide_overlay_screen.dart';
// 引入色彩系統

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

  final AuthService _authService = AuthService();
  bool _isLoading = false;

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

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. 呼叫 Supabase 註冊帳號並寫入 profiles 表
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        username: _nameController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.tr(context, 'register_success'))),
      );

      // 2. 註冊成功後關閉註冊頁並開啟使用指南
      Navigator.pop(context);
      showUserGuide(context);

    } on AuthException catch (e) {
      // 捕捉 Supabase 驗證錯誤（例如信箱已被註冊、密碼太弱等）
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      // 捕捉其他網路或資料庫錯誤
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${LanguageService.tr(context, 'register_failed')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

                // 2. Logo 設計
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
                Text(
                  LanguageService.tr(context, 'register_title'),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  LanguageService.tr(context, 'register_subtitle'),
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
                  validator: (v) => (v == null || v.trim().isEmpty) ? LanguageService.tr(context, 'register_name_required') : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
  controller: _emailController,
  keyboardType: TextInputType.emailAddress,
  textAlign: TextAlign.center,
  style: const TextStyle(color: inputTextColor, fontSize: 15),
  decoration: _buildInputDeco(hint: 'Email'),
  validator: (v) {
    if (v == null || v.trim().isEmpty) {
      return LanguageService.tr(context, 'register_email_required');
    }
    final email = v.trim();
    // 只要有字元 + @ + 網域名稱 + 小數點 就判定通過，不再刁難格式
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return LanguageService.tr(context, 'register_email_invalid');
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
                  validator: (v) => (v == null || v.length < 6) ? LanguageService.tr(context, 'register_password_short') : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: inputTextColor, fontSize: 15),
                  decoration: _buildInputDeco(hint: 'Confirm Password'),
                  validator: (v) {
                    if (v != _passwordController.text) return LanguageService.tr(context, 'register_password_mismatch');
                    return null;
                  },
                ),
                const SizedBox(height: 22),

                // 5. Sign Up 按鈕
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp, // 👈 載入時禁用防止重複點擊
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: _isLoading
                      ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                      LanguageService.tr(context, 'register_title'),
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
               
                const Spacer(flex: 2),

                // 6. 已有帳號？返回登入
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      LanguageService.tr(context, 'register_have_account'),
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        LanguageService.tr(context, 'register_login'),
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
