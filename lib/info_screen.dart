import "package:flutter/material.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:share_plus/share_plus.dart";
import "package:url_launcher/url_launcher.dart";

/// Information & Privacy: app info/FAQ, privacy policy, other apps, share —
/// the standard block store listings expect.
class InfoPrivacyScreen extends StatelessWidget {
  const InfoPrivacyScreen({super.key});

  static const _shareText = "Al-Quran — read, listen and search the Holy "
      "Quran with translations, prayer times, tahlil and daily duas.\n\n"
      "By World Cruise Academy — https://worldcruiseacademy.co.id\n"
      "Download: https://github.com/mustang77/tideview/releases/download/al-quran-latest/app-release.apk";

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: const Text("Information & Privacy",
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _BigTile(
            icon: Icons.info,
            color: scheme.primary,
            title: "App information",
            subtitle: "Info, tips & FAQ about this app",
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppInfoScreen())),
          ),
          _BigTile(
            icon: Icons.lock,
            color: scheme.primary,
            title: "Privacy policy",
            subtitle: "How this app handles your data",
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PrivacyPolicyScreen())),
          ),
          _BigTile(
            icon: Icons.apps,
            color: scheme.primary,
            title: "Other apps & website",
            subtitle: "World Cruise Academy — worldcruiseacademy.co.id",
            onTap: () => launchUrl(
                Uri.parse("https://worldcruiseacademy.co.id"),
                mode: LaunchMode.externalApplication),
          ),
          _BigTile(
            icon: Icons.share,
            color: scheme.primary,
            title: "Share this app",
            subtitle: "Tell a friend about this Quran app",
            onTap: () =>
                SharePlus.instance.share(ShareParams(text: _shareText)),
          ),
        ],
      ),
    );
  }
}

class _BigTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BigTile(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  static const _faq = [
    (
      "How do I listen to recitation?",
      "Open any surah and tap the play icon on an ayah, or the play button "
          "in the top bar to play the whole surah. Change the reciter in "
          "Profile > Reciter."
    ),
    (
      "How do I change the translation?",
      "Profile > Translation. You can also show a second translation "
          "underneath (e.g. English + Indonesian) and a Latin "
          "transliteration."
    ),
    (
      "Does the app work offline?",
      "The surah and juz index, Tahlil and Duas work offline. Verse text, "
          "audio and prayer times need an internet connection; surahs you "
          "have opened stay available during the same session."
    ),
    (
      "How do bookmarks work?",
      "Tap the bookmark icon on any ayah. Your bookmarks live in the "
          "Bookmarks tab — swipe one to remove it."
    ),
    (
      "How are prayer times calculated?",
      "Times come from the Aladhan API for the city you set on the Home "
          "screen. Tap the city name to change it."
    ),
    (
      "Where does the Quran text come from?",
      "Uthmani text, translations and search are provided by the AlQuran "
          "Cloud API; audio by the Islamic Network CDN; Tahlil text from "
          "NU Online."
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: const Text("App information",
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Image.asset("assets/branding/icon_fg.png", width: 120),
                const Text("Al-Quran",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) => Text(
                    snap.hasData
                        ? "Version ${snap.data!.version} (${snap.data!.buildNumber})"
                        : "",
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "Read, listen and search the Holy Quran — with "
                    "translations, transliteration, audio recitation, "
                    "prayer times, tahlil, daily duas and a tasbih counter.",
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text("TIPS & FAQ",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: scheme.primary)),
          const SizedBox(height: 4),
          for (final (q, a) in _faq)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              shape: const Border(),
              title: Text(q,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(a,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, height: 1.5)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    (
      "Data we collect",
      "None. The app has no user accounts, no registration, no analytics, "
          "no advertising, and no tracking of any kind. We do not collect, "
          "store, or share any personal information on our servers — we "
          "operate no servers."
    ),
    (
      "Data stored on your device only",
      "The app keeps your preferences locally on your device and nowhere "
          "else: your display name (optional), bookmarks and last-read "
          "position, translation/reciter/theme/text-size settings, "
          "prayer-times city, and tasbih counter value. Uninstalling the "
          "app permanently deletes all of this data."
    ),
    (
      "Network requests",
      "The app downloads content from third-party services: AlQuran Cloud "
          "API (Quran text, translations, search), Islamic Network CDN "
          "(recitation audio), Aladhan API (prayer times — the city name "
          "you type is sent to look up times), and Google Fonts. These are "
          "ordinary content downloads with no identifiers attached. Each "
          "service has its own privacy policy."
    ),
    (
      "Permissions",
      "The app requests only the Internet permission, used solely for the "
          "content above. It does not access your location, contacts, "
          "camera, microphone, or files."
    ),
    (
      "Children",
      "The app is suitable for all ages and collects no data from anyone, "
          "including children."
    ),
    (
      "Contact",
      "Questions about this policy: contact World Cruise Academy via "
          "https://worldcruiseacademy.co.id. The current policy is also "
          "published in the app repository as PRIVACY_POLICY.md."
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: const Text("Privacy policy",
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Effective date: 28 July 2026",
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          const Text(
            "Al-Quran is a Quran reading, listening and prayer-times app. "
            "Your privacy matters; this policy explains exactly what the "
            "app does with data.",
            style: TextStyle(height: 1.5),
          ),
          for (final (title, body) in _sections) ...[
            const SizedBox(height: 18),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: scheme.primary)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(height: 1.55)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
