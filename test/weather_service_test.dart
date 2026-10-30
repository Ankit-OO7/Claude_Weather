import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minimal_weather/weather_service.dart';

void main() {
  test('returns weather for a place that is found', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'geocoding-api.open-meteo.com') {
        return http.Response(
          jsonEncode({
            'results': [
              {
                'name': 'Paris',
                'country': 'France',
                'latitude': 48.85,
                'longitude': 2.35,
              }
            ]
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'current': {'temperature_2m': 18.4, 'weather_code': 3, 'is_day': 1}
        }),
        200,
      );
    });

    final weather = await WeatherService(client: client).fetch('Paris');

    expect(weather.place, 'Paris, France');
    expect(weather.temperatureC, 18.4);
    expect(weather.code, 3);
    expect(weather.isDay, isTrue);
  });

  test('reports an unknown place', () async {
    final client = MockClient((_) async => http.Response('{}', 200));

    expect(
      () => WeatherService(client: client).fetch('Nowhereville'),
      throwsA(isA<WeatherException>()),
    );
  });

  test('rejects an empty search', () {
    expect(
      () => WeatherService(client: MockClient((_) async => http.Response('', 200)))
          .fetch('   '),
      throwsA(isA<WeatherException>()),
    );
  });

  test('turns network failures into a friendly error', () {
    final client = MockClient((_) async => throw http.ClientException('offline'));

    expect(
      () => WeatherService(client: client).fetch('Paris'),
      throwsA(isA<WeatherException>()),
    );
  });
}
