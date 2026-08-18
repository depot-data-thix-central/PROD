// lib/models/phone_auth_session.dart
class PhoneAuthSession {
  final String verificationId;
  final String phoneNumber;

  PhoneAuthSession({
    required this.verificationId,
    required this.phoneNumber,
  });
}
