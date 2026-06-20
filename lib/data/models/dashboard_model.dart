class MonthlyCollection {
  final String month;
  final double collected;
  final double billed;
  const MonthlyCollection({
    required this.month,
    required this.collected,
    required this.billed,
  });
  // Short label e.g. "JAN"
  String get label => month.substring(0, 3);
}

class DashboardStats {
  final int totalFlats;
  final int paidFlats;
  final int unpaidFlats;
  final int vacantFlats;
  final double totalCollected;
  final double totalPending;
  final double corpusBalance;
  final int pendingExpenses;
  final int pendingRequests;
  final int reportedPayments;
  final String month;
  final double monthlyApprovedExpenses;

  const DashboardStats({
    required this.totalFlats,
    required this.paidFlats,
    required this.unpaidFlats,
    required this.vacantFlats,
    required this.totalCollected,
    required this.totalPending,
    required this.corpusBalance,
    required this.pendingExpenses,
    required this.pendingRequests,
    required this.month,
    this.reportedPayments = 0,
    this.monthlyApprovedExpenses = 0,
  });

  double get collectionPercentage =>
      totalFlats > 0 ? (paidFlats / totalFlats) * 100 : 0;

  double get monthlyNet =>
      totalCollected - monthlyApprovedExpenses;
}