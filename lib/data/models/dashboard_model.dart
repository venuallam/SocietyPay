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
  final String month;

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
  });

  double get collectionPercentage =>
      totalFlats > 0 ? (paidFlats / totalFlats) * 100 : 0;
}