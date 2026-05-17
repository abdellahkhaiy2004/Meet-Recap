import 'category.dart';

/// Pure-Dart domain entity for a meeting folder (architecture §10).
///
/// [isInbox] marks the virtual default folder created at DB migration v1.
class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.category,
    required this.colorHex,
    required this.iconName,
    required this.meetingCount,
    required this.createdAt,
    this.isInbox = false,
  });

  final int id;
  final String name;
  final Category category;
  final String colorHex;
  final String iconName;
  final int meetingCount;
  final DateTime createdAt;
  final bool isInbox;

  Folder copyWith({
    int? id,
    String? name,
    Category? category,
    String? colorHex,
    String? iconName,
    int? meetingCount,
    DateTime? createdAt,
    bool? isInbox,
  }) =>
      Folder(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        colorHex: colorHex ?? this.colorHex,
        iconName: iconName ?? this.iconName,
        meetingCount: meetingCount ?? this.meetingCount,
        createdAt: createdAt ?? this.createdAt,
        isInbox: isInbox ?? this.isInbox,
      );
}
