import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  final String id;
  final String name;
  final String bankName;
  final String accountNumber;
  final String accountType; // Savings, Current, Credit Card, Loan
  final String? nickname;   // Optional user-friendly label
  final double balance; // Legacy fallback
  final double currentBalance; // Authoritative balance
  final String balanceSource; // 'sms', 'statement', 'manual'
  final DateTime? balanceUpdatedAt;
  final DateTime? lastStatementImportAt;
  final String currency;
  final Color accentColor;
  final bool isAutoDiscovered;

  /// Whether SMS transaction tracking is enabled for this account.
  ///
  /// IMPORTANT: Defaults to FALSE on new accounts.
  /// Only set to true after the user has confirmed at least one SMS rule.
  /// When false, NO incoming SMS will create a transaction for this account.
  final bool smsTrackingEnabled;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    this.nickname,
    this.balance = 0.0,
    this.currentBalance = 0.0,
    this.balanceSource = 'manual',
    this.balanceUpdatedAt,
    this.lastStatementImportAt,
    this.currency = 'INR',
    required this.accentColor,
    this.isAutoDiscovered = false,
    this.smsTrackingEnabled = false, // OFF by default — user must configure rules
    this.createdAt,
    this.updatedAt,
  });

  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '****${accountNumber.substring(accountNumber.length - 4)}';
  }

  /// Returns last 3 digits of account number for matching purposes.
  String? get last3Digits {
    final digits = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 3) return null;
    return digits.substring(digits.length - 3);
  }

  /// Display name: nickname if set, otherwise name.
  String get displayName => (nickname != null && nickname!.trim().isNotEmpty)
      ? nickname!.trim()
      : name;

  Account copyWith({
    String? id,
    String? name,
    String? bankName,
    String? accountNumber,
    String? accountType,
    String? nickname,
    double? balance,
    double? currentBalance,
    String? balanceSource,
    DateTime? balanceUpdatedAt,
    DateTime? lastStatementImportAt,
    String? currency,
    Color? accentColor,
    bool? isAutoDiscovered,
    bool? smsTrackingEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountType: accountType ?? this.accountType,
      nickname: nickname ?? this.nickname,
      balance: balance ?? this.balance,
      currentBalance: currentBalance ?? this.currentBalance,
      balanceSource: balanceSource ?? this.balanceSource,
      balanceUpdatedAt: balanceUpdatedAt ?? this.balanceUpdatedAt,
      lastStatementImportAt: lastStatementImportAt ?? this.lastStatementImportAt,
      currency: currency ?? this.currency,
      accentColor: accentColor ?? this.accentColor,
      isAutoDiscovered: isAutoDiscovered ?? this.isAutoDiscovered,
      smsTrackingEnabled: smsTrackingEnabled ?? this.smsTrackingEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountType': accountType,
      'nickname': nickname,
      'balance': balance,
      'currentBalance': currentBalance,
      'balanceSource': balanceSource,
      'balanceUpdatedAt': balanceUpdatedAt != null ? Timestamp.fromDate(balanceUpdatedAt!) : null,
      'lastStatementImportAt': lastStatementImportAt != null ? Timestamp.fromDate(lastStatementImportAt!) : null,
      'currency': currency,
      'accentColor': accentColor.toARGB32(),
      'isAutoDiscovered': isAutoDiscovered,
      'smsTrackingEnabled': smsTrackingEnabled,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Account(
      id: map['id'],
      name: map['name'] ?? '',
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      accountType: map['accountType'] ?? 'Savings',
      nickname: map['nickname'] as String?,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['currentBalance'] as num?)?.toDouble() ?? (map['balance'] as num?)?.toDouble() ?? 0.0,
      balanceSource: map['balanceSource'] ?? 'manual',
      balanceUpdatedAt: parseDate(map['balanceUpdatedAt']),
      lastStatementImportAt: parseDate(map['lastStatementImportAt']),
      currency: map['currency'] ?? 'INR',
      accentColor: map['accentColor'] != null ? Color(map['accentColor']) : Colors.blue,
      isAutoDiscovered: map['isAutoDiscovered'] ?? false,
      // Default false for backward compatibility — existing accounts without
      // smsTrackingEnabled field start as disabled until user configures rules.
      smsTrackingEnabled: map['smsTrackingEnabled'] ?? false,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
