import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/algorithm/route_optimizer.dart';
import 'package:taipei_travel_app/models/tdx_route.dart';
import 'package:taipei_travel_app/services/itinerary_schedule_service.dart';

void main() {
  const scheduleService = ItineraryScheduleService();

  test('下一段出發時間包含上一站交通與停留時間', () {
    const firstStop = RouteStop(
      id: 'first',
      name: '第一站',
      latitude: 25,
      longitude: 121,
      stayDurationMinutes: 60,
    );
    const secondStop = RouteStop(
      id: 'second',
      name: '第二站',
      latitude: 25.1,
      longitude: 121.1,
      stayDurationMinutes: 90,
    );

    final firstVisit = scheduleService.scheduleVisit(
      departureMinutes: 9 * 60,
      travelMinutes: 20,
      destination: firstStop,
    );
    final secondVisit = scheduleService.scheduleVisit(
      departureMinutes: firstVisit.visitEndMinutes,
      travelMinutes: 30,
      destination: secondStop,
    );

    expect(firstVisit.arrivalMinutes, 9 * 60 + 20);
    expect(firstVisit.visitEndMinutes, 10 * 60 + 20);
    expect(secondVisit.departureMinutes, firstVisit.visitEndMinutes);
    expect(secondVisit.arrivalMinutes, 10 * 60 + 50);
    expect(secondVisit.visitEndMinutes, 12 * 60 + 20);
  });

  test('提早抵達時會等待景點開門再開始停留', () {
    const stop = RouteStop(
      id: 'night-market',
      name: '夜市',
      latitude: 25,
      longitude: 121,
      stayDurationMinutes: 60,
      earliestTimeMinutes: 18 * 60,
    );

    final visit = scheduleService.scheduleVisit(
      departureMinutes: 17 * 60,
      travelMinutes: 20,
      destination: stop,
    );

    expect(visit.arrivalMinutes, 17 * 60 + 20);
    expect(visit.waitingMinutes, 40);
    expect(visit.visitStartMinutes, 18 * 60);
    expect(visit.visitEndMinutes, 19 * 60);
  });

  test('只選擇指定出發時間之後且最早抵達的 TDX 班次', () {
    final requestedDeparture = DateTime(2026, 8, 15, 10);
    final missedRoute = TdxRoute(
      transfers: 0,
      travelTime: 20 * 60,
      startTime: DateTime(2026, 8, 15, 9, 50),
      endTime: DateTime(2026, 8, 15, 10, 10),
      sections: const [],
    );
    final laterRoute = TdxRoute(
      transfers: 0,
      travelTime: 25 * 60,
      startTime: DateTime(2026, 8, 15, 10, 10),
      endTime: DateTime(2026, 8, 15, 10, 35),
      sections: const [],
    );
    final earlierArrivalRoute = TdxRoute(
      transfers: 0,
      travelTime: 18 * 60,
      startTime: DateTime(2026, 8, 15, 10, 5),
      endTime: DateTime(2026, 8, 15, 10, 23),
      sections: const [],
    );

    final selected = scheduleService.selectRouteForDeparture(
      routes: [missedRoute, laterRoute, earlierArrivalRoute],
      requestedDeparture: requestedDeparture,
    );

    expect(selected, same(earlierArrivalRoute));
    expect(
      scheduleService.travelMinutesFromTdx(
        route: selected!,
        requestedDeparture: requestedDeparture,
      ),
      23,
    );
  });

  test('單次候選中同一路線多個班次會選擇可搭且最早抵達者', () {
    final requestedDeparture = DateTime(2026, 8, 15, 10);
    TdxRoute busAt(int departureMinute, int arrivalMinute) {
      return TdxRoute(
        transfers: 0,
        travelTime: (arrivalMinute - departureMinute) * 60,
        startTime: DateTime(2026, 8, 15, 10, departureMinute),
        endTime: DateTime(2026, 8, 15, 10, arrivalMinute),
        sections: [
          RouteSection(
            mode: 'bus',
            lineName: '藍1',
            travelTime: 20 * 60,
            stopCount: 0,
            intermediateStops: [],
          ),
        ],
      );
    }

    final missed = busAt(0, 20);
    final catchable = busAt(8, 28);
    final slower = busAt(5, 35);

    final selected = scheduleService.selectRouteForDeparture(
      routes: [missed, catchable, slower],
      requestedDeparture: DateTime(2026, 8, 15, 10, 3),
    );

    expect(selected, same(catchable));
  });
}
