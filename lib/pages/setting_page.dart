import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_screen.dart'; // 引入編輯個人資料頁面

import 'guide_overlay_screen.dart'; // 引入使用指南
import 'login_screen.dart';         // 引入登入頁面
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../services/language_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 🌟 1. 宣告 Supabase 驗證狀態監聽訂閱[cite: 1, 2]
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // 🌟 2. 監聽登入狀態改變：只要一登入或登出，自動刷新名片姓名與圖示[cite: 1, 2]
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {}); // 觸發畫面重繪，名片自動更新[cite: 1, 2]
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel(); // 🌟 3. 釋放資源，防止 memory leak[cite: 1, 2]
    super.dispose();
  }
  // 色彩配置（延續草圖風格色調）
  static Color get bgColor => AppColors.background;
  static Color get cardColor => AppColors.primary;
  static Color get textDark => AppColors.textPrimary;
  static Color get dividerColor => AppColors.primaryLight;

  // 開關與設定狀態變數
  bool _isNotificationEnabled = true;
  bool _isLoggedIn = false; // 模擬是否已登入

  // 彈出半透明磨砂選擇視窗（以語言選擇為例）
  void _showFrostedLanguageDialog() {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    builder: (dialogCtx) {
      // 🌟 關鍵：直接監聽全域 Locale 變更，語系一變，彈窗內部與勾勾保證立刻切換
      return ValueListenableBuilder<Locale>(
        valueListenable: LanguageService().currentLocale,
        builder: (context, locale, _) {
          final isEnglish = locale.languageCode == 'en';

          return Center(
            child: Material(
              type: MaterialType.transparency,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          LanguageService.tr(context, 'select_language'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontFamily: 'NotoSansTC',
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 繁體中文選項
                        // 找到 _showFrostedLanguageDialog 內部：
                        _buildLanguageOption(
                          '繁體中文',
                          !isEnglish,
                          dialogCtx,
                        ),
                        _buildLanguageOption(
                          'English',
                          isEnglish,
                          dialogCtx,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  Widget _buildLanguageOption(String lang, bool isSelected, BuildContext dialogCtx) {
    return InkWell(
      onTap: () {
        LanguageService().changeLanguage(lang);
        setState(() {});
        Future.delayed(const Duration(milliseconds: 200), () {
        if (dialogCtx.mounted) {
          Navigator.pop(dialogCtx);
        }
      });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? cardColor.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              lang,
              style: TextStyle(
                color: textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected) Icon(Icons.check_rounded, size: 18, color: textDark),
          ],
        ),
      ),
    );
  }

  // 彈出清除快取確認框
  void _showClearCacheDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(LanguageService.tr(context, 'clear_cache_title'), style: AppTypography.cardTitle(color: textDark)),
        content: Text(LanguageService.tr(context, 'clear_cache_content'), style: const TextStyle(color: Colors.black87, fontFamily: 'NotoSansTC')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LanguageService.tr(context, 'clear_cache_cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cardColor,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(LanguageService.tr(context, 'clear_cache_success'))),
              );
            },
            child: Text(LanguageService.tr(context, 'clear_cache_confirm'), style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontFamily: 'NotoSansTC')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. 頁面標題：⚙️ 設定
               Row(
                children: [
                  Icon(Icons.settings_outlined, size: 28, color: textDark),
                  SizedBox(width: 8),
                  Text(
                    LanguageService.tr(context, 'settings_title'),
                    style: AppTypography.headline(color: textDark),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. 個人帳號名片卡片 (Profile Card)
              _buildProfileHeaderCard(),

              const SizedBox(height: 24),

              // 4. 區塊一：個人帳號設置
              Text(
                LanguageService.tr(context, 'account_settings'),
                style: AppTypography.sectionTitle(color: textDark),
              ),
              const SizedBox(height: 12),
              _buildSettingsGroup([
                _buildSettingTile(
                  icon: Icons.person_outline_rounded,
                  title: LanguageService.tr(context, 'edit_profile'),
                  subtitle: LanguageService.tr(context, 'edit_profile_sub'),
                  onTap: () async{
                    final bool? updated = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                    // 儲存成功後若回傳 true，可重新刷新設定頁的名片資訊
                    if (updated == true && mounted) {
                      setState(() {});
                    }
                  },
                ),
                /*_buildSettingTile(
                  icon: Icons.explore_outlined,
                  title: LanguageService.tr(context, 'travel_pref'),
                  subtitle: LanguageService.tr(context, 'travel_pref_sub'),
                  onTap: () {
                    // TODO: 跳轉旅遊偏好選擇頁面
                  },
                ),*/
                _buildSwitchTile(
                  icon: Icons.notifications_none_rounded,
                  title: LanguageService.tr(context, 'notifications'),
                  subtitle: LanguageService.tr(context, 'notifications_sub') ,
                  value: _isNotificationEnabled,
                  onChanged: (val) => setState(() => _isNotificationEnabled = val),
                ),
              ]),

              _buildSectionDivider(),

              // 5. 區塊二：頁面與系統設定
              Text(
                LanguageService.tr(context, 'system_settings'),
                style: AppTypography.sectionTitle(color: textDark),
              ),
              const SizedBox(height: 12),
              _buildSettingsGroup([
                /*_buildSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  title: LanguageService.tr(context, 'dark_mode'),
                  subtitle: LanguageService.tr(context, 'dark_mode_sub'),
                  value: _isDarkMode,
                  onChanged: (val) => setState(() => _isDarkMode = val),
                ),*/
                _buildSettingTile(
                  icon: Icons.language_rounded,
                  title: LanguageService.tr(context, 'language_setting'),
                  trailingText: LanguageService().currentLanguageName,
                  onTap: _showFrostedLanguageDialog,
                ),
                _buildSettingTile(
                  icon: Icons.help_outline_rounded,
                  title: LanguageService.tr(context, 'review_guide'),
                  onTap: () => showUserGuide(context),
                ),
                _buildSettingTile(
                  icon: Icons.info_outline_rounded,
                  title: LanguageService.tr(context, 'about_app'),
                  trailingText: "v1.0.0",
                  onTap: () {
                    // TODO: 展示關於頁面或隱私條款
                  },
                ),
              ]),

              const SizedBox(height: 32),

              // 6. 底部登出 / 帳號切換按鈕
              if (_isLoggedIn)
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _isLoggedIn = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(LanguageService.tr(context, 'logged_out_safe'))),
                      );
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    label: Text(
                      LanguageService.tr(context, 'logout_account'),
                      style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 個人資料頂部卡片
  Widget _buildProfileHeaderCard() {
  // 1. 取得目前 Supabase 登入者物件
  final user = Supabase.instance.client.auth.currentUser;
  final bool isLoggedIn = user != null;

  // 2. 取得使用者名稱（優先讀取註冊/Google回傳的 username/full_name，沒有的話抓 Email 前綴）
  final String displayName = isLoggedIn
      ? (user.userMetadata?['username'] ?? 
         user.userMetadata?['full_name'] ?? 
         user.email?.split('@').first ?? 
         LanguageService.tr(context, 'traveler'))
      : LanguageService.tr(context, 'guest_traveler');

  // 3. 取得副標題（已登入顯示信箱，未登入顯示引導提示）
  final String displaySubtitle = isLoggedIn 
      ? (user.email ?? '') 
      : LanguageService.tr(context, 'login_sync_hint');

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primary, // 或你的 cardColor
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        // 圓形大頭貼
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          child: Icon(
            isLoggedIn ? Icons.person_rounded : Icons.person_outline_rounded,
            size: 36,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 14),

        // 姓名與信箱/提示
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName, // 👈 這裡會自動呈現登入者名字或「訪客旅人」
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displaySubtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),

        // 未登入時顯示「登入」按鈕，已登入時可顯示「登出」快捷按鈕
        if (!isLoggedIn)
          ElevatedButton(
            onPressed: () async{
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
              if (mounted) {
                setState(() {}); // 登入後刷新名片資訊
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(LanguageService.tr(context, 'login_action'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          )
        else
          IconButton(
            icon: Icon(Icons.logout_rounded, color: AppColors.textPrimary),
            tooltip: LanguageService.tr(context, 'logout_account'),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(LanguageService.tr(context, 'logged_out_safe_leaf')),
                    duration: Duration(seconds: 1),
                  ),
                );  
              }
            },
          ),
      ],
    ),
  );
}

  // 設定卡片群組包裹器
  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }

  // 一般設定選單項目
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: Icon(icon, color: textDark, size: 22),
      title: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark, fontFamily: 'NotoSansTC'),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 14, color: textDark.withValues(alpha: 0.7), fontFamily: 'NotoSansTC'))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: TextStyle(fontSize: 14, color: textDark.withValues(alpha: 0.7), fontFamily: 'NotoSansTC'),
            ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textDark),
        ],
      ),
    );
  }

  // 開關式設定項目 (Switch Tile)
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: Icon(icon, color: textDark, size: 22),
      title: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark, fontFamily: 'NotoSansTC'),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 14, color: textDark.withValues(alpha: 0.7), fontFamily: 'NotoSansTC'))
          : null,
      trailing: Switch.adaptive(
        value: value,
        activeColor: cardColor,
        onChanged: onChanged,
      ),
    );
  }

  // 居中淡色分隔線
  Widget _buildSectionDivider() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        height: 3,
        width: 180,
        decoration: BoxDecoration(
          color: dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
