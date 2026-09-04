import 'package:flutter/material.dart';

import '../../models/place.dart';
import '../../models/trip_request.dart';
import '../../models/visit_preferences.dart';

Future<VisitPreferences?> showVisitPreferencesDialog({
  required BuildContext context,
  required Place place,
  required TripRequest request,
  required VisitPreferences initial,
  int? day,
  MealType? suggestedMealType,
  List<String> information = const [],
}) => showDialog<VisitPreferences>(
  context: context,
  builder: (_) => VisitPreferencesDialog(
    place: place,
    request: request,
    initial: initial,
    day: day,
    suggestedMealType: suggestedMealType,
    information: information,
  ),
);

class VisitPreferencesDialog extends StatefulWidget {
  final Place place;
  final TripRequest request;
  final VisitPreferences initial;
  final int? day;
  final MealType? suggestedMealType;
  final List<String> information;

  const VisitPreferencesDialog({
    super.key,
    required this.place,
    required this.request,
    required this.initial,
    this.day,
    this.suggestedMealType,
    this.information = const [],
  });

  @override
  State<VisitPreferencesDialog> createState() => _VisitPreferencesDialogState();
}

class _VisitPreferencesDialogState extends State<VisitPreferencesDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _duration;
  late final TextEditingController _mealStart;
  late final TextEditingController _mealEnd;
  late final TextEditingController _checkInTime;
  late MealType _mealType;
  late int _checkInDay;
  late int _checkOutDay;
  late bool _usesDefaultDuration;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _mealType = initial.mealType;
    _usesDefaultDuration = initial.durationMinutes == null;
    _duration = TextEditingController(
      text: (initial.durationMinutes ?? _defaultDuration).toString(),
    );
    _mealStart = TextEditingController(
      text: _timeText(initial.mealWindowStart),
    );
    _mealEnd = TextEditingController(text: _timeText(initial.mealWindowEnd));
    _checkInTime = TextEditingController(
      text: _timeText(initial.hotelStay?.checkInFromMinutes),
    );
    _checkInDay = initial.hotelStay?.checkInDay ?? widget.day ?? 1;
    _checkOutDay =
        initial.hotelStay?.checkOutDay ??
        (widget.day == null ? widget.request.days + 1 : _checkInDay + 1);
  }

  @override
  void dispose() {
    for (final controller in [_duration, _mealStart, _mealEnd, _checkInTime]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHotel = widget.place.type == PlaceType.accommodation;
    return AlertDialog(
      title: Text('${widget.place.name}・安排設定'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.information.isNotEmpty) ...[
                  const Text(
                    '本次安排資訊',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...widget.information.map((text) => Text('• $text')),
                  const Divider(),
                ],
                if (widget.place.type == PlaceType.restaurant) ...[
                  DropdownButtonFormField<MealType>(
                    initialValue: _mealType,
                    decoration: const InputDecoration(labelText: '餐別'),
                    items: MealType.values
                        .map(
                          (meal) => DropdownMenuItem(
                            value: meal,
                            child: Text(meal.label),
                          ),
                        )
                        .toList(),
                    onChanged: (meal) => setState(() {
                      _mealType = meal!;
                      if (_usesDefaultDuration) {
                        _duration.text = _defaultDuration.toString();
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  const Text('以下是偏好的「用餐開始」時段，不代表實際營業時間。留空使用餐別預設；未指定餐別會提出建議。'),
                  _timeField(_mealStart, '偏好開始（HH:mm）', '例如 11:00'),
                  _timeField(
                    _mealEnd,
                    '偏好結束（HH:mm）',
                    '例如 14:00',
                    allowMidnight: true,
                  ),
                ],
                if (isHotel) ...[
                  const Text('系統會把飯店排在住宿日的最後一站；隔日第一段交通會從前一晚飯店出發。這不代表已完成訂房。'),
                  DropdownButtonFormField<int>(
                    initialValue: _checkInDay,
                    decoration: const InputDecoration(labelText: '住宿開始日期'),
                    items: List.generate(
                      widget.request.days,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(_dayText(index + 1)),
                      ),
                    ),
                    onChanged: (day) => setState(() => _checkInDay = day!),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _checkOutDay,
                    decoration: const InputDecoration(labelText: '住宿結束日期'),
                    items: List.generate(
                      widget.request.days,
                      (index) => DropdownMenuItem(
                        value: index + 2,
                        child: Text(_dayText(index + 2)),
                      ),
                    ),
                    onChanged: (day) => setState(() => _checkOutDay = day!),
                  ),
                  const SizedBox(height: 12),
                  const Text('最早抵達飯店時間未知時可留空，系統暫以 15:00 估算，仍須向飯店確認。'),
                  _timeField(_checkInTime, '最早抵達飯店（HH:mm）', '未知：暫估 15:00'),
                  const Text('飯店只出現在每天最後，不會在隔日早上重複顯示。'),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isHotel ? '住宿停留時間（分鐘）' : '停留／用餐時間（分鐘）',
                    helperText: _usesDefaultDuration
                        ? '系統預設，會直接用於排程；不滿意再修改'
                        : '使用者自訂，會優先用於排程',
                    suffixIcon: _usesDefaultDuration
                        ? null
                        : IconButton(
                            tooltip: '恢復系統預設',
                            onPressed: _resetDuration,
                            icon: const Icon(Icons.restore),
                          ),
                  ),
                  onChanged: (_) =>
                      setState(() => _usesDefaultDuration = false),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final minutes = int.tryParse(value.trim());
                    return minutes == null || minutes < 1 || minutes > 1440
                        ? '請輸入 1 至 1440 的整數'
                        : null;
                  },
                ),
                Text(
                  '系統預設：$_defaultDuration 分鐘；目前${_usesDefaultDuration ? '採用預設估算' : '採用使用者設定'}。',
                ),
                if (!isHotel)
                  Text(
                    widget.place.hasKnownOpeningHours
                        ? '營業時段：資料庫提供（每日例外未確認）。'
                        : '營業時間未知，不會當成已確認全天營業。',
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('套用設定')),
      ],
    );
  }

  Widget _timeField(
    TextEditingController controller,
    String label,
    String hint, {
    bool allowMidnight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (value) =>
            value == null ||
                value.trim().isEmpty ||
                _parseTime(value, allowMidnight: allowMidnight) != null
            ? null
            : '請輸入有效的 HH:mm 時間',
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final preferences = VisitPreferences(
      mealType: _mealType,
      durationMinutes: _usesDefaultDuration
          ? null
          : int.tryParse(_duration.text.trim()),
      mealWindowStart: _parseTime(_mealStart.text),
      mealWindowEnd: _parseTime(_mealEnd.text, allowMidnight: true),
      hotelStay: widget.place.type == PlaceType.accommodation
          ? HotelStay(
              checkInDay: _checkInDay,
              checkOutDay: _checkOutDay,
              checkInFromMinutes: _parseTime(_checkInTime.text),
            )
          : null,
    );
    final error = preferences.validationError(
      widget.place,
      widget.request.days,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, preferences);
  }

  int get _defaultDuration => VisitPreferences(mealType: _mealType).durationFor(
    widget.place,
    suggestedMealType: _mealType == MealType.unspecified
        ? widget.suggestedMealType
        : null,
  );

  void _resetDuration() {
    setState(() {
      _usesDefaultDuration = true;
      _duration.text = _defaultDuration.toString();
    });
  }

  int? _parseTime(String text, {bool allowMidnight = false}) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (allowMidnight && hour == 24 && minute == 0) return 1440;
    return hour < 24 && minute < 60 ? hour * 60 + minute : null;
  }

  String _timeText(int? minutes) => minutes == null
      ? ''
      : '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  String _dayText(int day) {
    final start = widget.request.startDate;
    final date = DateTime(start.year, start.month, start.day + day - 1);
    return 'Day $day（${date.month}/${date.day}${day > widget.request.days ? '・旅程結束隔日' : ''}）';
  }
}
