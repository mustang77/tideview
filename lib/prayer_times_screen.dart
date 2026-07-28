import "package:flutter/material.dart";

import "app_state.dart";
import "quran_service.dart";

/// Daily prayer times for a saved city, via the Aladhan API.
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  static const _mainPrayers = [
    ("Fajr", Icons.dark_mode_outlined),
    ("Sunrise", Icons.wb_twilight),
    ("Dhuhr", Icons.light_mode_outlined),
    ("Asr", Icons.wb_sunny_outlined),
    ("Maghrib", Icons.nights_stay_outlined),
    ("Isha", Icons.bedtime_outlined),
  ];

  final _service = PrayerTimesService();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

  PrayerTimesResult? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppScope.of(context);
      _cityController.text = state.prayerCity;
      _countryController.text = state.prayerCountry;
      if (state.prayerCity.isNotEmpty) _fetch();
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final city = _cityController.text.trim();
    final country = _countryController.text.trim();
    if (city.isEmpty) {
      setState(() => _error = "Enter a city name.");
      return;
    }
    FocusScope.of(context).unfocus();
    AppScope.of(context).setPrayerLocation(city, country);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.byCity(city, country);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't fetch prayer times. Check the city name "
            "and your connection.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _result;
    return Scaffold(
      appBar: AppBar(
          title: const Text("Prayer Times",
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _cityController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: "City", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _countryController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _fetch(),
                  decoration: const InputDecoration(
                      labelText: "Country", border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.schedule),
            label: Text(_loading ? "Loading…" : "Get prayer times"),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          if (result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(result.gregorianDate,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer)),
                  if (result.hijriDate.isNotEmpty)
                    Text(result.hijriDate,
                        style: TextStyle(
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.85))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final (name, icon) in _mainPrayers)
              if (result.timings[name] != null)
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerLow,
                  child: ListTile(
                    leading: Icon(icon, color: scheme.primary),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(
                      result.timings[name]!,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
