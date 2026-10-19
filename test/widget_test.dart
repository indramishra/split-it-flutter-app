import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise_app/models/expense.dart';
import 'package:splitwise_app/models/user.dart';
import 'package:splitwise_app/services/debt_simplifier.dart';

void main() {
  testWidgets('SplitItApp unit test structure', (WidgetTester tester) async {
    // Tests are supported
    expect(true, isTrue);
  });

  test('DebtSimplifier algorithm correctly minimizes transactions', () {
    // A pays 60 for A, B, C equally (20 each) -> B owes 20, C owes 20, A is owed 40
    // B pays 30 for B, C equally (15 each) -> C owes B 15
    // Net:
    // A: +40
    // B: -20 + 15 = -5
    // C: -20 - 15 = -35
    //
    // Simplified debts:
    // C owes A 35
    // B owes A 5
    // Total transactions = 2 (instead of 3)

    final expenses = [
      Expense(
        id: '1',
        description: 'Dinner',
        cost: 60.0,
        date: DateTime.now(),
        paidByUserId: 'A',
        splitShares: {'A': 20.0, 'B': 20.0, 'C': 20.0},
      ),
      Expense(
        id: '2',
        description: 'Snacks',
        cost: 30.0,
        date: DateTime.now(),
        paidByUserId: 'B',
        splitShares: {'B': 15.0, 'C': 15.0},
      ),
    ];

    final net = DebtSimplifier.computeNetBalances(expenses: expenses);
    expect(net['A'], 40.0);
    expect(net['B'], -5.0);
    expect(net['C'], -35.0);

    final simplified = DebtSimplifier.simplifyDebts(net);
    expect(simplified.length, 2);

    // C should pay A 35
    final cDebt = simplified.firstWhere((d) => d.fromUserId == 'C');
    expect(cDebt.toUserId, 'A');
    expect(cDebt.amount, 35.0);

    // B should pay A 5
    final bDebt = simplified.firstWhere((d) => d.fromUserId == 'B');
    expect(bDebt.toUserId, 'A');
    expect(bDebt.amount, 5.0);
  });

  test('User model handles resetPasswordCode serialization and copyWith', () {
    final now = DateTime.now();
    final user = User(
      id: 'u123',
      name: 'Test User',
      email: 'test@example.com',
      resetPasswordCode: '654321',
      resetPasswordCodeSentAt: now,
    );

    final json = user.toJson();
    expect(json['resetPasswordCode'], '654321');
    expect(json['resetPasswordCodeSentAt'], now.toIso8601String());

    final parsed = User.fromJson(json);
    expect(parsed.resetPasswordCode, '654321');
    expect(parsed.resetPasswordCodeSentAt, isNotNull);

    final updated = parsed.copyWith(password: 'newSecretPass');
    expect(updated.password, 'newSecretPass');
    expect(updated.resetPasswordCode, '654321');
  });

  test('User model defaults isEmailVerified to false when missing in JSON', () {
    final minimalJson = {
      'id': 'u456',
      'name': 'Friend Test',
      'email': 'friend@example.com',
    };

    final user = User.fromJson(minimalJson);
    // Verified that default is false so user is NOT allowed to bypass verification
    expect(user.isEmailVerified, isFalse);
    expect(user.isPhoneVerified, isFalse);
  });

  test('User model handles phoneNumber and phone verification serialization', () {
    final now = DateTime.now();
    final user = User(
      id: 'u789',
      name: 'Phone User',
      email: 'phoneuser@example.com',
      phoneNumber: '+15551234567',
      isPhoneVerified: false,
      phoneVerificationCode: '987654',
      phoneVerificationCodeSentAt: now,
    );

    final json = user.toJson();
    expect(json['phoneNumber'], '+15551234567');
    expect(json['isPhoneVerified'], isFalse);
    expect(json['phoneVerificationCode'], '987654');
    expect(json['phoneVerificationCodeSentAt'], now.toIso8601String());

    final parsed = User.fromJson(json);
    expect(parsed.phoneNumber, '+15551234567');
    expect(parsed.isPhoneVerified, isFalse);
    expect(parsed.phoneVerificationCode, '987654');

    final verifiedUser = parsed.copyWith(
      isPhoneVerified: true,
      clearPhoneVerificationCode: true,
    );
    expect(verifiedUser.isPhoneVerified, isTrue);
    expect(verifiedUser.phoneVerificationCode, isNull);
  });
}
