import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/tdx_place_matcher.dart';

void main() {
  test('地址正規化可處理臺台與郵遞區號差異', () {
    expect(
      TdxPlaceMatcher.normalizeAddress('100 臺北市中正區中山南路21號'),
      TdxPlaceMatcher.normalizeAddress('台北市中正區中山南路21號'),
    );
  });

  test('名稱與地址完全相符時列為高可信匹配', () {
    final matcher = TdxPlaceMatcher([
      _attraction(
        id: 'A1',
        name: '中正紀念堂',
        city: '臺北市',
        town: '中正區',
        streetAddress: '中山南路21號',
      ),
      _attraction(
        id: 'A2',
        name: '中正公園',
        city: '基隆市',
        town: '信義區',
        streetAddress: '壽山路',
      ),
    ]);

    final result = matcher.match(
      const LocalPlaceRecord(
        id: '1',
        name: '中正紀念堂',
        address: '100台北市中正區中山南路21號',
        category: '紀念館',
        latitude: null,
        longitude: null,
        stayTime: null,
        openMinutes: null,
        closeMinutes: null,
      ),
    );

    expect(result.confidence, MatchConfidence.high);
    expect(result.attraction?.id, 'A1');
    expect(result.proposedStayTime, 120);
  });

  test('營運時間會選擇涵蓋服務日最多的時段', () {
    final result = TdxPlaceMatcher.deriveRepresentativeHours([
      const TdxServicePeriod(
        name: '平日',
        description: '',
        serviceDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        startTime: '09:00',
        endTime: '17:00',
        effectiveDate: '',
        expireDate: '',
      ),
      const TdxServicePeriod(
        name: '假日',
        description: '',
        serviceDays: ['Saturday', 'Sunday'],
        startTime: '10:00',
        endTime: '18:00',
        effectiveDate: '',
        expireDate: '',
      ),
    ]);

    expect(result?.openMinutes, 540);
    expect(result?.closeMinutes, 1020);
  });

  test('營運時間可解析 TDX 的 HH:mm:ss 格式', () {
    expect(TdxPlaceMatcher.parseTime('06:30:00'), 390);
    expect(TdxPlaceMatcher.parseTime('20:00:00'), 1200);
  });

  test('TDX 建議停留時間優先於類型規則', () {
    final matcher = TdxPlaceMatcher([
      _attraction(
        id: 'A1',
        name: '測試博物館',
        city: '臺北市',
        town: '中正區',
        streetAddress: '測試路1號',
        visitDuration: 75,
      ),
    ]);

    final result = matcher.match(
      const LocalPlaceRecord(
        id: '1',
        name: '測試博物館',
        address: '臺北市中正區測試路1號',
        category: '博物館',
        latitude: null,
        longitude: null,
        stayTime: null,
        openMinutes: null,
        closeMinutes: null,
      ),
    );

    expect(result.proposedStayTime, 75);
    expect(result.stayTimeSource, 'tdx_visit_duration');
  });

  test('同名同縣市但地址不同時必須人工審核', () {
    final matcher = TdxPlaceMatcher([
      _attraction(
        id: 'A1',
        name: '鎮瀾文化大樓',
        city: '臺中市',
        town: '大甲區',
        streetAddress: '和平路222號',
      ),
    ]);

    final result = matcher.match(
      const LocalPlaceRecord(
        id: '1',
        name: '鎮瀾文化大樓',
        address: '臺中市大甲區和平路223號',
        category: '文化設施',
        latitude: null,
        longitude: null,
        stayTime: null,
        openMinutes: null,
        closeMinutes: null,
      ),
    );

    expect(result.confidence, MatchConfidence.review);
    expect(result.canAutoUpdate, isFalse);
  });
}

TdxAttractionRecord _attraction({
  required String id,
  required String name,
  required String city,
  required String town,
  required String streetAddress,
  int? visitDuration,
}) {
  return TdxAttractionRecord(
    id: id,
    name: name,
    alternateNames: const [],
    city: city,
    town: town,
    streetAddress: streetAddress,
    latitude: 25.0345,
    longitude: 121.5219,
    visitDuration: visitDuration,
    serviceTimeInfo: '',
    attractionClasses: const [],
    servicePeriods: const [],
  );
}
