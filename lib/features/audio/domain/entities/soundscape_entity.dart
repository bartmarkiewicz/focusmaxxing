import 'package:equatable/equatable.dart';

/// Represents an offline ambient audio soundscape available for focus sessions.
class SoundscapeEntity extends Equatable {
  static const String chimeCompleteAssetPath =
      'assets/audio/chime_complete.ogg';

  static const SoundscapeEntity none = SoundscapeEntity(
    id: 'none',
    title: 'None',
    subtitle: 'Silent focus',
    assetPath: '',
    isProOnly: false,
  );

  static const SoundscapeEntity brownNoise = SoundscapeEntity(
    id: 'brown_noise',
    title: 'Brown Noise',
    subtitle: 'Low-frequency household noise masking',
    assetPath: 'assets/audio/brown_noise_loop.ogg',
    isProOnly: true,
  );

  static const SoundscapeEntity gamma40Hz = SoundscapeEntity(
    id: 'gamma_40hz',
    title: '40Hz Gamma',
    subtitle: 'Isochronic cognitive entrainment',
    assetPath: 'assets/audio/gamma_40hz_loop.ogg',
    isProOnly: true,
  );

  static const SoundscapeEntity rain = SoundscapeEntity(
    id: 'rain',
    title: 'Rain on Canvas',
    subtitle: 'Gentle natural ambient',
    assetPath: 'assets/audio/rain_canvas_loop.ogg',
    isProOnly: true,
  );

  static const List<SoundscapeEntity> presets = [
    none,
    brownNoise,
    gamma40Hz,
    rain,
  ];

  final String id;
  final String title;
  final String subtitle;
  final String assetPath;
  final bool isProOnly;

  const SoundscapeEntity({
    required this.id,
    required this.title,
    required this.assetPath,
    this.isProOnly = false,
    this.subtitle = '',
  });

  bool get isNone => id == none.id || assetPath.isEmpty;

  static SoundscapeEntity fromId(String id) {
    for (final preset in presets) {
      if (preset.id == id) {
        return preset;
      }
    }
    return none;
  }

  @override
  List<Object?> get props => [id, title, subtitle, assetPath, isProOnly];
}
