import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/bank_detection_service.dart';

void main() {
  group('BankDetectionService', () {
    final service = BankDetectionService();

    test('Identifies Kerala Gramin Bank from normalized sender variations', () {
      final variations = [
        'KGBANK',
        'BX-KGBANK-S',
        'AD-KGBANK-S',
        'AX-KGBANK-T',
        'AX-KGBANK-S',
        'BZ-KGBANK-S',
        'JD-KGBANK-S',
        'BX-KGBANK-T',
        'JX-KGBANK-S',
        'JM-KGBANK-S',
        'BZ-KGBANK-T',
      ];

      for (final sender in variations) {
        final bank = service.identifyBank(sender, 'Some message text');
        expect(bank, isNotNull, reason: 'Failed to identify $sender');
        expect(bank!.id, 'kgbank');
        expect(bank.displayName, 'Kerala Gramin Bank');
      }
    });

    test('Identifies Bank of Baroda from normalized sender variations', () {
      final variations = [
        'BOBSMS',
        'JD-BOBSMS-S',
        'JX-BOBSMS-S',
        'VM-BOBSMS-S',
        'JK-BOBSMS-S',
      ];

      for (final sender in variations) {
        final bank = service.identifyBank(sender, 'Some message text');
        expect(bank, isNotNull, reason: 'Failed to identify $sender');
        expect(bank!.id, 'bob');
        expect(bank.displayName, 'Bank of Baroda');
      }
    });

    test('Ignores unrelated senders', () {
      final bank = service.identifyBank('Google', 'Your OTP is 123456');
      expect(bank, isNull);
    });

    test('Identifies other banks correctly', () {
      final hdfc = service.identifyBank('JD-HDFCBK', 'Message');
      expect(hdfc?.id, 'hdfc');

      final sbi = service.identifyBank('VM-SBIINB', 'Message');
      expect(sbi?.id, 'sbi');

      final icici = service.identifyBank('AD-ICICIB', 'Message');
      expect(icici?.id, 'icici');

      final axis = service.identifyBank('AXISBK', 'Message');
      expect(axis?.id, 'axis');
    });
  });
}
