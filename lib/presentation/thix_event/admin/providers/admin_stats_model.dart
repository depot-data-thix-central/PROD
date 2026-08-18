class AdminStats {
  final int totalEvents;
  final int totalBookings;
  final int totalSeatsSold;
  final int waitingQueue;
  final double totalRevenue;
  final int todayBookings;

  const AdminStats({
    this.totalEvents = 0,
    this.totalBookings = 0,
    this.totalSeatsSold = 0,
    this.waitingQueue = 0,
    this.totalRevenue = 0,
    this.todayBookings = 0,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalEvents: (json['total_events'] as num?)?.toInt() ?? 0,
      totalBookings: (json['total_bookings'] as num?)?.toInt() ?? 0,
      totalSeatsSold: (json['total_seats_sold'] as num?)?.toInt() ?? 0,
      waitingQueue: (json['waiting_queue'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      todayBookings: (json['today_bookings'] as num?)?.toInt() ?? 0,
    );
  }

  AdminStats copyWith({
    int? totalEvents,
    int? totalBookings,
    int? totalSeatsSold,
    int? waitingQueue,
    double? totalRevenue,
    int? todayBookings,
  }) {
    return AdminStats(
      totalEvents: totalEvents ?? this.totalEvents,
      totalBookings: totalBookings ?? this.totalBookings,
      totalSeatsSold: totalSeatsSold ?? this.totalSeatsSold,
      waitingQueue: waitingQueue ?? this.waitingQueue,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      todayBookings: todayBookings ?? this.todayBookings,
    );
  }

  static AdminStats empty() => const AdminStats();

  Map<String, dynamic> toJson() => {
        'total_events': totalEvents,
        'total_bookings': totalBookings,
        'total_seats_sold': totalSeatsSold,
        'waiting_queue': waitingQueue,
        'total_revenue': totalRevenue,
        'today_bookings': todayBookings,
      };
}
