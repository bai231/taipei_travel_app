import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. 註冊帳號並同步寫入 profiles 資料表
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    // A. 在 Supabase Auth 建立帳號
    final AuthResponse res = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    final user = res.user;
    if (user == null) {
      throw const AuthException('註冊失敗，未取得使用者資訊');
    }

    // B. 將使用者暱稱與資訊寫入 profiles 資料表
    await _supabase.from('profiles').insert({
      'id': user.id,
      'email': email,
      'username': username,
      'avatar_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150', // 預設大頭貼
    });
  }

  // 2. 一般信箱密碼登入
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // 3. 登出
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // 4. 取得當前登入者 User 物件
  User? get currentUser => _supabase.auth.currentUser;
}