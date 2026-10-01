# Travel weather alerts

When the traveller taps **開始行程**, the initial overview uses today's first attraction rather than the traveller's GPS position. The app reads the city and district retained from the source database (`location`/`district`, the government catalog's Chinese fields, or OSM `addr:city`/`addr:district` tags); address parsing is only a legacy-data fallback. It requests only that city's 3-day and 1-week CWA location IDs, prefers an exact district match, and falls back within the same city when the district has no record. It calls CWA's aggregate `/v1/rest/datastore/F-D0047-093` endpoint and shows the forecast description, 3-hour rain probability, maximum temperature, UV index, and minimum temperature.

After the overview, live weather advisories continue to use the traveller's current GPS position. The initial attraction lookup does not change GPS tracking.

When the traveller taps **開始行程**, the existing GPS tracker supplies position updates. The active guardian also rechecks its last known position every 30 seconds, so a stationary traveller does not need to move 20 metres to make the next weather check eligible. `WeatherAdvisoryService` checks CWA's township forecast for the closest forecast point and sends a normal device notification for:

- rain probability of 50% or more in the active forecast period;
- UV index of 8 or more; and
- apparent temperature of 33°C or more.

It intentionally does **not** create earthquake, flood, or other official emergency alerts.

## In-app indoor itinerary prompt

When a newly detected alert is for rain or high UV, the itinerary page asks whether the traveller wants an indoor alternative after the overview is dismissed. Choosing **查看室內建議** creates a `WeatherIndoorItineraryRequest` and calls the optional `onRequestIndoorItineraryAlternatives` callback. This is the handoff point for the AI recommendation feature; it does not alter the current itinerary by itself.

The app records the time **before** each attempted CWA request in local preferences. All active itineraries share this one-hour limiter; closing and reopening a trip or restarting the app does not reset it. Failed HTTP requests also consume the interval. This is an app-installation limit, not a server-enforced quota across different phones or devices. A check is attempted on the first eligible guardian update after the hour has elapsed; Android background execution is not guaranteed to occur at an exact minute.

For each weather risk, only the transition from below-threshold to above-threshold sends a notification. A successful observation below the threshold clears that risk, allowing a future above-threshold observation to notify again. Missing weather fields and failed queries do not count as an observed recovery. These alert states live for the current guardian session; they are not persisted across process death.


## CWA setup

Register with CWA and create an API authorization code, then run the app with it outside source control:

```bash
flutter run --dart-define=CWA_API_KEY=your-cwa-authorization-code
```

When starting with `--dart-define-from-file=config/secrets.json`, add `CWA_API_KEY` to that JSON file. See `config/secrets.example.json`; do not commit the real key.

The implementation uses CWA's `F-D0047-093` township forecast REST endpoint and asks only for the weather elements it needs. CWA documents that the data is refreshed every six hours, so this app-level hourly check avoids unnecessary requests.

## Combined weather behaviour

The initial attraction overview and GPS checks use the same weather service and persisted one-hour CWA request limiter. A same-city cache hit does not reserve another request. If the traveller moves outside the cached city before the hour expires, fresh weather data is unavailable until the next eligible request; GPS tracking continues. A weather failure must not block trip tracking. Indoor suggestions request alternatives only and do not apply changes without confirmation.

## Guardian lifetime and closed-app notifications

On Android, the user starts a location foreground service from the visible result page. Its persistent **正在守護行程** status notification is separate from weather alerts. Switching apps, locking the phone, or closing the result page does **not** stop the active guardian; selecting **停止追蹤** does. The app offers **返回守護行程** when its result page was closed. The in-process guardian cannot restore monitoring after Android kills the app process, the user force-stops it, or the phone restarts. The foreground location service uses high-accuracy GPS and a wake lock while active, so users should stop it when the trip ends.

A reliable product that must also notify after the app process is no longer running would need a server-side delivery path:

1. Store a trip's opted-in notification device token and a coarse current/last-known location, with a clear consent screen and deletion policy.
2. Use a scheduled Supabase Edge Function (or equivalent) to query CWA, evaluate the same thresholds, de-duplicate alerts, and send FCM/APNs push notifications.
3. Keep push credentials and the CWA key in server secrets; never ship a production CWA key in the Flutter binary.

Android WorkManager and iOS BackgroundTasks can supplement refreshes but are opportunistic, so they are not substitutes for server push. This project's current Android service is started while the app is visible; iOS background location is not configured.
