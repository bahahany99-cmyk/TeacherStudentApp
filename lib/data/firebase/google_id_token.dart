import 'dart:convert';

/// قراءة حمولة `idToken` (JWT) بلا أي مكتبة خارجية.
///
/// لماذا نحن؟ لأن الفرق بين **عميل ويب** (`client_type: 3`) و**عميل أندرويد**
/// (`client_type: 1`) في `google-services.json` لا يظهر في شكل المعرّف نفسه —
/// الشكلان متطابقان: `<رقم المشروع>-<هاش>.apps.googleusercontent.com`. الخطأ
/// الشائع هو لصق معرّف أندرويد في `serverClientId`، فيصدر Google رمزًا جمهوره
/// (`aud`) هو عميل أندرويد، ويرفضه Firebase برسالة غامضة.
///
/// بالتحقق من `aud` داخل الرمز **قبل** إرساله إلى Firebase نستطيع أن نقول
/// السبب بالحرف بدل «حدث خطأ».
///
/// ⚠️ هذا **ليس** تحققًا أمنيًا: لا نتحقق من التوقيع (Firebase هو من يفعله).
/// غايته تشخيصية بحتة، ولذلك لا نعتمد عليه في أي قرار صلاحيات.
abstract final class GoogleIdToken {
  /// يعيد قيمة `aud` من حمولة الرمز، أو `null` إن كان الرمز غير قابل للقراءة.
  static String? audience(String token) {
    final Map<String, Object?>? payload = _payload(token);
    final Object? aud = payload?['aud'];
    return aud is String && aud.isNotEmpty ? aud : null;
  }

  /// هل `aud` في الرمز يخالف معرّف عميل الويب المتوقع؟
  ///
  /// `false` أيضًا عندما يتعذّر قراءة الرمز (ندع Firebase يحكم في هذه الحالة
  /// بدل منع محاولة سليمة).
  static bool hasForeignAudience({
    required String token,
    required String expectedClientId,
  }) {
    final String? aud = audience(token);
    if (aud == null || expectedClientId.isEmpty) {
      return false;
    }
    return aud != expectedClientId;
  }

  static Map<String, Object?>? _payload(String token) {
    final List<String> parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    try {
      // JWT يستخدم Base64Url بلا حشو (padding) — نعيد الحشو قبل الفك.
      String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      final int remainder = normalized.length % 4;
      if (remainder > 0) {
        normalized = normalized.padRight(normalized.length + 4 - remainder, '=');
      }
      final Object? decoded = jsonDecode(utf8.decode(base64Decode(normalized)));
      return decoded is Map<String, Object?> ? decoded : null;
    } on Object {
      return null;
    }
  }
}
