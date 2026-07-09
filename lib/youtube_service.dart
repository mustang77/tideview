import "dart:convert";
import "package:http/http.dart" as http;
import "api_key.dart";

class Video {
  final String id;
  final String title;
  final String channel;
  final String thumbnail;
  Video({required this.id, required this.title, required this.channel, required this.thumbnail});
}

class SearchResult {
  final List<Video> videos;
  final String? nextPageToken;
  SearchResult(this.videos, this.nextPageToken);
}

class YoutubeService {
  static Future<SearchResult> search(String query, {String? pageToken}) async {
    var u = "https://www.googleapis.com/youtube/v3/search"
        "?part=snippet&type=video&maxResults=24"
        "&q=${Uri.encodeComponent(query)}"
        "&key=$kYoutubeApiKey";
    if (pageToken != null && pageToken.isNotEmpty) {
      u += "&pageToken=$pageToken";
    }
    final res = await http.get(Uri.parse(u));
    if (res.statusCode != 200) {
      throw Exception("API error ${res.statusCode}: ${res.body}");
    }
    final data = jsonDecode(res.body);
    final items = (data["items"] as List?) ?? [];
    final videos = items
        .where((it) => it["id"]?["videoId"] != null)
        .map((it) {
          final s = it["snippet"];
          final thumbs = s["thumbnails"];
          final t = (thumbs["medium"] ?? thumbs["default"])["url"];
          return Video(
            id: it["id"]["videoId"],
            title: s["title"] ?? "",
            channel: s["channelTitle"] ?? "",
            thumbnail: t ?? "",
          );
        })
        .toList();
    return SearchResult(videos, data["nextPageToken"] as String?);
  }
}
