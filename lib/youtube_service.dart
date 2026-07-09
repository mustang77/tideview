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

class VideoStats {
  final String views;
  final String likes;
  VideoStats(this.views, this.likes);
}

class Comment {
  final String author;
  final String authorImage;
  final String text;
  final String likeCount;
  Comment(this.author, this.authorImage, this.text, this.likeCount);
}

class YoutubeService {
  static Future<SearchResult> search(String query, {String? pageToken, bool shortOnly = false}) async {
    var u = "https://www.googleapis.com/youtube/v3/search"
        "?part=snippet&type=video&maxResults=24"
        "&q=${Uri.encodeComponent(query)}"
        "&key=$kYoutubeApiKey";
    if (shortOnly) u += "&videoDuration=short";
    if (pageToken != null && pageToken.isNotEmpty) u += "&pageToken=$pageToken";
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

  static String _fmt(String? raw) {
    if (raw == null) return "0";
    final n = int.tryParse(raw) ?? 0;
    if (n >= 1000000000) return "${(n / 1000000000).toStringAsFixed(1)}B";
    if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K";
    return n.toString();
  }

  static Future<VideoStats> stats(String videoId) async {
    final u = "https://www.googleapis.com/youtube/v3/videos"
        "?part=statistics&id=$videoId&key=$kYoutubeApiKey";
    final res = await http.get(Uri.parse(u));
    if (res.statusCode != 200) {
      throw Exception("API error ${res.statusCode}");
    }
    final data = jsonDecode(res.body);
    final items = (data["items"] as List?) ?? [];
    if (items.isEmpty) return VideoStats("0", "0");
    final st = items[0]["statistics"];
    return VideoStats(_fmt(st["viewCount"]), _fmt(st["likeCount"]));
  }

  static Future<List<Comment>> comments(String videoId) async {
    final u = "https://www.googleapis.com/youtube/v3/commentThreads"
        "?part=snippet&videoId=$videoId&maxResults=20&order=relevance&key=$kYoutubeApiKey";
    final res = await http.get(Uri.parse(u));
    if (res.statusCode != 200) {
      // Comments may be disabled; return empty rather than throwing.
      return [];
    }
    final data = jsonDecode(res.body);
    final items = (data["items"] as List?) ?? [];
    return items.map((it) {
      final c = it["snippet"]["topLevelComment"]["snippet"];
      return Comment(
        c["authorDisplayName"] ?? "",
        c["authorProfileImageUrl"] ?? "",
        c["textDisplay"] ?? "",
        _fmt(c["likeCount"]?.toString()),
      );
    }).toList();
  }
}
