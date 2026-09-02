import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/sms_service.dart';
import 'package:expense_tracker/models/sms_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmsService Startup & State Tests', () {
    late SmsService service;

    setUp(() {
      service = SmsService();
    });

    test('SmsLoadingState has distinct states', () {
      expect(SmsLoadingState.values, containsAll([
        SmsLoadingState.notLoaded,
        SmsLoadingState.loading,
        SmsLoadingState.loaded,
        SmsLoadingState.empty,
        SmsLoadingState.permissionDenied,
        SmsLoadingState.error,
      ]));
    });

    test('setConversationsForTesting caches list and updates state to loaded', () {
      final mockConvs = [
        Conversation(
          id: 'test_1',
          senderName: 'HDFC Bank',
          senderNumber: 'HDFCBK',
          avatarColor: Colors.blue,
          messages: [
            Message(
              id: 'm1',
              text: 'Rs. 500 debited from a/c 1234',
              timestamp: DateTime.now(),
              isMe: false,
            ),
          ],
        ),
      ];

      service.setConversationsForTesting(mockConvs);
      expect(service.loadingState, SmsLoadingState.loaded);
      expect(service.conversations.length, 1);
      expect(service.filteredConversations.length, 1);
    });

    test('setConversationsForTesting with empty list updates state to empty', () {
      service.setConversationsForTesting([]);
      expect(service.loadingState, SmsLoadingState.empty);
      expect(service.conversations.isEmpty, isTrue);
      expect(service.filteredConversations.isEmpty, isTrue);
    });

    test('loadingState test helper can simulate loading and error states', () {
      service.setLoadingStateForTesting(SmsLoadingState.loading);
      expect(service.isLoading, isTrue);
      expect(service.loadingState, SmsLoadingState.loading);

      service.setLoadingStateForTesting(SmsLoadingState.error);
      expect(service.isLoading, isFalse);
      expect(service.loadingState, SmsLoadingState.error);

      service.setLoadingStateForTesting(SmsLoadingState.permissionDenied);
      expect(service.isLoading, isFalse);
      expect(service.loadingState, SmsLoadingState.permissionDenied);
    });
  });
}
