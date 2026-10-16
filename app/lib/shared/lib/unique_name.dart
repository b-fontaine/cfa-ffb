/// Le premier nom libre : [base] s'il l'est, sinon « base (2) », « base (3) »,
/// etc. [isTaken] dit si un nom candidat est déjà pris (à la façon de
/// l'appelant : casse, espaces).
String firstFreeName(String base, bool Function(String candidate) isTaken) {
  if (!isTaken(base)) return base;
  for (var n = 2; ; n++) {
    final candidate = '$base ($n)';
    if (!isTaken(candidate)) return candidate;
  }
}
