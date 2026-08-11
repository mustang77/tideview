import 'package:flutter_test/flutter_test.dart';
import 'package:tideview/screens/hiburan_ext/tv_screen.dart';

void main() {
  test('parser M3U iptv-org: nama, logo, kategori, referrer', () {
    // Cuplikan nyata dari playlist Indonesia iptv-org.
    const m3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="AFBTVKupang.id@SD" tvg-logo="https://i.postimg.cc/bJpyzPbB/afbtv.png" http-referrer="https://afbtvkupang.com/" group-title="General",AFBTV Kupang (1080p) [Not 24/7]
#EXTVLCOPT:http-referrer=https://afbtvkupang.com/
https://afbtv.siar.us/live/afbtv.m3u8
#EXTINF:-1 tvg-id="AhsanTV.id@SD" tvg-logo="https://i.imgur.com/dZdUbYd.png" group-title="Religious",Ahsan TV
https://5bf7b725107e5.streamlock.net/ahsantv/ahsantv/playlist.m3u8
#EXTINF:-1 tvg-id="X.id" group-title="News;General",Contoh Berita (720p)
https://contoh.id/live.m3u8
''';
    final ch = TvRepository.parseM3u(m3u);
    expect(ch.length, 3);
    expect(ch[0].name, 'AFBTV Kupang'); // (1080p) & [Not 24/7] dibuang
    expect(ch[0].logo, contains('afbtv.png'));
    expect(ch[0].category, 'General');
    expect(ch[0].referrer, 'https://afbtvkupang.com/');
    expect(ch[0].url, 'https://afbtv.siar.us/live/afbtv.m3u8');
    expect(ch[1].name, 'Ahsan TV');
    expect(ch[1].referrer, '');
    expect(ch[2].category, 'News'); // tag pertama dari "News;General"
    expect(
        TvRepository.categories(ch), ['Semua', 'General', 'Religious', 'News']);
  });
}
