// © 2021 Raoul Müller. All rights reserved.

export 'package:habits/app.dart';

/// An [Archive] contains information about a history of data.
///
/// [T] is the [Type] of data the archive contains.
class Archive<T> {
  /// The history of data.
  final List<T> _archive = <T>[];

  /// Add new data to the [Archive].
  void add(T t) => _archive.add(t);

  /// Get the latest data.
  T latest() => _archive.last;

  /// Get the latest data of a specific type [U].
  ///
  /// If no [U] was archived, null is returned.
  U? latestOf<U>() {
    for (final T t in _archive.reversed) if (t is U) return t;
  }

  /// Whether there is data of a specific type [U] in the [Archive].
  bool containsOf<U>() {
    for (final T t in _archive) if (t is U) return true;
    return false;
  }
}
