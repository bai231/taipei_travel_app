import 'package:flutter/material.dart';

import '../../../services/location_service.dart';
import '../models/route_day.dart';
import '../models/route_itinerary.dart';
import 'guardian_debug_controller.dart';
import 'guardian_schedule_context.dart';

class GuardianDebugConsole extends StatelessWidget {
  final GuardianDebugController controller;
  final RouteItinerary itinerary;
  final bool isTracking;

  const GuardianDebugConsole({
    super.key,
    required this.controller,
    required this.itinerary,
    required this.isTracking,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final schedule = guardianScheduleContext(
          itinerary,
          controller.simulatedNow,
        );
        final day = schedule.day;
        final boarding = day == null ? null : _nextBoardingStop(day);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '保母測試控制台',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '關閉',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  '僅 Debug 版本可用；GPS、班次即時狀態與天氣使用模擬資料。交通備案會查真實 TDX，步行、汽車與 TDX 失敗時的大眾運輸備援會查真實 Google Maps（可能消耗額度）；提醒仍會發送標明「測試」的手機通知。',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('啟用模擬模式'),
                  subtitle: isTracking
                      ? const Text('追蹤已啟動；切換模式後請先停止，再重新開始行程。')
                      : const Text('啟用後回到結果頁按「開始行程」。'),
                  value: controller.enabled,
                  onChanged: controller.setEnabled,
                ),
                if (controller.enabled) ...[
                  const Divider(),
                  Text(
                    '模擬時間：${_dateTime(controller.simulatedNow)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _scheduleSummary(context, schedule),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: '切換行程日期'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: day?.day,
                        hint: const Text('目前不在行程日期，請選擇 Day'),
                        items: [
                          for (final item in itinerary.days)
                            DropdownMenuItem(
                              value: item.day,
                              child: Text(
                                'Day ${item.day}・${_date(item.date)}',
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          final chosen = itinerary.day(value);
                          controller.setTime(_suggestedTime(chosen));
                        },
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: day == null
                            ? null
                            : () => controller.setTime(_suggestedTime(day)),
                        child: const Text('跳到行程時段'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            controller.advance(const Duration(minutes: 1)),
                        child: const Text('+1 分鐘'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            controller.advance(const Duration(minutes: 5)),
                        child: const Text('+5 分鐘'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            controller.advance(const Duration(minutes: 15)),
                        child: const Text('+15 分鐘'),
                      ),
                    ],
                  ),
                  if (day != null && schedule.daySegments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '快速跳到原訂時段',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final segment in schedule.daySegments)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width - 64,
                            ),
                            child: ActionChip(
                              label: Text(
                                '${_hm(segment.start)} '
                                '${segment.phase == GuardianSchedulePhase.travel ? '交通' : '停留'}・${segment.label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () =>
                                  controller.setTime(segment.start),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '模擬位置：${controller.simulatedLocation.latitude.toStringAsFixed(5)}, '
                    '${controller.simulatedLocation.longitude.toStringAsFixed(5)}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: day == null
                            ? null
                            : () => controller.setLocation(
                                LocationPoint(
                                  latitude: day.origin.latitude,
                                  longitude: day.origin.longitude,
                                ),
                                label: day.origin.name,
                              ),
                        child: const Text('行程起點'),
                      ),
                      OutlinedButton(
                        onPressed: boarding == null
                            ? null
                            : () => controller.setLocation(
                                boarding.$1,
                                label: boarding.$2,
                              ),
                        child: const Text('下一個上車站'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<GuardianTransitScenario>(
                    initialValue: controller.transitScenario,
                    decoration: const InputDecoration(labelText: '班次即時情境（模擬）'),
                    items: [
                      for (final value in GuardianTransitScenario.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) controller.setTransitScenario(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<GuardianWeatherScenario>(
                    initialValue: controller.weatherScenario,
                    decoration: const InputDecoration(labelText: '天氣情境'),
                    items: [
                      for (final value in GuardianWeatherScenario.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) controller.setWeatherScenario(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: isTracking ? controller.emitLocation : null,
                    icon: const Icon(Icons.my_location),
                    label: Text(isTracking ? '送出模擬 GPS 更新' : '請先回結果頁開始行程'),
                  ),
                  if (controller.events.isNotEmpty) ...[
                    const Divider(height: 28),
                    const Text(
                      '最近事件',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final event in controller.events.take(8))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('• $event'),
                      ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scheduleSummary(
    BuildContext context,
    GuardianScheduleContext schedule,
  ) {
    final day = schedule.day;
    final current = schedule.current;
    final next = schedule.next;
    final status = switch (schedule.phase) {
      GuardianSchedulePhase.outsideTrip => '目前不在這份行程的日期或跨夜時段',
      GuardianSchedulePhase.emptyDay => '這一天沒有排定項目',
      GuardianSchedulePhase.beforeFirst => '尚未到這一天的第一項',
      GuardianSchedulePhase.travel =>
        '原定交通時段：${current!.label}（${current.detail ?? '交通'}）',
      GuardianSchedulePhase.visit => '原定停留時段：${current!.label}',
      GuardianSchedulePhase.gap => '目前是兩項之間的空白／等待時段',
      GuardianSchedulePhase.afterLast => '這一天的原定時段已結束',
    };
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              day == null ? '未對應到行程日期' : 'Day ${day.day}・${_date(day.date)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(status),
            if (current != null)
              Text(
                '原訂時間：${_dateTime(current.start)}–${_dateTime(current.end)}',
              ),
            if (next != null)
              Text(
                '下一項：Day ${next.day.day} '
                '${_dateTime(next.start)} ${next.label}',
              ),
            const SizedBox(height: 6),
            Text(
              '這是原排程的時間對照，不代表 GPS 已到達或項目已完成。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  (LocationPoint, String)? _nextBoardingStop(RouteDay day) {
    final choices = [
      for (final leg in day.travelLegs)
        for (final section in leg.route?.sections ?? const [])
          if (section.departureLatitude != null &&
              section.departureLongitude != null &&
              section.scheduledDeparture != null &&
              section.scheduledDeparture!.isAfter(controller.simulatedNow))
            (
              time: section.scheduledDeparture!,
              location: LocationPoint(
                latitude: section.departureLatitude!,
                longitude: section.departureLongitude!,
              ),
              label: section.departureTitle ?? '下一個上車站',
            ),
    ]..sort((a, b) => a.time.compareTo(b.time));
    return choices.isEmpty
        ? null
        : (choices.first.location, choices.first.label);
  }

  DateTime _suggestedTime(RouteDay day) {
    final departures = <DateTime>[
      for (final leg in day.travelLegs)
        for (final section in leg.route?.sections ?? const [])
          if (section.scheduledDeparture != null) section.scheduledDeparture!,
    ]..sort();
    if (departures.isNotEmpty) {
      return departures.first.subtract(const Duration(minutes: 10));
    }
    final firstStart = day.visits.isEmpty
        ? 9 * 60
        : day.visits.first.startMinutes;
    return DateTime(
      day.date.year,
      day.date.month,
      day.date.day,
    ).add(Duration(minutes: firstStart - 10));
  }
}

String _dateTime(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _date(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')}';

String _hm(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
