import 'package:firebase_auth/firebase_auth.dart';

/// نفس قائمة المطورين بالأصل (dev-panel.js). السيرفر يتحقق مرة ثانية.
const devEmails = ['anldheb429@gmail.com', 'hamodeygame45@gmail.com'];

bool isDevUser(User? u) {
  final e = u?.email?.trim().toLowerCase();
  return e != null && devEmails.contains(e);
}
