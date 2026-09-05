import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 引入 Supabase 錯誤型別
import '../services/auth_service.dart';                  // 引入會員驗證服務
import '../services/favorite_service.dart';              // 引入收藏雲端同步服務
import 'register_screen.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrNameController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService(); // 會員驗證服務
  bool _isLoading = false;                        // 登入中旋轉狀態

  // ==========================================
  // 顏色設定
  // ==========================================
  static const Color backgroundColor = Color(0xFFB5D5C5);
  static const Color textPrimaryColor = Color(0xFF2D5A46);
  static const Color textSecondaryColor = Color(0xFF386652);
  static const Color inputFillColor = Color(0xFF72B095);
  static const Color inputTextColor = Color(0xFF1E3F31);
  static const Color buttonColor = Color(0xFF356852);
  static const Color buttonTextColor = Colors.white;

  @override
  void dispose() {
    _emailOrNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 登入處理與跳轉核心
  Future<void> _handleLogin() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    final email = _emailOrNameController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    debugPrint("🚀 1. 正在驗證登入: $email");

    // 1. Supabase 驗證帳密
    await _authService.signIn(
      email: email,
      password: password,
    );

    debugPrint("✅ 2. 帳密驗證成功！開始同步收藏清單...");

    // 2. 嘗試載入收藏（若這裡報錯也不卡死登入流程）
    try {
      await FavoriteService().fetchFavoritesFromCloud();
      debugPrint("✅ 3. 雲端收藏同步成功！");
    } catch (favError) {
      debugPrint("⚠️ 收藏同步失敗（但不影響登入）: $favError");
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('登入成功！歡迎回來 🌿'),
        duration: Duration(seconds: 1),
      ),
    );

    // 3. 執行跳轉
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

  } on AuthException catch (e) {
    debugPrint("❌ [AuthException 帳密驗證失敗]: ${e.message} (StatusCode: ${e.statusCode})");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('帳號或密碼錯誤: ${e.message}')),
    );
  } catch (e, stackTrace) {
    debugPrint("❌ [未預期的系統錯誤]: $e");
    debugPrint("堆疊追蹤: $stackTrace");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('登入過程發生錯誤: $e')),
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
                    Icons.face_3_outlined,
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

                // 4. Email / 帳號輸入框
                TextFormField(
                  controller: _emailOrNameController,
                  keyboardType: TextInputType.emailAddress,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: inputTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _buildCapsuleInputDecoration(hint: 'Email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入電子信箱';
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

                // 6. Log In 按鈕（支援 Loading 動畫防重複點擊）
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: buttonTextColor,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Log In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const Spacer(flex: 2),

                // 7. 註冊按鈕 與 忘記密碼
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 註冊按鈕
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

                    // 忘記密碼按鈕
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('請聯繫管理員重設密碼')),
                        );
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

  // 膠囊狀輸入框裝飾樣式
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