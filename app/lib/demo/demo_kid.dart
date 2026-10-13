import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/kid/data/kid_badges_repository.dart';

/// Badges for the kid screenshots: the starter set, with the first one earned by the
/// child who is shown. In memory only, as the rest of the demo.
class DemoKidBadgesRepository implements KidBadgesRepository {
  @override
  Future<Result<List<KidBadge>>> badges(String profileId) async => Ok([
    KidBadge(
      id: 'b-first',
      title: 'Erste Aufgabe',
      description: 'Die erste Aufgabe erledigt',
      earned: profileId == DemoData.lotta,
    ),
    KidBadge(
      id: 'b-week',
      title: 'Sieben Tage am Stück',
      description: 'Sieben Fälligkeiten hintereinander erledigt',
      earned: false,
    ),
    KidBadge(
      id: 'b-25',
      title: 'Fünfundzwanzig Aufgaben',
      description: 'Fünfundzwanzig Aufgaben erledigt',
      earned: false,
    ),
    KidBadge(
      id: 'b-100',
      title: 'Hundert Punkte',
      description: 'Hundert Punkte verdient',
      earned: false,
    ),
  ]);
}
