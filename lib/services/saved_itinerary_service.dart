import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'itinerary_snapshot.dart';

abstract interface class SavedItineraryGateway {
  String? get currentUserId;

  Future<void> save({
    required String id,
    required String userId,
    required String title,
    required Map<String, dynamic> snapshot,
  });

  Future<List<Map<String, dynamic>>> list({
    int offset = 0,
    int limit = 20,
  });

  Future<Map<String, dynamic>> read(String id);
}

/// 雲端行程儲存服務實作
class SavedItineraryService implements SavedItineraryGateway {
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  final SupabaseClient client;

  SavedItineraryService(this.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<void> save({
    required String id,
    required String userId,
    required String title,
    required Map<String, dynamic> snapshot,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid != userId) {
      throw StateError('登入狀態已變更，請重新登入後儲存');
    }

    if (snapshot['schemaVersion'] != currentItinerarySnapshotVersion) {
      throw const FormatException('儲存必須使用最新行程版本');
    }

    // 驗證快照結構是否合法
    decodeItinerarySnapshot(snapshot);

    await client.from('saved_itineraries').upsert({
        'id': id,
        'user_id': userId,
        'title': title,
        'snapshot': snapshot,
      }, onConflict: 'user_id,id');

    if (currentUserId != userId) {
      throw StateError('帳號已變更，請在原帳號確認儲存結果');
    }
    changes.value++;
  }

  /// 撈取使用者行程清單（不載入龐大的 snapshot 欄位，加快效能）
  @override
  Future<List<Map<String, dynamic>>> list({
    int offset = 0,
    int limit = 20,
  }) async {
    if (offset < 0 || limit < 1 || limit > 100) {
      throw ArgumentError('無效分頁參數');
    }

    final uid = currentUserId;
    if (uid == null) throw StateError('請先登入');

    final rows = await client
        .from('saved_itineraries')
        .select('id, title, created_at, updated_at')
        .eq('user_id', uid)
        .order('updated_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);

    if (currentUserId != uid) throw StateError('帳號已變更');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// 依行程 ID 讀取完整快照資料
  @override
  Future<Map<String, dynamic>> read(String id) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('請先登入');

    final row = await client
        .from('saved_itineraries')
        .select('snapshot')
        .eq('user_id', uid)
        .eq('id', id)
        .single();

    if (currentUserId != uid) throw StateError('帳號已變更');
    final snapshot = Map<String, dynamic>.from(row['snapshot'] as Map);
    return decodeItinerarySnapshot(snapshot);
  }
}
