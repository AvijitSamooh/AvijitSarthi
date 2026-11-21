import '../../../core/network/api_client.dart';
import '../models/city.dart';
import '../models/city_content.dart';

class CityRepository {
  CityRepository(this._api);

  final ApiClient _api;

  Future<List<City>> getCities(String languageCode) async {
    final data = await _api.getCities(languageCode);
    return data.map(City.fromJson).toList(growable: false);
  }

  Future<List<CityContent>> getPublicContent(
    String kind, {
    String? cityId,
  }) async {
    final data = await _api.getPublicCityContent(kind, cityId: cityId);
    return data.map(CityContent.fromJson).toList(growable: false);
  }
}
