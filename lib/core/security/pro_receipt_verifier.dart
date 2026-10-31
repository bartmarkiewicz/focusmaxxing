import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Immutable value record representing a cryptographically verified Pro receipt.
class VerifiedProReceipt {
  final bool isUnlocked;
  final int? purchaseDateMs;
  final String? orderId;

  const VerifiedProReceipt({
    required this.isUnlocked,
    this.purchaseDateMs,
    this.orderId,
  });

  static const VerifiedProReceipt locked = VerifiedProReceipt(
    isUnlocked: false,
  );
}

/// Unified cryptographic receipt signer and verifier for Lifetime Pro entitlements.
///
/// Prevents trivial anti-tampering bypasses where plain-text booleans
/// (`is_lifetime_pro`, `is_pro_unlocked`) are edited in `SharedPreferences`.
class ProReceiptVerifier {
  ProReceiptVerifier._();

  static const String lifetimeProProductId = 'focusmaxxing_lifetime_pro_999';
  static const String proUnlockedPrefsKey = 'is_pro_unlocked';
  static const String lifetimeProLegacyPrefsKey = 'is_lifetime_pro';
  static const String encryptedReceiptPrefsKey = 'billing_encrypted_receipt_v1';
  static const String purchaseDateMsPrefsKey = 'billing_purchase_date_ms';
  static const String orderIdPrefsKey = 'billing_order_id';

  static const List<int> _cipherKeyBytes = <int>[
    0x46, 0x4F, 0x43, 0x55, 0x53, 0x4D, 0x41, 0x58, // FOCUSMAX
    0x58, 0x49, 0x4E, 0x47, 0x5F, 0x50, 0x52, 0x4F, // XING_PRO
    0x5F, 0x39, 0x39, 0x39, 0x5F, 0x4B, 0x45, 0x59, // _999_KEY
  ];

  static const List<int> _sha256K = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  /// Reads and cryptographically verifies the cached [VerifiedProReceipt]
  /// from [prefs]. Unverified plaintext booleans are ignored.
  static VerifiedProReceipt readVerifiedReceiptSync(SharedPreferences prefs) {
    try {
      final encryptedPayload = prefs.getString(encryptedReceiptPrefsKey);
      if (encryptedPayload != null && encryptedPayload.isNotEmpty) {
        final decodedStatus = decodeAndVerifyReceipt(encryptedPayload);
        if (decodedStatus != null) {
          return decodedStatus;
        }
      }
    } on Exception {
      return VerifiedProReceipt.locked;
    }
    return VerifiedProReceipt.locked;
  }

  /// Returns `true` only if [prefs] contains an authentic, untampered Pro receipt.
  static bool isProUnlockedInPrefs(SharedPreferences prefs) {
    return readVerifiedReceiptSync(prefs).isUnlocked;
  }

  /// Ensures an unlocked receipt exists in [prefs] without clobbering existing
  /// `purchaseDateMs` or `orderId` metadata if already unlocked.
  static Future<void> ensureUnlockedInPrefs(SharedPreferences prefs) async {
    final existing = readVerifiedReceiptSync(prefs);
    if (existing.isUnlocked) {
      await prefs.setBool(proUnlockedPrefsKey, true);
      await prefs.setBool(lifetimeProLegacyPrefsKey, true);
      return;
    }
    await persistVerifiedReceipt(
      prefs,
      const VerifiedProReceipt(isUnlocked: true),
    );
  }

  /// Persists the signed receipt and synchronized flags to [prefs], preserving
  /// existing `purchaseDateMs` and `orderId` metadata if omitted on an unlock.
  static Future<void> persistVerifiedReceipt(
    SharedPreferences prefs,
    VerifiedProReceipt receipt,
  ) async {
    var effectiveReceipt = receipt;
    if (receipt.isUnlocked &&
        (receipt.purchaseDateMs == null || receipt.orderId == null)) {
      final existing = readVerifiedReceiptSync(prefs);
      if (existing.isUnlocked) {
        effectiveReceipt = VerifiedProReceipt(
          isUnlocked: true,
          purchaseDateMs: receipt.purchaseDateMs ?? existing.purchaseDateMs,
          orderId: receipt.orderId ?? existing.orderId,
        );
      }
    }

    final encodedReceipt = encodeSignedReceipt(
      isUnlocked: effectiveReceipt.isUnlocked,
      purchaseDateMs: effectiveReceipt.purchaseDateMs,
      orderId: effectiveReceipt.orderId,
    );
    await prefs.setString(encryptedReceiptPrefsKey, encodedReceipt);
    await prefs.setBool(proUnlockedPrefsKey, effectiveReceipt.isUnlocked);
    await prefs.setBool(lifetimeProLegacyPrefsKey, effectiveReceipt.isUnlocked);

    final purchaseDateMs = effectiveReceipt.purchaseDateMs;
    if (purchaseDateMs != null) {
      await prefs.setInt(purchaseDateMsPrefsKey, purchaseDateMs);
    } else if (!effectiveReceipt.isUnlocked) {
      await prefs.remove(purchaseDateMsPrefsKey);
    }

    final orderId = effectiveReceipt.orderId;
    if (orderId != null) {
      await prefs.setString(orderIdPrefsKey, orderId);
    } else if (!effectiveReceipt.isUnlocked) {
      await prefs.remove(orderIdPrefsKey);
    }
  }

