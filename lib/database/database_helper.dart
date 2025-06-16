import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  // Tên database và version
  static const String _databaseName = 'user_database.db';
  static const int _databaseVersion = 1;

  // Tên bảng
  static const String tableUsers = 'users';

  // Các cột trong bảng users
  static const String columnId = 'id';
  static const String columnEmail = 'email';
  static const String columnPassword = 'password';
  static const String columnFullName = 'full_name';
  static const String columnPhone = 'phone';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnIsActive = 'is_active';

  // Getter cho database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Khởi tạo database
  Future<Database> _initDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _databaseName);

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('Error initializing database: $e');
      throw Exception('Failed to initialize database');
    }
  }

  // Tạo bảng khi database được tạo lần đầu
  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE $tableUsers (
          $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnEmail TEXT UNIQUE NOT NULL,
          $columnPassword TEXT NOT NULL,
          $columnFullName TEXT NOT NULL,
          $columnPhone TEXT,
          $columnCreatedAt TEXT NOT NULL,
          $columnUpdatedAt TEXT NOT NULL,
          $columnIsActive INTEGER DEFAULT 1
        )
      ''');

      // Tạo index cho email để tăng tốc độ truy vấn
      await db.execute('''
        CREATE INDEX idx_users_email ON $tableUsers($columnEmail)
      ''');

      print('Database tables created successfully');
    } catch (e) {
      print('Error creating tables: $e');
      throw Exception('Failed to create database tables');
    }
  }

  // Xử lý khi nâng cấp database
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      // Xử lý nâng cấp database ở đây
      if (oldVersion < 2) {
        // Ví dụ: thêm cột mới
        // await db.execute('ALTER TABLE $tableUsers ADD COLUMN avatar TEXT');
      }
    } catch (e) {
      print('Error upgrading database: $e');
      throw Exception('Failed to upgrade database');
    }
  }

  // Hash mật khẩu
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Đăng ký người dùng mới
  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final db = await database;

      // Kiểm tra email đã tồn tại chưa
      final existingUser = await getUserByEmail(email);
      if (existingUser != null) {
        return {'success': false, 'message': 'Email đã được sử dụng'};
      }

      // Hash mật khẩu
      String hashedPassword = _hashPassword(password);

      String currentTime = DateTime.now().toIso8601String();

      Map<String, dynamic> user = {
        columnEmail: email.toLowerCase().trim(),
        columnPassword: hashedPassword,
        columnFullName: fullName.trim(),
        columnPhone: phone?.trim(),
        columnCreatedAt: currentTime,
        columnUpdatedAt: currentTime,
        columnIsActive: 1,
      };

      int userId = await db.insert(tableUsers, user);

      return {
        'success': true,
        'message': 'Đăng ký thành công',
        'userId': userId,
      };
    } catch (e) {
      print('Error registering user: $e');
      return {'success': false, 'message': 'Có lỗi xảy ra khi đăng ký'};
    }
  }

  // Đăng nhập người dùng
  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final db = await database;

      String hashedPassword = _hashPassword(password);

      List<Map<String, dynamic>> result = await db.query(
        tableUsers,
        where:
            '$columnEmail = ? AND $columnPassword = ? AND $columnIsActive = 1',
        whereArgs: [email.toLowerCase().trim(), hashedPassword],
      );

      if (result.isNotEmpty) {
        Map<String, dynamic> user = result.first;
        // Loại bỏ mật khẩu khỏi kết quả trả về
        user.remove(columnPassword);

        return {
          'success': true,
          'message': 'Đăng nhập thành công',
          'user': user,
        };
      } else {
        return {'success': false, 'message': 'Email hoặc mật khẩu không đúng'};
      }
    } catch (e) {
      print('Error logging in user: $e');
      return {'success': false, 'message': 'Có lỗi xảy ra khi đăng nhập'};
    }
  }

  // Lấy thông tin người dùng theo email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final db = await database;

      List<Map<String, dynamic>> result = await db.query(
        tableUsers,
        where: '$columnEmail = ?',
        whereArgs: [email.toLowerCase().trim()],
      );

      if (result.isNotEmpty) {
        Map<String, dynamic> user = result.first;
        user.remove(columnPassword); // Loại bỏ mật khẩu
        return user;
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  // Lấy thông tin người dùng theo ID
  Future<Map<String, dynamic>?> getUserById(int id) async {
    try {
      final db = await database;

      List<Map<String, dynamic>> result = await db.query(
        tableUsers,
        where: '$columnId = ?',
        whereArgs: [id],
      );

      if (result.isNotEmpty) {
        Map<String, dynamic> user = result.first;
        user.remove(columnPassword); // Loại bỏ mật khẩu
        return user;
      }
      return null;
    } catch (e) {
      print('Error getting user by id: $e');
      return null;
    }
  }

  // Cập nhật thông tin người dùng
  Future<Map<String, dynamic>> updateUser({
    required int userId,
    String? fullName,
    String? phone,
  }) async {
    try {
      final db = await database;

      Map<String, dynamic> updates = {
        columnUpdatedAt: DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates[columnFullName] = fullName.trim();
      if (phone != null) updates[columnPhone] = phone.trim();

      int rowsAffected = await db.update(
        tableUsers,
        updates,
        where: '$columnId = ?',
        whereArgs: [userId],
      );

      if (rowsAffected > 0) {
        return {'success': true, 'message': 'Cập nhật thông tin thành công'};
      } else {
        return {'success': false, 'message': 'Không tìm thấy người dùng'};
      }
    } catch (e) {
      print('Error updating user: $e');
      return {'success': false, 'message': 'Có lỗi xảy ra khi cập nhật'};
    }
  }

  // Đổi mật khẩu
  Future<Map<String, dynamic>> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final db = await database;

      String hashedOldPassword = _hashPassword(oldPassword);

      // Kiểm tra mật khẩu cũ
      List<Map<String, dynamic>> result = await db.query(
        tableUsers,
        where: '$columnId = ? AND $columnPassword = ?',
        whereArgs: [userId, hashedOldPassword],
      );

      if (result.isEmpty) {
        return {'success': false, 'message': 'Mật khẩu cũ không đúng'};
      }

      // Cập nhật mật khẩu mới
      String hashedNewPassword = _hashPassword(newPassword);

      int rowsAffected = await db.update(
        tableUsers,
        {
          columnPassword: hashedNewPassword,
          columnUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '$columnId = ?',
        whereArgs: [userId],
      );

      if (rowsAffected > 0) {
        return {'success': true, 'message': 'Đổi mật khẩu thành công'};
      } else {
        return {'success': false, 'message': 'Có lỗi xảy ra khi đổi mật khẩu'};
      }
    } catch (e) {
      print('Error changing password: $e');
      return {'success': false, 'message': 'Có lỗi xảy ra khi đổi mật khẩu'};
    }
  }

  // Vô hiệu hóa tài khoản người dùng
  Future<Map<String, dynamic>> deactivateUser(int userId) async {
    try {
      final db = await database;

      int rowsAffected = await db.update(
        tableUsers,
        {columnIsActive: 0, columnUpdatedAt: DateTime.now().toIso8601String()},
        where: '$columnId = ?',
        whereArgs: [userId],
      );

      if (rowsAffected > 0) {
        return {'success': true, 'message': 'Vô hiệu hóa tài khoản thành công'};
      } else {
        return {'success': false, 'message': 'Không tìm thấy người dùng'};
      }
    } catch (e) {
      print('Error deactivating user: $e');
      return {'success': false, 'message': 'Có lỗi xảy ra'};
    }
  }

  // Lấy danh sách tất cả người dùng (để admin quản lý)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final db = await database;

      List<Map<String, dynamic>> result = await db.query(
        tableUsers,
        orderBy: '$columnCreatedAt DESC',
      );

      // Loại bỏ mật khẩu khỏi tất cả kết quả
      return result.map((user) {
        user.remove(columnPassword);
        return user;
      }).toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  // Xóa hoàn toàn người dùng (cẩn thận khi sử dụng)
  Future<Map<String, dynamic>> deleteUser(int userId) async {
    try {
      final db = await database;

      int rowsAffected = await db.delete(
        tableUsers,
        where: '$columnId = ?',
        whereArgs: [userId],
      );

      if (rowsAffected > 0) {
        return {'success': true, 'message': 'Xóa người dùng thành công'};
      } else {
        return {'success': false, 'message': 'Không tìm thấy người dùng'};
      }
    } catch (e) {
      print('Error deleting user: $e');
      return {'success': false, 'message': 'Có lỗi xảy ra khi xóa'};
    }
  }

  // Đóng database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Xóa database (để testing)
  Future<void> deleteDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _databaseName);
      await databaseFactory.deleteDatabase(path);
      _database = null;
    } catch (e) {
      print('Error deleting database: $e');
    }
  }
}
