class AppConstants {
  static const String equipmentCollection = 'ict_equipment';
  static const String historySubcollection = 'history';
  static const String metadataCollection = 'metadata';
  static const String sheetSyncDocId = 'sheet_sync';

  static const List<String> divisions = [
    'Finance and Administrative Division',
    'Office of the TRC Chief',
    'Outpatient and Aftercare Division',
    'Residential/Inpatient Treatment Division',
  ];

  static String normalizeDivision(String raw) {
    final clean = raw.trim();
    final upper = clean.toUpperCase();
    if (upper.isEmpty) return 'Office of the TRC Chief';
    if (upper == 'FAD' || upper.contains('FINANCE')) {
      return 'Finance and Administrative Division';
    }
    if (upper == 'OTRCC' || upper.contains('TRC CHIEF')) {
      return 'Office of the TRC Chief';
    }
    if (upper == 'OAD' ||
        upper.contains('OUTPATIENT') ||
        upper.contains('AFTERCARE')) {
      return 'Outpatient and Aftercare Division';
    }
    if (upper == 'RITD' ||
        upper.contains('RESIDENTIAL') ||
        upper.contains('INPATIENT')) {
      return 'Residential/Inpatient Treatment Division';
    }
    return clean;
  }

  static const List<String> defaultLocations = [
    'Accounting',
    'Aftercare and Billings',
    'Billing and Claims Section',
    'Budget',
    'Cash Operations Section',
    'Clinical Laboratory Section',
    'GSS',
    'HIMS',
    'HRDU',
    'ICTU',
    'Legal Office',
    'MMS',
    'NDS',
    'OCAO',
    'OCHPO',
    'OPD',
    'Outpatient Section',
    'Pharmacy',
    'Planning',
    'Procurement',
    'Psychology Section',
  ];

  static const List<String> equipmentTypes = [
    'Desktop Set',
    'Desktop',
    'Laptop',
    'Printer',
    'Scanner',
    'Projector',
    'UPS',
    'Network Switch / Router',
    'USB Wifi Adapter',
    'Flash Drive',
    'External Hard Drive',
    'Other ICT Equipment',
  ];

  static const List<String> conditions = ['Working', 'For Repair', 'Defective'];
}
