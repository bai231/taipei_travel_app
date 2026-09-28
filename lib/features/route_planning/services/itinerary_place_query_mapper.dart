class ItineraryMappedPlaceQuery {
  final String originalQuery;
  final Set<String> categories;
  final Set<String> tags;
  final Set<String> locations;

  const ItineraryMappedPlaceQuery({
    required this.originalQuery,
    this.categories = const {},
    this.tags = const {},
    this.locations = const {},
  });

  bool get hasStructuredCriteria {
    return categories.isNotEmpty || tags.isNotEmpty || locations.isNotEmpty;
  }
}

class ItineraryPlaceQueryMapper {
  const ItineraryPlaceQueryMapper();

  ItineraryMappedPlaceQuery map(String query) {
    final normalized = _normalize(query);
    final categories = <String>{};
    final tags = <String>{};
    final locations = <String>{};

    for (final entry in _locationAliases.entries) {
      if (entry.value.any(normalized.contains)) {
        locations.add(entry.key);
      }
    }

    for (final rule in _rules) {
      final matched = rule.triggers.any(normalized.contains);

      if (!matched) {
        continue;
      }

      categories.addAll(rule.categories);
      tags.addAll(rule.tags);
    }

    return ItineraryMappedPlaceQuery(
      originalQuery: query.trim(),
      categories: Set.unmodifiable(categories),
      tags: Set.unmodifiable(tags),
      locations: Set.unmodifiable(locations),
    );
  }

  String _normalize(String value) {
    return value
        .trim()
        .replaceAll('臺', '台')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');
  }

