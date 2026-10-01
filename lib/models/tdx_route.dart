class TdxRoute {
  final int transfers;
  final int travelTime;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? distanceMeters;
  final List<RouteSection> sections;

  TdxRoute({
    required this.transfers,
    required this.travelTime,
    this.startTime,
    this.endTime,
    this.distanceMeters,
    required this.sections,
  });

  factory TdxRoute.fromJson(Map<String, dynamic> json) {
    var sectionsList = json['sections'] as List? ?? [];
    return TdxRoute(
      transfers: json['transfers'] ?? 0,
      travelTime: json['travel_time'] ?? json['duration'] ?? 0,
      startTime: DateTime.tryParse(json['start_time']?.toString() ?? ''),
      endTime: DateTime.tryParse(json['end_time']?.toString() ?? ''),
      distanceMeters: (json['distance_meters'] as num?)?.toInt(),
      sections: sectionsList.map((s) => RouteSection.fromJson(s)).toList(),
    );
  }
}

class RouteSection {
  final String mode; // transit, pedestrian, drive, cycle
  final String? lineName; // 公車/車次號碼 (1816, 9023, 112)
  final String? destination; // 終點站/方向
  final String? departureTitle; // 起始站
  final String? arrivalTitle; // 到達站
  final String? departureTime;
  final String? arrivalTime;
  final int travelTime;
  final int stopCount;
  final List<String> intermediateStops; // 中途站點列表
  final String? operatorCode; // TRA、CityBus、HighwayBus 等營運系統代碼
  final String? agencyId;
  final String? serviceId; // MaaS transport.uuid，供後續班次解析使用
  final String? routeId;
  final String? city;
  final String? departureStopId;
  final String? arrivalStopId;
  final double? departureLatitude;
  final double? departureLongitude;
  final double? arrivalLatitude;
  final double? arrivalLongitude;
  final DateTime? scheduledDeparture;
  final DateTime? scheduledArrival;

  RouteSection({
    required this.mode,
    this.lineName,
    this.destination,
    this.departureTitle,
    this.arrivalTitle,
    this.departureTime,
    this.arrivalTime,
    required this.travelTime,
    required this.stopCount,
    required this.intermediateStops,
    this.operatorCode,
    this.agencyId,
    this.serviceId,
    this.routeId,
    this.city,
    this.departureStopId,
    this.arrivalStopId,
    this.departureLatitude,
    this.departureLongitude,
    this.arrivalLatitude,
    this.arrivalLongitude,
    this.scheduledDeparture,
    this.scheduledArrival,
  });

