# Travel weather alerts

When the traveller taps **開始行程**, the initial overview uses today's first attraction rather than the traveller's GPS position. The app reads the city and district retained from the source database (`location`/`district`, the government catalog's Chinese fields, or OSM `addr:city`/`addr:district` tags); address parsing is only a legacy-data fallback. It requests only that city's 3-day and 1-week CWA location IDs, prefers an exact district match, and falls back within the same city when the district has no record. It calls CWA's aggregate `/v1/rest/datastore/F-D0047-093` endpoint and shows the forecast description, 3-hour rain probability, maximum temperature, UV index, and minimum temperature.

After the overview, live weather advisories continue to use the traveller's current GPS position. The initial attraction lookup does not change GPS tracking.

`WeatherAdvisoryService` checks the same township forecast at most once per hour and sends a normal device notification for:

- rain probability of 50% or more in the active forecast period;
- UV index of 8 or more; and
- apparent temperature of 33°C or more.

It intentionally does **not** create earthquake, flood, or other official emergency alerts.

## In-app indoor itinerary prompt

When a newly detected alert is for rain or high UV, the itinerary page asks whether the traveller wants an indoor alternative after the overview is dismissed. Choosing **查看室內建議** creates a `WeatherIndoorItineraryRequest` and calls the optional `onRequestIndoorItineraryAlternatives` callback. This is the handoff point for the AI recommendation feature; it does not alter the current itinerary by itself.

## CWA setup

Register with CWA and create an API authorization code, then run the app with it outside source control:

```bash
flutter run --dart-define=CWA_API_KEY=your-cwa-authorization-code
```

When starting with `--dart-define-from-file=config/secrets.json`, add `CWA_API_KEY` to that JSON file. See `config/secrets.example.json`; do not commit the real key.

The implementation uses CWA's `F-D0047-093` township forecast REST endpoint and asks only for the weather elements it needs. CWA documents that the data is refreshed every six hours, so this app-level hourly check avoids unnecessary requests.

## Closed-app notifications (production requirement)

The included monitor can notify while the app process remains alive (including when it is backgrounded). Mobile OSes may suspend it and it cannot run after the user force-quits the app. A reliable “app is not open” product must add a server-side delivery path:

1. Store a trip's opted-in notification device token and a coarse current/last-known location, with a clear consent screen and deletion policy.
2. Use a scheduled Supabase Edge Function (or equivalent) to query CWA, evaluate the same thresholds, de-duplicate alerts, and send FCM/APNs push notifications.
3. Keep push credentials and the CWA key in server secrets; never ship a production CWA key in the Flutter binary.

Android WorkManager and iOS BackgroundTasks can supplement refreshes but are opportunistic, so they are not substitutes for server push. Background GPS additionally needs separate platform permissions and a prominent user explanation.
