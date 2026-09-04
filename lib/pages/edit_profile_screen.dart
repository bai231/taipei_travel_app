import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart'; // 引入你的 AppColors

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _emailController;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _avatarUrl;

  // 顏色配置（若已有 AppColors 可直接替換引用）
  static const Color bgColor = Color(0xFFF2F6F9);
  static const Color primaryNavy = Color(0xFF1B435A);
  static const Color primaryBlue = Color(0xFF2E6B8E);
  static const Color inputFill = Color(0xFFD6E6F0);
  static const Color textMuted = Color(0xFF6C8796);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _emailController = TextEditingController();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // 載入當前資料庫紀錄
  Future<void> _loadCurrentProfile() async {
    try {
      final profile = await _authService.getCurrentUserProfile();
      final user = _authService.currentUser;

      if (mounted) {
        setState(() {
          _emailController.text = user?.email ?? '';
          _nameController.text = profile?['username'] ?? user?.email?.split('@').first ?? '';
          _bioController.text = profile?['bio'] ?? '熱愛探索世界的旅伴 🌿';
          _avatarUrl = profile?['avatar_url'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入資料失敗: $e')),
        );
      }
    }
  }

  // 儲存修改
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _authService.updateProfile(
        username: _nameController.text,
        bio: _bioController.text,
        avatarUrl: _avatarUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('個人資料已同步更新 ✨')),
      );
      Navigator.pop(context, true); // 回傳 true 讓前頁知道有更新
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: primaryNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "編輯個人資料",
          style: TextStyle(
            color: primaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. 大頭貼預覽與更換按鈕
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryNavy.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: inputFill,
                                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                                child: _avatarUrl == null
                                    ? const Icon(Icons.person, size: 50, color: primaryNavy)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('更換大頭貼功能（可串接圖片上傳）')),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: primaryBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "點擊相機更換頭像",
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      const SizedBox(height: 32),

                      // 2. 暱稱欄位
                      _buildFieldLabel("使用者暱稱"),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: primaryNavy, fontSize: 15),
                        decoration: _buildInputDeco(
                          hint: "請輸入你的暱稱",
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? '暱稱不能為空' : null,
                      ),
                      const SizedBox(height: 20),

                      // 3. 信箱（唯讀）
                      _buildFieldLabel("綁定信箱 (不可修改)"),
                      TextFormField(
                        controller: _emailController,
                        readOnly: true,
                        style: const TextStyle(color: textMuted, fontSize: 15),
                        decoration: _buildInputDeco(
                          hint: "電子信箱",
                          prefixIcon: Icons.email_outlined,
                        ).copyWith(
                          fillColor: inputFill.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. 個人簡介 / 旅遊標語
                      _buildFieldLabel("個人簡介 / 旅伴名言"),
                      TextFormField(
                        controller: _bioController,
                        maxLines: 3,
                        style: const TextStyle(color: primaryNavy, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: "寫下一兩句你的旅遊風格，例如：熱愛戶外探險...",
                          hintStyle: const TextStyle(color: textMuted, fontSize: 14),
                          filled: true,
                          fillColor: inputFill,
                          contentPadding: const EdgeInsets.all(18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // 5. 儲存按鈕（膠囊樣式）
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  "儲存變更",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: primaryNavy,
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDeco({required String hint, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: primaryNavy, size: 20),
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}