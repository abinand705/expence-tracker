/// Configuration for Gemini AI Transaction Intelligence.
class GeminiConfig {
  final bool enabled;
  final String modelName;
  final double confidenceThreshold;
  final double reviewThreshold;
  final int maxMessagesPerRequest;
  final int maxCandidatesPerRequest;
  final Duration timeout;
  final int retryCount;

  const GeminiConfig({
    this.enabled = true,
    this.modelName = 'gemini-2.5-flash',
    this.confidenceThreshold = 0.90,
    this.reviewThreshold = 0.70,
    this.maxMessagesPerRequest = 10,
    this.maxCandidatesPerRequest = 5,
    this.timeout = const Duration(seconds: 15),
    this.retryCount = 1,
  });

  GeminiConfig copyWith({
    bool? enabled,
    String? modelName,
    double? confidenceThreshold,
    double? reviewThreshold,
    int? maxMessagesPerRequest,
    int? maxCandidatesPerRequest,
    Duration? timeout,
    int? retryCount,
  }) {
    return GeminiConfig(
      enabled: enabled ?? this.enabled,
      modelName: modelName ?? this.modelName,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      reviewThreshold: reviewThreshold ?? this.reviewThreshold,
      maxMessagesPerRequest: maxMessagesPerRequest ?? this.maxMessagesPerRequest,
      maxCandidatesPerRequest: maxCandidatesPerRequest ?? this.maxCandidatesPerRequest,
      timeout: timeout ?? this.timeout,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'modelName': modelName,
      'confidenceThreshold': confidenceThreshold,
      'reviewThreshold': reviewThreshold,
      'maxMessagesPerRequest': maxMessagesPerRequest,
      'maxCandidatesPerRequest': maxCandidatesPerRequest,
      'timeoutSeconds': timeout.inSeconds,
      'retryCount': retryCount,
    };
  }

  factory GeminiConfig.fromJson(Map<String, dynamic> json) {
    return GeminiConfig(
      enabled: json['enabled'] as bool? ?? true,
      modelName: json['modelName'] as String? ?? 'gemini-2.5-flash',
      confidenceThreshold: (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.90,
      reviewThreshold: (json['reviewThreshold'] as num?)?.toDouble() ?? 0.70,
      maxMessagesPerRequest: json['maxMessagesPerRequest'] as int? ?? 10,
      maxCandidatesPerRequest: json['maxCandidatesPerRequest'] as int? ?? 5,
      timeout: Duration(seconds: json['timeoutSeconds'] as int? ?? 15),
      retryCount: json['retryCount'] as int? ?? 1,
    );
  }
}
