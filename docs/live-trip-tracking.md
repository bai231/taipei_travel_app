# Live trip tracking

## What the traveller does

1. Open a generated itinerary on the travel day and select **開始行程**.
2. Grant location and notification permission when the phone asks.
3. The map shows the current GPS point and a teal line for the route already travelled.
4. Select **停止追蹤** when the trip is over.

## What the app does

- Reads a high-accuracy GPS point initially, then keeps points at least 20 metres apart while the itinerary screen is active.
- Keeps at most 500 recent points in memory; locations are not uploaded or stored in Supabase.
- Compares the current time and location with today's planned stops. It flags a delay of 15 minutes or more when the traveller has stayed past a visit's planned end, or cannot reasonably reach the next visit in time.
- Shows one native phone notification at most every 15 minutes to avoid repeated alerts.
- Keeps completed visits unchanged. It makes the current GPS point the new start, orders only unfinished visits for today, recalculates their estimated arrival and visit times, and leaves all other days untouched. User-locked visits remain locked.

## Important scope

This first version monitors while the itinerary screen is open and the app is running. Continuous tracking after the app is closed would require a separately designed background-location mode, including additional Android foreground-service and iOS background-location declarations, battery policy, and an explicit user-facing privacy choice.
