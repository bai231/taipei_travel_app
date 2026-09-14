import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/planner_favorites.dart';

/// Read-only adapter for the schema already referenced by FavoriteService and
/// UserDataService. RLS must independently enforce ownership on all tables.
class PlannerFavoritesService {
  final SupabaseClient client;
  PlannerFavoritesService(this.client);

  Future<PlannerFavorites> load() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('請先登入以查看收藏');
    const pageSize = 500;
    final favorites = <Map<String, dynamic>>[];
    for (var start = 0; ; start += pageSize) {
      final rows = await client
          .from('favorites')
          .select('place_id')
          .eq('user_id', userId)
          .order('place_id')
          .range(start, start + pageSize - 1);
      favorites.addAll(rows);
      if (rows.length < pageSize) break;
    }
    final folders = <PlannerFavoriteFolder>[];
    for (var start = 0; ; start += pageSize) {
      final rows = await client
          .from('folders')
          .select('id, title')
          .eq('user_id', userId)
          .order('id')
          .range(start, start + pageSize - 1);
      for (final row in rows) {
        final members = <String>{};
        for (var offset = 0; ; offset += pageSize) {
          final entries = await client
              .from('folder_places')
              .select('place_id')
              .eq('folder_id', row['id'])
              .order('place_id')
              .range(offset, offset + pageSize - 1);
          members.addAll(
            entries
                .where((e) => e['place_id'] != null)
                .map((e) => e['place_id'].toString()),
          );
          if (entries.length < pageSize) break;
        }
        folders.add(
          PlannerFavoriteFolder(
            id: row['id'].toString(),
            title: row['title']?.toString() ?? '未命名資料夾',
            placeIds: members,
          ),
        );
      }
      if (rows.length < pageSize) break;
    }
    if (client.auth.currentUser?.id != userId) {
      throw StateError('登入帳號已變更，請重新載入收藏');
    }
    return PlannerFavorites(
      placeIds: favorites
          .where((row) => row['place_id'] != null)
          .map((row) => row['place_id'].toString())
          .toSet(),
      folders: folders,
    );
  }
}
