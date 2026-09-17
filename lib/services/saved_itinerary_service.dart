import 'package:supabase_flutter/supabase_flutter.dart';
import 'itinerary_snapshot.dart';

abstract interface class SavedItineraryGateway {
  String? get currentUserId;
  Future<void> save({
    required String id,
    required String userId,
    required String title,
    required Map<String, dynamic> snapshot,
  });
}

/// Requires the reviewed saved_itineraries schema. Does not write legacy trips.
class SavedItineraryService implements SavedItineraryGateway {
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
    if (currentUserId == null || currentUserId != userId) {
      throw StateError('登入狀態已變更，請重新登入後儲存');
    }
    if (snapshot['schemaVersion'] != currentItinerarySnapshotVersion) {
      throw const FormatException('儲存必須使用最新行程版本');
    }
    decodeItinerarySnapshot(snapshot);
    await client.from('saved_itineraries').upsert({
      'id': id,
      'user_id': userId,
      'title': title,
      'snapshot': snapshot,
    }, onConflict: 'user_id,id');
    if (currentUserId != userId) throw StateError('帳號已變更，請在原帳號確認儲存結果');
  }

  /// Summary pagination for the teammate's personal page (no large JSON field).
  Future<List<Map<String, dynamic>>> list({
    int offset = 0,
    int limit = 20,
  }) async {
    if (offset < 0 || limit < 1 || limit > 100) throw ArgumentError('無效分頁');
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
    return rows;
  }

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
