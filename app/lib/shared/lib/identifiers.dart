/// Identifiants typés du suivi des élèves (UUID texte généré hors du domaine).
///
/// Les `extension type` sont gratuits à l'exécution et empêchent de confondre
/// deux identifiants de nature différente.
extension type const StudentId(String value);

extension type const GroupId(String value);

extension type const SeasonId(String value);

extension type const SessionId(String value);

extension type const AttemptId(String value);

extension type const AssessmentId(String value);
