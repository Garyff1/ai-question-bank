import 'dart:math';

/// Selects coherent excerpts from the whole source instead of blindly keeping
/// only its beginning.
///
/// For long material, the selector samples evenly distributed windows and
/// adds extra focus windows around chapter/user keywords. Every returned
/// excerpt carries its original position so the model understands that it is
/// reading representative source fragments rather than a continuous rewrite.
class MaterialContextSelector {
  const MaterialContextSelector._();

  static String select({
    required String material,
    required int maxChars,
    String focusQuery = '',
  }) {
    final source = material.replaceAll('\r\n', '\n').trim();
    if (source.length <= maxChars || maxChars <= 0) return source;

    final chapterStarts = _chapterStarts(source);
    if (chapterStarts.length >= 3) {
      return _selectChapterSegments(
        source: source,
        chapterStarts: chapterStarts,
        maxChars: maxChars,
        focusQuery: focusQuery,
      );
    }

    final windowCount = (maxChars ~/ 900).clamp(3, 7);
    final markerReserve = windowCount * 46;
    final contentBudget = max(300, maxChars - markerReserve);
    final windowLength = max(120, contentBudget ~/ windowCount);
    final maxStart = max(0, source.length - windowLength);
    final starts = <int>{0, maxStart};

    for (var index = 1; index < windowCount - 1; index++) {
      starts.add(((maxStart * index) / (windowCount - 1)).round());
    }

    final focusStarts = _focusStarts(
      source: source,
      focusQuery: focusQuery,
      windowLength: windowLength,
    );
    for (final start in focusStarts) {
      if (starts.length >= windowCount + 2) break;
      starts.add(start.clamp(0, maxStart));
    }

    var ordered = starts.toList()..sort();
    if (ordered.length > windowCount) {
      ordered = _prioritizeWindows(
        ordered,
        sourceLength: source.length,
        focusStarts: focusStarts,
        limit: windowCount,
      );
    }

    final buffer = StringBuffer();
    for (var index = 0; index < ordered.length; index++) {
      final rawStart = ordered[index];
      final rawEnd = min(source.length, rawStart + windowLength);
      final start = _snapStart(source, rawStart);
      final end = _snapEnd(source, rawEnd, minimum: start + 1);
      final marker =
          '【资料片段 ${index + 1}/${ordered.length} · 原文位置 ${start + 1}-$end】\n';
      if (buffer.length + marker.length >= maxChars) break;
      final remaining = maxChars - buffer.length - marker.length;
      final excerpt = source.substring(start, end).trim();
      final safeExcerpt = excerpt.length > remaining
          ? excerpt.substring(0, remaining)
          : excerpt;
      if (buffer.isNotEmpty) buffer.writeln('\n');
      buffer.write(marker);
      buffer.write(safeExcerpt);
      if (buffer.length >= maxChars) break;
    }
    final result = buffer.toString().trim();
    return result.length > maxChars ? result.substring(0, maxChars) : result;
  }

  static List<int> _chapterStarts(String source) {
    final heading = RegExp(
      r'^(?:第[一二三四五六七八九十百零〇\d]+(?:章|节|篇|单元)|chapter\s+\d+|\d+(?:\.\d+)*[、.．]\s*\S+)',
      caseSensitive: false,
      multiLine: true,
    );
    return heading.allMatches(source).map((match) => match.start).toList();
  }

