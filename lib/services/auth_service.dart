import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. 註冊帳號（Supabase 後端 Trigger 會自動將 username 寫入 profiles 表）
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    await _supabase.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password.trim(),
      data: {'username': username.trim()}, // 👈 Trigger 會自動讀取並建立 profiles 紀錄，避免 duplicate key 衝突
    );
  }

  // 2. 一般信箱密碼登入
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _supabase.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );
  }

  // 3. 登出
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // 4. 取得當前登入者 User 物件
  User? get currentUser => _supabase.auth.currentUser;

  // 5. 抓取當前登入者的個人資料 (暱稱、大頭貼等)
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return data;
  }

  // 更新個人資料（暱稱、簡介、頭像網址等）
Future<void> updateProfile({
  required String username,
  String? bio,
  String? avatarUrl,
}) async {
  final user = _supabase.auth.currentUser;
  if (user == null) throw Exception("尚未登入帳號");

  final updateData = <String, dynamic>{
    'username': username.trim(),
    'updated_at': DateTime.now().toIso8601String(),
  };

  if (bio != null) updateData['bio'] = bio.trim();
  if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;

  await _supabase
      .from('profiles')
      .update(updateData)
      .eq('id', user.id);
  }
}

