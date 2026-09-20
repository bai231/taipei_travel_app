class TravelPreferenceMapping {
  TravelPreferenceMapping._();

  /// Gemini 標準 category
  /// → Supabase places.category 實際值
  static const Map<String, Set<String>> databaseCategoriesByKey = {
    'nature': {
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
    },
    'religious': {'宗教廟宇類'},
    'cultural': {'文化類', '原住民文化類', '客家文化類'},
    'heritage': {'文化資產類'},
    'art_venue': {'藝文場館類', '藝術類'},
    'farm': {'休閒農業類'},

    /// 博物館主要使用 tag 判斷
    'museum': <String>{},

    'tourism_factory': {'觀光工廠類'},
    'general_recreation': {'遊憩類', '娛樂場館類', '觀光遊樂業類', '體育健身類'},
    'old_street_market': {'商圈商店類'},
    'other': {'其他'},
  };

  /// 部分 Gemini category 沒有精確的資料庫 category，
  /// 因此需要補充 tag 或搜尋關鍵字。
  static const Map<String, Set<String>> searchTermsByCategoryKey = {
    'museum': {'博物館'},
    'old_street_market': {'商圈購物', '老街', '市場'},
  };

  /// 手動偏好
  /// → Gemini 使用的標準 category key
  static const Map<String, Set<String>> manualCategoryKeys = {
    '美食': <String>{},
    '購物': {'old_street_market'},
    '文化': {'cultural'},
    '自然': {'nature'},
    '攝影': <String>{},
    '夜景': <String>{},
    '親子': <String>{},
    '歷史': {'heritage'},
    '藝術': {'art_venue'},
  };

  /// 手動偏好
  /// → Supabase places.tags 或搜尋關鍵字
  static const Map<String, Set<String>> manualTags = {
    '美食': {'美食'},
    '購物': {'商圈購物'},
    '文化': {'文化體驗'},
    '自然': {'自然景觀', '自然生態'},
    '攝影': {'拍照景點'},
    '夜景': {'夜景'},
    '親子': {'親子'},
    '歷史': {'歷史人文', '古蹟'},
    '藝術': {'藝文展覽'},
  };

  /// Gemini 的自由文字 tag
  /// → 資料庫實際使用的標準 tag
  ///
  /// 如果查不到別名，下一步的轉換器會保留原始文字，
  /// 例如「咖啡廳」仍可拿來搜尋景點名稱與描述。
  static const Map<String, Set<String>> tagAliases = {
    '爬山': {'登山健行'},
    '登山': {'登山健行'},
    '健行': {'登山健行'},
    '登山健行': {'登山健行'},
    '拍照': {'拍照景點'},
    '攝影': {'拍照景點'},
    '網美景點': {'拍照景點'},
    '拍照景點': {'拍照景點'},
    '購物': {'商圈購物'},
    '逛街': {'商圈購物'},
    '商圈': {'商圈購物'},
    '商圈購物': {'商圈購物'},
    '親子旅遊': {'親子'},
    '家庭旅遊': {'親子'},
    '親子': {'親子'},
    '歷史': {'歷史人文', '古蹟'},
    '歷史景點': {'歷史人文', '古蹟'},
    '古蹟': {'古蹟'},
    '博物館': {'博物館'},
    '藝術展覽': {'藝文展覽'},
    '藝文展覽': {'藝文展覽'},
    '自然': {'自然景觀'},
    '自然景觀': {'自然景觀'},
    '生態': {'自然生態'},
    '自然生態': {'自然生態'},
    '夜景': {'夜景'},
    '海景': {'海景'},
    '夕陽': {'夕陽'},
    '日出': {'日出'},
    '溫泉': {'溫泉'},
    '騎自行車': {'自行車'},
    '自行車': {'自行車'},
    '玩水': {'戲水'},
    '戲水': {'戲水'},
    '無障礙設施': {'無障礙'},
    '無障礙': {'無障礙'},
  };

  /// 當使用者排除整個 category 時，
  /// 同時需要排除或清除的相關 tag。
  static const Map<String, Set<String>> tagsCoveredByCategoryKey = {
    'nature': {'自然景觀', '自然生態'},
    'religious': {'宗教文化'},
    'cultural': {'文化體驗', '原住民文化', '客家文化', '產業文化'},
    'heritage': {'歷史人文', '古蹟'},
    'art_venue': {'藝文展覽'},
    'farm': {'休閒農業'},
    'museum': {'博物館'},
    'tourism_factory': {'觀光工廠'},
    'general_recreation': {'休閒遊憩', '休閒娛樂', '運動休閒', '主題樂園'},
    'old_street_market': {'商圈購物', '老街', '市場'},
    'other': <String>{},
  };
}
