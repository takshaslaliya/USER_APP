class MonthlyStats {
  final String month; // e.g. "2026-03"
  final double spent;
  final double received;
  final double net;
  final int year;
  final String monthName;

  MonthlyStats({
    required this.month,
    required this.spent,
    required this.received,
    required this.net,
    required this.year,
    required this.monthName,
  });

  factory MonthlyStats.fromJson(Map<String, dynamic> json) {
    return MonthlyStats(
      month: json['month'] ?? '',
      spent: (json['spent'] ?? 0.0).toDouble(),
      received: (json['received'] ?? 0.0).toDouble(),
      net: (json['net'] ?? 0.0).toDouble(),
      year: json['year'] ?? 0,
      monthName: json['month_name'] ?? '',
    );
  }
}