  /// Encodes and signs the receipt parameters with both HMAC-SHA256 and FNV-1a.
  static String encodeSignedReceipt({
    required bool isUnlocked,
    int? purchaseDateMs,
    String? orderId,
  }) {
    final payloadMap = <String, Object?>{
      'u': isUnlocked,
      'd': purchaseDateMs,
      'o': orderId,
      'p': lifetimeProProductId,
    };
    final jsonString = jsonEncode(payloadMap);
    final signature = _computeFnv1aHash(jsonString);
    final hmacHex = _computeHmacSha256Hex(jsonString);
    final envelope = jsonEncode(<String, Object?>{
      'p': jsonString,
      's': signature,
      'h': hmacHex,
    });
    final plainBytes = utf8.encode(envelope);
    final cipherBytes = _xorTransform(plainBytes);
    return base64UrlEncode(cipherBytes);
  }

  /// Decodes and verifies a signed receipt string, returning `null` if tampered
  /// or if the HMAC-SHA256 signature is missing/invalid.
  static VerifiedProReceipt? decodeAndVerifyReceipt(String encoded) {
    try {
      final cipherBytes = base64Url.decode(encoded);
      final plainBytes = _xorTransform(cipherBytes);
      final envelopeString = utf8.decode(plainBytes);
      final dynamic decodedEnvelope = jsonDecode(envelopeString);
      if (decodedEnvelope is! Map<String, dynamic>) {
        return null;
      }

      final payloadString = decodedEnvelope['p'];
      final signature = decodedEnvelope['s'];
      final hmac = decodedEnvelope['h'];
      if (payloadString is! String || signature is! int || hmac is! String) {
        return null;
      }

      if (_computeFnv1aHash(payloadString) != signature) {
        return null;
      }

      final expectedHmac = _computeHmacSha256Hex(payloadString);
      if (!_constantTimeEquals(hmac, expectedHmac)) {
        return null;
      }

      final dynamic payload = jsonDecode(payloadString);
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final isUnlocked = payload['u'];
      final purchaseDateMs = payload['d'];
      final orderId = payload['o'];
      final productId = payload['p'];

      if (isUnlocked is! bool) {
        return null;
      }
      if (productId != lifetimeProProductId) {
        return null;
      }

      return VerifiedProReceipt(
        isUnlocked: isUnlocked,
        purchaseDateMs: purchaseDateMs is int ? purchaseDateMs : null,
        orderId: orderId is String ? orderId : null,
      );
    } on Exception {
      return null;
    }
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static Uint8List _xorTransform(List<int> input) {
    final output = Uint8List(input.length);
    for (var i = 0; i < input.length; i++) {
      output[i] = input[i] ^ _cipherKeyBytes[i % _cipherKeyBytes.length];
    }
    return output;
  }

  static int _computeFnv1aHash(String input) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static String _computeHmacSha256Hex(String message) {
    const blockSize = 64;
    final keyBlock = Uint8List(blockSize);
    for (var i = 0; i < _cipherKeyBytes.length && i < blockSize; i++) {
      keyBlock[i] = _cipherKeyBytes[i];
    }

    final ipad = Uint8List(blockSize);
    final opad = Uint8List(blockSize);
    for (var i = 0; i < blockSize; i++) {
      ipad[i] = keyBlock[i] ^ 0x36;
      opad[i] = keyBlock[i] ^ 0x5c;
    }

    final msgBytes = utf8.encode(message);
    final innerInput = Uint8List(blockSize + msgBytes.length)
      ..setRange(0, blockSize, ipad)
      ..setRange(blockSize, blockSize + msgBytes.length, msgBytes);
    final innerDigest = _sha256(innerInput);

    final outerInput = Uint8List(blockSize + innerDigest.length)
      ..setRange(0, blockSize, opad)
      ..setRange(blockSize, blockSize + innerDigest.length, innerDigest);
    final outerDigest = _sha256(outerInput);

    final sb = StringBuffer();
    for (final byte in outerDigest) {
      sb.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Uint8List _sha256(List<int> data) {
    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    final bitLength = data.length * 8;
    final paddedLength = ((data.length + 9 + 63) ~/ 64) * 64;
    final padded = Uint8List(paddedLength);
    padded.setRange(0, data.length, data);
    padded[data.length] = 0x80;

    final bd = ByteData.sublistView(padded);
    bd.setUint32(paddedLength - 8, (bitLength >>> 32) & 0xffffffff, Endian.big);
    bd.setUint32(paddedLength - 4, bitLength & 0xffffffff, Endian.big);

    final w = Uint32List(64);

    for (var chunkStart = 0; chunkStart < paddedLength; chunkStart += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = bd.getUint32(chunkStart + (i * 4), Endian.big);
      }
      for (var i = 16; i < 64; i++) {
        final s0 =
            _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        final s1 =
            _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
      }

      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      var f = h5;
      var g = h6;
      var h = h7;

      for (var i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ ((~e & 0xffffffff) & g);
        final temp1 = (h + s1 + ch + _sha256K[i] + w[i]) & 0xffffffff;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xffffffff;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }

      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
      h5 = (h5 + f) & 0xffffffff;
      h6 = (h6 + g) & 0xffffffff;
      h7 = (h7 + h) & 0xffffffff;
    }

    final digest = Uint8List(32);
    final out = ByteData.sublistView(digest);
    out.setUint32(0, h0, Endian.big);
    out.setUint32(4, h1, Endian.big);
    out.setUint32(8, h2, Endian.big);
    out.setUint32(12, h3, Endian.big);
    out.setUint32(16, h4, Endian.big);
    out.setUint32(20, h5, Endian.big);
    out.setUint32(24, h6, Endian.big);
    out.setUint32(28, h7, Endian.big);
    return digest;
  }

  static int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xffffffff;
}
