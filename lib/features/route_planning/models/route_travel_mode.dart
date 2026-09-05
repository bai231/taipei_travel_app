enum RouteTravelMode {
  transit,
  walking,
  driving;

  String get label => switch (this) {
    RouteTravelMode.transit => '大眾運輸',
    RouteTravelMode.walking => '純步行',
    RouteTravelMode.driving => '汽車',
  };

  String get sourceLabel => switch (this) {
    RouteTravelMode.transit => 'TDX',
    RouteTravelMode.walking || RouteTravelMode.driving => 'Google Maps',
  };

  String get googleTravelMode => switch (this) {
    RouteTravelMode.transit => 'TRANSIT',
    RouteTravelMode.walking => 'WALKING',
    RouteTravelMode.driving => 'DRIVING',
  };

  String get navigationMode => switch (this) {
    RouteTravelMode.transit => 'transit',
    RouteTravelMode.walking => 'walking',
    RouteTravelMode.driving => 'driving',
  };

  String get sectionMode => switch (this) {
    RouteTravelMode.transit => 'transit',
    RouteTravelMode.walking => 'walking',
    RouteTravelMode.driving => 'drive',
  };
}

typedef RouteLegKey = ({int day, String originId, String destinationId});

RouteLegKey routeLegKey({
  required int day,
  required String originId,
  required String destinationId,
}) => (day: day, originId: originId, destinationId: destinationId);
