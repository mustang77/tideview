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

class YoutubeService {
  static Future<List<Video>> search(String query) async {
    final url = Uri.parse(
      "https://www.googleapis.com/youtube/v3/search"
      "?part=snippet&type=video&maxResults=24"
      "&q=${Uri.encodeComponent(query)}"
      "&key=$kYoutubeApiKey",
    );
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception("API error ${res.statusCode}: ${res.body}");
    }
    final data = jsonDecode(res.body);
    final items = (data["items"] as List?) ?? [];
    return items
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
  }
}
