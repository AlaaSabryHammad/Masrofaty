import 'package:flutter_test/flutter_test.dart';
import 'package:masrofaty/core/services/auth_service.dart';
import 'package:masrofaty/core/services/bill_parser_service.dart';
import 'package:masrofaty/core/services/debt_communication_service.dart';
import 'package:masrofaty/core/services/email_otp_service.dart';
import 'package:masrofaty/core/utils/currency_formatter.dart';
import 'package:masrofaty/models/contact_model.dart';
import 'package:masrofaty/models/debt_model.dart';
import 'package:masrofaty/models/goal_model.dart';
import 'package:masrofaty/core/services/storage_service.dart';
import 'package:masrofaty/models/transaction_model.dart';
import 'package:masrofaty/models/user_model.dart';
import 'package:masrofaty/models/user_profile_model.dart';
import 'package:masrofaty/providers/auth_provider.dart';
import 'package:masrofaty/providers/user_profile_provider.dart';
import 'package:masrofaty/models/workspace_model.dart';
import 'package:masrofaty/models/saas_plan_model.dart';
import 'package:masrofaty/providers/workspace_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('formats regular amount correctly with symbol', () {
      final result = CurrencyFormatter.format(1250.5, symbol: 'ر.س');
      expect(result, contains('1,250.50'));
      expect(result, contains('ر.س'));
    });

    test('hides amount when privacy mode is enabled', () {
      final result = CurrencyFormatter.format(5000, symbol: 'ر.س', hide: true);
      expect(result, '•••••• ر.س');
    });

    test('formats compact amounts correctly', () {
      final result = CurrencyFormatter.formatCompact(25000, symbol: 'ر.س');
      expect(result, contains('25K'));
      expect(result, contains('ر.س'));
    });
  });

  group('DebtModel Calculations Tests', () {
    test('calculates remaining amount and progress accurately with installments', () {
      final debt = DebtModel(
        id: 'test_debt_1',
        personName: 'خالد',
        totalAmount: 1000.0,
        type: 'lent',
        createdDate: DateTime.now(),
        payments: [
          DebtPayment(id: 'p1', amount: 250.0, date: DateTime.now()),
          DebtPayment(id: 'p2', amount: 250.0, date: DateTime.now()),
        ],
      );

      expect(debt.paidAmount, 500.0);
      expect(debt.remainingAmount, 500.0);
      expect(debt.progress, 0.5);
      expect(debt.isSettled, false);
      expect(debt.isLent, true);
      expect(debt.isBorrowed, false);
    });

    test('marks debt as settled when payments cover total', () {
      final debt = DebtModel(
        id: 'test_debt_2',
        personName: 'شركة التقسيط',
        totalAmount: 500.0,
        type: 'borrowed',
        createdDate: DateTime.now(),
        payments: [
          DebtPayment(id: 'p1', amount: 500.0, date: DateTime.now()),
        ],
      );

      expect(debt.remainingAmount, 0.0);
      expect(debt.progress, 1.0);
      expect(debt.isSettled, true);
      expect(debt.isBorrowed, true);
    });

    test('detects overdue debts accurately', () {
      final overdueDebt = DebtModel(
        id: 'test_debt_3',
        personName: 'عمرو',
        totalAmount: 300.0,
        type: 'lent',
        createdDate: DateTime.now().subtract(const Duration(days: 30)),
        dueDate: DateTime.now().subtract(const Duration(days: 5)),
        payments: [],
      );

      expect(overdueDebt.isOverdue, true);
    });
  });

  group('BillParserService Tests', () {
    test('extracts amount, merchant, and food category from supermarket SMS', () {
      const sms = 'خصم بطاقة مدى: مبلغ 145.50 ر.س لدى سوبرماركت بنده ماركت';
      final result = BillParserService.parse(sms);

      expect(result.amount, 145.50);
      expect(result.isExpense, true);
      expect(result.categoryId, 'cat_food');
      expect(result.merchant, contains('بنده'));
    });

    test('extracts fuel transport expense accurately', () {
      const sms = 'تمت عملية شراء عبر البطاقة بمبلغ 95.00 SAR لدى محطة ساسكو للوقود';
      final result = BillParserService.parse(sms);

      expect(result.amount, 95.0);
      expect(result.isExpense, true);
      expect(result.categoryId, 'cat_transport');
    });

    test('detects salary deposit accurately', () {
      const sms = 'حوالة واردة / إيداع راتب بمبلغ 12,500.00 ر.س لحسابك الجاري';
      final result = BillParserService.parse(sms);

      expect(result.amount, 12500.0);
      expect(result.isExpense, false);
      expect(result.categoryId, 'cat_salary');
    });
  });

  group('GoalModel Tests', () {
    test('calculates savings progress and remaining target accurately', () {
      final goal = GoalModel(
        id: 'g1',
        title: 'شراء سيارة',
        targetAmount: 50000.0,
        savedAmount: 20000.0,
        iconCode: 0,
        colorValue: 0xFF10B981,
      );

      expect(goal.progress, 0.4);
      expect(goal.remainingAmount, 30000.0);
      expect(goal.isAchieved, false);
    });

    test('marks goal as achieved when target met', () {
      final goal = GoalModel(
        id: 'g2',
        title: 'لابتوب جديد',
        targetAmount: 6000.0,
        savedAmount: 6000.0,
        iconCode: 0,
        colorValue: 0xFF10B981,
      );

      expect(goal.progress, 1.0);
      expect(goal.remainingAmount, 0.0);
      expect(goal.isAchieved, true);
    });
  });

  group('DebtCommunicationService Tests', () {
    test('generates polite Arabic WhatsApp reminder text', () {
      final debt = DebtModel(
        id: 'd1',
        personName: 'عبدالرحمن',
        totalAmount: 1200.0,
        type: 'lent',
        createdDate: DateTime.now(),
        payments: [],
      );

      final text = DebtCommunicationService.generateReminderText(debt, 'ر.س');
      expect(text, contains('عبدالرحمن'));
      expect(text, contains('1,200.00 ر.س'));
      expect(text, contains('تذكير'));
    });

    test('generates formal debt statement with header and balance', () {
      final debt = DebtModel(
        id: 'd2',
        personName: 'فيصل',
        totalAmount: 2000.0,
        type: 'lent',
        createdDate: DateTime.now(),
        payments: [
          DebtPayment(id: 'p1', amount: 500.0, date: DateTime.now(), notes: 'دفعة أولى'),
        ],
      );

      final statement = DebtCommunicationService.generateStatement(debt, 'ر.س');
      expect(statement, contains('سند كشف حساب مالي'));
      expect(statement, contains('فيصل'));
      expect(statement, contains('1,500.00 ر.س'));
      expect(statement, contains('دفعة أولى'));
    });
  });

  group('UserProfileModel Tests', () {
    test('creates default profile and converts to/from json correctly', () {
      final defaultProf = UserProfileModel.defaultProfile();
      expect(defaultProf.name, 'مستخدم مصروفاتي');
      expect(defaultProf.monthlyBudget, 5000.0);

      final json = defaultProf.toJson();
      final reconstructed = UserProfileModel.fromJson(json);
      expect(reconstructed.name, defaultProf.name);
      expect(reconstructed.title, defaultProf.title);
      expect(reconstructed.monthlyBudget, defaultProf.monthlyBudget);
    });

    test('copyWith updates user profile fields properly', () {
      final prof = UserProfileModel.defaultProfile();
      final updated = prof.copyWith(
        name: 'سارة خالد',
        monthlyBudget: 12000.0,
        title: 'مديرة استثمار',
      );

      expect(updated.name, 'سارة خالد');
      expect(updated.monthlyBudget, 12000.0);
      expect(updated.title, 'مديرة استثمار');
      expect(updated.email, prof.email);
    });
  });

  group('ContactModel & Statement Tests', () {
    test('creates ContactModel and formats avatar initial and label properly', () {
      final contact = ContactModel(
        id: 'c1',
        name: 'أحمد المنصور',
        phone: '+966551234567',
        relationship: 'client',
        createdAt: DateTime.now(),
      );

      expect(contact.avatarInitial, 'أ');
      expect(contact.relationshipLabel, 'عميل');

      final json = contact.toJson();
      final reconstructed = ContactModel.fromJson(json);
      expect(reconstructed.id, 'c1');
      expect(reconstructed.name, 'أحمد المنصور');
      expect(reconstructed.phone, '+966551234567');
      expect(reconstructed.relationship, 'client');
    });

    test('calculates net person statement balance correctly', () {
      final contact = ContactModel(
        id: 'c2',
        name: 'سعد العتيبي',
        relationship: 'friend',
        createdAt: DateTime.now(),
      );

      final debt1 = DebtModel(
        id: 'd1',
        personName: contact.name,
        totalAmount: 1500.0,
        type: 'lent', // Money I gave him
        createdDate: DateTime.now(),
        payments: [
          DebtPayment(id: 'p1', amount: 500.0, date: DateTime.now()),
        ],
      );

      final debt2 = DebtModel(
        id: 'd2',
        personName: contact.name,
        totalAmount: 300.0,
        type: 'borrowed', // Money I borrowed from him
        createdDate: DateTime.now(),
        payments: [],
      );

      // Remaining lent = 1500 - 500 = 1000
      // Remaining borrowed = 300
      // Net = 1000 - 300 = +700 (أطلبه 700 ر.س)
      final netBalance = debt1.remainingAmount - debt2.remainingAmount;
      expect(netBalance, 700.0);
      expect(debt1.remainingAmount, 1000.0);
      expect(debt2.remainingAmount, 300.0);
    });
  });

  group('Bank SMS & ATM Parser Tests', () {
    test('extracts ATM cash withdrawal correctly and marks as atm_withdrawal', () {
      const sms = 'سحب نقدي من صراف آلي الراجحي بمبلغ 500.00 ر.س بطاقة مدى *8821';
      final res = BillParserService.parse(sms);

      expect(res.amount, 500.0);
      expect(res.isAtmWithdrawal, true);
      expect(res.isExpense, false);
      expect(res.operationType, 'atm_withdrawal');
      expect(res.bankName, 'مصرف الراجحي');
      expect(res.cardLastDigits, '8821');
    });

    test('extracts bank purchase with card digits and bank name', () {
      const sms = 'شراء عبر مدى: بمبلغ 120.75 SAR لدى مطعم البيك بطاقة *9944 البنك الأهلي SNB';
      final res = BillParserService.parse(sms);

      expect(res.amount, 120.75);
      expect(res.isExpense, true);
      expect(res.isAtmWithdrawal, false);
      expect(res.categoryId, 'cat_food');
      expect(res.bankName, 'البنك الأهلي SNB');
      expect(res.cardLastDigits, '9944');
    });

    test('detects salary and credit transactions accurately', () {
      const sms = 'تم إيداع راتب بمبلغ 15,000.00 ر.س في حسابك لدى مصرف الإنماء';
      final res = BillParserService.parse(sms);

      expect(res.amount, 15000.0);
      expect(res.isExpense, false);
      expect(res.operationType, 'income');
      expect(res.categoryId, 'cat_salary');
      expect(res.bankName, 'مصرف الإنماء');
    });
  });

  group('Wealth & Multi-Account Asset Distribution Tests', () {
    test('calculates Net Worth and Asset Allocations accurately', () {
      final bankBalance = 10000.0;
      final cashBalance = 3000.0;
      final savingsBalance = 2000.0;
      final moneyLoanedToFriends = 5000.0; // Asset (receivable)
      final debtsOwedToOthers = 4000.0; // Liability

      final totalPositiveAssets = bankBalance + cashBalance + savingsBalance + moneyLoanedToFriends;
      final totalNetWorth = totalPositiveAssets - debtsOwedToOthers;

      expect(totalPositiveAssets, 20000.0);
      expect(totalNetWorth, 16000.0);

      // Percentage shares
      final bankShare = (bankBalance / totalPositiveAssets) * 100;
      final cashShare = (cashBalance / totalPositiveAssets) * 100;
      final friendsShare = (moneyLoanedToFriends / totalPositiveAssets) * 100;

      expect(bankShare, 50.0);
      expect(cashShare, 15.0);
      expect(friendsShare, 25.0);
    });

    test('DebtModel supports walletId and walletName for tracking source of funds', () {
      final debt = DebtModel(
        id: 'd_wallet_1',
        personName: 'فيصل',
        totalAmount: 1200.0,
        type: 'lent',
        createdDate: DateTime.now(),
        walletId: 'wallet_cash',
        walletName: 'نقدي (كاش)',
        payments: [
          DebtPayment(
            id: 'p_1',
            amount: 400.0,
            date: DateTime.now(),
            walletId: 'wallet_bank',
            walletName: 'الحساب البنكي',
          ),
        ],
      );

      expect(debt.walletId, 'wallet_cash');
      expect(debt.walletName, 'نقدي (كاش)');
      expect(debt.payments.first.walletId, 'wallet_bank');
      expect(debt.payments.first.walletName, 'الحساب البنكي');

      final json = debt.toJson();
      final restored = DebtModel.fromJson(json);
      expect(restored.walletId, 'wallet_cash');
      expect(restored.walletName, 'نقدي (كاش)');
      expect(restored.payments.first.walletId, 'wallet_bank');
    });
  });

  group('Auth & User Management Tests', () {
    test('UserModel serializes and deserializes correctly', () {
      final user = UserModel(
        id: 'u_123',
        name: 'علاء صبري',
        email: 'alaa@example.com',
        phone: '+966501234567',
        photoUrl: 'https://example.com/avatar.jpg',
        authMethod: 'google',
        isGuest: false,
        createdAt: DateTime(2026, 1, 1),
        lastLoginAt: DateTime(2026, 1, 1),
      );

      final json = user.toJson();
      final restored = UserModel.fromJson(json);

      expect(restored.id, 'u_123');
      expect(restored.name, 'علاء صبري');
      expect(restored.email, 'alaa@example.com');
      expect(restored.phone, '+966501234567');
      expect(restored.authMethod, 'google');
      expect(restored.isGuest, false);
    });

    test('UserModel.guestUser creates valid guest session', () {
      final guest = UserModel.guestUser();

      expect(guest.isGuest, true);
      expect(guest.authMethod, 'guest');
      expect(guest.name, 'مستخدم ضيف');
      expect(guest.email, isNull);
      expect(guest.id, startsWith('guest_'));
    });

    test('AuthService and AuthProvider handle guest login and logout', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService(prefs);
      final authProvider = AuthProvider(authService);

      expect(authProvider.isAuthenticated, false);
      expect(authProvider.currentUser, isNull);

      // Guest Login
      await authProvider.loginAsGuest();
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.isGuest, true);
      expect(authProvider.currentUser?.name, 'مستخدم ضيف');

      // Check persistence in SharedPreferences
      final savedUser = authService.loadSavedUser();
      expect(savedUser, isNotNull);
      expect(savedUser?.isGuest, true);

      // Logout
      await authProvider.logout();
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.currentUser, isNull);
      expect(authService.loadSavedUser(), isNull);
    });

    test('AuthService local fallback login and signup works seamlessly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService(prefs);
      final authProvider = AuthProvider(authService);

      // Sign up with Email
      final registered = await authProvider.registerWithEmail(
        name: 'محمد أحمد',
        email: 'mohamed@test.com',
        password: 'password123',
      );

      expect(registered, true);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.isGuest, false);
      expect(authProvider.currentUser?.name, 'محمد أحمد');
      expect(authProvider.currentUser?.email, 'mohamed@test.com');
      expect(authProvider.currentUser?.authMethod, 'email');

      // Logout
      await authProvider.logout();
      expect(authProvider.isAuthenticated, false);

      // Login with saved credentials
      final loggedIn = await authProvider.loginWithEmail(
        email: 'mohamed@test.com',
        password: 'password123',
      );

      expect(loggedIn, true);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.currentUser?.email, 'mohamed@test.com');
    });

    test('Phone OTP verification creates user with phone number', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService(prefs);
      final authProvider = AuthProvider(authService);

      final verified = await authProvider.verifyPhoneOtp(
        verificationId: 'v_id_123',
        smsCode: '123456',
        phone: '+966551234567',
        name: 'سالم الدوسري',
      );

      expect(verified, true);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.currentUser?.phone, '+966551234567');
      expect(authProvider.currentUser?.name, 'سالم الدوسري');
      expect(authProvider.currentUser?.authMethod, 'phone');
    });

    test('Real Account Database: rejects duplicate email and validates password correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService(prefs);
      final authProvider = AuthProvider(authService);

      // Register first user
      final r1 = await authProvider.registerWithEmail(
        name: 'علي حسن',
        email: 'ali@masrofaty.com',
        password: 'correct_pass_123',
      );
      expect(r1, true);
      expect(authService.getAllAccounts().length, 1);

      // Attempt to register again with same email -> MUST FAIL
      await authProvider.logout();
      final rDuplicate = await authProvider.registerWithEmail(
        name: 'علي آخر',
        email: 'ali@masrofaty.com',
        password: 'another_password',
      );
      expect(rDuplicate, false);
      expect(authProvider.errorMessage, contains('مسجل بالفعل'));

      // Attempt login with WRONG password -> MUST FAIL
      final rWrongPass = await authProvider.loginWithEmail(
        email: 'ali@masrofaty.com',
        password: 'wrong_password_here',
      );
      expect(rWrongPass, false);
      expect(authProvider.errorMessage, contains('كلمة المرور غير صحيحة'));

      // Attempt login with non-existent email -> MUST FAIL
      final rNonExistent = await authProvider.loginWithEmail(
        email: 'does_not_exist@domain.com',
        password: 'any_password',
      );
      expect(rNonExistent, false);
      expect(authProvider.errorMessage, contains('لم يتم العثور'));

      // Attempt login with CORRECT password -> MUST SUCCEED
      final rSuccess = await authProvider.loginWithEmail(
        email: 'ali@masrofaty.com',
        password: 'correct_pass_123',
      );
      expect(rSuccess, true);
      expect(authProvider.currentUser?.name, 'علي حسن');
    });

    test('Password Reset updates stored hash and allows login with new password', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService(prefs);
      final authProvider = AuthProvider(authService);

      await authProvider.registerWithEmail(
        name: 'فاطمة عمر',
        email: 'fatima@test.com',
        password: 'old_password_123',
      );
      await authProvider.logout();

      // Reset password
      final resetRes = await authProvider.resetPassword(
        email: 'fatima@test.com',
        newPassword: 'new_secret_pass_999',
      );
      expect(resetRes.isSuccess, true);

      // Old password should now fail
      final oldLogin = await authProvider.loginWithEmail(
        email: 'fatima@test.com',
        password: 'old_password_123',
      );
      expect(oldLogin, false);

      // New password should succeed
      final newLogin = await authProvider.loginWithEmail(
        email: 'fatima@test.com',
        password: 'new_secret_pass_999',
      );
      expect(newLogin, true);
      expect(authProvider.currentUser?.name, 'فاطمة عمر');
    });

    test('EmailOtpService generates 6-digit OTP, verifies correctly, and enforces cooldown & attempt limits', () async {
      final otpService = EmailOtpService();
      otpService.clearAll();

      const testEmail = 'tester.otp@masrofaty.app';

      // Send OTP
      final sendResult = await otpService.sendOtp(
        email: testEmail,
        userName: 'مستخدم تجريبي',
      );

      expect(sendResult.isSuccess, true);
      expect(sendResult.code, isNotNull);
      expect(sendResult.code!.length, 6);
      expect(int.tryParse(sendResult.code!), isNotNull);

      // Attempt immediate resend -> should be blocked by 60s cooldown
      final resendResult = await otpService.sendOtp(
        email: testEmail,
        userName: 'مستخدم تجريبي',
      );
      expect(resendResult.isSuccess, false);
      expect(resendResult.errorMessage, contains('ثانية'));

      // Test incorrect OTP verification
      final wrongVerify = otpService.verifyOtp(
        email: testEmail,
        inputOtp: '000000',
      );
      expect(wrongVerify.isValid, false);
      expect(wrongVerify.errorMessage, contains('رمز التحقق غير صحيح'));

      // Test correct OTP verification
      final correctVerify = otpService.verifyOtp(
        email: testEmail,
        inputOtp: sendResult.code!,
      );
      expect(correctVerify.isValid, true);

      // Code should now be consumed and cannot be reused
      final reuseVerify = otpService.verifyOtp(
        email: testEmail,
        inputOtp: sendResult.code!,
      );
      expect(reuseVerify.isValid, false);
    });

    test('AuthProvider email registration with OTP marks user as isEmailVerified', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService(prefs);
      final authProvider = AuthProvider(authService);
      authProvider.emailOtpService.clearAll();

      const email = 'verified.user@masrofaty.app';
      final sendRes = await authProvider.sendEmailOtp(email: email, name: 'سارة خالد');
      expect(sendRes.isSuccess, true);

      final verifyRes = authProvider.verifyEmailOtp(email: email, otp: sendRes.code!);
      expect(verifyRes.isValid, true);

      final registered = await authProvider.registerWithEmail(
        name: 'سارة خالد',
        email: email,
        password: 'securePassword123',
        isEmailVerified: true,
      );

      expect(registered, true);
      expect(authProvider.currentUser?.isEmailVerified, true);
      expect(authProvider.currentUser?.email, email);

      // Verify stored account reflects isEmailVerified
      final account = authService.findAccountByEmail(email);
      expect(account, isNotNull);
      expect(account?.user.isEmailVerified, true);
    });

    test('Per-Account Data Isolation in StorageService isolates User A from User B', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      // User A partition
      storage.setCurrentUserId('user_A');
      await storage.saveTransactions([
        TransactionModel(
          id: 'tx_a1',
          title: 'راتب User A',
          amount: 10000.0,
          type: 'income',
          categoryId: 'salary',
          walletId: 'w1',
          date: DateTime.now(),
        ),
      ]);
      expect(storage.loadTransactions().length, 1);
      expect(storage.loadTransactions().first.title, 'راتب User A');

      // Switch to User B partition
      storage.setCurrentUserId('user_B');
      expect(storage.loadTransactions().length, 0); // User B has no transactions yet!

      await storage.saveTransactions([
        TransactionModel(
          id: 'tx_b1',
          title: 'قهوة User B',
          amount: 25.0,
          type: 'expense',
          categoryId: 'food',
          walletId: 'w2',
          date: DateTime.now(),
        ),
      ]);
      expect(storage.loadTransactions().length, 1);
      expect(storage.loadTransactions().first.title, 'قهوة User B');

      // Switch back to User A -> User A transactions preserved!
      storage.setCurrentUserId('user_A');
      expect(storage.loadTransactions().length, 1);
      expect(storage.loadTransactions().first.title, 'راتب User A');
    });

    test('UserModel supports profession field and serializes correctly', () {
      final user = UserModel(
        id: 'u_prof_1',
        name: 'د. خالد العمري',
        email: 'dr.khaled@hospital.sa',
        profession: 'طبيب استشاري',
        authMethod: 'email',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      expect(user.profession, 'طبيب استشاري');

      final json = user.toJson();
      expect(json['profession'], 'طبيب استشاري');

      final restored = UserModel.fromJson(json);
      expect(restored.profession, 'طبيب استشاري');
    });

    test('UserProfileProvider partitions profiles by userId and maps from UserModel', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final profileProvider = UserProfileProvider(prefs);

      // User 1: Doctor
      final user1 = UserModel(
        id: 'user_doc',
        name: 'د. خالد العمري',
        email: 'dr.khaled@hospital.sa',
        profession: 'طبيب جراح',
        authMethod: 'email',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      profileProvider.initForUser(user1.id, user1);
      expect(profileProvider.profile.name, 'د. خالد العمري');
      expect(profileProvider.profile.title, 'طبيب جراح');
      expect(profileProvider.profile.email, 'dr.khaled@hospital.sa');

      // User 2: Engineer
      final user2 = UserModel(
        id: 'user_eng',
        name: 'م. سارة خالد',
        email: 'eng.sarah@tech.sa',
        profession: 'مهندسة برمجيات',
        authMethod: 'email',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      profileProvider.initForUser(user2.id, user2);
      expect(profileProvider.profile.name, 'م. سارة خالد');
      expect(profileProvider.profile.title, 'مهندسة برمجيات');
      expect(profileProvider.profile.email, 'eng.sarah@tech.sa');

      // Switch back to User 1 -> profile is strictly isolated and preserved!
      profileProvider.initForUser(user1.id, user1);
      expect(profileProvider.profile.name, 'د. خالد العمري');
      expect(profileProvider.profile.title, 'طبيب جراح');
      expect(profileProvider.profile.email, 'dr.khaled@hospital.sa');
    });

    test('StorageService initializes newly registered users with zeroed financial data (0.00 SAR)', () async {
      SharedPreferences.setMockInitialValues({
        // Simulate legacy guest data on device
        'masrofaty_transactions': '[{"id":"legacy_1","title":"old","amount":999.0,"type":"expense","categoryId":"food","walletId":"w1","date":"2026-01-01T00:00:00.000"}]',
        'masrofaty_debts': '[{"id":"legacy_d1","personName":"old","totalAmount":500.0,"type":"lent","createdDate":"2026-01-01T00:00:00.000"}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      // Register new user
      const newUserId = 'new_clean_user_99';
      await storage.migrateGuestDataToUser(newUserId);
      storage.setCurrentUserId(newUserId);

      // Verify transactions are clean and empty (0)
      final userTxs = storage.loadTransactions();
      expect(userTxs.length, 0);

      // Verify debts are clean and empty (0)
      final userDebts = storage.loadDebts();
      expect(userDebts.length, 0);

      // Verify wallets are initialized with 0.00 balance
      final userWallets = storage.loadWallets();
      expect(userWallets.length, 4);
      for (final w in userWallets) {
        expect(w.balance, 0.0);
      }
    });
  });

  group('Multi-Tenant SaaS & Workspace Isolation Tests', () {
    test('WorkspaceModel creates default workspace and converts to/from JSON correctly', () {
      final defaultWs = WorkspaceModel.defaultWorkspace(userId: 'u_test_1');
      expect(defaultWs.id, 'ws_personal_u_test_1');
      expect(defaultWs.name, 'حسابي الشخصي');
      expect(defaultWs.type, WorkspaceType.personal);
      expect(defaultWs.currency, 'SAR');
      expect(defaultWs.isDefault, true);

      final json = defaultWs.toJson();
      final restored = WorkspaceModel.fromJson(json);
      expect(restored.id, defaultWs.id);
      expect(restored.name, defaultWs.name);
      expect(restored.type, WorkspaceType.personal);
      expect(restored.isDefault, true);
    });

    test('SaaSPlanModel handles tiers and limits accurately', () {
      final starter = SaaSPlanModel.starter();
      expect(starter.tier, SaaSTier.starter);
      expect(starter.tier.maxWorkspaces, 2);

      final pro = SaaSPlanModel.pro();
      expect(pro.tier, SaaSTier.pro);
      expect(pro.tier.maxWorkspaces, 10);
      expect(pro.tier.priceText, contains('39'));

      expect(SaaSTier.enterprise.maxWorkspaces, 999);
    });

    test('WorkspaceProvider creates isolated business workspace with smart auto-generated wallets', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final workspaceProv = WorkspaceProvider(storage);

      workspaceProv.initForUser('u_saas_user');
      expect(workspaceProv.workspaces.length, 1);
      expect(workspaceProv.activeWorkspace.name, 'حسابي الشخصي');

      // Create a business workspace
      final bizWs = await workspaceProv.createWorkspace(
        name: 'مؤسسة الابتكار',
        type: WorkspaceType.business,
        currency: 'SAR',
        currencySymbol: 'ر.س',
        taxNumber: '300123456700003',
      );

      expect(bizWs, isNotNull);
      expect(bizWs?.name, 'مؤسسة الابتكار');
      expect(bizWs?.type, WorkspaceType.business);
      expect(bizWs?.taxNumber, '300123456700003');
      expect(workspaceProv.workspaces.length, 2);
      expect(workspaceProv.activeWorkspace.id, bizWs?.id);

      // Verify smart auto-generated wallets for business
      final bizWallets = storage.loadWallets();
      expect(bizWallets.length, 3);
      expect(bizWallets.any((w) => w.name.contains('تجاري')), true);
      expect(bizWallets.any((w) => w.name.contains('عهدة')), true);
      expect(bizWallets.any((w) => w.name.contains('فيزا') || w.name.contains('مشتريات')), true);
    });

    test('Workspace data isolation in StorageService partitions transactions per workspace', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final workspaceProv = WorkspaceProvider(storage);

      workspaceProv.initForUser('u_founder');
      final personalWs = workspaceProv.activeWorkspace;

      // 1. Add Personal Transaction
      await storage.saveTransactions([
        TransactionModel(
          id: 'tx_p1',
          title: 'بقالة وسوبرماركت',
          amount: 150.0,
          type: 'expense',
          categoryId: 'food',
          walletId: 'w_cash',
          date: DateTime.now(),
        ),
      ]);
      expect(storage.loadTransactions().length, 1);
      expect(storage.loadTransactions().first.title, 'بقالة وسوبرماركت');

      // 2. Create Business Workspace
      final bizWs = await workspaceProv.createWorkspace(
        name: 'شركة الاستشارات',
        type: WorkspaceType.business,
      );
      expect(workspaceProv.activeWorkspace.id, bizWs?.id);

      // 3. Verify 0 transactions in the new business workspace (complete isolation!)
      expect(storage.loadTransactions().length, 0);

      // 4. Add Business Transaction
      await storage.saveTransactions([
        TransactionModel(
          id: 'tx_b1',
          title: 'فاتورة خادم سحابي AWS',
          amount: 1200.0,
          type: 'expense',
          categoryId: 'bills',
          walletId: 'w_biz_card',
          date: DateTime.now(),
        ),
      ]);
      expect(storage.loadTransactions().length, 1);
      expect(storage.loadTransactions().first.title, 'فاتورة خادم سحابي AWS');

      // 5. Switch back to Personal Workspace -> Only Personal Transaction is returned!
      await workspaceProv.switchWorkspace(personalWs.id);
      expect(workspaceProv.activeWorkspace.id, personalWs.id);
      expect(storage.loadTransactions().length, 1);
      expect(storage.loadTransactions().first.title, 'بقالة وسوبرماركت');
    });

    test('SaaS Tier Limits Enforcement and Upgrade', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final workspaceProv = WorkspaceProvider(storage);

      workspaceProv.initForUser('u_tiered');
      expect(workspaceProv.currentPlan.tier, SaaSTier.starter);
      expect(workspaceProv.canAddWorkspace, true); // 1/2 used

      // Add 2nd workspace (reaches starter limit of 2)
      await workspaceProv.createWorkspace(
        name: 'متجر الهدايا',
        type: WorkspaceType.store,
      );
      expect(workspaceProv.workspaces.length, 2);
      expect(workspaceProv.canAddWorkspace, false); // 2/2 used

      // Attempt to add 3rd workspace on Starter -> Rejected!
      final rejectedWs = await workspaceProv.createWorkspace(
        name: 'مكتب هندسي',
        type: WorkspaceType.business,
      );
      expect(rejectedWs, isNull);
      expect(workspaceProv.workspaces.length, 2);

      // Upgrade to Pro
      await workspaceProv.upgradePlan(SaaSTier.pro);
      expect(workspaceProv.currentPlan.tier, SaaSTier.pro);
      expect(workspaceProv.isPro, true);
      expect(workspaceProv.canAddWorkspace, true); // 2/10 used

      // Now adding 3rd workspace succeeds!
      final allowedWs = await workspaceProv.createWorkspace(
        name: 'مكتب هندسي',
        type: WorkspaceType.business,
      );
      expect(allowedWs, isNotNull);
      expect(workspaceProv.workspaces.length, 3);
    });
  });
}
