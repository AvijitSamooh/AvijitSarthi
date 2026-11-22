import 'package:flutter_test/flutter_test.dart';

import 'package:avijit_sahyog/l10n/app_localizations.dart';

void main() {
  test('content-image descriptions are localized in all supported languages', () async {
    final expected = <String, Map<String, String>>{
      'en': {
        'beneficiary': 'Photo of Alice',
        'beneficiaryGallery': "Photo 2 in Alice's story",
        'organisationGallery': "Photo 1 in Seva Trust's gallery",
      },
      'hi': {
        'beneficiary': 'लाभार्थी Alice की तस्वीर',
        'beneficiaryGallery': 'लाभार्थी Alice की कहानी की तस्वीर 2',
        'organisationGallery': 'संस्था Seva Trust की गैलरी की तस्वीर 1',
      },
      'mr': {
        'beneficiary': 'Alice यांचे छायाचित्र',
        'beneficiaryGallery': 'Alice यांच्या कथेमधील छायाचित्र 2',
        'organisationGallery': 'Seva Trust यांच्या गॅलरीतील छायाचित्र 1',
      },
      'gu': {
        'beneficiary': 'Aliceનો ફોટો',
        'beneficiaryGallery': 'Aliceની વાર્તાનો ફોટો 2',
        'organisationGallery': 'Seva Trustની ગેલેરીનો ફોટો 1',
      },
    };

    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      final values = expected[locale.languageCode]!;

      expect(l10n.accessibilityBeneficiaryPhoto('Alice'), values['beneficiary']);
      expect(
        l10n.accessibilityBeneficiaryGalleryImage('Alice', 2),
        values['beneficiaryGallery'],
      );
      expect(
        l10n.accessibilityOrganisationGalleryImage('Seva Trust', 1),
        values['organisationGallery'],
      );
    }
  });
}
