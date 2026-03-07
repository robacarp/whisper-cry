# Crystal bindings for whisper.cpp, providing speech-to-text transcription
# using OpenAI's Whisper model running locally.
#
# ```
# whisper = Whisper.new("/path/to/ggml-base.en.bin")
# segments = whisper.transcribe_file("audio.wav")
# segments.each { |seg| puts "#{seg.start_timestamp} #{seg.text}" }
# whisper.close
# ```
class Whisper
  class Error < Exception; end

  getter? closed : Bool = false

  # Loads a whisper model from disk and initializes the inference context.
  #
  # *model_path* should point to a GGML-format model file (e.g. `ggml-base.en.bin`).
  # Set *use_gpu* to `true` to enable Metal acceleration on macOS.
  #
  # Raises `Whisper::Error` if the file doesn't exist or the model fails to load.
  def initialize(model_path : String, use_gpu : Bool = false)
    raise Error.new("Model file not found: #{model_path}") unless File.exists?(model_path)

    ctx_params = LibWhisper.context_default_params
    ctx_params.use_gpu = use_gpu

    @ctx = LibWhisper.init_from_file_with_params(model_path, ctx_params)
    raise Error.new("Failed to initialize whisper context from: #{model_path}") if @ctx.nil?
  end

  def finalize
    close
  end

  # Frees the underlying whisper context. Safe to call multiple times.
  # Called automatically by `#finalize`, but explicit cleanup is preferred.
  def close
    return if closed?
    LibWhisper.free(@ctx)
    @closed = true
  end

  # Transcribes pre-loaded audio samples into text segments.
  #
  # *samples* must be 32-bit float PCM audio normalized to [-1.0, 1.0], mono, at 16kHz.
  # Use `#transcribe_file` to load and convert a WAV file automatically.
  #
  # - *language*: BCP-47 language code (e.g. `"en"`, `"es"`), or `nil` for auto-detection.
  # - *n_threads*: number of CPU threads for inference.
  # - *translate*: when `true`, translates speech to English regardless of source language.
  #
  # Raises `Whisper::Error` if the context is closed or transcription fails.
  def transcribe(samples : Array(Float32), language : String? = "en", n_threads : Int32 = 4, translate : Bool = false) : Array(Segment)
    raise Error.new("Context has been closed") if closed?
    raise Error.new("No audio samples provided") if samples.empty?

    params = LibWhisper.full_default_params(LibWhisper::SamplingStrategy::Greedy)
    params.n_threads = n_threads
    params.translate = translate
    params.print_special = false
    params.print_progress = false
    params.print_realtime = false
    params.print_timestamps = false

    if language
      params.language = language.to_unsafe
    end

    result = LibWhisper.full(@ctx, params, samples.to_unsafe, samples.size)
    raise Error.new("Transcription failed (error code: #{result})") if result != 0

    read_segments
  end

  # Transcribes a WAV file into text segments.
  #
  # The file must be 16-bit signed PCM, mono, 16kHz. Convert other formats with:
  # ```
  # ffmpeg -i input.mp3 -ar 16000 -ac 1 -f wav output.wav
  # ```
  #
  # Accepts the same keyword arguments as `#transcribe`.
  #
  # Raises `Whisper::Error` if the file is missing or not a valid WAV.
  def transcribe_file(path : String, **kwargs) : Array(Segment)
    samples = load_wav_samples(path)
    transcribe(samples, **kwargs)
  end

  # Returns the whisper.cpp library version string (e.g. `"1.8.3"`).
  def version : String
    String.new(LibWhisper.version)
  end

  # Returns a human-readable model type (e.g. `"base"`, `"small"`, `"large"`).
  def model_type : String
    raise Error.new("Context has been closed") if closed?
    String.new(LibWhisper.model_type_readable(@ctx))
  end

  # Returns `true` if the loaded model supports multiple languages.
  # English-only models (e.g. `ggml-base.en.bin`) return `false`.
  def multilingual? : Bool
    raise Error.new("Context has been closed") if closed?
    LibWhisper.is_multilingual(@ctx) != 0
  end

  # Returns a string describing the CPU features available for inference
  # (e.g. AVX, NEON, Metal support).
  def system_info : String
    String.new(LibWhisper.print_system_info)
  end

  private def read_segments : Array(Segment)
    n = LibWhisper.full_n_segments(@ctx)
    segments = Array(Segment).new(n)

    n.times do |i|
      text_ptr = LibWhisper.full_get_segment_text(@ctx, i)
      text = text_ptr.null? ? "" : String.new(text_ptr)

      t0 = LibWhisper.full_get_segment_t0(@ctx, i) * 10
      t1 = LibWhisper.full_get_segment_t1(@ctx, i) * 10
      no_speech = LibWhisper.full_get_segment_no_speech_prob(@ctx, i)
      speaker_turn = LibWhisper.full_get_segment_speaker_turn_next(@ctx, i)

      segments << Segment.new(
        text: text,
        start_ms: t0,
        end_ms: t1,
        no_speech_probability: no_speech,
        speaker_turn_next: speaker_turn,
      )
    end

    segments
  end

  # Loads a 16-bit PCM WAV file and converts to float32 samples.
  # Expects: mono, 16kHz, 16-bit signed PCM (standard whisper input format).
  # Use ffmpeg to convert other formats:
  #   ffmpeg -i input.mp3 -ar 16000 -ac 1 -f wav output.wav
  private def load_wav_samples(path : String) : Array(Float32)
    raise Error.new("Audio file not found: #{path}") unless File.exists?(path)

    File.open(path, "rb") do |file|
      header = Bytes.new(12)
      file.read_fully(header)

      riff = String.new(header[0, 4])
      raise Error.new("Not a WAV file (missing RIFF header)") unless riff == "RIFF"

      wave = String.new(header[8, 4])
      raise Error.new("Not a WAV file (missing WAVE format)") unless wave == "WAVE"

      audio_format = 0_i16
      channels = 0_i16
      sample_rate = 0_i32
      bits_per_sample = 0_i16
      data_size = 0_u32

      loop do
        chunk_id = Bytes.new(4)
        break if file.read(chunk_id) < 4
        chunk_size = file.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
        chunk_name = String.new(chunk_id)

        if chunk_name == "fmt "
          fmt_data = Bytes.new(chunk_size)
          file.read_fully(fmt_data)
          audio_format = IO::ByteFormat::LittleEndian.decode(Int16, fmt_data[0, 2])
          channels = IO::ByteFormat::LittleEndian.decode(Int16, fmt_data[2, 2])
          sample_rate = IO::ByteFormat::LittleEndian.decode(Int32, fmt_data[4, 4])
          bits_per_sample = IO::ByteFormat::LittleEndian.decode(Int16, fmt_data[14, 2])
        elsif chunk_name == "data"
          data_size = chunk_size
          break
        else
          file.skip(chunk_size)
        end
      end

      raise Error.new("No fmt chunk found in WAV file") if audio_format == 0
      raise Error.new("Expected PCM format (1), got #{audio_format}") unless audio_format == 1
      raise Error.new("Expected mono audio, got #{channels} channels") unless channels == 1
      raise Error.new("Expected 16kHz sample rate, got #{sample_rate}") unless sample_rate == 16000
      raise Error.new("Expected 16-bit samples, got #{bits_per_sample}") unless bits_per_sample == 16
      raise Error.new("No data chunk found in WAV file") if data_size == 0

      n_samples = data_size // 2
      samples = Array(Float32).new(n_samples)
      raw = Bytes.new(data_size)
      file.read_fully(raw)

      n_samples.times do |i|
        sample_i16 = IO::ByteFormat::LittleEndian.decode(Int16, raw[i * 2, 2])
        samples << sample_i16.to_f32 / 32768.0_f32
      end

      samples
    end
  end
end
