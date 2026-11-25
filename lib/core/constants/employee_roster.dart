class EmployeeRoster {
  static const List<String> officialEmployees = [
    'AGGALUT, ALFRED A.',
    'AGUANA, LOISE C.',
    'AMBATANG, LESLINE G.',
    'ARONDA, LORRAINE P.',
    'BAGAYAO, ARNIEL C.',
    'BALANZA, KAREN N.',
    'BALATA, CHRISEL B.',
    'BANAE, RENELYN A.',
    'BARTLETT, JANICE BABE V.',
    'BASCOS, GEOFFREY M.',
    'BATONG, FRANKLIN B.',
    'BATONG, ROJOHN T.',
    'BUGUELLES, ZENNY W.',
    'CABAL, WYLON P.',
    'CABEN, EDGAR M.',
    'CADSI, NOVELYN W.',
    'CAJIGAN, RYAN A.',
    'CAMOSOL, RAFAEL F.',
    'CAWILAN, FLORDELIZ BELLE B.',
    'CAYACHEN, DARLENE A.',
    'CAYAMDAS, JOMEL A.',
    'CHELNAG, ARABEAH MARIE P.',
    'CULAPO, SERAFIN B.',
    'DALASEN, JASMINE W.',
    'DAPIAWEN, ARLENE I.',
    'DE VERA, RHODESSA B.',
    'DEGAY, DHARYL RIZA C.',
    'DUMAGUIN, ROWENA B.',
    'DUMAWOL, LOISAM B.',
    'FAGYAN, ASHLEY CATE O.',
    'FELIPE, BILLY SALVADOR T.',
    'GOMEZ, EDWIN P.',
    'GOYEN, CHRISTINE A.',
    'ISICAN, FAITH KAREEN B.',
    'KIMMAYONG-DE LARA, GAYLE M.',
    'LINGBANAN, DIEGO ELDON S.',
    'MADON-AN, MOISES M.',
    'MALICDAN, JOYDA T.',
    'MASLANG, GABRIELA L.',
    'MAYAMES, JASMIN',
    'MENDOZA-TENEZA, CZARINA T.',
    'MI-ING, MYKEE M.',
    'NADIAHAN, HAZEN L.',
    'NGATEB, NOLITA W.',
    'NGILAC, MAE NARESS',
    'NGIOAS, REYNARD P.',
    'OBEDOZA, JUSTIN LEO G.',
    'ONG, GARY U.',
    'PALANGDAN, CAROLINE P.',
    'PALANGDAN, JOSOAH D.',
    'PALITOGEN, RHYNLYN A.',
    'PAMO, EDNA T.',
    'PAMO, RAPHAEL RANDY T.',
    'PENAFLOR, CINDY B.',
    'PEREZ, MARIUS VINCENT P.',
    'POLIDO, NOVIE CLAIRE L.',
    'RAMO, HAZEL JOCELYN A.',
    'SAMONTE, RANDY B.',
    'SEGUNDO, JANET L.',
    'SIW-ANGAN, JEREMY P.',
    'SUBION, JENIFER B.',
    'TACYO, LUCIEL S.',
    'TAYABAN, WILFREDA A.',
    'TAY-OG, JEODILINE B.',
    'TINGBAWEN, MAEVE JOAQUINA D.',
    'TULAS, KATHLEEN B.',
    'TULDICAN, DELIE M.',
    'WACLET, JOE G.',
  ];

  /// Normalizes strings by uppercasing, stripping punctuation, and collapsing silent 'H' / double letters.
  static String _simplifyToken(String raw) {
    var s = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\s-]'), ' ').trim();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  static String _phoneticKey(String word) {
    return word
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .replaceAll('H', '')
        .replaceAll(RegExp(r'(.)\1+'), r'$1');
  }

  /// Extracts {lastName, firstNames} from "LAST, FIRST MI."
  static ({String lastName, List<String> firstTokens}) parseRosterName(
    String rosterName,
  ) {
    final parts = rosterName.split(',');
    final last = _simplifyToken(parts.isNotEmpty ? parts[0] : rosterName);
    final rest = parts.length > 1 ? _simplifyToken(parts[1]) : '';
    final tokens = rest
        .split(' ')
        .where((t) => t.length > 1) // Drop single-letter middle initials
        .toList();
    return (lastName: last, firstTokens: tokens);
  }

  /// Checks whether an equipment's `responsiblePersonnel` (e.g., "Arlene L. Dapiawen"
  /// or "DAPIAWEN, ARLENE I.") belongs to the given official roster entry.
  static bool matchesResponsiblePersonnel({
    required String rosterName,
    required String responsiblePersonnel,
  }) {
    final target = _simplifyToken(responsiblePersonnel);
    if (target.isEmpty) return false;

    final parsed = parseRosterName(rosterName);
    if (parsed.lastName.isEmpty) return false;

    // Handle multi-word or hyphenated surnames (e.g. "DE VERA", "KIMMAYONG-DE LARA")
    final lastVariants = <String>{
      parsed.lastName,
      parsed.lastName.replaceAll('-', ' '),
      ...parsed.lastName.split('-').where((p) => p.length > 2),
    };

    final targetWords = target.split(RegExp(r'[\s-]+'));
    final targetPhonetics = targetWords.map(_phoneticKey).toSet();

    final hasLastMatch = lastVariants.any((lv) {
      if (target.contains(lv)) return true;
      final lvPhonetic = _phoneticKey(lv);
      return lvPhonetic.length >= 3 && targetPhonetics.contains(lvPhonetic);
    });

    if (!hasLastMatch) return false;

    // If no first-name tokens exist, fallback to last name match
    if (parsed.firstTokens.isEmpty) return true;

    // Require at least the primary first name token (or phonetic match) to match
    final primaryFirst = parsed.firstTokens.first;
    final primaryFirstPhonetic = _phoneticKey(primaryFirst);

    return targetWords.any(
      (w) =>
          w == primaryFirst ||
          (primaryFirstPhonetic.length >= 3 &&
              _phoneticKey(w) == primaryFirstPhonetic),
    );
  }
}
