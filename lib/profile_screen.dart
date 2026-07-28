import "package:flutter/material.dart";

import "app_state.dart";
import "prayer_times_screen.dart";
import "quran_data.dart";

/// Profile tab: who you are, your reading stats, and all app settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context, AppState state) async {
    final controller = TextEditingController(text: state.userName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Your name"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "e.g. Ahmad"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel")),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Save")),
        ],
      ),
    );
    if (saved == true) state.setUserName(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final lastRead = state.lastRead;

    return Scaffold(
      appBar: AppBar(
          title: const Text("Profile",
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ---- user card ----
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B8A6B), Color(0xFF0B4437)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    state.userName.isEmpty
                        ? "؟"
                        : state.userName.characters.first.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B4437)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.userName.isEmpty
                            ? "Assalamu'alaikum"
                            : state.userName,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.userName.isEmpty
                            ? "Tap to set your name"
                            : "May your reading be blessed",
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _editName(context, state),
                  icon: const Icon(Icons.edit, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ---- stats ----
          Row(
            children: [
              const SizedBox(width: 16),
              _Stat(
                icon: Icons.bookmark,
                value: "${state.bookmarks.length}",
                label: "Bookmarks",
              ),
              const SizedBox(width: 10),
              _Stat(
                icon: Icons.auto_stories,
                value: lastRead == null
                    ? "—"
                    : surahByNumber(lastRead.surah).nameEnglish,
                label: lastRead == null
                    ? "Last read"
                    : "Ayah ${lastRead.ayah}",
              ),
              const SizedBox(width: 10),
              _Stat(
                icon: Icons.radio_button_checked,
                value: "${state.tasbihCount}",
                label: "Dhikr count",
              ),
              const SizedBox(width: 16),
            ],
          ),
          const Divider(height: 28),
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
          ListTile(
            leading: const Icon(Icons.g_translate),
            title: const Text("Second translation"),
            subtitle: Text(state.translation2Label),
            onTap: () => _pickTranslation2(context, state),
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

  void _pickTranslation2(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<String>(
          groupValue: state.translation2Id,
          onChanged: (id) {
            state.setTranslation2(id!);
            Navigator.of(sheetContext).pop();
          },
          child: ListView(
            shrinkWrap: true,
            children: [
              const RadioListTile<String>(title: Text("None"), value: ""),
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

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: scheme.primary, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
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
