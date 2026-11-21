import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:avijit_sahyog/core/network/api_client.dart';
import 'package:avijit_sahyog/features/community/data/city_repository.dart';

void main() {
  test('maps localized cities and city-scoped public activities', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/cities') {
        expect(request.url.queryParameters['language'], 'gu');
        return http.Response.bytes(utf8.encode(jsonEncode([
          {'id': 'pune', 'name': 'પુણે'},
        ])), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      expect(request.url.path, '/activities');
      expect(request.url.queryParameters['cityId'], 'pune');
      return http.Response(jsonEncode([
        {
          'id': 'activity-1',
          'cityId': 'pune',
          'title': 'Seva camp',
          'description': 'Community service',
          'startsAt': '2026-12-01T10:00:00.000Z',
        },
      ]), 200);
    });
    final api = ApiClient(client: client, baseUrl: 'https://api.example.com');
    final repository = CityRepository(api);

    final cities = await repository.getCities('gu');
    final activities = await repository.getPublicContent('activities', cityId: 'pune');

    expect(cities.single.name, 'પુણે');
    expect(activities.single.id, 'activity-1');
    expect(activities.single.startsAt, DateTime.utc(2026, 12, 1, 10));
    api.dispose();
  });
}
