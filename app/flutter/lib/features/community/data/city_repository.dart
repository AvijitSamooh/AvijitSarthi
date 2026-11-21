import '../../../core/network/api_client.dart';
import '../../causes/models/organisation.dart';
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

  Future<CityContent> getPublicContentDetail(String kind, String id) async {
    return CityContent.fromJson(await _api.getPublicCityContentDetail(kind, id));
  }

  Future<List<Organisation>> getOrganisations(String languageCode) async {
    final data = await _api.getPublicOrganisations(languageCode);
    return data.map(Organisation.fromJson).toList(growable: false);
  }
}
