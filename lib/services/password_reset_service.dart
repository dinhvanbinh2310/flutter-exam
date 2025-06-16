import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class PasswordResetService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Gmail SMTP configuration
  static const String _smtpUsername =
      'your-email@gmail.com'; // Replace with your Gmail
  static const String _smtpPassword =
      'your-app-password'; // Replace with your app password

  // Generate a random password
  String _generateRandomPassword() {
    const String chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final Random random = Random.secure();
    return List.generate(
      12,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // Send password reset email
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      // Check if email exists in database
      final user = await _databaseHelper.getUserByEmail(email);
      if (user == null) {
        return {
          'success': false,
          'message': 'Email không tồn tại trong hệ thống',
        };
      }

      // Generate new password
      final String newPassword = _generateRandomPassword();

      // Configure SMTP server
      final smtpServer = gmail(_smtpUsername, _smtpPassword);

      // Create email message
      final message =
          Message()
            ..from = Address(_smtpUsername, 'UTC2 Password Reset')
            ..recipients.add(email)
            ..subject = 'Đặt lại mật khẩu - UTC2'
            ..html = '''
          <h2>Đặt lại mật khẩu</h2>
          <p>Xin chào,</p>
          <p>Mật khẩu mới của bạn là: <strong>$newPassword</strong></p>
          <p>Vui lòng đăng nhập lại với mật khẩu mới này.</p>
          <p>Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.</p>
          <p>Trân trọng,<br>UTC2 Team</p>
        ''';

      // Send email
      final sendReport = await send(message, smtpServer);

      if (sendReport.toString().contains('OK')) {
        // Update password in database
        final result = await _databaseHelper.changePassword(
          userId: user['id'],
          oldPassword: user['password'], // This will be hashed in the database
          newPassword: newPassword,
        );

        if (result['success']) {
          return {
            'success': true,
            'message': 'Mật khẩu mới đã được gửi đến email của bạn',
          };
        } else {
          return {
            'success': false,
            'message': 'Không thể cập nhật mật khẩu trong cơ sở dữ liệu',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Không thể gửi email đặt lại mật khẩu',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Có lỗi xảy ra: $e'};
    }
  }
}
