import { CitiesController } from './cities.controller';
import { cityCatalogueForLanguage, isCityId, normalizeCityLanguage } from './city-catalogue';

describe('CitiesController', () => {
  const controller = new CitiesController();

  it.each([
    ['en', 'Pune'],
    ['hi', 'पुणे'],
    ['mr', 'पुणे'],
    ['gu', 'પુણે'],
  ])('returns the %s city labels with stable IDs', (language, expectedName) => {
    const cities = controller.list(language);
    expect(cities[0]).toEqual({ id: 'pune', name: expectedName });
    expect(cities.some((city) => city.id === 'new-delhi')).toBe(true);
  });

  it('falls back to English for unsupported and regional locale codes', () => {
    expect(normalizeCityLanguage('fr')).toBe('en');
    expect(normalizeCityLanguage('hi-IN')).toBe('hi');
    expect(cityCatalogueForLanguage('fr')[0]).toEqual({ id: 'pune', name: 'Pune' });
  });

  it('validates canonical city identifiers', () => {
    expect(isCityId('pune')).toBe(true);
    expect(isCityId('new-delhi')).toBe(true);
    expect(isCityId('Pune')).toBe(false);
    expect(isCityId('unknown-city')).toBe(false);
  });
});
