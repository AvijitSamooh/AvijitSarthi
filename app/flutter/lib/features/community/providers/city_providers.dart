import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../causes/providers/causes_providers.dart';
import '../data/city_repository.dart';
import '../models/city.dart';
import '../models/city_content.dart';

final cityRepositoryProvider = Provider<CityRepository>((ref) {
  return CityRepository(ref.watch(apiClientProvider));
});

final cityCatalogueProvider = FutureProvider.autoDispose.family<List<City>, String>(
  (ref, languageCode) => ref.watch(cityRepositoryProvider).getCities(languageCode),
);

final cityContentProvider = FutureProvider.autoDispose.family<
    List<CityContent>,
    ({String kind, String? cityId})>(
  (ref, query) => ref.watch(cityRepositoryProvider).getPublicContent(
        query.kind,
        cityId: query.cityId,
      ),
);
