/// Vrai quand la **largeur** de la zone, et non sa hauteur, borne un schéma de
/// rapport [aspect] (largeur / hauteur) : il occupe toute la largeur et laisse
/// de la hauteur libre. C'est le cas d'un téléphone tenu droit, où tourner
/// l'appareil agrandit le schéma.
bool isWidthLimited({
  required double width,
  required double height,
  required double aspect,
}) {
  if (aspect <= 0) throw ArgumentError.value(aspect, 'aspect', 'doit être > 0');
  return width / aspect <= height;
}
