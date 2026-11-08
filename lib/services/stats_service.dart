import '../models/brew_model.dart';

class MethodStat {
  const MethodStat({
    required this.method,
    required this.count,
    required this.averageRating,
  });

  final BrewMethod method;
  final int count;
  final double averageRating;
}

class ComboStat {
  const ComboStat({
    required this.method,
    required this.roast,
    required this.count,
    required this.averageRating,
  });

  final BrewMethod method;
  final RoastLevel roast;
  final int count;
  final double averageRating;
}

class DayCount {
  const DayCount({required this.date, required this.count});

  final DateTime date;
  final int count;
}

class TagCount {
  const TagCount({required this.tag, required this.count});

  final FlavorTag tag;
  final int count;
}

/// Ringkasan statistik jurnal.
class JournalStats {
  const JournalStats({
    required this.totalBrews,
    required this.averageRating,
    required this.averageBrewSeconds,
    required this.currentStreak,
    required this.longestStreak,
    required this.recentRatings,
    required this.perMethod,
    required this.bestCombo,
    required this.last7Days,
    required this.topTags,
  });

  final int totalBrews;
  final double averageRating;

  /// Rata-rata durasi dari catatan yang memakai timer; `null` bila tidak ada.
  final int? averageBrewSeconds;

  /// Hari beruntun menyeduh sampai hari ini (atau kemarin).
  final int currentStreak;
  final int longestStreak;

  /// Rating terakhir, urut dari terlama ke terbaru (maks 14).
  final List<int> recentRatings;

  /// Per metode, terbanyak di atas.
  final List<MethodStat> perMethod;

  /// Kombinasi metode + roast dengan rata-rata rating tertinggi (minimal dua
  /// catatan); `null` bila belum ada.
  final ComboStat? bestCombo;

  /// Jumlah seduhan 7 hari terakhir, hari ini di akhir.
  final List<DayCount> last7Days;

  /// Tag rasa terpopuler (maks 5).
  final List<TagCount> topTags;

  bool get isEmpty => totalBrews == 0;

  MethodStat? get favoriteMethod => perMethod.isEmpty ? null : perMethod.first;
}

/// Menghitung statistik dari catatan jurnal. Murni, tanpa Flutter.
class StatsService {
  const StatsService();

  static const int recentLimit = 14;
  static const int minComboEntries = 2;

  JournalStats compute(List<BrewEntry> entries, DateTime now) {
    if (entries.isEmpty) {
      return JournalStats(
        totalBrews: 0,
        averageRating: 0,
        averageBrewSeconds: null,
        currentStreak: 0,
        longestStreak: 0,
        recentRatings: const <int>[],
        perMethod: const <MethodStat>[],
        bestCombo: null,
        last7Days: _lastSevenDays(const <BrewEntry>[], now),
        topTags: const <TagCount>[],
      );
    }

    final List<BrewEntry> chronological = List<BrewEntry>.of(entries)
      ..sort((BrewEntry a, BrewEntry b) => a.createdAt.compareTo(b.createdAt));

    final double average =
        entries.fold<int>(0, (int s, BrewEntry e) => s + e.rating) /
        entries.length;

    final List<BrewEntry> timed = entries
        .where((BrewEntry e) => e.brewSeconds > 0)
        .toList();
    final int? averageSeconds = timed.isEmpty
        ? null
        : (timed.fold<int>(0, (int s, BrewEntry e) => s + e.brewSeconds) /
                  timed.length)
              .round();

    final List<int> recent = chronological
        .skip(
          chronological.length > recentLimit
              ? chronological.length - recentLimit
              : 0,
        )
        .map((BrewEntry e) => e.rating)
        .toList();

    final Set<DateTime> days = <DateTime>{
      for (final BrewEntry e in entries) _dayOf(e.createdAt),
    };

    return JournalStats(
      totalBrews: entries.length,
      averageRating: average,
      averageBrewSeconds: averageSeconds,
      currentStreak: _currentStreak(days, now),
      longestStreak: _longestStreak(days),
      recentRatings: recent,
      perMethod: _perMethod(entries),
      bestCombo: _bestCombo(entries),
      last7Days: _lastSevenDays(entries, now),
      topTags: _topTags(entries),
    );
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _currentStreak(Set<DateTime> days, DateTime now) {
    DateTime cursor = _dayOf(now);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) {
        return 0;
      }
    }
    int streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  static int _longestStreak(Set<DateTime> days) {
    final List<DateTime> sorted = days.toList()..sort();
    int best = 0;
    int run = 0;
    DateTime? previous;
    for (final DateTime day in sorted) {
      final bool consecutive =
          previous != null &&
          DateTime(previous.year, previous.month, previous.day + 1) == day;
      run = consecutive ? run + 1 : 1;
      if (run > best) {
        best = run;
      }
      previous = day;
    }
    return best;
  }

  static List<MethodStat> _perMethod(List<BrewEntry> entries) {
    final List<MethodStat> stats = <MethodStat>[];
    for (final BrewMethod method in BrewMethod.values) {
      final List<BrewEntry> of = entries
          .where((BrewEntry e) => e.method == method)
          .toList();
      if (of.isEmpty) {
        continue;
      }
      stats.add(
        MethodStat(
          method: method,
          count: of.length,
          averageRating:
              of.fold<int>(0, (int s, BrewEntry e) => s + e.rating) / of.length,
        ),
      );
    }
    stats.sort((MethodStat a, MethodStat b) {
      final int byCount = b.count.compareTo(a.count);
      return byCount != 0
          ? byCount
          : b.averageRating.compareTo(a.averageRating);
    });
    return stats;
  }

  static ComboStat? _bestCombo(List<BrewEntry> entries) {
    ComboStat? best;
    for (final BrewMethod method in BrewMethod.values) {
      for (final RoastLevel roast in RoastLevel.values) {
        final List<BrewEntry> of = entries
            .where((BrewEntry e) => e.method == method && e.roast == roast)
            .toList();
        if (of.length < minComboEntries) {
          continue;
        }
        final double avg =
            of.fold<int>(0, (int s, BrewEntry e) => s + e.rating) / of.length;
        final bool better =
            best == null ||
            avg > best.averageRating ||
            (avg == best.averageRating && of.length > best.count);
        if (better) {
          best = ComboStat(
            method: method,
            roast: roast,
            count: of.length,
            averageRating: avg,
          );
        }
      }
    }
    return best;
  }

  static List<DayCount> _lastSevenDays(List<BrewEntry> entries, DateTime now) {
    final DateTime today = _dayOf(now);
    return <DayCount>[
      for (int i = 6; i >= 0; i--)
        () {
          final DateTime day = DateTime(today.year, today.month, today.day - i);
          return DayCount(
            date: day,
            count: entries
                .where((BrewEntry e) => _dayOf(e.createdAt) == day)
                .length,
          );
        }(),
    ];
  }

  static List<TagCount> _topTags(List<BrewEntry> entries) {
    final Map<FlavorTag, int> counts = <FlavorTag, int>{};
    for (final BrewEntry e in entries) {
      for (final FlavorTag tag in e.flavorTags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final List<TagCount> result =
        <TagCount>[
          for (final MapEntry<FlavorTag, int> e in counts.entries)
            TagCount(tag: e.key, count: e.value),
        ]..sort((TagCount a, TagCount b) {
          final int byCount = b.count.compareTo(a.count);
          return byCount != 0 ? byCount : a.tag.index.compareTo(b.tag.index);
        });
    return result.take(5).toList();
  }
}
