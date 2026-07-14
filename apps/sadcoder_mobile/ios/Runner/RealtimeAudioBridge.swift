import AVFoundation
import Flutter
import UIKit

final class RealtimeAudioBridge: NSObject, FlutterStreamHandler {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let audioQueue = DispatchQueue(label: "com.sadcoder.sadcoder_mobile.realtime-audio")
  private var eventSink: FlutterEventSink?
  private var converter: AVAudioConverter?
  private var targetFormat: AVAudioFormat?
  private var targetSampleRate = 24_000
  private var targetChannels = 1
  private var targetSamplesPerChannel = 480
  private var pendingInput = Data()
  private var capturing = false
  private var playerAttached = false
  private var tapInstalled = false

  override init() {
    super.init()
  }

  func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(
      name: "com.sadcoder.sadcoder_mobile/realtime_audio",
      binaryMessenger: messenger
    ).setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    FlutterEventChannel(
      name: "com.sadcoder.sadcoder_mobile/realtime_audio_input",
      binaryMessenger: messenger
    ).setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    stopCapture()
    return nil
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startCapture":
      startCapture(arguments: call.arguments, result: result)
    case "stopCapture":
      stopCapture()
      result(nil)
    case "play":
      play(arguments: call.arguments, result: result)
    case "stopPlayback":
      stopPlayback()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startCapture(arguments: Any?, result: @escaping FlutterResult) {
    let args = arguments as? [String: Any]
    let sampleRate = positiveInt(args?["sampleRate"], fallback: 24_000)
    let channels = positiveInt(args?["numChannels"], fallback: 1)
    let samples = positiveInt(args?["samplesPerChannel"], fallback: 480)
    guard channels == 1 else {
      result(FlutterError(
        code: "unsupported_audio_channels",
        message: "iOS realtime capture currently supports mono PCM only.",
        details: nil
      ))
      return
    }

    AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
      DispatchQueue.main.async {
        guard let self = self else {
          result(FlutterError(
            code: "realtime_audio_unavailable",
            message: "Realtime audio is no longer available.",
            details: nil
          ))
          return
        }
        guard granted else {
          result(FlutterError(
            code: "microphone_permission_denied",
            message: "Microphone permission is required for realtime audio.",
            details: nil
          ))
          return
        }
        do {
          try self.beginCapture(
            sampleRate: sampleRate,
            channels: channels,
            samplesPerChannel: samples
          )
          result(nil)
        } catch {
          result(FlutterError(
            code: "audio_input_unavailable",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func beginCapture(sampleRate: Int, channels: Int, samplesPerChannel: Int) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
    try session.setPreferredSampleRate(Double(sampleRate))
    try session.setActive(true)

    stopCapture()
    targetSampleRate = sampleRate
    targetChannels = channels
    targetSamplesPerChannel = samplesPerChannel
    pendingInput.removeAll(keepingCapacity: true)

    let input = engine.inputNode
    let inputFormat = input.inputFormat(forBus: 0)
    guard let outputFormat = AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: Double(sampleRate),
      channels: AVAudioChannelCount(channels),
      interleaved: false
    ), let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
      throw NSError(domain: "RealtimeAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "The microphone format could not be converted."])
    }
    self.targetFormat = outputFormat
    self.converter = converter

    if !playerAttached {
      engine.attach(player)
      engine.connect(player, to: engine.mainMixerNode, format: nil)
      playerAttached = true
    }
    if tapInstalled {
      input.removeTap(onBus: 0)
      tapInstalled = false
    }
    input.installTap(
      onBus: 0,
      bufferSize: AVAudioFrameCount(samplesPerChannel),
      format: inputFormat
    ) { [weak self] buffer, _ in
      self?.handleInput(buffer)
    }
    tapInstalled = true
    if !engine.isRunning {
      try engine.start()
    }
    capturing = true
  }

  private func handleInput(_ input: AVAudioPCMBuffer) {
    guard let converter, let targetFormat else { return }
    let ratio = targetFormat.sampleRate / input.format.sampleRate
    let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio + 64)
    guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
    var supplied = false
    var conversionError: NSError?
    let status = converter.convert(to: output, error: &conversionError) { _, requestStatus in
      if supplied {
        requestStatus.pointee = .noDataNow
        return nil
      }
      supplied = true
      requestStatus.pointee = .haveData
      return input
    }
    guard status != .error, conversionError == nil, output.frameLength > 0,
          let samples = output.int16ChannelData?[0] else { return }
    let byteCount = Int(output.frameLength) * MemoryLayout<Int16>.size
    let pcmData = Data(bytes: samples, count: byteCount)
    audioQueue.async { [weak self] in
      guard let self = self else { return }
      pendingInput.append(pcmData)
      let frameBytes = targetSamplesPerChannel * targetChannels * MemoryLayout<Int16>.size
      while pendingInput.count >= frameBytes {
        let chunk = Data(pendingInput.prefix(frameBytes))
        pendingInput.removeFirst(frameBytes)
        let payload: [String: Any] = [
          "data": FlutterStandardTypedData(bytes: chunk),
          "sampleRate": targetSampleRate,
          "numChannels": targetChannels,
          "samplesPerChannel": targetSamplesPerChannel,
        ]
        DispatchQueue.main.async { [weak self] in
          self?.eventSink?(payload)
        }
      }
    }
  }

  private func stopCapture() {
    let input = engine.inputNode
    if tapInstalled {
      input.removeTap(onBus: 0)
      tapInstalled = false
    }
    capturing = false
    converter = nil
    pendingInput.removeAll(keepingCapacity: false)
    if !player.isPlaying {
      engine.stop()
    }
  }

  private func play(arguments: Any?, result: @escaping FlutterResult) {
    let args = arguments as? [String: Any]
    guard let typedData = args?["data"] as? FlutterStandardTypedData else {
      result(FlutterError(
        code: "invalid_audio_frame",
        message: "Audio data must be PCM bytes.",
        details: nil
      ))
      return
    }
    let sampleRate = positiveInt(args?["sampleRate"], fallback: 24_000)
    let channels = positiveInt(args?["numChannels"], fallback: 1)
    guard channels == 1 else {
      result(FlutterError(
        code: "unsupported_audio_channels",
        message: "iOS realtime playback currently supports mono PCM only.",
        details: nil
      ))
      return
    }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
      try session.setActive(true)
      guard let format = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: Double(sampleRate),
        channels: AVAudioChannelCount(channels),
        interleaved: false
      ), let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(typedData.data.count / MemoryLayout<Int16>.size)
      ) else {
        throw NSError(domain: "RealtimeAudio", code: 2, userInfo: [NSLocalizedDescriptionKey: "The speaker format could not be initialized."])
      }
      buffer.frameLength = buffer.frameCapacity
      typedData.data.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress,
              let destination = buffer.int16ChannelData?[0] else { return }
        destination.update(from: baseAddress.assumingMemoryBound(to: Int16.self), count: Int(buffer.frameLength))
      }
      if !playerAttached {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        playerAttached = true
      }
      if !engine.isRunning {
        try engine.start()
      }
      player.scheduleBuffer(buffer)
      if !player.isPlaying {
        player.play()
      }
      result(nil)
    } catch {
      result(FlutterError(
        code: "audio_output_unavailable",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  private func stopPlayback() {
    player.stop()
    if !capturing {
      engine.stop()
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }

  private func positiveInt(_ value: Any?, fallback: Int) -> Int {
    if let number = value as? NSNumber, number.intValue > 0 {
      return number.intValue
    }
    return fallback
  }
}
