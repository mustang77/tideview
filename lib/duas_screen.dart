import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:share_plus/share_plus.dart";

import "app_state.dart";

class Dua {
  final String title;
  final String arabic;
  final String latin;
  final String translation;
  const Dua(this.title, this.arabic, this.latin, this.translation);
}

/// Well-known daily supplications from the Quran and Sunnah.
const List<Dua> duas = [
  Dua(
    "Waking up",
    "الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ",
    "Alhamdu lillahil-ladhi ahyana ba'da ma amatana wa ilayhin-nushur",
    "Praise is to Allah who gave us life after death, and to Him is the resurrection.",
  ),
  Dua(
    "Before sleeping",
    "بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا",
    "Bismika Allahumma amutu wa ahya",
    "In Your name, O Allah, I die and I live.",
  ),
  Dua(
    "Before eating",
    "بِسْمِ اللَّهِ",
    "Bismillah",
    "In the name of Allah. (If forgotten at the start: Bismillahi awwalahu wa akhirahu.)",
  ),
  Dua(
    "After eating",
    "الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مُسْلِمِينَ",
    "Alhamdu lillahil-ladhi at'amana wa saqana wa ja'alana muslimin",
    "Praise is to Allah who fed us, gave us drink, and made us Muslims.",
  ),
  Dua(
    "Leaving home",
    "بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ",
    "Bismillahi tawakkaltu 'alallah, wa la hawla wa la quwwata illa billah",
    "In the name of Allah, I place my trust in Allah; there is no might nor power except with Allah.",
  ),
  Dua(
    "Entering the mosque",
    "اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ",
    "Allahummaftah li abwaba rahmatik",
    "O Allah, open for me the doors of Your mercy.",
  ),
  Dua(
    "Leaving the mosque",
    "اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ",
    "Allahumma inni as'aluka min fadlik",
    "O Allah, I ask You of Your bounty.",
  ),
  Dua(
    "Entering the restroom",
    "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْخُبُثِ وَالْخَبَائِثِ",
    "Allahumma inni a'udhu bika minal-khubuthi wal-khaba'ith",
    "O Allah, I seek refuge in You from male and female evil spirits.",
  ),
  Dua(
    "Leaving the restroom",
    "غُفْرَانَكَ",
    "Ghufranak",
    "I seek Your forgiveness.",
  ),
  Dua(
    "For parents",
    "رَبِّ اغْفِرْ لِي وَلِوَالِدَيَّ وَارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا",
    "Rabbighfir li wa liwalidayya warhamhuma kama rabbayani saghira",
    "My Lord, forgive me and my parents, and have mercy on them as they raised me when I was small.",
  ),
  Dua(
    "Good in both worlds",
    "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
    "Rabbana atina fid-dunya hasanah wa fil-akhirati hasanah wa qina 'adhaban-nar",
    "Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire. (Quran 2:201)",
  ),
  Dua(
    "Increase in knowledge",
    "رَبِّ زِدْنِي عِلْمًا",
    "Rabbi zidni 'ilma",
    "My Lord, increase me in knowledge. (Quran 20:114)",
  ),
  Dua(
    "In distress",
    "لَا إِلَٰهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ",
    "La ilaha illa anta subhanaka inni kuntu minaz-zalimin",
    "There is no god but You; glory be to You. Indeed, I have been of the wrongdoers. (Quran 21:87)",
  ),
  Dua(
    "When travelling",
    "سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَٰذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَىٰ رَبِّنَا لَمُنْقَلِبُونَ",
    "Subhanal-ladhi sakhkhara lana hadha wa ma kunna lahu muqrinin, wa inna ila rabbina lamunqalibun",
    "Glory to Him who has subjected this to us, and we could never have it by our own efforts. Surely to our Lord we are returning. (Quran 43:13-14)",
  ),
];

class DuasScreen extends StatelessWidget {
  const DuasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: const Text("Daily Duas",
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: duas.length,
        itemBuilder: (context, i) {
          final d = duas[i];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(d.title,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.share_outlined, size: 20),
                      onPressed: () => SharePlus.instance.share(ShareParams(
                          text:
                              "${d.title}\n\n${d.arabic}\n\n${d.latin}\n\n${d.translation}")),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  d.arabic,
                  style: GoogleFonts.amiri(
                      fontSize: state.arabicFontSize * 0.85, height: 1.9),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                Text(d.latin,
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13.5,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(d.translation,
                    style: const TextStyle(fontSize: 14.5, height: 1.4)),
              ],
            ),
          );
        },
      ),
    );
  }
}