  static const List<_PlaceQueryRule> _rules = [
    // 自然類
    _PlaceQueryRule(
      triggers: ['自然景點', '自然風景', '大自然', '山林景點', '自然類'],
      categories: [
        '自然風景類',
        '國家自然公園類',
        '國家風景區類',
        '生態類',
        '水域環境類',
        '森林遊樂區類',
        '國家公園類',
        '平地森林園區類',
        '都會公園類',
        '公園綠地類',
      ],
      tags: ['自然景觀', '自然生態', '戶外景點', '森林', '風景區', '公園綠地'],
    ),

    // 歷史文化
    _PlaceQueryRule(
      triggers: ['文化景點', '歷史景點', '歷史文化', '歷史人文', '古蹟', '人文景點'],
      categories: ['文化類', '文化資產類', '藝文場館類', '藝術類'],
      tags: ['歷史人文', '文化體驗', '古蹟', '博物館', '藝文展覽'],
    ),

    // 宗教廟宇
    _PlaceQueryRule(
      triggers: ['宗教景點', '寺廟', '廟宇', '拜拜'],
      categories: ['宗教廟宇類'],
      tags: ['宗教文化', '古蹟'],
    ),

    // 藝術展覽
    _PlaceQueryRule(
      triggers: ['藝術景點', '藝文景點', '展覽', '美術館', '藝文活動'],
      categories: ['藝文場館類', '藝術類'],
      tags: ['藝文展覽', '室內景點'],
    ),

    // 博物館
    _PlaceQueryRule(
      triggers: ['博物館', '文物館', '紀念館'],
      categories: ['文化類', '文化資產類', '藝文場館類'],
      tags: ['博物館', '室內景點', '歷史人文'],
    ),

    // 室內
    _PlaceQueryRule(
      triggers: ['室內景點', '室內活動', '不會曬太陽', '躲雨', '下雨天', '雨天景點'],
      tags: ['室內景點', '博物館', '藝文展覽'],
    ),

    // 戶外
    _PlaceQueryRule(
      triggers: ['戶外景點', '戶外活動', '走走', '踏青'],
      tags: ['戶外景點', '自然景觀', '公園綠地'],
    ),

    // 登山
    _PlaceQueryRule(
      triggers: ['爬山', '登山', '健行', '步道'],
      categories: ['自然風景類', '森林遊樂區類', '國家公園類'],
      tags: ['登山健行', '森林', '自然景觀'],
    ),

    // 親子
    _PlaceQueryRule(
      triggers: ['親子景點', '帶小孩', '兒童景點', '適合小孩', '家庭景點'],
      tags: ['親子', '休閒遊憩'],
    ),

    // 購物商圈
    _PlaceQueryRule(
      triggers: ['購物', '逛街', '商圈', '市集', '夜市'],
      categories: ['商圈商店類'],
      tags: ['商圈購物', '美食', '休閒娛樂'],
    ),

    // 美食
    _PlaceQueryRule(
      triggers: ['美食景點', '吃東西', '小吃', '在地美食', '美食'],
      tags: ['美食'],
    ),

    // 觀光工廠
    _PlaceQueryRule(
      triggers: ['觀光工廠', '工廠參觀', '產業體驗'],
      categories: ['觀光工廠類'],
      tags: ['觀光工廠', '產業文化', '親子'],
    ),

    // 休閒農業
    _PlaceQueryRule(
      triggers: ['農場', '農業體驗', '休閒農業', '採果'],
      categories: ['休閒農業類'],
      tags: ['休閒農業', '親子', '戶外景點'],
    ),

    // 公園
    _PlaceQueryRule(
      triggers: ['公園', '綠地', '草地'],
      categories: ['都會公園類', '公園綠地類'],
      tags: ['公園綠地', '草原', '戶外景點'],
    ),

    // 水域
    _PlaceQueryRule(
      triggers: ['海邊', '海景', '湖泊', '溪流', '水域景點', '玩水'],
      categories: ['水域環境類', '自然風景類'],
      tags: ['海景', '湖泊', '溪流', '水域景觀', '戲水'],
    ),

    // 溫泉
    _PlaceQueryRule(triggers: ['溫泉', '泡湯'], categories: ['溫泉類'], tags: ['溫泉']),

    // 遊樂園
    _PlaceQueryRule(
      triggers: ['遊樂園', '主題樂園', '遊樂設施'],
      categories: ['觀光遊樂業類', '娛樂場館類'],
      tags: ['主題樂園', '休閒娛樂', '親子'],
    ),

    // 拍照
    _PlaceQueryRule(
      triggers: ['拍照景點', '打卡景點', '網美景點', '適合拍照'],
      tags: ['拍照景點', '特色景點'],
    ),

    // 夜景
    _PlaceQueryRule(triggers: ['夜景', '晚上看風景'], tags: ['夜景']),

    // 免費
    _PlaceQueryRule(triggers: ['免費景點', '不用門票', '不花錢'], tags: ['免費景點']),

    // 無障礙
    _PlaceQueryRule(triggers: ['無障礙', '輪椅', '行動不便'], tags: ['無障礙']),
  ];

  static const Map<String, List<String>> _locationAliases = {
    '台北市': ['台北市', '台北'],
    '新北市': ['新北市', '新北'],
    '桃園市': ['桃園市', '桃園'],
    '台中市': ['台中市', '台中'],
    '台南市': ['台南市', '台南'],
    '高雄市': ['高雄市', '高雄'],
    '基隆市': ['基隆市', '基隆'],
    '新竹市': ['新竹市'],
    '嘉義市': ['嘉義市'],
    '新竹縣': ['新竹縣'],
    '苗栗縣': ['苗栗縣', '苗栗'],
    '彰化縣': ['彰化縣', '彰化'],
    '南投縣': ['南投縣', '南投'],
    '雲林縣': ['雲林縣', '雲林'],
    '嘉義縣': ['嘉義縣'],
    '屏東縣': ['屏東縣', '屏東'],
    '宜蘭縣': ['宜蘭縣', '宜蘭'],
    '花蓮縣': ['花蓮縣', '花蓮'],
    '台東縣': ['台東縣', '台東'],
    '澎湖縣': ['澎湖縣', '澎湖'],
    '金門縣': ['金門縣', '金門'],
    '連江縣': ['連江縣', '連江', '馬祖'],
  };
}

class _PlaceQueryRule {
  final List<String> triggers;
  final List<String> categories;
  final List<String> tags;

  const _PlaceQueryRule({
    required this.triggers,
    this.categories = const [],
    this.tags = const [],
  });
}
