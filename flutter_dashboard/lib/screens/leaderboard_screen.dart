import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/auth_provider.dart';
import '../models/dashboard.dart' as models;

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load leaderboard data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).loadLeaderboard();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          Consumer<DashboardProvider>(
            builder: (context, dashboardProvider, child) {
              return IconButton(
                icon: dashboardProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.refresh),
                onPressed: dashboardProvider.isLoading
                    ? null
                    : () => dashboardProvider.loadLeaderboard(),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overall'),
            Tab(text: 'This Week'),
          ],
        ),
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, dashboardProvider, child) {
          if (dashboardProvider.isLoading &&
              dashboardProvider.leaderboard.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (dashboardProvider.error != null &&
              dashboardProvider.leaderboard.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading leaderboard',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dashboardProvider.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => dashboardProvider.loadLeaderboard(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // Overall leaderboard
              _buildLeaderboardTab(
                context,
                dashboardProvider.leaderboard,
                dashboardProvider,
                isWeekly: false,
              ),
              // Weekly leaderboard
              _buildLeaderboardTab(
                context,
                dashboardProvider.weeklyLeaderboard,
                dashboardProvider,
                isWeekly: true,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeaderboardTab(
    BuildContext context,
    List<models.LeaderboardEntry> entries,
    DashboardProvider provider, {
    required bool isWeekly,
  }) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${isWeekly ? 'weekly ' : ''}rankings available',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to submit a report!',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadLeaderboard(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top 3 podium
            if (entries.length >= 3) ...[
              _buildPodium(context, entries.take(3).toList()),
              const SizedBox(height: 32),
            ],

            // Rankings list
            _buildRankingsList(context, entries, isWeekly),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium(
    BuildContext context,
    List<models.LeaderboardEntry> topThree,
  ) {
    return SizedBox(
      height: 250,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Second place
          if (topThree.length > 1)
            _buildPodiumPlace(
              context,
              topThree[1],
              2,
              150,
              Colors.grey.shade400,
            ),

          // First place
          _buildPodiumPlace(context, topThree[0], 1, 180, Colors.amber),

          // Third place
          if (topThree.length > 2)
            _buildPodiumPlace(
              context,
              topThree[2],
              3,
              120,
              Colors.orange.shade300,
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(
    BuildContext context,
    models.LeaderboardEntry entry,
    int position,
    double height,
    Color color,
  ) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final isCurrentUser = authProvider.user?.id == entry.userId;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Avatar and crown
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: isCurrentUser
                        ? Colors.blue.shade100
                        : Colors.grey.shade200,
                    child: Text(
                      entry.displayName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isCurrentUser
                            ? Colors.blue.shade600
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                if (position == 1)
                  Icon(Icons.emoji_events, color: Colors.amber, size: 24),
              ],
            ),
            const SizedBox(height: 8),

            // Name
            SizedBox(
              width: 80,
              child: Text(
                entry.displayName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: isCurrentUser
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isCurrentUser ? Colors.blue.shade600 : null,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Score
            Text(
              entry.score.toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),

            // Podium base
            Container(
              width: 80,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '#$position',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRankingsList(
    BuildContext context,
    List<models.LeaderboardEntry> entries,
    bool isWeekly,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${isWeekly ? 'Weekly ' : ''}Rankings',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _buildRankingCard(context, entry, index + 1);
          },
        ),
      ],
    );
  }

  Widget _buildRankingCard(
    BuildContext context,
    models.LeaderboardEntry entry,
    int position,
  ) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final isCurrentUser = authProvider.user?.id == entry.userId;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isCurrentUser ? Colors.blue.shade50 : null,
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rank badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getRankColor(position),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      position.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isCurrentUser
                      ? Colors.blue.shade100
                      : Colors.grey.shade200,
                  child: Text(
                    entry.displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCurrentUser
                          ? Colors.blue.shade600
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              entry.displayName,
              style: TextStyle(
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                color: isCurrentUser ? Colors.blue.shade600 : null,
              ),
            ),
            subtitle: entry.organizationName != null
                ? Text(entry.organizationName!)
                : null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  entry.score.toString(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getRankColor(position),
                  ),
                ),
                const Text(
                  'points',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            onTap: isCurrentUser
                ? null
                : () => _showUserProfile(context, entry),
          ),
        );
      },
    );
  }

  Color _getRankColor(int position) {
    switch (position) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey.shade400;
      case 3:
        return Colors.orange.shade300;
      default:
        return Colors.blue.shade600;
    }
  }

  void _showUserProfile(BuildContext context, models.LeaderboardEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade200,
              child: Text(
                entry.displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.displayName,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.organizationName != null) ...[
              _buildProfileField(
                context,
                'Organization',
                entry.organizationName!,
              ),
              const SizedBox(height: 12),
            ],
            _buildProfileField(context, 'Total Score', entry.score.toString()),
            const SizedBox(height: 12),
            _buildProfileField(context, 'Rank', entry.rank.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
