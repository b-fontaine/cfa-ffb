import 'dart:math' as math;

/// Angle en radians, dans `[0, π]`, entre les rayons `vertex → a` et
/// `vertex → b`. Vaut 0 quand un rayon est de longueur nulle (angle
/// indéfini : rien à mesurer).
double angleBetween({
  required math.Point<double> vertex,
  required math.Point<double> a,
  required math.Point<double> b,
}) {
  final u = a - vertex;
  final v = b - vertex;
  if (u.magnitude == 0 || v.magnitude == 0) return 0;
  final cross = u.x * v.y - u.y * v.x;
  final dot = u.x * v.x + u.y * v.y;
  return math.atan2(cross.abs(), dot);
}

/// Angle de [angleBetween] arrondi au degré entier.
int angleDegrees({
  required math.Point<double> vertex,
  required math.Point<double> a,
  required math.Point<double> b,
}) => (angleBetween(vertex: vertex, a: a, b: b) * 180 / math.pi).round();
