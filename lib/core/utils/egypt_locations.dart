/// Address picker data for patient registration: Egypt's governorates, and for
/// Alexandria its districts and the areas people actually name. English only.
/// Mirrors web's `lib/egypt-locations.ts`.
///
/// The picked values only help typing: they are joined into the patient's
/// single free-text `address`, so an unlisted area can always be typed.
class EgyptLocations {
  static const String defaultGovernorate = 'Alexandria';

  static const List<String> governorates = [
    'Alexandria',
    'Aswan',
    'Asyut',
    'Beheira',
    'Beni Suef',
    'Cairo',
    'Dakahlia',
    'Damietta',
    'Faiyum',
    'Gharbia',
    'Giza',
    'Ismailia',
    'Kafr El Sheikh',
    'Luxor',
    'Matrouh',
    'Minya',
    'Monufia',
    'New Valley',
    'North Sinai',
    'Port Said',
    'Qalyubia',
    'Qena',
    'Red Sea',
    'Sharqia',
    'Sohag',
    'South Sinai',
    'Suez',
  ];

  /// Alexandria's districts, each with its well-known areas.
  static const Map<String, List<String>> alexandriaDistricts = {
    'Montaza': [
      'Abu Qir',
      'Al Maamoura',
      'Al Mandara',
      'Al Montaza',
      'Al Asafra',
      'Miami',
      'Sidi Bishr',
      'Al Seyouf',
      'Victoria',
      'Al Awayed',
      'Khorshid',
      'Abis',
    ],
    'East (Sharq)': [
      'Smouha',
      'Sidi Gaber',
      'Sporting',
      'Cleopatra',
      'Camp Shezar',
      'Ibrahimia',
      'Stanley',
      'Gleem',
      'San Stefano',
      'Saba Pasha',
      'Bolkly',
      'Roushdy',
      'Kafr Abdo',
      'Zizinia',
      'Laurent',
      'Fleming',
      'Bacchus',
      'Ezbet Saad',
    ],
    'Middle (Wasat)': [
      'Raml Station',
      'Shatby',
      'Azarita',
      'Al Hadra',
      'Moharam Bek',
      'Kom El Dikka',
      'Al Attarin',
      'Bab Sharqi',
    ],
    'West (Gharb)': [
      'Karmouz',
      'Mina El Basal',
      'Ghet El Enab',
      'Al Labban',
      'Kom El Shoqafa',
      'Al Wardian',
      'Al Max',
    ],
    'Gomrok': ['Bahary', 'Anfoushi', 'Ras El Tin', 'Al Mansheya', 'Al Gomrok'],
    'Agami': [
      'Al Agami',
      'Al Bitash',
      'Hannoville',
      'Al Dekheila',
      'Abu Youssef',
    ],
    'Amreya': ['Al Amreya', 'King Mariout', 'Al Nahda'],
    'Borg El Arab': ['Borg El Arab', 'New Borg El Arab', 'Bahig'],
  };

  /// The single address saved on the patient: "details, area, governorate",
  /// skipping empty parts. Empty when neither an area nor details were given —
  /// a governorate alone is not an address.
  static String compose({
    required String governorate,
    String? area,
    String? details,
  }) {
    final trimmedArea = area?.trim() ?? '';
    final trimmedDetails = details?.trim() ?? '';
    if (trimmedArea.isEmpty && trimmedDetails.isEmpty) return '';
    return [trimmedDetails, trimmedArea, governorate.trim()]
        .where((part) => part.isNotEmpty)
        .join(', ');
  }
}
