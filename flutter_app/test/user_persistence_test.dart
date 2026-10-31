import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solvex_alert/core/constants.dart';
import 'package:solvex_alert/services/auth.dart';
import 'package:solvex_alert/services/mock_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Comprehensive test matching user exact flow', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // 1. First app launch: seed data loads
    final db1 = MockDb(prefs);
    expect(db1.findUserByUsername('admin'), isNotNull);
    expect(db1.findUserByUsername('samir'), isNotNull);

    // 2. Admin logs in
    final auth1 = AuthService(db1, null);
    final session1 = SessionController(auth1, db1, prefs);
    await session1.signIn('admin', 'admin');
    expect(session1.user!.isAdmin, isTrue);

    // 3. Admin deletes all users
    await db1.clearAllUsers(currentAdminUid: session1.user!.uid);
    expect(db1.findUserByUsername('samir'), isNull);
    expect(db1.findUserByUsername('admin'), isNotNull);

    // 4. Admin creates a new user account
    final createdUser = await db1.createUserByAdmin(
      fullName: 'Mohamed Test',
      username: 'mohamed',
      password: 'mypassword123',
      phone: '0555123456',
      wilayaCode: 16,
      vehicleType: VehicleType.car,
      role: 'user',
    );
    expect(createdUser.username, equals('mohamed'));

    // 5. Admin logs out
    await session1.signOut();
    expect(session1.user, isNull);

    // 6. User attempts to log in with new credentials on Login screen
    await session1.signIn('mohamed', 'mypassword123');
    expect(session1.user, isNotNull);
    expect(session1.user!.username, equals('mohamed'));
    expect(session1.user!.isAdmin, isFalse);

    // 7. User logs out
    await session1.signOut();
    expect(session1.user, isNull);

    // 8. Simulate app restart (process killed and relaunched)
    final db2 = MockDb(prefs);
    expect(db2.findUserByUsername('samir'), isNull, reason: 'Samir must not return!');
    expect(db2.findUserByUsername('mohamed'), isNotNull, reason: 'mohamed must still exist!');
    expect(db2.verifyPassword('mohamed', 'mypassword123'), isTrue);

    // 9. Admin logs back in after restart
    final auth2 = AuthService(db2, null);
    final session2 = SessionController(auth2, db2, prefs);
    await session2.signIn('admin', 'admin');
    expect(session2.user!.isAdmin, isTrue);

    // 10. Admin checks user list: mohamed exists, samir does not exist
    final users = await db2.allUsers().first;
    expect(users.any((u) => u.username == 'mohamed'), isTrue);
    expect(users.any((u) => u.username == 'samir'), isFalse);
  });
}
