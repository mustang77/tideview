import "package:flutter/material.dart";

import "app_state.dart";
import "prayer_times_screen.dart";
import "quran_data.dart";

/// Settings and extras: translation, reciter, text options, theme,
/// prayer times.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
          title:
              const Text("More", style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: Icon(Icons.schedule, color: scheme.primary),
            title: const Text("Prayer times",
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Daily salah times for your city"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PrayerTimesScreen())),
          ),
          const Divider(),
          _SectionLabel("Reading"),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text("Translation"),
            subtitle: Text(state.translationLabel),
            onTap: () => _pickTranslation(context, state),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.abc),
            title: const Text("Show transliteration"),
            subtitle: const Text("Latin pronunciation under the Arabic"),
            value: state.showTransliteration,
            onChanged: state.setShowTransliteration,
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text("Arabic text size"),
            subtitle: Slider(
              min: 20,
              max: 44,
              divisions: 12,
              value: state.arabicFontSize.clamp(20, 44),
              label: state.arabicFontSize.round().toString(),
              onChanged: state.setArabicFontSize,
            ),
          ),
          const Divider(),
          _SectionLabel("Audio"),
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: const Text("Reciter"),
            subtitle: Text(state.reciterName),
            onTap: () => _pickReciter(context, state),
          ),
          const Divider(),
          _SectionLabel("Appearance"),
          RadioGroup<ThemeMode>(
            groupValue: state.themeMode,
            onChanged: (m) => state.setThemeMode(m!),
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  secondary: Icon(Icons.brightness_auto),
                  title: Text("System theme"),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  secondary: Icon(Icons.light_mode),
                  title: Text("Light"),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  secondary: Icon(Icons.dark_mode),
                  title: Text("Dark"),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("About"),
            subtitle: Text(
                "Quran text, translations and audio are provided by the "
                "AlQuran Cloud API and the Islamic Network CDN. Prayer times "
                "by the Aladhan API."),
          ),
        ],
      ),
    );
  }

  void _pickTranslation(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<String>(
          groupValue: state.translationId,
          onChanged: (id) {
            state.setTranslation(id!);
            Navigator.of(sheetContext).pop();
          },
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final e in translationEditions)
                RadioListTile<String>(title: Text(e.label), value: e.id),
            ],
          ),
        ),
      ),
    );
  }

  void _pickReciter(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<String>(
          groupValue: state.reciterId,
          onChanged: (id) {
            state.setReciter(id!);
            Navigator.of(sheetContext).pop();
          },
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final r in reciters)
                RadioListTile<String>(title: Text(r.name), value: r.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
