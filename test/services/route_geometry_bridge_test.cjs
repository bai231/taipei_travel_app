const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function setup() {
  const requests = [];
  const context = {
    window: {},
    google: { maps: { importLibrary: async () => ({
      Route: { computeRoutes: async request => {
        requests.push(request);
        return { routes: [] };
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
  return { requests, query };
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
