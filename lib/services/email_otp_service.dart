import 'package:dio/dio.dart';
import 'package:rider_app/services/api_client.dart';

// ── Shared types (unchanged — other files import these) ───────────────────────

class OtpException implements Exception {
  OtpException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OtpResult {
  const OtpResult.success(String this.token)
      : ok = true,
        message = null;
  const OtpResult.failure(String this.message)
      : ok = false,
        token = null;

  final bool ok;
  final String? token;
  final String? message;
}

abstract class OtpService {
  Future<void> sendEmailOtp(String email);
  Future<OtpResult> verifyEmailOtp(String email, String code);
}

// ── Real HTTP implementation ──────────────────────────────────────────────────

class HttpOtpService implements OtpService {
  @override
  Future<void> sendEmailOtp(String email) async {
    try {
      await apiClient.post(
        '/api/auth/email-otp/send',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw OtpException(apiErrorMessage(e));
    }
  }

  @override
  Future<OtpResult> verifyEmailOtp(String email, String code) async {
    try {
      final res = await apiClient.post(
        '/api/auth/email-otp/verify',
        data: {'email': email, 'code': code},
      );
      final token = res.data['verificationToken'] as String?;
      if (token != null && token.isNotEmpty) {
        return OtpResult.success(token);
      }
      return const OtpResult.failure('Verification failed. Please try again.');
    } on DioException catch (e) {
      return OtpResult.failure(apiErrorMessage(e));
    }
  }
}

// ── Singleton used by the UI ──────────────────────────────────────────────────

final OtpService otpService = HttpOtpService();
