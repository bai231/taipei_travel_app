import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'guide_overlay_screen.dart'; // 引入使用指南
import 'login_screen.dart';         // 引入登入頁面
import '../theme/app_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 色彩配置（延續草圖風格色調）
  static const Color bgColor = Color(0xFFC7DEC8);         // 水彩淺綠底色
  static const Color cardColor = Color(0xFF70B19B);       // 卡片綠色
  static const Color textDark = Color(0xFF1E3A2F);        // 深墨綠主要文字
  static const Color dividerColor = Color(0xFFA1C6B4);     // 分隔線淡綠色

  // 開關與設定狀態變數
  bool _isNotificationEnabled = true;
  bool _isDarkMode = false;
  String _currentLanguage = '繁體中文';
  bool _isLoggedIn = false; // 模擬是否已登入

  // 彈出半透明磨砂選擇視窗（以語言選擇為例）
  void _showFrostedLanguageDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) {
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '選擇語言',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLanguageOption('繁體中文'),
                    _buildLanguageOption('English'),
                    _buildLanguageOption('日本語'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String lang) {
    final bool isSelected = _currentLanguage == lang;
    return InkWell(
      onTap: () {
        setState(() => _currentLanguage = lang);
        Navigator.pop(context);
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
            if (isSelected) const Icon(Icons.check_rounded, size: 18, color: textDark),
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
        title: const Text('清除暫存資料', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
        content: const Text('將清除暫存的景點圖片與離線資料（約 48.5 MB），這不會影響你的收藏或自訂行程。', style: TextStyle(color: textDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
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
                const SnackBar(content: Text('已成功清除暫存檔案 🧹')),
              );
            },
            child: const Text('確認清除', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
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
              const Row(
                children: [
                  Icon(Icons.settings_outlined, size: 28, color: textDark),
                  SizedBox(width: 8),
                  Text(
                    "設定",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. 個人帳號名片卡片 (Profile Card)
              _buildProfileHeaderCard(),

              const SizedBox(height: 24),

              // 4. 區塊一：個人帳號設置
              const Text(
                "個人帳號設置",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
              ),
              const SizedBox(height: 12),
              _buildSettingsGroup([
                _buildSettingTile(
                  icon: Icons.person_outline_rounded,
                  title: "編輯個人資料",
                  subtitle: "修改頭像、暱稱與個人簡介",
                  onTap: () {
                    // TODO: 跳轉編輯個人資料頁面
                  },
                ),
                _buildSettingTile(
                  icon: Icons.explore_outlined,
                  title: "旅遊偏好設定",
                  subtitle: "海島放鬆、戶外探險、人文美食",
                  onTap: () {
                    // TODO: 跳轉旅遊偏好選擇頁面
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.notifications_none_rounded,
                  title: "行程與推播通知",
                  subtitle: "接收景點時間提醒與優惠資訊",
                  value: _isNotificationEnabled,
                  onChanged: (val) => setState(() => _isNotificationEnabled = val),
                ),
              ]),

              _buildSectionDivider(),

              // 5. 區塊二：頁面與系統設定
              const Text(
                "頁面與系統設定",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
              ),
              const SizedBox(height: 12),
              _buildSettingsGroup([
                _buildSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  title: "深色模式",
                  subtitle: "降低低光源環境下的視覺刺眼感",
                  value: _isDarkMode,
                  onChanged: (val) => setState(() => _isDarkMode = val),
                ),
                _buildSettingTile(
                  icon: Icons.language_rounded,
                  title: "語言設定",
                  trailingText: _currentLanguage,
                  onTap: _showFrostedLanguageDialog,
                ),
                _buildSettingTile(
                  icon: Icons.help_outline_rounded,
                  title: "重新檢視使用指南",
                  onTap: () => showUserGuide(context),
                ),
                _buildSettingTile(
                  icon: Icons.info_outline_rounded,
                  title: "關於陪伴旅伴 App",
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
                        const SnackBar(content: Text('已安全登出')),
                      );
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    label: const Text(
                      "登出帳號",
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
         '旅人')
      : '訪客旅人';

  // 3. 取得副標題（已登入顯示信箱，未登入顯示引導提示）
  final String displaySubtitle = isLoggedIn 
      ? (user.email ?? '') 
      : '登入以同步自訂行程與收藏';

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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text("登入", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          )
        else
          IconButton(
            icon: Icon(Icons.logout_rounded, color: AppColors.textPrimary),
            tooltip: '登出帳號',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已安全登出 🌿')),
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
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: textDark.withValues(alpha: 0.7)))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: TextStyle(fontSize: 13, color: textDark.withValues(alpha: 0.7)),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textDark),
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
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: textDark.withValues(alpha: 0.7)))
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