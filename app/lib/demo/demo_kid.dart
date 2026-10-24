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
      title: DemoData.tr4(
        'Erste Aufgabe',
        'First chore',
        'Première tâche',
        'Primera tarea',
      ),
      description: DemoData.tr4(
        'Die erste Aufgabe erledigt',
        'Finished the first chore',
        'Première tâche terminée',
        'Primera tarea completada',
      ),
      earned: profileId == DemoData.daughter,
      // Earned an hour ago, so the demo shows Wusel proud of it (specs/25).
      awardedAt: profileId == DemoData.daughter
          ? DateTime.now().subtract(const Duration(hours: 1))
          : null,
    ),
    KidBadge(
      id: 'b-week',
      title: DemoData.tr4(
        'Sieben Tage am Stück',
        'Seven days in a row',
        'Sept jours d’affilée',
        'Siete días seguidos',
      ),
      description: DemoData.tr4(
        'Sieben Fälligkeiten hintereinander erledigt',
        'Seven chores in a row done on time',
        'Sept tâches à la suite terminées à temps',
        'Siete tareas seguidas completadas a tiempo',
      ),
      earned: false,
    ),
    KidBadge(
      id: 'b-25',
      title: DemoData.tr4(
        'Fünfundzwanzig Aufgaben',
        'Twenty-five chores',
        'Vingt-cinq tâches',
        'Veinticinco tareas',
      ),
      description: DemoData.tr4(
        'Fünfundzwanzig Aufgaben erledigt',
        'Finished twenty-five chores',
        'Vingt-cinq tâches terminées',
        'Veinticinco tareas completadas',
      ),
      earned: false,
    ),
    KidBadge(
      id: 'b-100',
      title: DemoData.tr4(
        'Hundert Punkte',
        'A hundred points',
        'Cent points',
        'Cien puntos',
      ),
      description: DemoData.tr4(
        'Hundert Punkte verdient',
        'Earned a hundred points',
        'Cent points gagnés',
        'Cien puntos conseguidos',
      ),
      earned: false,
    ),
  ]);
}
