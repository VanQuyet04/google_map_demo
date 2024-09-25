import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleMapsService {
  // Phương thức để lấy gợi ý địa điểm
  Future<List<String>> getPlaceSuggestions(String input) async {
    final String url =
        'https://nominatim.openstreetmap.org/search?q=$input&format=json&addressdetails=1&limit=5';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<String> suggestions = [];

      for (var item in data) {
        suggestions.add(item['display_name']);
      }

      return suggestions;
    } else {
      throw Exception('Failed to load suggestions');
    }
  }
}
