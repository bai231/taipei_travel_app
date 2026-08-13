class TdxRoute {
  final int transfers;
  final int travelTime;
  final List<RouteSection> sections;

  TdxRoute({
    required this.transfers,
    required this.travelTime,
    required this.sections,
  });

  factory TdxRoute.fromJson(Map<String, dynamic> json) {
    var sectionsList = json['sections'] as List? ?? [];
    return TdxRoute(
      transfers: json['transfers'] ?? 0,
      travelTime: json['travel_time'] ?? json['duration'] ?? 0,
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
  });

  factory RouteSection.fromJson(Map<String, dynamic> json) {
    String type = (json['type'] ?? 'pedestrian').toString();

    // 1. 相容取得 transport 或 transit 內的資訊
    var transport = json['transport'] as Map<String, dynamic>? ?? 
                    json['transit']?['transport'] as Map<String, dynamic>?;

    String? line = transport?['shortName'] ?? 
                   transport?['name'] ?? 
                   transport?['number'] ?? 
                   transport?['category'];

    String? headsign = transport?['headsign'] ?? json['transit']?['headsign'];

    // 2. 提取起訖站點名稱
    String? depTitle = json['departure']?['place']?['name'] ?? json['departure']?['place']?['type'];
    String? arrTitle = json['arrival']?['place']?['name'] ?? json['arrival']?['place']?['type'];

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
    var stopsRaw = json['intermediateStops'] as List? ?? 
                json['transit']?['intermediateStops'] as List? ?? [];

    for (var s in stopsRaw) {
        if (s is Map) {
            // 修正:站名實際包在 departure.place.name 底下
            String? name = s['departure']?['place']?['name'] ?? s['place']?['name'] ?? s['name'];
            if (name != null && name.isNotEmpty) {
                stops.add(name);
            }
        } else if (s is String) {
            stops.add(s);
        }
    }

    // 花費秒數
    int durationSec = json['travelSummary']?['duration'] ?? json['travel_time'] ?? 0;

    return RouteSection(
      mode: type,
      lineName: line,
      destination: headsign,
      departureTitle: depTitle,
      arrivalTitle: arrTitle,
      departureTime: formatTime(json['departure']?['time']),
      arrivalTime: formatTime(json['arrival']?['time']),
      travelTime: durationSec,
      stopCount: stops.length,
      intermediateStops: stops,
    );
  }
}