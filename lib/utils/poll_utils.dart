class PollUtils {
  /// Calculates percentages that sum up to exactly 100 using the Largest Remainder Method.
  static List<int> calculatePercentages(List<int> counts) {
    if (counts.isEmpty) return [];

    int total = counts.fold(0, (sum, item) => sum + item);
    if (total == 0) return List.filled(counts.length, 0);

    // 1. Calculate floor percentages and remainders
    List<double> exactPercentages = counts
        .map((c) => (c * 100) / total)
        .toList();
    List<int> roundedPercentages = exactPercentages
        .map((p) => p.floor())
        .toList();

    int currentSum = roundedPercentages.fold(0, (sum, item) => sum + item);
    int difference = 100 - currentSum;

    // 2. Distribute the difference to those with the largest remainders
    if (difference > 0) {
      List<int> indices = List.generate(counts.length, (i) => i);
      indices.sort((a, b) {
        double remainderA = exactPercentages[a] - roundedPercentages[a];
        double remainderB = exactPercentages[b] - roundedPercentages[b];
        return remainderB.compareTo(remainderA);
      });

      for (int i = 0; i < difference; i++) {
        roundedPercentages[indices[i]]++;
      }
    }

    return roundedPercentages;
  }
}
