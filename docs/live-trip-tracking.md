# Live trip tracking

## What the traveller does

1. Open a generated itinerary on the travel day and select **開始行程**. This explicitly starts the current trip's guardian.
2. Grant location and notification permission when the phone asks.
3. The map shows the current GPS point and a teal line for the route already travelled.
4. On Android, the persistent **正在守護行程** notification indicates that location tracking is active even after switching apps, locking the screen, or leaving the result page. If the result page was closed, use **返回守護行程** in the app. Select **停止追蹤** when the trip is over.

## What the app does

- Reads a high-accuracy GPS point initially, then keeps points at least 20 metres apart. On Android the stream runs as a location foreground service started from the visible result page.
- Every 30 seconds, reevaluates the last known position against the current time even when the traveller has not moved. Clock checks do not create duplicate travelled-route points.
- The in-process active-trip session owns the tracker after the result page is closed. A risk found without a visible result page sends a phone notification; tapping it returns to the active result page to check for a candidate and, if one is available, preview the comparison. It never claims a candidate is ready before route queries succeed, or applies one in the background.
- Weather uses the guardian's latest position, including when the traveller is stationary. CWA requests are reserved no more often than once per hour across itineraries and app restarts on this installation. A rain, heat, or UV alert is sent only on an observed safe-to-risk transition; missing data does not clear a risk. The hourly check is best-effort while Android keeps this in-process guardian alive, not a precise background alarm.
- Keeps at most 500 recent points in memory; locations are not uploaded or stored in Supabase.
- Compares the current time and location with today's planned stops. It flags a delay of 15 minutes or more when the traveller has stayed past a visit's planned end, or cannot reasonably reach the next visit in time.
- Suppresses repeated ordinary delay alerts for 15 minutes; repeated bus/TRA risk alerts are also cooled down per affected connection. Debug simulation is an exception: test notifications are sent to the real OS notification channel with a **[測試]** title and separate IDs so they are visibly distinguishable.
- Before rebuilding, asks the traveller to confirm the last completed visit. Scheduled time or GPS proximity alone no longer causes the result page to silently treat a visit as completed.
- Prepares an alternative plan when a delay is detected or when the traveller selects **重排剩餘行程**. It first keeps the remaining visit order; if fixed times or the end of the day make that order infeasible it may offer to reorder unfinished visits. Opening-hour validation is owned by the teammate and is not yet part of this alternative planner.
- Re-queries every unfinished leg in sequence. Walking and driving use Google Routes; public transport tries TDX first, then Google Routes TRANSIT as a clearly labelled reference fallback. Each next query starts at the previous real arrival/visit-end time. It does not silently substitute the old straight-line estimate when both queries fail.
- Existing adjacent legs keep their selected travel mode. If reordering creates new adjacent places, the traveller must choose the mode used for those new legs.
- Shows the candidate to the traveller. The original itinerary remains unchanged unless the traveller explicitly selects **套用備案**; selecting **保留原行程** dismisses the candidate without replacing anything.

## Bus and TRA monitoring while guardian is active

- MaaS route sections retain their operator, service UUID, route number, station identifiers when present, stop coordinates, and full scheduled timestamps.
- The guardian checks only the next relevant bus or TRA boarding/transfer. The app evaluates location/time every 30 seconds, but TDX checks are spaced at least two minutes apart both while the result page is visible and while it is closed. Duplicate risk alerts are suppressed for 15 minutes.
- Bus monitoring reads TDX estimated arrival data and rejects stale observations. TRA monitoring resolves station names to station IDs, matches the planned departure to a daily timetable train number, then reads the train live board and matching operational alerts.
- A multi-transfer journey preserves completed sections. If an incoming section is expected to arrive too late for the next boarding buffer, only that outgoing connection and the unfinished remainder are treated as affected.
- For an ordinary boarding risk, alternatives start at the current GPS point and current time. For a missed intermediate transfer, they start at the incoming section's arrival station and expected ready time when those data are available.
- Up to three TDX options are shown, or one clearly labelled Google reference option if TDX fails. Selecting an option only opens a complete Before/After preview. The common planner then re-queries every later unfinished leg before the traveller can apply it. Google options do not carry TDX realtime identifiers and are not monitored as verified TDX services.
- Sections already taken within a multi-transfer leg remain attached to the rebuilt leg instead of being replaced by the outgoing alternative.
- If any continuation cannot be queried, the candidate is rejected and the original itinerary remains unchanged.

## Important scope

In Debug builds, the guardian test console shows which Day and originally scheduled travel or visit interval contains the simulated clock, the next item, and whether the time is a gap or outside the itinerary. It can jump to a chosen Day or scheduled segment. These labels are a **planned-time comparison**, not evidence that GPS has reached a stop or that a visit is complete.

When Debug simulation is enabled, GPS, clock, vehicle observations, weather and Google walking/driving routes remain simulated, but public-transport alternatives query the real TDX MaaS routing API and can then use Google TRANSIT if TDX fails. These queries consume provider quota and require an available route for the simulated departure date. A failed or empty TDX response never falls back to the former fixed 20-minute route. The simulated realtime-failure scenario affects vehicle observations, not MaaS route queries. Test risk notifications still use the Android notification channel with a visible test label.

Android tracking continues while the app process remains alive after the user switches apps, locks the phone, or closes the result page. It does **not** promise continued monitoring after Android kills the app process, the user force-stops it, or the phone restarts. The active trip, manually confirmed progress and pending comparison are not yet persisted for process-death recovery. iOS background location is not configured. There is no fixed departure reminder scheduler. Weather warnings are advisory notifications. High-speed rail and metro disruption feeds are outside this phase; bus monitoring currently uses ETA stop status, while TRA also checks operational alerts.
