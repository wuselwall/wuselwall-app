/// A word the household taught the app: [text] belongs in the category [key]
/// (`api.match_corrections`, specs/29 "Learning from the family").
class MatchCorrection {
  const MatchCorrection({
    required this.id,
    required this.domain,
    required this.text,
    required this.key,
    required this.setAt,
    this.foldedText,
    this.setBy,
  });

  factory MatchCorrection.fromJson(Map<String, dynamic> json) =>
      MatchCorrection(
        id: json['id'] as String,
        domain: json['domain'] as String,
        text: json['text'] as String,
        foldedText: json['folded_text'] as String?,
        key: json['key'] as String,
        setBy: json['set_by'] as String?,
        setAt: DateTime.parse(json['set_at'] as String),
      );

  final String id;

  /// `shopping_category` today.
  final String domain;

  /// The item name as it was typed.
  final String text;
  final String? foldedText;

  /// A seeded category key (`snacks`), or the name of a category the family made.
  final String key;

  /// The profile that made the correction; null once that person is gone.
  final String? setBy;
  final DateTime setAt;
}
