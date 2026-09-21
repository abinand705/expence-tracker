// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/gemini_config.dart';
import '../models/gemini_decision.dart';
import '../models/transaction_candidate.dart';
import 'gemini_config_service.dart';

typedef GeminiApiCaller = Future<String?> Function(String prompt);

/// Service for classifying ambiguous transaction candidates using Firebase Gemini AI Logic.
///
/// Principles:
/// - NEVER directly writes to Firestore.
/// - Sends only minimal required privacy-safe candidate data (no raw SMS bodies).
/// - Enforces strict JSON response parsing.
/// - Handles timeouts, quota limits, and network errors gracefully by falling back to UNCERTAIN.
class GeminiTransactionService {
  final GeminiConfigService configService;
  final GeminiApiCaller? _mockCaller; // For unit/widget tests

  GeminiTransactionService({
    GeminiConfigService? configService,
    GeminiApiCaller? mockCaller,
  })  : configService = configService ?? GeminiConfigService(),
        _mockCaller = mockCaller;

  static const String systemInstruction = '''
You are a financial SMS transaction classification engine for a personal expense application.
Your task is NOT to create financial records.
Your task is only to analyze a small group of transaction candidates and determine whether they describe the same underlying financial event.
Never invent transaction data.
Use only the supplied candidate information.
Consider:
transaction reference numbers
UPI references
account identifiers
amount
debit/credit type
merchant
bank
timestamps
transaction lifecycle language
reversal/refund/failure/success states
Possible classifications:
SAME_TRANSACTION
SEPARATE_TRANSACTIONS
TRANSACTION_UPDATE
NON_TRANSACTION
UNCERTAIN
If multiple SMS messages are notifications about the same debit/credit, classify them as SAME_TRANSACTION.
If one message represents a payment initiation and another represents successful completion of the same payment, classify them as TRANSACTION_UPDATE rather than creating another transaction.
If a transaction is reversed or refunded, identify it as a lifecycle update when the evidence supports that conclusion.
If there is insufficient evidence, return UNCERTAIN.
Never assume that two transactions are duplicates only because their amounts are equal.
Return JSON only.
''';

  /// Classifies a small group of ambiguous transaction candidates.
  Future<GeminiDecision> classifyCandidates(List<TransactionCandidate> candidates) async {
    final candidateIds = candidates.map((c) => c.candidateId).toList();
    if (candidates.isEmpty) {
      return GeminiDecision.uncertain(
        candidateIds: [],
        reason: 'No candidates supplied',
      );
    }

    if (!configService.isEnabled) {
      debugPrint('[AI] Gemini AI disabled by configuration. Returning UNCERTAIN fallback.');
      return GeminiDecision.uncertain(
        candidateIds: candidateIds,
        reason: 'Gemini AI is disabled in settings',
      );
    }

    final config = configService.config;
    final prompt = _buildPrompt(candidates);

    int attempts = 0;
    final maxAttempts = 1 + config.retryCount;

    while (attempts < maxAttempts) {
      attempts++;
      try {
        debugPrint('[AI] Calling Gemini (attempt $attempts/$maxAttempts) for ${candidates.length} candidates...');
        final rawResponse = await _callModel(prompt, config);

        if (rawResponse == null || rawResponse.trim().isEmpty) {
          throw Exception('Empty response from Gemini');
        }

        final decision = _parseResponse(rawResponse, candidateIds);
        configService.incrementAiDecisions();
        if (decision.classification == GeminiClassification.sameTransaction ||
            decision.classification == GeminiClassification.transactionUpdate) {
          configService.incrementAiAssisted();
        }
        return decision;
      } catch (e) {
        debugPrint('[AI] Error in Gemini call (attempt $attempts): $e');
        if (attempts >= maxAttempts) {
          return GeminiDecision.uncertain(
            candidateIds: candidateIds,
            reason: 'AI classification failed: $e',
          );
        }
      }
    }

    return GeminiDecision.uncertain(
      candidateIds: candidateIds,
      reason: 'AI classification failed after retries',
    );
  }

  Future<String?> _callModel(String prompt, GeminiConfig config) async {
    final caller = _mockCaller;
    if (caller != null) {
      return await caller(prompt).timeout(config.timeout);
    }

    try {
      final googleAI = FirebaseAI.googleAI();
      final model = googleAI.generativeModel(
        model: config.modelName,
        systemInstruction: Content.system(systemInstruction),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(config.timeout);

      return response.text;
    } catch (e) {
      debugPrint('[AI] FirebaseAI.googleAI call failed: $e');
      rethrow;
    }
  }

  String _buildPrompt(List<TransactionCandidate> candidates) {
    final summaries = candidates.map((c) => c.toAiSummaryMap()).toList();
    final jsonContent = jsonEncode(summaries);

    return '''
Analyze the following transaction candidates and return a JSON object with:
- "classification": one of "SAME_TRANSACTION", "SEPARATE_TRANSACTIONS", "TRANSACTION_UPDATE", "NON_TRANSACTION", "UNCERTAIN"
- "confidence": float between 0.0 and 1.0
- "groupCandidateIds": array of candidate IDs belonging together
- "reason": brief explanation
- "canonicalCandidateId": ID of the candidate containing the most accurate/complete info

Transaction candidates:
$jsonContent
''';
  }

  GeminiDecision _parseResponse(String text, List<String> originalIds) {
    try {
      // Clean up markdown code block wrappers if any (e.g. ```json ... ```)
      var cleaned = text.trim();
      if (cleaned.startsWith('```')) {
        final firstNewline = cleaned.indexOf('\n');
        if (firstNewline != -1) {
          cleaned = cleaned.substring(firstNewline + 1);
        }
        if (cleaned.endsWith('```')) {
          cleaned = cleaned.substring(0, cleaned.length - 3);
        }
      }
      cleaned = cleaned.trim();

      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      final decision = GeminiDecision.fromJson(decoded);

      // Sanity check: Ensure returned candidate IDs are valid
      final validIds = decision.groupCandidateIds
          .where((id) => originalIds.contains(id))
          .toList();

      return GeminiDecision(
        classification: decision.classification,
        confidence: decision.confidence,
        groupCandidateIds: validIds.isNotEmpty ? validIds : originalIds,
        reason: decision.reason,
        canonicalCandidateId: decision.canonicalCandidateId != null &&
                originalIds.contains(decision.canonicalCandidateId)
            ? decision.canonicalCandidateId
            : (validIds.isNotEmpty ? validIds.first : originalIds.first),
      );
    } catch (e) {
      debugPrint('[AI] Failed to parse Gemini JSON response: $e\nRaw text: $text');
      throw FormatException('Malformed JSON response from AI: $e');
    }
  }
}
