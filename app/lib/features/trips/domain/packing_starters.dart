import 'package:uuid/uuid.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// The structure of the starter packing list (specs/30 "Packing and preparing"): what
/// *Vorschläge* adds to a trip. The titles are localised in the app, like the chore
/// examples; this file holds only the ids, the groups and who each item is for.
///
/// **The ARB keys** a UI adds, one per entry of [packingStarters]:
/// `tripPackStarter` plus the id with a capital first letter, for example
/// `tripPackStarterPassports`, `tripPackStarterHealthInsuranceCard`. The groups are named
/// by `tripPackGroup` plus the group's name, for example `tripPackGroupDocuments`.
///
/// The ids: passports, healthInsuranceCard, bookingConfirmations, cashAndCards;
/// pharmacyBag, regularMedication, sunscreen, insectRepellent; chargers, powerAdapter,
/// powerBank, headphones; underwearSocks, tshirts, trousersShorts, warmJumper, rainJacket,
/// walkingShoes, sleepwear; swimwear, beachTowels, sunHat, sunglasses; cuddlyToy,
/// kidsGames, nappiesWipes, journeySnacks.
enum PackingGroup { documents, health, electronics, clothes, beach, kids }

/// One starter item.
class PackingStarter {
  const PackingStarter(
    this.id,
    this.group, {
    this.perPerson = false,
    this.childrenOnly = false,
  });

  /// The key of its localised title: `tripPackStarter` + [id] capitalised.
  final String id;
  final PackingGroup group;

  /// One item for each travelling person (`profile_id` set) instead of one for the
  /// family (`profile_id` null).
  final bool perPerson;

  /// With [perPerson]: only for the travelling children.
  final bool childrenOnly;

  /// The ARB key of the title.
  String get arbKey =>
      'tripPackStarter${id[0].toUpperCase()}${id.substring(1)}';
}

/// The starter list, in the order it is added.
const packingStarters = <PackingStarter>[
  PackingStarter('passports', PackingGroup.documents, perPerson: true),
  PackingStarter(
    'healthInsuranceCard',
    PackingGroup.documents,
    perPerson: true,
  ),
  PackingStarter('bookingConfirmations', PackingGroup.documents),
  PackingStarter('cashAndCards', PackingGroup.documents),
  PackingStarter('pharmacyBag', PackingGroup.health),
  PackingStarter('regularMedication', PackingGroup.health, perPerson: true),
  PackingStarter('sunscreen', PackingGroup.health),
  PackingStarter('insectRepellent', PackingGroup.health),
  PackingStarter('chargers', PackingGroup.electronics),
  PackingStarter('powerAdapter', PackingGroup.electronics),
  PackingStarter('powerBank', PackingGroup.electronics),
  PackingStarter('headphones', PackingGroup.electronics, perPerson: true),
  PackingStarter('underwearSocks', PackingGroup.clothes, perPerson: true),
  PackingStarter('tshirts', PackingGroup.clothes, perPerson: true),
  PackingStarter('trousersShorts', PackingGroup.clothes, perPerson: true),
  PackingStarter('warmJumper', PackingGroup.clothes, perPerson: true),
  PackingStarter('rainJacket', PackingGroup.clothes, perPerson: true),
  PackingStarter('walkingShoes', PackingGroup.clothes, perPerson: true),
  PackingStarter('sleepwear', PackingGroup.clothes, perPerson: true),
  PackingStarter('swimwear', PackingGroup.beach, perPerson: true),
  PackingStarter('beachTowels', PackingGroup.beach, perPerson: true),
  PackingStarter('sunHat', PackingGroup.beach, perPerson: true),
  PackingStarter('sunglasses', PackingGroup.beach, perPerson: true),
  PackingStarter(
    'cuddlyToy',
    PackingGroup.kids,
    perPerson: true,
    childrenOnly: true,
  ),
  PackingStarter('kidsGames', PackingGroup.kids),
  PackingStarter('nappiesWipes', PackingGroup.kids),
  PackingStarter('journeySnacks', PackingGroup.kids),
];

/// The checks a starter list adds to a trip: one per family item, one per traveller for
/// a per-person item (only the [children] for a children-only one).
///
/// [titleOf] gives the localised title of a starter (the UI's `tripPackStarter...` ARB
/// keys). [travellers] are the profile ids of everyone who travels and [children] the
/// children among them; an empty [travellers] gives the per-person items to the family
/// (`profile_id` null) once.
List<TripCheck> buildStarterChecks({
  required String tripId,
  required String Function(PackingStarter starter) titleOf,
  required List<String> travellers,
  required List<String> children,
  List<PackingStarter> starters = packingStarters,
}) {
  const uuid = Uuid();
  final checks = <TripCheck>[];
  void add(PackingStarter s, String? profileId) => checks.add(
    TripCheck(
      id: uuid.v4(),
      tripId: tripId,
      kind: CheckKind.pack,
      title: titleOf(s),
      profileId: profileId,
      position: checks.length,
    ),
  );
  for (final s in starters) {
    if (!s.perPerson) {
      add(s, null);
      continue;
    }
    final people = s.childrenOnly ? children : travellers;
    if (people.isEmpty) {
      if (!s.childrenOnly) add(s, null);
      continue;
    }
    for (final p in people) {
      add(s, p);
    }
  }
  return checks;
}
