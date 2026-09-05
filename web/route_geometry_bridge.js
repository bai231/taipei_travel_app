(function () {
  function coordinate(point) {
    const latitude = typeof point.lat === 'function' ? point.lat() : point.lat;
    const longitude = typeof point.lng === 'function' ? point.lng() : point.lng;
    return { latitude, longitude };
  }

  function usableDepartureTime(value) {
    if (!value) return undefined;
    const departure = new Date(value);
    if (Number.isNaN(departure.getTime())) return undefined;
    const now = Date.now();
    const minimum = now - 7 * 24 * 60 * 60 * 1000;
    const maximum = now + 100 * 24 * 60 * 60 * 1000;
    return departure.getTime() >= minimum && departure.getTime() <= maximum
      ? departure
      : undefined;
  }

  window.computeTransitRouteGeometry = async function (requestJson) {
    if (!window.google || !google.maps || !google.maps.importLibrary) {
      throw new Error('Google Maps JavaScript API 尚未載入。');
    }

    const input = JSON.parse(requestJson);
    const { Route } = await google.maps.importLibrary('routes');
    const travelMode = input.travelMode || 'TRANSIT';
    const request = {
      origin: {
        lat: input.origin.latitude,
        lng: input.origin.longitude,
      },
      destination: {
        lat: input.destination.latitude,
        lng: input.destination.longitude,
      },
      travelMode,
      fields: ['path', 'legs'],
      polylineQuality: 'HIGH_QUALITY',
      language: 'zh-TW',
      region: 'TW',
    };
    if (travelMode === 'TRANSIT') {
      request.departureTime = usableDepartureTime(input.departureTime);
    } else if (travelMode === 'DRIVING') {
      request.routingPreference = 'TRAFFIC_UNAWARE';
    }

    const { routes } = await Route.computeRoutes(request);
    if (!routes || routes.length === 0) return '[]';

    const segments = [];
    for (const leg of routes[0].legs || []) {
      for (const step of leg.steps || []) {
        const points = (step.path || []).map(coordinate);
        if (points.length < 2) continue;
        const transitLine = step.transitDetails?.transitLine;
        segments.push({
          travelMode: step.travelMode || 'TRANSIT',
          vehicleType: transitLine?.vehicle?.vehicleType || null,
          lineName: transitLine?.shortName || transitLine?.name || null,
          lineColor: transitLine?.color || null,
          points,
        });
      }
    }
    return JSON.stringify(segments);
  };

  window.computeGoogleRouteInformation = async function (requestJson) {
    if (!window.google || !google.maps || !google.maps.importLibrary) {
      throw new Error('Google Maps JavaScript API 尚未載入。');
    }

    const input = JSON.parse(requestJson);
    const { Route } = await google.maps.importLibrary('routes');
    const request = {
      origin: {
        lat: input.origin.latitude,
        lng: input.origin.longitude,
      },
      destination: {
        lat: input.destination.latitude,
        lng: input.destination.longitude,
      },
      travelMode: input.travelMode,
      fields: ['durationMillis', 'distanceMeters'],
      language: 'zh-TW',
      region: 'TW',
    };
    if (input.travelMode === 'DRIVING') {
      request.routingPreference = 'TRAFFIC_UNAWARE';
    }

    const { routes } = await Route.computeRoutes(request);
    if (!routes || routes.length === 0) return 'null';
    const route = routes[0];
    return JSON.stringify({
      durationMillis: route.durationMillis || 0,
      distanceMeters: route.distanceMeters || null,
    });
  };
})();