  static String _selectChapterSegments({
    required String source,
    required List<int> chapterStarts,
    required int maxChars,
    required String focusQuery,
  }) {
    final segmentLimit = min(
      chapterStarts.length,
      (maxChars ~/ 550).clamp(3, 12),
    );
    final selectedIndexes = <int>{0, chapterStarts.length - 1};
    for (var index = 1; index < segmentLimit - 1; index++) {
      selectedIndexes.add(
        (((chapterStarts.length - 1) * index) / (segmentLimit - 1)).round(),
      );
    }
    final lowerSource = source.toLowerCase();
    final focusTerms = focusQuery
        .split(RegExp(r'[\s,，。；;：:\n、/]+'))
        .map((term) => term.trim().toLowerCase())
        .where((term) => term.length >= 2)
        .toSet();
    for (final term in focusTerms.take(12)) {
      final position = lowerSource.indexOf(term);
      if (position < 0) continue;
      var chapterIndex = 0;
      for (var index = 0; index < chapterStarts.length; index++) {
        if (chapterStarts[index] > position) break;
        chapterIndex = index;
      }
      selectedIndexes.add(chapterIndex);
    }
    var ordered = selectedIndexes.toList()..sort();
    if (ordered.length > segmentLimit) {
      ordered = _evenlyReduceIndexes(
        ordered,
        limit: segmentLimit,
        requiredIndexes: {
          0,
          chapterStarts.length - 1,
          ...selectedIndexes.where((index) {
            final start = chapterStarts[index];
            final end = index + 1 < chapterStarts.length
                ? chapterStarts[index + 1]
                : source.length;
            final section = source.substring(start, end).toLowerCase();
            return focusTerms.any(section.contains);
          }),
        },
      );
    }

    final markerReserve = ordered.length * 48;
    final perSection = max(120, (maxChars - markerReserve) ~/ ordered.length);
    final buffer = StringBuffer();
    for (var outputIndex = 0; outputIndex < ordered.length; outputIndex++) {
      final chapterIndex = ordered[outputIndex];
      final start = chapterStarts[chapterIndex];
      final sectionEnd = chapterIndex + 1 < chapterStarts.length
          ? chapterStarts[chapterIndex + 1]
          : source.length;
      final end = min(sectionEnd, start + perSection);
      final marker =
          '【章节片段 ${outputIndex + 1}/${ordered.length} · 原文位置 ${start + 1}-$end】\n';
      if (buffer.isNotEmpty) buffer.writeln('\n');
      final available = maxChars - buffer.length - marker.length;
      if (available <= 0) break;
      final excerpt = source.substring(start, end).trim();
      buffer.write(marker);
      buffer.write(
        excerpt.length > available ? excerpt.substring(0, available) : excerpt,
      );
      if (buffer.length >= maxChars) break;
    }
    final result = buffer.toString().trim();
    return result.length > maxChars ? result.substring(0, maxChars) : result;
  }

  static List<int> _evenlyReduceIndexes(
    List<int> indexes, {
    required int limit,
    required Set<int> requiredIndexes,
  }) {
    final selected = <int>{...requiredIndexes.where(indexes.contains)};
    while (selected.length > limit) {
      final removable = selected
          .where((index) => index != indexes.first && index != indexes.last)
          .toList();
      if (removable.isEmpty) break;
      selected.remove(removable.last);
    }
    while (selected.length < limit) {
      int? best;
      var distance = -1;
      for (final candidate in indexes) {
        if (selected.contains(candidate)) continue;
        final nearest = selected.isEmpty
            ? candidate
            : selected.map((value) => (candidate - value).abs()).reduce(min);
        if (nearest > distance) {
          distance = nearest;
          best = candidate;
        }
      }
      if (best == null) break;
      selected.add(best);
    }
    final result = selected.toList()..sort();
    return result;
  }

  static List<int> _focusStarts({
    required String source,
    required String focusQuery,
    required int windowLength,
  }) {
    final terms = focusQuery
        .split(RegExp(r'[\s,，。；;：:\n、/]+'))
        .map((term) => term.trim())
        .where((term) => term.length >= 2)
        .toSet();
    final starts = <int>[];
    final lowerSource = source.toLowerCase();
    for (final term in terms.take(12)) {
      var from = 0;
      final lowerTerm = term.toLowerCase();
      while (from < source.length) {
        final found = lowerSource.indexOf(lowerTerm, from);
        if (found < 0) break;
        starts.add(max(0, found - windowLength ~/ 3));
        from = found + lowerTerm.length;
        if (starts.length >= 12) return starts;
      }
    }
    return starts;
  }

  static List<int> _prioritizeWindows(
    List<int> starts, {
    required int sourceLength,
    required List<int> focusStarts,
    required int limit,
  }) {
    final selected = <int>{starts.first, starts.last};
    final focus = focusStarts.toSet();
    for (final start in starts.where(focus.contains)) {
      if (selected.length >= limit) break;
      selected.add(start);
    }
    while (selected.length < limit) {
      int? best;
      var bestDistance = -1;
      for (final candidate in starts) {
        if (selected.contains(candidate)) continue;
        final distance = selected
            .map((value) => (candidate - value).abs())
            .reduce(min);
        if (distance > bestDistance) {
          bestDistance = distance;
          best = candidate;
        }
      }
      if (best == null) break;
      selected.add(best);
    }
    final result = selected.toList()..sort();
    return result;
  }

  static int _snapStart(String source, int rawStart) {
    if (rawStart <= 0) return 0;
    final newline = source.indexOf('\n', rawStart);
    if (newline >= 0 && newline - rawStart <= 80) return newline + 1;
    return rawStart;
  }

  static int _snapEnd(String source, int rawEnd, {required int minimum}) {
    if (rawEnd >= source.length) return source.length;
    final newline = source.lastIndexOf('\n', rawEnd);
    if (newline >= minimum && rawEnd - newline <= 80) return newline;
    return rawEnd.clamp(minimum, source.length);
  }
}
