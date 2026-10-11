class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.checked,
    required this.createdAt,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: json['id'] as String,
    name: json['name'] as String,
    quantity: json['quantity'] as String?,
    checked: json['checked'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final String name;
  final String? quantity;
  final bool checked;
  final DateTime createdAt;
}

/// What `api.shopping_finish` reports.
class ShoppingTrip {
  const ShoppingTrip({required this.bought, required this.carriedOver});

  factory ShoppingTrip.fromJson(Map<String, dynamic> json) => ShoppingTrip(
    bought: json['bought'] as int,
    carriedOver: json['carried_over'] as int,
  );

  final int bought;
  final int carriedOver;
}
