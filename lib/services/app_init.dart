import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppInit {
  static bool _ready = false;

  static Future<void> ensureReady() async {
    if (_ready) return;
    // Desktop SQLite init
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ready = true;
  }
}
