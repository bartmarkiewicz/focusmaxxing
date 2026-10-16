import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/theme/app_theme.dart';
import 'package:focusmaxxing/features/audio/domain/entities/soundscape_entity.dart';
import 'package:focusmaxxing/features/audio/domain/repositories/i_audio_repository.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/play_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/set_audio_volume_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/stop_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:focusmaxxing/features/audio/presentation/widgets/soundscape_config_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioRepository implements IAudioRepository {
  final List<String> playedAssets = [];
  final List<double> volumes = [];
  int stopCount = 0;
  Failure? failureToReturn;

  @override
  Future<Either<Failure, void>> playLoop(String assetPath) async {
    if (failureToReturn case final failure?) {
      return Left(failure);
    }
    playedAssets.add(assetPath);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> stopLoop() async {
    stopCount++;
    if (failureToReturn case final failure?) {
      return Left(failure);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setVolume(double volume) async {
    if (failureToReturn case final failure?) {
      return Left(failure);
    }
    volumes.add(volume);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> preloadAssets(List<String> assetPaths) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> playChime({
    String assetPath = SoundscapeEntity.chimeCompleteAssetPath,
  }) async =>
      const Right(null);

  @override
  Future<void> dispose() async {}
}

void main() {
  late _FakeAudioRepository repository;
  late AudioNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = _FakeAudioRepository();
    notifier = AudioNotifier(
      playSoundscapeUseCase: PlaySoundscapeUseCase(repository),
      stopSoundscapeUseCase: StopSoundscapeUseCase(repository),
      setAudioVolumeUseCase: SetAudioVolumeUseCase(repository),
      repository: repository,
      sharedPreferences: prefs,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  Widget buildTestWidget({bool? isProUnlocked}) {
    return MaterialApp(
      theme: AppTheme.buildDarkTheme(null),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChangeNotifierProvider<AudioNotifier>.value(
            value: notifier,
            child: SoundscapeConfigTile(isProUnlocked: isProUnlocked),
          ),
        ),
      ),
    );
  }

  group('SoundscapeConfigTile Widget Tests', () {
    testWidgets('renders radio options, preview button, and volume slider',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Ambient Audio'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(find.text('Brown Noise'), findsOneWidget);
      expect(find.text('40Hz Gamma'), findsOneWidget);
      expect(find.text('Rain on Canvas'), findsOneWidget);

      expect(
        find.byKey(const ValueKey('soundscape_preview_button')),
        findsOneWidget,
      );
      expect(find.text('Preview'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      expect(
        find.byKey(const ValueKey('soundscape_volume_slider')),
        findsOneWidget,
      );
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets(
        'displays Pro padlock badges when locked and hides them when unlocked',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(isProUnlocked: false));

      expect(find.text('PRO'), findsNWidgets(3));
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3));

      await tester.pumpWidget(buildTestWidget(isProUnlocked: true));
      await tester.pump();

      expect(find.text('PRO'), findsNothing);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    });

    testWidgets('tapping a locked Pro option prompts pro requirement banner cleanly',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(isProUnlocked: false));

      await tester.tap(
        find.byKey(const ValueKey('soundscape_option_brown_noise')),
      );
      await tester.pumpAndSettle();

      expect(notifier.activeSoundscape, equals(SoundscapeEntity.none));
      expect(notifier.isPlaying, isFalse);
      expect(
        find.byKey(const ValueKey('soundscape_error_banner')),
        findsOneWidget,
      );
      expect(
        find.text('Unlock Lifetime Pro to access Brown Noise'),
        findsOneWidget,
      );

      // Dismiss banner
      await tester.tap(find.byKey(const ValueKey('soundscape_error_dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('soundscape_error_banner')), findsNothing);
    });

    testWidgets('pro user selecting soundscape updates active state and preview button toggles playback',
        (tester) async {
      notifier.setProUnlocked(true);
      await tester.pumpWidget(buildTestWidget(isProUnlocked: true));

      await tester.tap(
        find.byKey(const ValueKey('soundscape_option_brown_noise')),
      );
      await tester.pumpAndSettle();

      expect(notifier.activeSoundscape, equals(SoundscapeEntity.brownNoise));
      expect(notifier.isPlaying, isFalse);

      await tester.tap(find.byKey(const ValueKey('soundscape_preview_button')));
      await tester.pumpAndSettle();

      expect(notifier.isPlaying, isTrue);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('soundscape_preview_button')));
      await tester.pumpAndSettle();

      expect(notifier.isPlaying, isFalse);
      expect(find.text('Preview'), findsOneWidget);
    });

    testWidgets('dragging volume slider updates AudioNotifier volume',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final sliderFinder = find.byKey(
        const ValueKey('soundscape_volume_slider'),
      );
      await tester.drag(sliderFinder, const Offset(150, 0));
      await tester.pumpAndSettle();

      expect(notifier.volume, greaterThan(0.5));
      expect(repository.volumes, isNotEmpty);
    });

    testWidgets('renders error banner when AudioNotifier reports an error',
        (tester) async {
      notifier.setProUnlocked(true);
      repository.failureToReturn =
          const PlatformFailure('Unable to initialize audio output');

      await tester.pumpWidget(buildTestWidget(isProUnlocked: true));
      await tester.tap(
        find.byKey(const ValueKey('soundscape_preview_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('soundscape_error_banner')),
        findsOneWidget,
      );
      expect(find.text('Unable to initialize audio output'), findsOneWidget);
    });
  });
}
