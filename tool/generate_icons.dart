import 'dart:io';
import 'dart:typed_data';

// Simple, dependency-free PNG generator for app icons and splash screen.

Uint8List createPng({
  required int width,
  required int height,
  required void Function(int x, int y, Uint8List pixel) pixelShader,
}) {
  final rawScanlines = BytesBuilder();
  final pixel = Uint8List(4);

  for (var y = 0; y < height; y++) {
    rawScanlines.addByte(0); // Filter type 0: None
    for (var x = 0; x < width; x++) {
      pixelShader(x, y, pixel);
      rawScanlines.add(pixel);
    }
  }

  final compressed = zlib.encode(rawScanlines.toBytes());

  final png = BytesBuilder();
  // PNG signature
  png.add([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR chunk
  final ihdrData = ByteData(13)
    ..setUint32(0, width, Endian.big)
    ..setUint32(4, height, Endian.big)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // RGBA color type
    ..setUint8(10, 0) // compression
    ..setUint8(11, 0) // filter
    ..setUint8(12, 0); // interlace
  _writeChunk(png, 'IHDR', ihdrData.buffer.asUint8List());

  // IDAT chunk
  _writeChunk(png, 'IDAT', Uint8List.fromList(compressed));

  // IEND chunk
  _writeChunk(png, 'IEND', Uint8List(0));

  return png.toBytes();
}

void _writeChunk(BytesBuilder builder, String type, Uint8List data) {
  final length = data.length;
  final lengthBytes = ByteData(4)..setUint32(0, length, Endian.big);
  builder.add(lengthBytes.buffer.asUint8List());

  final typeBytes = Uint8List.fromList(type.codeUnits);
  builder.add(typeBytes);
  builder.add(data);

  final crcPayload = Uint8List(typeBytes.length + data.length);
  crcPayload.setRange(0, typeBytes.length, typeBytes);
  crcPayload.setRange(typeBytes.length, crcPayload.length, data);
  final crc = _crc32(crcPayload);

  final crcBytes = ByteData(4)..setUint32(0, crc, Endian.big);
  builder.add(crcBytes.buffer.asUint8List());
}

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

// Glyph renderer: A stylized lock / shield glyph representing Focusmaxxing.
// Shackle on top, rounded lock body with keyhole / bolt in center.
bool isInsideLockGlyph(int x, int y, int size, {double scale = 1.0}) {
  final cx = size / 2.0;
  final cy = size / 2.0;
  final r = (size * 0.32) * scale;

  // Normalized coordinates (-1 to 1) relative to center
  final nx = (x - cx) / r;
  final ny = (y - cy) / r;

  // Lock Body: rounded rect at bottom [-0.65 to 0.65] x [-0.05 to 0.75]
  final inBody = nx >= -0.65 && nx <= 0.65 && ny >= -0.1 && ny <= 0.75;
  if (inBody) {
    // Round corners of lock body
    const cornerR = 0.22;
    if (nx > 0.65 - cornerR && ny > 0.75 - cornerR) {
      final dx = nx - (0.65 - cornerR);
      final dy = ny - (0.75 - cornerR);
      if (dx * dx + dy * dy > cornerR * cornerR) return false;
    }
    if (nx < -0.65 + cornerR && ny > 0.75 - cornerR) {
      final dx = nx - (-0.65 + cornerR);
      final dy = ny - (0.75 - cornerR);
      if (dx * dx + dy * dy > cornerR * cornerR) return false;
    }
    if (nx > 0.65 - cornerR && ny < -0.1 + cornerR) {
      final dx = nx - (0.65 - cornerR);
      final dy = ny - (-0.1 + cornerR);
      if (dx * dx + dy * dy > cornerR * cornerR) return false;
    }
    if (nx < -0.65 + cornerR && ny < -0.1 + cornerR) {
      final dx = nx - (-0.65 + cornerR);
      final dy = ny - (-0.1 + cornerR);
      if (dx * dx + dy * dy > cornerR * cornerR) return false;
    }

    // Keyhole / bolt cutout in lock body:
    // Circle at (0, 0.22) with radius 0.12, and vertical slot down to 0.52 width 0.08
    final kx = nx;
    final ky = ny - 0.22;
    if (kx * kx + ky * ky <= 0.018) return false; // cutout circle
    if (nx.abs() <= 0.05 && ny >= 0.22 && ny <= 0.48) return false; // cutout slot

    return true;
  }

  // Shackle (Arch): Outer arch centered at (0, -0.1) with outer radius 0.46, inner radius 0.26
  final sy = ny - (-0.1);
  final distSq = nx * nx + sy * sy;
  if (sy <= 0 && distSq <= 0.46 * 0.46 && distSq >= 0.26 * 0.26) {
    return true;
  }
  // Shackle legs going down into lock body
  if (sy > 0 && sy <= 0.15 && (nx.abs() >= 0.26 && nx.abs() <= 0.46)) {
    return true;
  }

  return false;
}

void main() {
  final outDir = Directory('assets/icons');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  // 1. app_icon.png: 512x512, OLED Midnight background (#090A0D), Electric Emerald lock (#00E676)
  final appIcon = createPng(
    width: 512,
    height: 512,
    pixelShader: (x, y, pixel) {
      if (isInsideLockGlyph(x, y, 512, scale: 0.85)) {
        pixel[0] = 0x00; // R
        pixel[1] = 0xE6; // G
        pixel[2] = 0x76; // B
        pixel[3] = 0xFF; // A
      } else {
        pixel[0] = 0x09;
        pixel[1] = 0x0A;
        pixel[2] = 0x0D;
        pixel[3] = 0xFF;
      }
    },
  );
  File('assets/icons/app_icon.png').writeAsBytesSync(appIcon);
  stdout.writeln('Generated assets/icons/app_icon.png');

  // 2. app_icon_background.png: 432x432, solid OLED Midnight (#090A0D)
  final bgIcon = createPng(
    width: 432,
    height: 432,
    pixelShader: (x, y, pixel) {
      pixel[0] = 0x09;
      pixel[1] = 0x0A;
      pixel[2] = 0x0D;
      pixel[3] = 0xFF;
    },
  );
  File('assets/icons/app_icon_background.png').writeAsBytesSync(bgIcon);
  stdout.writeln('Generated assets/icons/app_icon_background.png');

  // 3. app_icon_foreground.png: 432x432, transparent, Electric Emerald lock (#00E676)
  final fgIcon = createPng(
    width: 432,
    height: 432,
    pixelShader: (x, y, pixel) {
      // Safe zone in adaptive icon is central 66% (diameter ~288px)
      if (isInsideLockGlyph(x, y, 432, scale: 0.65)) {
        pixel[0] = 0x00;
        pixel[1] = 0xE6;
        pixel[2] = 0x76;
        pixel[3] = 0xFF;
      } else {
        pixel[0] = 0x00;
        pixel[1] = 0x00;
        pixel[2] = 0x00;
        pixel[3] = 0x00;
      }
    },
  );
  File('assets/icons/app_icon_foreground.png').writeAsBytesSync(fgIcon);
  stdout.writeln('Generated assets/icons/app_icon_foreground.png');

  // 4. app_icon_monochrome.png: 432x432, transparent, pure white (#FFFFFF)
  final monoIcon = createPng(
    width: 432,
    height: 432,
    pixelShader: (x, y, pixel) {
      if (isInsideLockGlyph(x, y, 432, scale: 0.65)) {
        pixel[0] = 0xFF;
        pixel[1] = 0xFF;
        pixel[2] = 0xFF;
        pixel[3] = 0xFF;
      } else {
        pixel[0] = 0x00;
        pixel[1] = 0x00;
        pixel[2] = 0x00;
        pixel[3] = 0x00;
      }
    },
  );
  File('assets/icons/app_icon_monochrome.png').writeAsBytesSync(monoIcon);
  stdout.writeln('Generated assets/icons/app_icon_monochrome.png');

  // 5. splash_icon.png: 512x512, transparent, Electric Emerald lock (#00E676)
  final splashIcon = createPng(
    width: 512,
    height: 512,
    pixelShader: (x, y, pixel) {
      if (isInsideLockGlyph(x, y, 512, scale: 0.70)) {
        pixel[0] = 0x00;
        pixel[1] = 0xE6;
        pixel[2] = 0x76;
        pixel[3] = 0xFF;
      } else {
        pixel[0] = 0x00;
        pixel[1] = 0x00;
        pixel[2] = 0x00;
        pixel[3] = 0x00;
      }
    },
  );
  File('assets/icons/splash_icon.png').writeAsBytesSync(splashIcon);
  stdout.writeln('Generated assets/icons/splash_icon.png');
}
