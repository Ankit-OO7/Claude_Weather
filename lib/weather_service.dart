import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Current conditions for one place.
class Weather {
  const Weather({
    required this.place,
    required this.temperatureC,
    required this.code,
    required this.isDay,
  });

  final String place;
  final double temperatureC;
  final int code;
  final bool isDay;
}

/// An error with a message that is safe to show to the person.
class WeatherException implements Exception {
  const WeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Looks a place up and fetches its current weather from Open-Meteo
/// (free, no API key).
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 10);

  Future<Weather> fetch(String query) async {
    final name = query.trim();
    if (name.isEmpty) {
      throw const WeatherException('Type a place to search.');
    }
    try {
      final geoRes = await _client
          .get(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': name,
        'count': '1',
        'language': 'en',
        'format': 'json',
      })).timeout(_timeout);
      if (geoRes.statusCode != 200) {
        throw const WeatherException('Location search failed. Try again.');
      }
      final geo = jsonDecode(geoRes.body) as Map<String, dynamic>;
      final results = geo['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        throw WeatherException('No place found for "$name".');
      }
      final found = results.first as Map<String, dynamic>;

      final weatherRes = await _client
          .get(Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${found['latitude']}',
        'longitude': '${found['longitude']}',
        'current': 'temperature_2m,weather_code,is_day',
      })).timeout(_timeout);
      if (weatherRes.statusCode != 200) {
        throw const WeatherException('Weather is unavailable. Try again.');
      }
      final body = jsonDecode(weatherRes.body) as Map<String, dynamic>;
      final current = body['current'] as Map<String, dynamic>;

      return Weather(
        place: _label(found),
        temperatureC: (current['temperature_2m'] as num).toDouble(),
        code: (current['weather_code'] as num).toInt(),
        isDay: (current['is_day'] as num) == 1,
      );
    } on WeatherException {
      rethrow;
    } on TimeoutException {
      throw const WeatherException('That took too long. Try again.');
    } on http.ClientException {
      throw const WeatherException('No connection. Check your internet.');
    } catch (_) {
      throw const WeatherException('Something went wrong. Try again.');
    }
  }

  static String _label(Map<String, dynamic> place) {
    final name = place['name'] as String? ?? 'Unknown';
    final country = place['country'] as String?;
    return country == null ? name : '$name, $country';
  }
}
