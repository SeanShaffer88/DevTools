// Sample model fixture: what a freezed model looks like, honestly
// labelled.
//
// WHAT IS HAND-WRITTEN HERE: the plain Dart class [SampleItemPlain]
// below is written by hand for this fixture. It compiles as-is, with
// no code generation and no dependencies, and shows the shape of the
// data (fields, JSON mapping, value equality) that the rest of the
// pack's fixtures use.
//
// WHAT FREEZED WOULD GENERATE: in a real project you do NOT write
// the class above by hand. You write the short @freezed source shown
// in the comment block at the bottom of this file, add the
// dependencies, and run build_runner. Freezed then generates a
// `.freezed.dart` part file (copyWith, equality, hashCode, toString)
// and, with json_serializable, a `.g.dart` part file (fromJson /
// toJson). Those generated files are build outputs — they are
// deliberately NOT included here, because pasting in fake "generated"
// code that was never produced by the tool would misrepresent what
// codegen emits for the pinned versions. Generate them yourself:
//
//   dart run build_runner build --delete-conflicting-outputs
//
// Pinned versions for this fixture (verified Nov 2026):
//   freezed 4.0.3 · freezed_annotation 3.1.0
//   json_serializable 6.15.2 · build_runner 2.17.1

/// Hand-written plain Dart model with the same shape freezed
/// generates for the source in the comment block below.
class SampleItemPlain {
  const SampleItemPlain({
    required this.id,
    required this.title,
    required this.subtitle,
    this.isFavorite = false,
    this.ownerId,
    this.createdAt,
  });

  factory SampleItemPlain.fromJson(Map<String, dynamic> json) {
    return SampleItemPlain(
      id: json['id'] as int,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      isFavorite: json['isFavorite'] as bool? ?? false,
      ownerId: json['ownerId'] as int?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );
  }

  final int id;
  final String title;
  final String subtitle;
  final bool isFavorite;
  final int? ownerId;
  final DateTime? createdAt;

  SampleItemPlain copyWith({
    int? id,
    String? title,
    String? subtitle,
    bool? isFavorite,
    int? ownerId,
    DateTime? createdAt,
  }) {
    return SampleItemPlain(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      isFavorite: isFavorite ?? this.isFavorite,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'isFavorite': isFavorite,
      'ownerId': ownerId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SampleItemPlain &&
            other.id == id &&
            other.title == title &&
            other.subtitle == subtitle &&
            other.isFavorite == isFavorite &&
            other.ownerId == ownerId &&
            other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, subtitle, isFavorite, ownerId, createdAt);

  @override
  String toString() {
    return 'SampleItemPlain(id: $id, title: $title, subtitle: $subtitle, '
        'isFavorite: $isFavorite, ownerId: $ownerId, createdAt: $createdAt)';
  }
}

// -------------------------------------------------------------------
// THE @freezed SOURCE THIS FIXTURE IS MODELLED ON
// (source you would write in a real project — the class, copyWith,
// equality, and JSON code are then generated into part files):
//
//   import 'package:freezed_annotation/freezed_annotation.dart';
//
//   part 'sample_item.freezed.dart';
//   part 'sample_item.g.dart';
//
//   @freezed
//   abstract class SampleItem with _$SampleItem {
//     const factory SampleItem({
//       required int id,
//       required String title,
//       required String subtitle,
//       @Default(false) bool isFavorite,
//       int? ownerId,
//       DateTime? createdAt,
//     }) = _SampleItem;
//
//     factory SampleItem.fromJson(Map<String, dynamic> json) =>
//         _$SampleItemFromJson(json);
//   }
//
// Differences to expect from real generated code versus the
// hand-written class above: freezed also generates pattern-matching
// helpers (when / map and their maybe/or-null variants) and sentinel
// handling in copyWith so nullable fields can be explicitly set back
// to null — the hand-written copyWith above cannot do that. That gap
// is exactly why projects use the generator instead of this pattern.
// -------------------------------------------------------------------
