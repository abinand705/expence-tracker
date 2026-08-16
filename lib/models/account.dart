import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  final String id;
  final String name;
  final String bankName;
  final String accountNumber;
  final String accountType; // Savings, Current, Credit Card
  final double balance; // Legacy fallback
  final double currentBalance; // Authoritative balance
  final String balanceSource; // 'sms', 'statement', 'manual'
  final DateTime? balanceUpdatedAt;
  final DateTime? lastStatementImportAt;
  final String currency;
  final Color accentColor;
  final bool isAutoDiscovered;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    this.balance = 0.0,
    this.currentBalance = 0.0,
    this.balanceSource = 'manual',
    this.balanceUpdatedAt,
    this.lastStatementImportAt,
    this.currency = 'INR',
    required this.accentColor,
    this.isAutoDiscovered = false,
    this.createdAt,
    this.updatedAt,
  });

  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '****${accountNumber.substring(accountNumber.length - 4)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountType': accountType,
      'balance': balance,
      'currentBalance': currentBalance,
      'balanceSource': balanceSource,
      'balanceUpdatedAt': balanceUpdatedAt != null ? Timestamp.fromDate(balanceUpdatedAt!) : null,
      'lastStatementImportAt': lastStatementImportAt != null ? Timestamp.fromDate(lastStatementImportAt!) : null,
      'currency': currency,
      'accentColor': accentColor.toARGB32(),
      'isAutoDiscovered': isAutoDiscovered,
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
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['currentBalance'] as num?)?.toDouble() ?? (map['balance'] as num?)?.toDouble() ?? 0.0,
      balanceSource: map['balanceSource'] ?? 'manual',
      balanceUpdatedAt: map['balanceUpdatedAt'] != null ? (map['balanceUpdatedAt'] as Timestamp).toDate() : null,
      lastStatementImportAt: map['lastStatementImportAt'] != null ? (map['lastStatementImportAt'] as Timestamp).toDate() : null,
      currency: map['currency'] ?? 'INR',
      accentColor: map['accentColor'] != null ? Color(map['accentColor']) : Colors.blue,
      isAutoDiscovered: map['isAutoDiscovered'] ?? false,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
