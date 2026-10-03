const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function setup(result = { routes: [] }) {
  const requests = [];
  const context = {
    window: {},
    google: { maps: { importLibrary: async () => ({
      Route: { computeRoutes: async request => {
        requests.push(request);
        return result;
      } },
    }) } },
  };
  context.window.google = context.google;
  vm.runInNewContext(fs.readFileSync('web/route_geometry_bridge.js', 'utf8'), context);
  const query = (departureTime, travelMode = 'TRANSIT') =>
    context.window.computeTransitRouteGeometry(JSON.stringify({
      origin: { latitude: 25, longitude: 121 },
      destination: { latitude: 24, longitude: 120 },
      departureTime, travelMode,
    }));
  const queryInfo = (departureTime, travelMode = 'TRANSIT') =>
    context.window.computeGoogleRouteInformation(JSON.stringify({
      origin: { latitude: 25, longitude: 121 },
      destination: { latitude: 24, longitude: 120 },
      departureTime, travelMode,
    }));
  return { requests, query, queryInfo };
}

test('invalid and unsupported transit dates do not send a replacement query', async () => {
  const { requests, query } = setup();
  for (const date of [undefined, 'invalid', '2000-01-01', '2100-01-01']) {
    await assert.rejects(() => query(date));
  }
  assert.equal(requests.length, 0);
});

test('valid transit departure is retained exactly', async () => {
  const { requests, query } = setup();
  const date = new Date().toISOString();
  await query(date);
  assert.equal(requests[0].departureTime.toISOString(), date);
});

test('walking and traffic-unaware driving do not require a date', async () => {
  const { requests, query } = setup();
  await query(undefined, 'WALKING');
  await query(undefined, 'DRIVING');
  assert.equal(requests.length, 2);
  assert.equal(requests[1].routingPreference, 'TRAFFIC_UNAWARE');
});

test('transit fallback uses the requested departure and returns line details', async () => {
  const result = { routes: [{
    durationMillis: 1800000,
    distanceMeters: 5000,
    legs: [{ steps: [{
      travelMode: 'TRANSIT',
      staticDurationMillis: 900000,
      transitDetails: {
        departureTime: new Date('2030-01-01T01:10:00Z'),
        arrivalTime: new Date('2030-01-01T01:25:00Z'),
        departureStop: { name: '甲站' },
        arrivalStop: { name: '乙站' },
        transitLine: { shortName: '307', vehicle: { vehicleType: 'BUS' } },
      },
    }] }],
  }] };
  const { requests, queryInfo } = setup(result);
  const departure = new Date().toISOString();
  const response = JSON.parse(await queryInfo(departure));
  assert.equal(requests[0].departureTime.toISOString(), departure);
  assert.equal(response.steps[0].transitDetails.transitLine.nameShort, '307');
  assert.equal(response.steps[0].transitDetails.departureStop.name, '甲站');
});

test('invalid transit fallback date does not query current time instead', async () => {
  const { requests, queryInfo } = setup();
  await assert.rejects(() => queryInfo('2000-01-01'));
  assert.equal(requests.length, 0);
});
