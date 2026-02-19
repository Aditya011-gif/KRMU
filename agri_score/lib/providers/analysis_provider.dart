import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analysis_model.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

/// State for analysis operations
class AnalysisState {
  final bool isLoading;
  final bool isAnalyzing;
  final AnalysisModel? latestResult;
  final List<AnalysisModel> history;
  final String? error;

  const AnalysisState({
    this.isLoading = false,
    this.isAnalyzing = false,
    this.latestResult,
    this.history = const [],
    this.error,
  });

  AnalysisState copyWith({
    bool? isLoading,
    bool? isAnalyzing,
    AnalysisModel? latestResult,
    List<AnalysisModel>? history,
    String? error,
  }) {
    return AnalysisState(
      isLoading: isLoading ?? this.isLoading,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      latestResult: latestResult ?? this.latestResult,
      history: history ?? this.history,
      error: error,
    );
  }
}

class AnalysisNotifier extends StateNotifier<AnalysisState> {
  final ApiService _apiService;

  AnalysisNotifier(this._apiService) : super(const AnalysisState());

  /// Perform land analysis
  Future<void> analyzeLand(double latitude, double longitude) async {
    state = state.copyWith(isAnalyzing: true, error: null);
    try {
      final result = await _apiService.analyzeLand(
        latitude: latitude,
        longitude: longitude,
      );
      state = state.copyWith(
        isAnalyzing: false,
        latestResult: result,
        history: [result, ...state.history],
      );
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        error: 'Analysis failed. Please check your connection and try again.',
      );
    }
  }

  /// Load analysis history
  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final analyses = await _apiService.getAnalyses();
      state = state.copyWith(
        isLoading: false,
        history: analyses,
        latestResult: analyses.isNotEmpty ? analyses.first : state.latestResult,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load history. Please try again.',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final analysisProvider = StateNotifierProvider<AnalysisNotifier, AnalysisState>(
  (ref) {
    return AnalysisNotifier(ref.read(apiServiceProvider));
  },
);
