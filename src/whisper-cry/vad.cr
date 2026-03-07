class Whisper
  # Voice Activity Detection (VAD) subsystem.
  #
  # Loads a standalone VAD model and detects speech segments in audio data
  # independently of the main Whisper transcription pipeline.
  #
  # ```
  # vad = Whisper::Vad.new("/path/to/silero-vad.onnx")
  # segments = vad.detect(samples)
  # segments.each { |seg| puts "Speech: #{seg.start_seconds}s - #{seg.end_seconds}s" }
  # vad.close
  # ```
  class Vad
    # A speech segment detected by the VAD model.
    struct SpeechSegment
      # Segment start time in seconds.
      getter start_seconds : Float32

      # Segment end time in seconds.
      getter end_seconds : Float32

      def initialize(@start_seconds, @end_seconds)
      end

      # Segment duration in seconds.
      def duration_seconds : Float32
        @end_seconds - @start_seconds
      end
    end

    getter? closed : Bool = false

    # Loads a VAD model from disk.
    #
    # *model_path* should point to a Silero VAD model file.
    # *n_threads* sets the number of CPU threads for processing.
    # Set *use_gpu* to `true` to enable GPU acceleration.
    def initialize(model_path : String, n_threads : Int32 = 4, use_gpu : Bool = false)
      raise Whisper::Error.new("VAD model file not found: #{model_path}") unless File.exists?(model_path)

      ctx_params = LibWhisper.vad_default_context_params
      ctx_params.n_threads = n_threads
      ctx_params.use_gpu = use_gpu

      @vctx = LibWhisper.vad_init_from_file_with_params(model_path, ctx_params)
      raise Whisper::Error.new("Failed to initialize VAD context from: #{model_path}") if @vctx.nil?
    end

    def finalize
      close
    end

    # Frees the underlying VAD context. Safe to call multiple times.
    def close
      return if closed?
      LibWhisper.vad_free(@vctx)
      @closed = true
    end

    # Runs speech detection on audio samples and returns speech segments.
    #
    # *samples* must be 32-bit float PCM audio normalized to [-1.0, 1.0], mono, at 16kHz.
    # VAD parameters can be customized via optional keyword arguments.
    def detect(samples : Array(Float32),
               threshold : Float32 = 0.5_f32,
               min_speech_duration_ms : Int32 = 250,
               min_silence_duration_ms : Int32 = 100,
               max_speech_duration_s : Float32 = Float32::MAX,
               speech_pad_ms : Int32 = 30,
               samples_overlap : Float32 = 0.0_f32) : Array(SpeechSegment)
      raise Whisper::Error.new("VAD context has been closed") if closed?
      raise Whisper::Error.new("No audio samples provided") if samples.empty?

      vad_params = LibWhisper.vad_default_params
      vad_params.threshold = threshold
      vad_params.min_speech_duration_ms = min_speech_duration_ms
      vad_params.min_silence_duration_ms = min_silence_duration_ms
      vad_params.max_speech_duration_s = max_speech_duration_s
      vad_params.speech_pad_ms = speech_pad_ms
      vad_params.samples_overlap = samples_overlap

      segments_ptr = LibWhisper.vad_segments_from_samples(@vctx, vad_params, samples.to_unsafe, samples.size)
      raise Whisper::Error.new("VAD speech detection failed") if segments_ptr.nil?

      begin
        n = LibWhisper.vad_segments_n_segments(segments_ptr)
        segments = Array(SpeechSegment).new(n)

        n.times do |i|
          t0 = LibWhisper.vad_segments_get_segment_t0(segments_ptr, i)
          t1 = LibWhisper.vad_segments_get_segment_t1(segments_ptr, i)
          segments << SpeechSegment.new(start_seconds: t0, end_seconds: t1)
        end

        segments
      ensure
        LibWhisper.vad_free_segments(segments_ptr)
      end
    end

    # Runs speech probability computation on audio samples.
    #
    # Returns `true` if speech was detected, and makes probabilities
    # accessible via `#n_probs` and `#probs`.
    def detect_speech(samples : Array(Float32)) : Bool
      raise Whisper::Error.new("VAD context has been closed") if closed?
      LibWhisper.vad_detect_speech(@vctx, samples.to_unsafe, samples.size)
    end

    # Returns the number of probability values from the last `detect_speech` call.
    def n_probs : Int32
      raise Whisper::Error.new("VAD context has been closed") if closed?
      LibWhisper.vad_n_probs(@vctx)
    end

    # Returns a Slice of speech probabilities from the last `detect_speech` call.
    def probs : Slice(Float32)
      raise Whisper::Error.new("VAD context has been closed") if closed?
      n = LibWhisper.vad_n_probs(@vctx)
      ptr = LibWhisper.vad_probs(@vctx)
      raise Whisper::Error.new("No VAD probabilities available") if ptr.null?
      Slice.new(ptr, n)
    end

    # Computes speech segments from previously computed probabilities.
    #
    # Requires `detect_speech` to have been called first.
    def segments_from_probs(threshold : Float32 = 0.5_f32,
                            min_speech_duration_ms : Int32 = 250,
                            min_silence_duration_ms : Int32 = 100,
                            max_speech_duration_s : Float32 = Float32::MAX,
                            speech_pad_ms : Int32 = 30,
                            samples_overlap : Float32 = 0.0_f32) : Array(SpeechSegment)
      raise Whisper::Error.new("VAD context has been closed") if closed?

      vad_params = LibWhisper.vad_default_params
      vad_params.threshold = threshold
      vad_params.min_speech_duration_ms = min_speech_duration_ms
      vad_params.min_silence_duration_ms = min_silence_duration_ms
      vad_params.max_speech_duration_s = max_speech_duration_s
      vad_params.speech_pad_ms = speech_pad_ms
      vad_params.samples_overlap = samples_overlap

      segments_ptr = LibWhisper.vad_segments_from_probs(@vctx, vad_params)
      raise Whisper::Error.new("VAD segments_from_probs failed") if segments_ptr.nil?

      begin
        n = LibWhisper.vad_segments_n_segments(segments_ptr)
        segments = Array(SpeechSegment).new(n)

        n.times do |i|
          t0 = LibWhisper.vad_segments_get_segment_t0(segments_ptr, i)
          t1 = LibWhisper.vad_segments_get_segment_t1(segments_ptr, i)
          segments << SpeechSegment.new(start_seconds: t0, end_seconds: t1)
        end

        segments
      ensure
        LibWhisper.vad_free_segments(segments_ptr)
      end
    end
  end
end
