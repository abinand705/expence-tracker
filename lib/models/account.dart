import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      'accentColor': accentColor.toARGB32(),
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
      accountType: map['accountType'] ?? '',
      balance: (map['balance'] as num).toDouble(),
      currency: map['currency'] ?? 'INR',
      accentColor: map['accentColor'] != null ? Color(map['accentColor']) : Colors.blue,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
