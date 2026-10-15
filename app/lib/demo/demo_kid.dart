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
      title: DemoData.tr('Erste Aufgabe', 'First chore'),
      description: DemoData.tr(
        'Die erste Aufgabe erledigt',
        'Finished the first chore',
      ),
      earned: profileId == DemoData.daughter,
    ),
    KidBadge(
      id: 'b-week',
      title: DemoData.tr('Sieben Tage am Stück', 'Seven days in a row'),
      description: DemoData.tr(
        'Sieben Fälligkeiten hintereinander erledigt',
        'Seven chores in a row done on time',
      ),
      earned: false,
    ),
    KidBadge(
      id: 'b-25',
      title: DemoData.tr('Fünfundzwanzig Aufgaben', 'Twenty-five chores'),
      description: DemoData.tr(
        'Fünfundzwanzig Aufgaben erledigt',
        'Finished twenty-five chores',
      ),
      earned: false,
    ),
    KidBadge(
      id: 'b-100',
      title: DemoData.tr('Hundert Punkte', 'A hundred points'),
      description: DemoData.tr(
        'Hundert Punkte verdient',
        'Earned a hundred points',
      ),
      earned: false,
    ),
  ]);
}
