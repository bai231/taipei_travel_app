Future<List<Map<String, dynamic>>> loadPlacesFromSupabase() async {
  final supabase = Supabase.instance.client;
  
  // 從 Supabase 的 places 資料表讀取前 20 筆景點
  final response = await supabase
      .from('places')
      .select('*')
      .limit(20);

  return List<Map<String, dynamic>>.from(response);
}
