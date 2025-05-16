import 'package:flutter/foundation.dart' show kIsWeb;
// Hanya impor dart:io jika tidak di web
import 'dart:io' if (dart.library.html) 'dart:io_unavailable.dart';

// Definisikan stub untuk Platform jika dart:io tidak tersedia (misalnya di web)
// Ini bisa menjadi file terpisah dart:io_unavailable.dart yang diekspor,
// atau didefinisikan di sini jika sederhana.
// Untuk contoh ini, kita asumsikan Platform akan tersedia jika !kIsWeb.

class PlatformChecker {
  static bool get isAndroid {
    if (kIsWeb) {
      return false;
    }
    // Aman untuk memanggil Platform.isAndroid di sini karena kita sudah memeriksa !kIsWeb
    return Platform.isAndroid;
  }

  static String get operatingSystem {
    if (kIsWeb) {
      return 'web';
    }
    // Aman untuk memanggil Platform.operatingSystem
    return Platform.operatingSystem;
  }

  static String get operatingSystemVersion {
    if (kIsWeb) {
      return 'N/A';
    }
    // Aman untuk memanggil Platform.operatingSystemVersion
    return Platform.operatingSystemVersion;
  }
}

// Anda mungkin perlu membuat file `lib/utils/dart_io_unavailable.dart`
// dengan konten minimal jika `import 'dart:io' if (dart.library.html) 'dart:io_unavailable.dart';`
// masih menyebabkan masalah. Isinya bisa seperti:
// class Platform {
//   static bool get isAndroid => false;
//   static String get operatingSystem => 'web_stub';
//   static String get operatingSystemVersion => 'web_stub_version';
//   // tambahkan getter lain yang mungkin Anda butuhkan
// }
// Namun, pendekatan dengan `kIsWeb` di atas seharusnya cukup.
