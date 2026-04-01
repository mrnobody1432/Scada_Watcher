import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/alert_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/alert_model.dart';

class SearchProvider extends StateNotifier<String> {
  SearchProvider() : super('');

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

final searchQueryProvider = StateNotifierProvider<SearchProvider, String>((
  ref,
) {
  return SearchProvider();
});

final filteredAlertsProvider =
    Provider.family<List<AlertModel>, List<AlertModel>>((ref, alerts) {
      final query = ref.watch(searchQueryProvider);

      if (query.isEmpty) {
        return alerts;
      }

      final lowerQuery = query.toLowerCase();

      return alerts.where((alert) {
        return alert.name.toLowerCase().contains(lowerQuery) ||
            alert.description.toLowerCase().contains(lowerQuery) ||
            alert.source.toLowerCase().contains(lowerQuery) ||
            alert.tagName.toLowerCase().contains(lowerQuery) ||
            alert.severity.toLowerCase().contains(lowerQuery);
      }).toList();
    });

class AlertSearchDelegate extends SearchDelegate<AlertModel?> {
  final List<AlertModel> alerts;

  AlertSearchDelegate(this.alerts);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return AppTheme.darkTheme.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white38),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return Container(
        color: const Color(0xFF0F0F0F),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
                child: const Icon(Icons.search_rounded, size: 64, color: Colors.white24),
              ),
              const SizedBox(height: 24),
              const Text(
                'Search Alerts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                'Type machine name, tag, or severity',
                style: TextStyle(color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    }

    final lowerQuery = query.toLowerCase();
    final results = alerts.where((alert) {
      return alert.name.toLowerCase().contains(lowerQuery) ||
          alert.description.toLowerCase().contains(lowerQuery) ||
          alert.source.toLowerCase().contains(lowerQuery) ||
          alert.tagName.toLowerCase().contains(lowerQuery) ||
          alert.severity.toLowerCase().contains(lowerQuery);
    }).toList();

    if (results.isEmpty) {
      return Container(
        color: const Color(0xFF0F0F0F),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.criticalColor.withOpacity(0.05),
                ),
                child: const Icon(Icons.search_off_rounded, size: 64, color: AppTheme.criticalColor),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Results Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'No matches for "$query"',
                style: const TextStyle(color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF0F0F0F),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final alert = results[index];
          return AlertCard(
            alert: alert,
            onTap: () {
              close(context, alert);
            },
          );
        },
      ),
    );
  }
}

