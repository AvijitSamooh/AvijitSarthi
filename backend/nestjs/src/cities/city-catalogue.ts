export type CityLanguage = 'en' | 'hi' | 'mr' | 'gu';

export interface CityDefinition {
  id: string;
  names: Record<CityLanguage, string>;
}

/**
 * Canonical city identifiers are persisted in Activities, Accomplishments
 * and user city assignments. Display names are always resolved by locale.
 */
export const CITY_CATALOGUE: readonly CityDefinition[] = [
  { id: 'pune', names: { en: 'Pune', hi: 'पुणे', mr: 'पुणे', gu: 'પુણે' } },
  { id: 'mumbai', names: { en: 'Mumbai', hi: 'मुंबई', mr: 'मुंबई', gu: 'મુંબઈ' } },
  { id: 'nashik', names: { en: 'Nashik', hi: 'नाशिक', mr: 'नाशिक', gu: 'નાશિક' } },
  { id: 'nagpur', names: { en: 'Nagpur', hi: 'नागपुर', mr: 'नागपूर', gu: 'નાગપુર' } },
  { id: 'kolhapur', names: { en: 'Kolhapur', hi: 'कोल्हापुर', mr: 'कोल्हापूर', gu: 'કોલ્હાપુર' } },
  { id: 'new-delhi', names: { en: 'New Delhi', hi: 'नई दिल्ली', mr: 'नवी दिल्ली', gu: 'નવી દિલ્હી' } },
  { id: 'ahmedabad', names: { en: 'Ahmedabad', hi: 'अहमदाबाद', mr: 'अहमदाबाद', gu: 'અમદાવાદ' } },
  { id: 'surat', names: { en: 'Surat', hi: 'सूरत', mr: 'સુરત', gu: 'સુરત' } },
  { id: 'jaipur', names: { en: 'Jaipur', hi: 'जयपुर', mr: 'जयपूर', gu: 'જયપુર' } },
  { id: 'indore', names: { en: 'Indore', hi: 'इंदौर', mr: 'इंदूर', gu: 'ઇન્દોર' } },
  { id: 'bhopal', names: { en: 'Bhopal', hi: 'भोपाल', mr: 'भोपाळ', gu: 'ભોપાલ' } },
  { id: 'bengaluru', names: { en: 'Bengaluru', hi: 'बेंगलुरु', mr: 'बेंगळुरू', gu: 'બેંગલુરુ' } },
  { id: 'hyderabad', names: { en: 'Hyderabad', hi: 'हैदराबाद', mr: 'हैदराबाद', gu: 'હૈદરાબાદ' } },
  { id: 'chennai', names: { en: 'Chennai', hi: 'चेन्नई', mr: 'चेन्नई', gu: 'ચેન્નઈ' } },
  { id: 'kolkata', names: { en: 'Kolkata', hi: 'कोलकाता', mr: 'कोलकाता', gu: 'કોલકાતા' } },
];

export function normalizeCityLanguage(language?: string): CityLanguage {
  const code = (language ?? 'en').split('-')[0].toLowerCase();
  return code === 'hi' || code === 'mr' || code === 'gu' ? code : 'en';
}

export function cityCatalogueForLanguage(language?: string) {
  const locale = normalizeCityLanguage(language);
  return CITY_CATALOGUE.map(({ id, names }) => ({ id, name: names[locale] }));
}

export function isCityId(value: string): boolean {
  return CITY_CATALOGUE.some((city) => city.id === value);
}
