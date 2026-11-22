import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:avijit_sahyog/core/network/api_client.dart';

void main() {
  test('protected admin requests include the Firebase bearer token', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer firebase-token');
      return http.Response('[]', 200);
    });

    final api = ApiClient(
      client: client,
      baseUrl: 'https://api.example.com',
      authTokenProvider: () async => 'firebase-token',
    );

    await api.getAdminCauses();
    api.dispose();
  });

  test('protected application history requests include the Firebase bearer token', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/applications/mine');
      expect(request.headers['authorization'], 'Bearer firebase-token');
      return http.Response('[]', 200);
    });

    final api = ApiClient(
      client: client,
      baseUrl: 'https://api.example.com',
      authTokenProvider: () async => 'firebase-token',
    );

    await api.getMyHelpApplications();
    api.dispose();
  });
  test('protected application deletion requests include the Firebase bearer token', () async {
    final client = MockClient((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/applications/mine/app-1');
      expect(request.headers['authorization'], 'Bearer firebase-token');
      return http.Response('', 204);
    });

    final api = ApiClient(
      client: client,
      baseUrl: 'https://api.example.com',
      authTokenProvider: () async => 'firebase-token',
    );

    await api.deleteMyHelpApplication('app-1');
    api.dispose();
  });

  test('protected organisation deletion requests include the Firebase bearer token and return the deactivation result', () async {
    final client = MockClient((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/admin/organisations/org-1');
      expect(request.headers['authorization'], 'Bearer firebase-token');
      return http.Response(
        '{"id":"org-1","deleted":false,"deactivated":true}',
        200,
      );
    });

    final api = ApiClient(
      client: client,
      baseUrl: 'https://api.example.com',
      authTokenProvider: () async => 'firebase-token',
    );

    final result = await api.deleteAdminOrganisation('org-1');
    expect(result['deactivated'], true);
    api.dispose();
  });

  test('city content publish and delete operations use the scoped admin routes', () async {
    var calls = 0;
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer city-token');
      calls++;
      if (calls == 1) {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/admin/accomplishments/accomp-1');
        expect(request.body, '{"status":"PUBLISHED"}');
        return http.Response('{"id":"accomp-1","status":"PUBLISHED"}', 200);
      }
      expect(request.method, 'DELETE');
      expect(request.url.path, '/admin/accomplishments/accomp-1');
      return http.Response('{"id":"accomp-1","deleted":true}', 200);
    });
    final api = ApiClient(client: client, baseUrl: 'https://api.example.com',
      authTokenProvider: () async => 'city-token');
    final result = await api.updateAdminCityContent('accomplishments', 'accomp-1', {'status': 'PUBLISHED'});
    expect(result['status'], 'PUBLISHED');
    await api.deleteAdminCityContent('accomplishments', 'accomp-1');
    expect(calls, 2);
    api.dispose();
  });

  test('public city catalogue and city discovery use localized, scoped API requests', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (request.url.path == '/cities') {
        expect(request.url.queryParameters['language'], 'mr');
        return http.Response.bytes(utf8.encode('[{"id":"pune","name":"पुणे"}]'), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      expect(request.url.path, '/activities');
      expect(request.url.queryParameters['cityId'], 'pune');
      return http.Response('[{"id":"a1","cityId":"pune","title":"Camp","description":"Service","startsAt":"2026-12-01T10:00:00Z"}]', 200);
    });
    final api = ApiClient(client: client, baseUrl: 'https://api.example.com');
    final cities = await api.getCities('mr');
    final activities = await api.getPublicCityContent('activities', cityId: 'pune');
    expect(cities.single['name'], 'पुणे');
    expect(activities.single['id'], 'a1');
    expect(calls, 2);
    api.dispose();
  });

  test('city admin role updates submit explicit city IDs with the authenticated request', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/admin/users/user-1/role');
      expect(request.headers['authorization'], 'Bearer root-token');
      expect(jsonDecode(request.body), {
        'role': 'CITY_ADMIN',
        'cityIds': ['pune', 'mumbai'],
      });
      return http.Response('{"id":"user-1","role":"CITY_ADMIN","cityIds":["pune","mumbai"],"createdAt":"2026-09-14T00:00:00.000Z"}', 200);
    });
    final api = ApiClient(
      client: client,
      baseUrl: 'https://api.example.com',
      authTokenProvider: () async => 'root-token',
    );
    final result = await api.makeAdmin('user-1', role: 'CITY_ADMIN', cityIds: ['pune', 'mumbai']);
    expect(result['cityIds'], ['pune', 'mumbai']);
    api.dispose();
  });

  test('public content details and organisation references remain guest-readable', () async {
    var calls = 0;
    final client = MockClient((request) async {
      expect(request.headers.containsKey('authorization'), isFalse);
      calls++;
      if (request.url.path == '/accomplishments/award-1') {
        return http.Response('{"id":"award-1","cityId":"pune","title":"Award","description":"Achievement","achievedAt":"2026-11-15T00:00:00Z","organisationIds":["org-1"]}', 200);
      }
      expect(request.url.path, '/organisations');
      expect(request.url.queryParameters['language'], 'gu');
      return http.Response('[{"id":"org-1","slug":"seva-trust","name":"Seva Trust"}]', 200);
    });
    final api = ApiClient(client: client, baseUrl: 'https://api.example.com');
    final detail = await api.getPublicCityContentDetail('accomplishments', 'award-1');
    final organisations = await api.getPublicOrganisations('gu');
    expect(detail['organisationIds'], ['org-1']);
    expect(organisations.single['name'], 'Seva Trust');
    expect(calls, 2);
    api.dispose();
  });


  test('donor history and receipt requests require the Firebase bearer token', () async {
    var calls = 0;
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer donor-token');
      calls++;
      if (request.method == 'GET' && request.url.path == '/donations/mine') {
        return http.Response('[]', 200);
      }
      if (request.method == 'GET' && request.url.path == '/donations/mine/donation-1') {
        return http.Response('{"id":"donation-1","amount":"25.00","currency":"INR","status":"SUCCESS","createdAt":"2026-01-01T00:00:00.000Z","updatedAt":"2026-01-01T00:00:00.000Z","allocations":[]}', 200);
      }
      expect(request.method, 'POST');
      expect(request.url.path, '/donations/mine/donation-1/receipt');
      expect(jsonDecode(request.body), {'language': 'hi'});
      return http.Response('{"id":"donation-1","donationId":"donation-1","receiptNumber":"AS-2026-ABCDEF1234","amount":"25.00","currency":"INR","language":"hi","allocations":[],"donationCreatedAt":"2026-01-01T00:00:00.000Z","issuedAt":"2026-01-01T00:00:00.000Z"}', 201);
    });
    final api = ApiClient(
      client: client,
      baseUrl: 'https://api.example.com',
      authTokenProvider: () async => 'donor-token',
    );

    await expect(api.getMyDonations(), completion(isEmpty));
    await expect(api.getMyDonation('donation-1'), completion(containsPair('id', 'donation-1')));
    final receipt = await api.issueMyDonationReceipt('donation-1', languageCode: 'hi');
    expect(receipt['language'], 'hi');
    expect(calls, 3);
    api.dispose();
  });

  test('tracks in-flight mutations and clears after completion', () async {
    final completer = Completer<http.Response>();
    final client = MockClient((request) {
      expect(request.method, 'POST');
      expect(request.url.path, '/applications');
      return completer.future;
    });
    final api = ApiClient(client: client, baseUrl: 'https://api.example.com');

    final future = api.createHelpApplication({'type': 'EDUCATION'});
    await Future<void>.delayed(Duration.zero);
    expect(ApiClient.activeRequests.value, 1);

    completer.complete(http.Response('{"id":"application-1"}', 201));
    await future;
    expect(ApiClient.activeRequests.value, 0);
    api.dispose();
  });
}
