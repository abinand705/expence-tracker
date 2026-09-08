import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/account_repository.dart';
import '../repositories/sms_rule_repository.dart';
import '../models/account.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../services/bank_statement_service.dart';
import 'import_statement_preview_screen.dart';
import 'account_create_screen.dart';
import 'account_sms_config_screen.dart';
import '../services/sms_service.dart';

class MyAccountsScreen extends StatefulWidget {
  const MyAccountsScreen({super.key});

  @override
  State<MyAccountsScreen> createState() => _MyAccountsScreenState();
}

class _MyAccountsScreenState extends State<MyAccountsScreen> {
  final AccountRepository _accountRepo = AccountRepository();
  final SmsRuleRepository _ruleRepo = SmsRuleRepository();

  List<Account> _accounts = [];

  bool _isLoading = true;
  StreamSubscription<List<Account>>? _accountSubscription;

  // Cache: accountId → rule count
  final Map<String, int> _ruleCountCache = {};

  @override
  void initState() {
    super.initState();
    _accountSubscription = _accountRepo.watchAccounts().listen(
      (accounts) {
        if (mounted) {
          setState(() {
            _accounts = accounts;
            _isLoading = false;
          });
          _loadRuleCounts(accounts);
        }
      },
      onError: (e) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _loadRuleCounts([List<Account>? accounts]) async {
    final list = accounts ?? _accounts;
    for (final acc in list) {
      try {
        final rules = await _ruleRepo.getRules(acc.id);
        if (mounted) {
          setState(() => _ruleCountCache[acc.id] = rules.length);
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _accountSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshAccounts() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          title: Text('My Accounts', style: AppTypography.headlineMd),
          elevation: 0,
        ),
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    final totalNetWorth = _accounts.fold(0.0, (sum, acc) => sum + acc.currentBalance);
    final currencyFormatter = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: Text('My Accounts', style: AppTypography.headlineMd),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAccounts,
        color: cs.primary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNetWorthCard(context, currencyFormatter, totalNetWorth),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Accounts',
                    style: AppTypography.headlineMd.copyWith(color: cs.onSurface),
                  ),
                  // SMS tracking summary badge
                  if (_accounts.isNotEmpty)
                    _buildSmsSummaryChip(cs),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Info banner
              _buildSmsBanner(cs),
              const SizedBox(height: AppSpacing.md),
              if (_accounts.isEmpty)
                _buildNoAccountsCard(context, cs)
              else
                ..._accounts.map((acc) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: InkWell(
                      onTap: () => _showAccountOptionsModal(context, acc),
                      borderRadius: BorderRadius.circular(12),
                      child: _buildLinkedAccountCard(
                        context: context,
                        account: acc,
                        ruleCount: _ruleCountCache[acc.id],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.lg),
              _buildAddAccountButton(context),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmsSummaryChip(ColorScheme cs) {
    final smsEnabled = _accounts.where((a) => a.smsTrackingEnabled).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: smsEnabled > 0
            ? AppColors.successGreen.withValues(alpha: 0.1)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sms,
              size: 12,
              color: smsEnabled > 0 ? AppColors.successGreen : cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '$smsEnabled SMS active',
            style: AppTypography.labelMuted.copyWith(
              fontSize: 11,
              color: smsEnabled > 0 ? AppColors.successGreen : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsBanner(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: cs.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'MoneyTrack never auto-creates accounts from SMS. '
              'Add an account here, then configure SMS rules to enable automatic tracking.',
              style: AppTypography.bodyMd.copyWith(
                  color: cs.onSurface, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetWorthCard(BuildContext context, NumberFormat formatter, double totalNetWorth) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL NET WORTH',
            style: AppTypography.labelCaps.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _formatCurrency(totalNetWorth),
            style: AppTypography.displayCurrency.copyWith(
                color: totalNetWorth < 0 ? AppColors.errorRed : cs.primary, 
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _refreshAccounts();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Balances updated.')),
                    );
                  },
                  icon: Icon(Icons.sync, color: cs.onPrimary, size: 16),
                  label: Text('Refresh Balances',
                      style: AppTypography.labelCaps.copyWith(
                          color: cs.onPrimary, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToCreateAccount(context),
                  icon: Icon(Icons.add, color: cs.onSurfaceVariant, size: 16),
                  label: Text('Add Account',
                      style: AppTypography.labelCaps.copyWith(
                          color: cs.onSurface, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    final numFormat = NumberFormat('#,##0.00');
    if (amount < 0) {
      return '-₹ ${numFormat.format(-amount)}';
    }
    return '₹ ${numFormat.format(amount)}';
  }

  Widget _buildLinkedAccountCard({
    required BuildContext context,
    required Account account,
    int? ruleCount,
  }) {
    final cs = Theme.of(context).colorScheme;

    // SMS status
    Widget smsStatus;
    if (account.smsTrackingEnabled) {
      smsStatus = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
                color: AppColors.successGreen, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            'SMS Active${ruleCount != null ? ' ($ruleCount rules)' : ''}',
            style: AppTypography.labelMuted.copyWith(
                fontSize: 10, color: AppColors.successGreen),
          ),
        ],
      );
    } else if (ruleCount != null && ruleCount > 0) {
      smsStatus = Text(
        'SMS Disabled',
        style: AppTypography.labelMuted.copyWith(
            fontSize: 10, color: cs.onSurfaceVariant),
      );
    } else {
      smsStatus = Text(
        'SMS Not Configured',
        style: AppTypography.labelMuted.copyWith(
            fontSize: 10, color: cs.error.withValues(alpha: 0.8)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.level1,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: account.accentColor, width: 4)),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: account.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.account_balance, color: account.accentColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.bankName,
                        style: AppTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w600, color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      '${account.accountType} • ${account.maskedAccountNumber}',
                      style: AppTypography.labelMuted.copyWith(
                          color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    smsStatus,
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(account.currentBalance),
                    style: AppTypography.headlineMd.copyWith(
                      color: account.currentBalance < 0 ? AppColors.errorRed : cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoAccountsCard(BuildContext context, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Icon(Icons.account_balance_outlined,
              size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text('No accounts yet', style: AppTypography.headlineMd),
          const SizedBox(height: 4),
          Text(
            'Add your bank account to start tracking transactions automatically from SMS.',
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => _navigateToCreateAccount(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAccountButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _navigateToCreateAccount(context),
      child: CustomPaint(
        painter: DashedRectPainter(
            color: cs.outlineVariant.withAlpha(120), strokeWidth: 1, gap: 5),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          color: Colors.transparent,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Add another account',
                  style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Configure SMS rules for automatic tracking',
                  style:
                      AppTypography.labelMuted.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToCreateAccount(BuildContext context,
      {Account? accountToEdit}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AccountCreateScreen(accountToEdit: accountToEdit),
      ),
    );
    if (result == true && mounted) {
      // Accounts stream will auto-update
      SmsService().refreshAccounts();
      _loadRuleCounts();
    }
  }

  void _showAccountOptionsModal(BuildContext context, Account account) {
    final cs = Theme.of(context).colorScheme;
    final ruleCount = _ruleCountCache[account.id] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: cs.onSurfaceVariant,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: AppSpacing.lg),
                Text(account.bankName,
                    style: AppTypography.headlineMd.copyWith(color: cs.onSurface)),
                Text(
                  '${account.accountType} • ${account.maskedAccountNumber}',
                  style: AppTypography.labelMuted,
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  leading: Icon(Icons.sms, color: cs.primary),
                  title: Text('SMS Recognition', style: TextStyle(color: cs.onSurface)),
                  subtitle: Text(
                    account.smsTrackingEnabled
                        ? 'Active — $ruleCount rule${ruleCount != 1 ? "s" : ""}'
                        : ruleCount > 0
                            ? 'Disabled — $ruleCount rule${ruleCount != 1 ? "s" : ""} configured'
                            : 'Not configured',
                    style: TextStyle(
                      fontSize: 12,
                      color: account.smsTrackingEnabled
                          ? AppColors.successGreen
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AccountSmsConfigScreen(account: account),
                      ),
                    ).then((_) => _loadRuleCounts(_accounts));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.edit, color: cs.primary),
                  title: Text('Edit Account', style: TextStyle(color: cs.onSurface)),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToCreateAccount(context, accountToEdit: account);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.file_upload, color: cs.primary),
                  title: Text('Import Bank Statement',
                      style: TextStyle(color: cs.onSurface)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _handleImportStatement(context, account);
                  },
                ),
                if (account.isAutoDiscovered)
                  ListTile(
                    leading: const Icon(Icons.merge_type, color: Colors.orange),
                    title: const Text('Auto-Created Account',
                        style: TextStyle(color: Colors.orange)),
                    subtitle: const Text(
                        'This account was auto-created from SMS. Consider creating a manual account and migrating.',
                        style: TextStyle(fontSize: 11)),
                    onTap: () => Navigator.pop(context),
                  ),
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.errorRed),
                  title: const Text('Delete Account',
                      style: TextStyle(color: AppColors.errorRed)),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await _accountRepo.deleteAccount(account.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account deleted')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleImportStatement(
      BuildContext context, Account account) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: AppSpacing.md),
            Text('Reading and parsing statement...'),
          ],
        ),
      ),
    );

    try {
      final service = BankStatementService();
      final parsedStatement = await service.pickAndParseStatement(account);

      if (context.mounted) Navigator.pop(context);

      if (parsedStatement != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImportStatementPreviewScreen(
              account: account,
              parsedStatement: parsedStatement,
              fileName: 'Bank Statement',
              fileType: 'document',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Failed'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter(
      {required this.color, required this.strokeWidth, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(12)));

    final Path dashedPath = Path();
    bool draw = true;
    double distance = 0;

    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final double nextDistance = distance + gap;
        if (draw) {
          dashedPath.addPath(
            metric.extractPath(distance, nextDistance),
            Offset.zero,
          );
        }
        distance = nextDistance;
        draw = !draw;
      }
      distance = 0;
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
