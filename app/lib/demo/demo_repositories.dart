import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// In-memory stand-ins for the backend, used only by `lib/main_demo.dart` to take
/// the screenshots of the user documentation. The PIN is 123456; nothing leaves the page.
class DemoIdentityRepository implements IdentityRepository {
  DemoIdentityRepository({required this.device});

  final DeviceInfo? device;
  final _members = [...DemoData.members];

  @override
  Future<Result<DeviceInfo?>> currentDevice() async => Ok(device);

  @override
  Future<Result<List<Member>>> members() async => Ok(List.of(_members));

  @override
  Future<Result<List<DeviceEntry>>> devices() async => Ok(DemoData.devices);

  @override
  Future<Result<void>> signIn(String email, String password) async =>
      const Ok(null);

  @override
  Future<void> signOut() async {}

  @override
  MfaState mfaState() => MfaState.none;

  @override
  Future<Result<GuardianProfile?>> myProfile() async => const Ok(null);

  @override
  Future<Result<String?>> totpFactorId() async => const Ok(null);

  @override
  Future<Result<void>> setPin({required String pin}) async => const Ok(null);

  @override
  Future<Result<void>> enrolDevice(String code) async =>
      const Err(ValidationFailure(code: 'code_invalid'));

  @override
  Future<Result<void>> addMember({
    required String? actor,
    required String name,
    required String colorHex,
  }) async {
    _members.add(
      Member(
        id: 'p-${_members.length}',
        displayName: name,
        color: parseHexColor(colorHex),
        role: Role.member,
        active: true,
      ),
    );
    return const Ok(null);
  }

  @override
  Future<Result<EnrolmentCode>> createEnrolmentCode({
    required String? actor,
    required String label,
    required DeviceClass deviceClass,
    required UiRegister register,
  }) async => Ok(
    EnrolmentCode(code: 'K7MQ4XWB', expiresAt: DateTime(2026, 10, 11, 9, 10)),
  );

  @override
  Future<Result<PinResult>> verifyPin({
    required String profileId,
    required String pin,
  }) async => Ok(
    pin == '123456'
        ? PinVerified(DateTime.now().add(const Duration(minutes: 15)))
        : const PinWrong(8),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is not part of the demo',
  );
}

class DemoShoppingRepository implements ShoppingRepository {
  final _items = DemoData.items();
  final _lists = [
    for (final (id, name, def) in DemoData.lists)
      (id: id, name: name, isDefault: def),
  ];
  var _next = 0;

  @override
  Future<Result<List<ShoppingItem>>> items() async => Ok(List.of(_items));

  @override
  Future<Result<List<ShoppingList>>> lists() async => Ok([
    for (final l in _lists)
      ShoppingList(
        id: l.id,
        name: l.name,
        isDefault: l.isDefault,
        openCount: _items
            .where((it) => it.listId == l.id && !it.checked)
            .length,
      ),
  ]);

  @override
  Future<Result<List<ShoppingCategory>>> categories() async =>
      Ok(DemoData.categories());

  @override
  Future<Result<List<CatalogEntry>>> catalog() async =>
      Ok(DemoData.catalogue());

  @override
  Future<Result<List<ShoppingTrip>>> trips(String listId) async =>
      Ok(listId == 'l-super' ? DemoData.trips() : const []);

  @override
  Future<Result<List<TripItem>>> tripItems(String tripId) async =>
      const Ok(DemoData.tripItems);

  @override
  Future<Result<String>> add({
    required String? actor,
    required String name,
    String? quantity,
    String? listId,
  }) async {
    final list = listId ?? 'l-super';
    final key = name.toLowerCase();
    final i = _items.indexWhere(
      (it) => it.listId == list && !it.checked && it.name.toLowerCase() == key,
    );
    if (i >= 0) {
      final it = _items[i];
      _items[i] = _copy(it, count: it.count + 1);
      return Ok(it.id);
    }
    final known = DemoData.catalogue().where(
      (c) => c.listId == list && c.name.toLowerCase() == key,
    );
    final id = 'n-${_next++}';
    _items.add(
      ShoppingItem(
        id: id,
        name: known.isEmpty ? name : known.first.name,
        quantity: quantity,
        checked: false,
        createdAt: DateTime.now(),
        listId: list,
        categoryId: known.isEmpty ? null : known.first.categoryId,
        addedBy: actor ?? DemoData.papa,
      ),
    );
    return Ok(id);
  }

  @override
  Future<Result<void>> toggle({
    required String? actor,
    required String itemId,
  }) async {
    final i = _items.indexWhere((it) => it.id == itemId);
    if (i >= 0) _items[i] = _copy(_items[i], checked: !_items[i].checked);
    return const Ok(null);
  }

  @override
  Future<Result<void>> adjustCount({
    required String? actor,
    required String itemId,
    required int delta,
  }) async {
    final i = _items.indexWhere((it) => it.id == itemId);
    if (i >= 0) {
      final count = _items[i].count + delta;
      count <= 0
          ? _items.removeAt(i)
          : _items[i] = _copy(_items[i], count: count);
    }
    return const Ok(null);
  }

  @override
  Future<Result<void>> setSpec({
    required String? actor,
    required String itemId,
    required String? text,
  }) async {
    final i = _items.indexWhere((it) => it.id == itemId);
    if (i >= 0) {
      _items[i] = _copy(
        _items[i],
        quantity: (text ?? '').isEmpty ? null : text,
        clearQuantity: (text ?? '').isEmpty,
      );
    }
    return const Ok(null);
  }

  @override
  Future<Result<String>> createList({
    required String? actor,
    required String name,
    required String kind,
  }) async {
    final id = 'l-${_lists.length}';
    _lists.add((id: id, name: name, isDefault: false));
    return Ok(id);
  }

  @override
  Future<Result<ShoppingFinishResult>> finish({
    required String? actor,
    String? listId,
  }) async {
    final list = listId ?? 'l-super';
    final done = _items.where((i) => i.listId == list && i.checked).length;
    _items.removeWhere((i) => i.listId == list && i.checked);
    return Ok(ShoppingFinishResult(bought: done, carriedOver: _items.length));
  }

  ShoppingItem _copy(
    ShoppingItem it, {
    int? count,
    bool? checked,
    String? quantity,
    bool clearQuantity = false,
  }) => ShoppingItem(
    id: it.id,
    name: it.name,
    quantity: clearQuantity ? null : (quantity ?? it.quantity),
    checked: checked ?? it.checked,
    createdAt: it.createdAt,
    listId: it.listId,
    categoryId: it.categoryId,
    addedBy: it.addedBy,
    count: count ?? it.count,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is not part of the demo',
  );
}
