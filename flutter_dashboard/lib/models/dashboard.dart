class UserStats {
  final double totalScore;
  final int totalActivities;
  final int weeklyActivities;
  final int currentRank;
  final double averageScore;
  final double weeklyProgress;
  final double weeklyScore;
  final int totalReports;

  UserStats({
    required this.totalScore,
    required this.totalActivities,
    required this.weeklyActivities,
    required this.currentRank,
    required this.averageScore,
    required this.weeklyProgress,
    required this.weeklyScore,
    required this.totalReports,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalScore: (json['total_score'] ?? 0).toDouble(),
      totalActivities: json['total_activities'] ?? 0,
      weeklyActivities: json['weekly_activities'] ?? 0,
      currentRank: json['current_rank'] ?? 0,
      averageScore: (json['average_score'] ?? 0).toDouble(),
      weeklyProgress: (json['weekly_progress'] ?? 0).toDouble(),
      weeklyScore: (json['weekly_score'] ?? 0).toDouble(),
      totalReports: json['total_reports'] ?? 0,
    );
  }
}

class LeaderboardEntry {
  final String userId;
  final String username;
  final String displayName;
  final String? profileImageUrl;
  final double totalScore;
  final int rank;
  final String? organizationName;

  LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.displayName,
    this.profileImageUrl,
    required this.totalScore,
    required this.rank,
    this.organizationName,
  });

  // Alias for score to match UI usage
  double get score => totalScore;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id']?.toString() ?? '',
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      profileImageUrl: json['profile_image_url'],
      totalScore: (json['total_score'] ?? 0).toDouble(),
      rank: json['rank'] ?? 0,
      organizationName: json['organization_name'],
    );
  }
}

class WeeklyData {
  final String week;
  final double score;
  final int activities;
  final DateTime weekStart;

  WeeklyData({
    required this.week,
    required this.score,
    required this.activities,
    required this.weekStart,
  });

  String get displayName => week;

  factory WeeklyData.fromJson(Map<String, dynamic> json) {
    return WeeklyData(
      week: json['week'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
      activities: json['activities'] ?? 0,
      weekStart: DateTime.parse(
        json['week_start'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class Category {
  final String id;
  final String name;
  final String? description;
  final double? maxScore;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.maxScore,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      maxScore: json['max_score']?.toDouble(),
      isActive: json['is_active'] ?? true,
    );
  }

  String get displayName => name;
}

class Group {
  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final bool isActive;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.memberCount,
    required this.isActive,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      memberCount: json['member_count'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  String get displayName => name;
}
