import 'package:flutter_test/flutter_test.dart';

import 'package:avijit_sahyog/l10n/app_localizations.dart';

void main() {
  test('cause detail strings are translated for every supported locale', () async {
    final expected = <String, Map<String, String>>{
      'en': {
        'title': 'Cause Details',
        'support': 'Support this Cause',
        'reach': 'How your contribution reaches people',
        'children': 'Specific causes',
        'choose': 'Choose a specific cause below to support this area.',
        'empty': 'No active causes are available here right now.',
      },
      'hi': {
        'title': 'सेवा क्षेत्र विवरण',
        'support': 'इस सेवा क्षेत्र का समर्थन करें',
        'reach': 'आपका योगदान लोगों तक कैसे पहुँचता है',
        'children': 'विशिष्ट सेवा क्षेत्र',
        'choose': 'इस क्षेत्र का समर्थन करने के लिए नीचे दिया गया विशिष्ट सेवा क्षेत्र चुनें।',
        'empty': 'फिलहाल यहाँ कोई सक्रिय सेवा क्षेत्र उपलब्ध नहीं है।',
      },
      'mr': {
        'title': 'सेवा क्षेत्राचे तपशील',
        'support': 'या सेवा क्षेत्राला पाठिंबा द्या',
        'reach': 'तुमचे योगदान लोकांपर्यंत कसे पोहोचते',
        'children': 'विशिष्ट सेवा क्षेत्रे',
        'choose': 'या क्षेत्राला पाठिंबा देण्यासाठी खालील विशिष्ट सेवा क्षेत्र निवडा.',
        'empty': 'सध्या येथे कोणतेही सक्रिय सेवा क्षेत्र उपलब्ध नाही.',
      },
      'gu': {
        'title': 'સેવા ક્ષેત્રની વિગતો',
        'support': 'આ સેવા ક્ષેત્રને ટેકો આપો',
        'reach': 'તમારું યોગદાન લોકો સુધી કેવી રીતે પહોંચે છે',
        'children': 'વિશિષ્ટ સેવા ક્ષેત્રો',
        'choose': 'આ ક્ષેત્રને ટેકો આપવા માટે નીચેનું વિશિષ્ટ સેવા ક્ષેત્ર પસંદ કરો.',
        'empty': 'હાલમાં અહીં કોઈ સક્રિય સેવા ક્ષેત્ર ઉપલબ્ધ નથી.',
      },
    };

    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      final values = expected[locale.languageCode]!;

      expect(l10n.causeDetailsTitle, values['title']);
      expect(l10n.supportThisCause, values['support']);
      expect(l10n.causeReachTitle, values['reach']);
      expect(l10n.causeChildrenTitle, values['children']);
      expect(l10n.causeChooseChild, values['choose']);
      expect(l10n.causeNoActiveChildren, values['empty']);
      expect(l10n.causeReachDescription, isNotEmpty);
      expect(l10n.causeLoadError, isNotEmpty);
      expect(l10n.retry, isNotEmpty);
    }
  });
}
