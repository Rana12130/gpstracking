// lib/services/speech_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/app_state.dart';
import '../models/place_model.dart';
import '../constants/app_constants.dart';
import '../constants/voice_commands.dart';

class SpeechService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _textToSpeech = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isListening = false;
  Timer? _repeatTimer;

  bool get isListening => _isListening;

  Future<void> init(AppState appState) async {
    await _initializeTextToSpeech(appState);
    final bool speechAvailable = await _speechToText.initialize(
      onError: (error) {
        if (kDebugMode) print("Speech error: $error");
      },
      onStatus: (status) {
        if (kDebugMode) print("Speech status: $status");
      },
    );

    if (!speechAvailable) {
      appState.setStatusText("Speech recognition not available");
    }
  }

  Future<void> _initializeTextToSpeech(AppState appState) async {
    try {
      await _textToSpeech.setLanguage('en-US');
      await _textToSpeech.setSpeechRate(0.95);
      await _textToSpeech.setVolume(1.0);
      await _textToSpeech.setPitch(1.0);
      _textToSpeech.setCompletionHandler(() {
        if (kDebugMode) print("TTS completed");
      });
      _textToSpeech.setErrorHandler((msg) {
        if (kDebugMode) print("TTS error: $msg");
      });
    } catch (e) {
      if (kDebugMode) print("TTS initialization error: $e");
    }
  }

  Future<void> startMicLoop(Place place, AppState appState) async {
    if (!appState.scenarioActive || !appState.mounted) return;

    _repeatTimer?.cancel();
    appState.setListening(true);

    await _playChime();

    if (!await _speechToText.hasPermission) {
      appState.setListening(false);
      await appState.notificationService.showNotification("Mic Error", "Please allow microphone");
      return;
    }

    String heard = "";
    try {
      await _speechToText.listen(
        onResult: (result) {
          heard = result.recognizedWords.toLowerCase();
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          listenFor: AppConstants.listenDuration,
          pauseFor: AppConstants.pauseDuration,
          cancelOnError: false,
          onDevice: false,
        ),
      );
      await Future.delayed(AppConstants.listenDuration);
      if (_speechToText.isListening) await _speechToText.stop();
    } catch (e) {
      if (kDebugMode) print("Speech error: $e");
    }

    appState.setListening(false);

    if (_processCommand(heard, place, appState)) return;

    if (appState.scenarioActive) {
      await appState.notificationService.showNotification("🎤 Still listening", "Say 'Enter' or 'Exit'");
      await _textToSpeech.speak("I am still listening, please say Enter or Exit");
      _repeatTimer = Timer(AppConstants.repeatDelay, () => startMicLoop(place, appState));
    }
  }

  bool _processCommand(String heard, Place place, AppState appState) {
    heard = heard.trim().toLowerCase();

    for (final String keyword in VoiceCommands.enterKeywords) {
      if (heard.contains(keyword)) {
        _handleEnterCommand(place, appState);
        return true;
      }
    }

    for (final String keyword in VoiceCommands.exitKeywords) {
      if (heard.contains(keyword)) {
        _handleExitCommand(appState);
        return true;
      }
    }

    return false;
  }

  void _handleEnterCommand(Place place, AppState appState) {
    cancelRepeatTimer();

    appState.visitedPlaces.add(place.name);

    appState.notificationService.showNotification("✅ Entry Confirmed", "Welcome to ${place.name}");
    _textToSpeech.speak("Welcome to ${place.name}. Enjoy your visit.");

    if (kDebugMode) print("User entered: ${place.name} at ${DateTime.now()}");

    cancelRepeatTimer();
    appState.setStatusText("Inside: ${place.name}");
  }

  void _handleExitCommand(AppState appState) {
    cancelRepeatTimer();

    appState.notificationService.showNotification("👋 Scenario Ended", "Voice commands stopped");
    _textToSpeech.speak("Okay, ending voice commands.");

    // Manual exit: Reset scenario without checkout notif/TTS
    appState.setScenarioActive(false);
    appState.setActivePlace(null);
    appState.setArrivalTime(null);
    appState.setStatusText("Monitoring locations");
  }

  void cancelRepeatTimer() {
    _repeatTimer?.cancel();
  }

  Future<void> _playChime() async {
    try {
      await _audioPlayer.play(AssetSource(AppConstants.chimeAsset));
    } catch (e) {
      if (kDebugMode) print("Chime error: $e");
      await _textToSpeech.speak("Listening now");
    }
  }

  Future<void> speak(String text) async {
    await _textToSpeech.speak(text);
  }

  void dispose() {
    _speechToText.cancel();
    _textToSpeech.stop();
    _audioPlayer.dispose();
    _repeatTimer?.cancel();
  }
}
