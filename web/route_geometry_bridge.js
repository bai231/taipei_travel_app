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
    const request = {
      origin: {
        lat: input.origin.latitude,
        lng: input.origin.longitude,
      },
      destination: {
        lat: input.destination.latitude,
        lng: input.destination.longitude,
      },
      travelMode: 'TRANSIT',
      departureTime: usableDepartureTime(input.departureTime),
      fields: ['path', 'legs'],
      polylineQuality: 'HIGH_QUALITY',
      language: 'zh-TW',
      region: 'TW',
    };

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
})();
