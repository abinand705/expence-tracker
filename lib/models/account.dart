import 'package:flutter/material.dart';

class Account {
  final String id;
  final String name;
  final String bankName;
  final String accountNumber;
  final String accountType;
  final double balance;
  final String currency;
  final Color accentColor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    required this.balance,
    this.currency = 'INR',
    required this.accentColor,
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
      'currency': currency,
      'accentColor': accentColor.value,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'] ?? '',
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      accountType: map['accountType'] ?? '',
      balance: (map['balance'] as num).toDouble(),
      currency: map['currency'] ?? 'INR',
      accentColor: map['accentColor'] != null ? Color(map['accentColor']) : Colors.blue,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }
}