  factory RouteSection.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? 'pedestrian').toString();

    // 1. 相容取得 transport 或 transit 內的資訊
    var transport =
        json['transport'] as Map<String, dynamic>? ??
        json['transit']?['transport'] as Map<String, dynamic>?;

    String? line =
        transport?['shortName'] ??
        transport?['name'] ??
        transport?['number'] ??
        transport?['category'];

    String? headsign = transport?['headsign'] ?? json['transit']?['headsign'];
    final mode = _resolveMode(type: type, transport: transport);

    // 2. 提取起訖站點名稱
    String? depTitle =
        json['departure']?['place']?['name'] ??
        json['departure']?['place']?['type'];
    String? arrTitle =
        json['arrival']?['place']?['name'] ??
        json['arrival']?['place']?['type'];

    // 3. 時間格式化 (HH:mm)
    String? formatTime(String? raw) {
      if (raw == null) return null;
      if (raw.contains('T')) {
        final parts = raw.split('T');
        if (parts.length > 1) return parts[1].substring(0, 5);
      }
      return raw.length >= 5 ? raw.substring(0, 5) : raw;
    }

    // 4. 解析中間經過站點 (支援多種 JSON 階層結構)
    List<String> stops = [];
    var stopsRaw =
        json['intermediateStops'] as List? ??
        json['transit']?['intermediateStops'] as List? ??
        [];

    for (var s in stopsRaw) {
      if (s is Map) {
        // 修正:站名實際包在 departure.place.name 底下
        String? name =
            s['departure']?['place']?['name'] ??
            s['place']?['name'] ??
            s['name'];
        if (name != null && name.isNotEmpty) {
          stops.add(name);
        }
      } else if (s is String) {
        stops.add(s);
      }
    }

    // 花費秒數
    int durationSec =
        json['travelSummary']?['duration'] ?? json['travel_time'] ?? 0;

    final departure = json['departure'] as Map?;
    final arrival = json['arrival'] as Map?;
    final departurePlace = departure?['place'] as Map?;
    final arrivalPlace = arrival?['place'] as Map?;
    final departureLocation = departurePlace?['location'] as Map?;
    final arrivalLocation = arrivalPlace?['location'] as Map?;
    final agency = json['agency'] as Map?;
    String? firstText(Iterable<Object?> values) {
      for (final value in values) {
        final text = value?.toString().trim();
        if (text != null && text.isNotEmpty) return text;
      }
      return null;
    }

    double? number(Object? value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    final rawDepartureTime = departure?['time']?.toString();
    final rawArrivalTime = arrival?['time']?.toString();

    return RouteSection(
      mode: mode,
      lineName: line,
      destination: headsign,
      departureTitle: depTitle,
      arrivalTitle: arrTitle,
      departureTime: formatTime(json['departure']?['time']),
      arrivalTime: formatTime(json['arrival']?['time']),
      travelTime: durationSec,
      stopCount: stops.length,
      intermediateStops: stops,
      operatorCode: firstText([
        agency?['agency_id'],
        agency?['id'],
        transport?['category'],
        transport?['mode'],
      ]),
      agencyId: firstText([agency?['agency_id'], agency?['id']]),
      serviceId: firstText([
        transport?['uuid'],
        transport?['trip_id'],
        transport?['tripId'],
      ]),
      routeId: firstText([
        transport?['route_uid'],
        transport?['routeUID'],
        transport?['number'],
        transport?['shortName'],
      ]),
      city: firstText([transport?['city']]),
      departureStopId: firstText([
        departurePlace?['stop_uid'],
        departurePlace?['stopUID'],
        departurePlace?['station_id'],
        departurePlace?['stationID'],
        departurePlace?['id'],
      ]),
      arrivalStopId: firstText([
        arrivalPlace?['stop_uid'],
        arrivalPlace?['stopUID'],
        arrivalPlace?['station_id'],
        arrivalPlace?['stationID'],
        arrivalPlace?['id'],
      ]),
      departureLatitude: number(
        departureLocation?['lat'] ?? departureLocation?['latitude'],
      ),
      departureLongitude: number(
        departureLocation?['lng'] ?? departureLocation?['longitude'],
      ),
      arrivalLatitude: number(
        arrivalLocation?['lat'] ?? arrivalLocation?['latitude'],
      ),
      arrivalLongitude: number(
        arrivalLocation?['lng'] ?? arrivalLocation?['longitude'],
      ),
      scheduledDeparture: _parseServiceDateTime(rawDepartureTime),
      scheduledArrival: _parseServiceDateTime(rawArrivalTime),
    );
  }

  static String _resolveMode({
    required String type,
    required Map<String, dynamic>? transport,
  }) {
    final normalizedType = type.toLowerCase();
    if (_containsAny(normalizedType, const ['pedestrian', 'walking', 'walk'])) {
      return 'pedestrian';
    }

    final description = [
      transport?['mode'],
      transport?['category'],
      transport?['name'],
      transport?['shortName'],
      type,
    ].whereType<Object>().join(' ').toLowerCase();

    if (_containsAny(description, const [
      'high_speed',
      'high speed',
      'highspeed',
      'thsr',
      '高鐵',
    ])) {
      return 'high_speed_rail';
    }
    if (_containsAny(description, const [
      'rail',
      'train',
      'railway',
      'tra',
      '台鐵',
      '臺鐵',
    ])) {
      return 'train';
    }
    if (_containsAny(description, const [
      'metro',
      'subway',
      'mrt',
      'rapid transit',
      '捷運',
      '輕軌',
    ])) {
      return 'metro';
    }
    if (_containsAny(description, const ['bus', 'coach', '公車', '客運'])) {
      return 'bus';
    }
    if (_containsAny(description, const ['ferry', 'ship', '渡輪'])) {
      return 'ferry';
    }
    if (_containsAny(description, const ['cable', 'gondola', '纜車'])) {
      return 'cable_car';
    }
    return normalizedType;
  }

  static bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }
}

DateTime? _parseServiceDateTime(String? value) {
  if (value == null || value.isEmpty) return null;
  // TDX MaaS timestamps describe Taiwan service wall-clock time. Keeping the
  // wall-clock portion avoids host timezone conversion changing 10:05 to 02:05
  // in tests or non-Taiwan build environments.
  final wallClock = value.length >= 19 ? value.substring(0, 19) : value;
  return DateTime.tryParse(wallClock);
}
