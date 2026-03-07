# Crystal bindings for whisper.cpp, providing speech-to-text transcription
# using OpenAI's Whisper model running locally.
#
# ```
# whisper = Whisper.new("/path/to/ggml-base.en.bin")
# segments = whisper.transcribe_file("audio.wav")
# segments.each { |seg| puts "#{seg.start_timestamp} #{seg.text}" }
# whisper.close
# ```
require "log"

class Whisper
  class Error < Exception; end

  Log = ::Log.for("whisper-cry")

  @@log_buffer : String = ""
  @@log_level : LibWhisper::GgmlLogLevel = LibWhisper::GgmlLogLevel::Info
  @@logging_setup : Bool = false

  protected def self.setup_logging
    return if @@logging_setup
    @@logging_setup = true

    LibWhisper.log_set(->(level : LibWhisper::GgmlLogLevel, text : LibC::Char*, _user_data : Void*) {
      message = String.new(text)

      if level == LibWhisper::GgmlLogLevel::Cont
        @@log_buffer += message
      else
        flush_log_buffer unless @@log_buffer.empty?
        @@log_level = level
        @@log_buffer = message
      end

      flush_log_buffer if @@log_buffer.ends_with?("\n")
    }, Pointer(Void).null)
  end

  protected def self.flush_log_buffer
    msg = @@log_buffer.chomp
    @@log_buffer = ""
    return if msg.empty?

    case @@log_level
    when .debug? then Log.debug { msg }
    when .warn?  then Log.warn { msg }
    when .error? then Log.error { msg }
    else              Log.info { msg }
    end
  end

  getter? closed : Bool = false

  # Loads a whisper model from disk and initializes the inference context.
  #
  # *model_path* should point to a GGML-format model file (e.g. `ggml-base.en.bin`).
  # Set *use_gpu* to `true` to enable Metal acceleration on macOS.
  #
  # Raises `Whisper::Error` if the file doesn't exist or the model fails to load.
  def initialize(model_path : String, use_gpu : Bool = false)
    Whisper.setup_logging
    raise Error.new("Model file not found: #{model_path}") unless File.exists?(model_path)

    ctx_params = LibWhisper.context_default_params
    ctx_params.use_gpu = use_gpu

    @ctx = LibWhisper.init_from_file_with_params(model_path, ctx_params)
    raise Error.new("Failed to initialize whisper context from: #{model_path}") if @ctx.nil?
  end

  # Initializes a whisper context from a pre-loaded model buffer in memory.
  #
  # *buffer* should contain the raw model data (same content as a model file).
  # Set *use_gpu* to `true` to enable Metal acceleration on macOS.
  #
  # Raises `Whisper::Error` if the model fails to load.
  def self.from_buffer(buffer : Bytes, use_gpu : Bool = false) : Whisper
    setup_logging

    ctx_params = LibWhisper.context_default_params
    ctx_params.use_gpu = use_gpu

    ctx = LibWhisper.init_from_buffer_with_params(buffer.to_unsafe.as(Void*), buffer.size, ctx_params)
    raise Error.new("Failed to initialize whisper context from buffer") if ctx.nil?

    new(ctx)
  end

  private def initialize(@ctx : LibWhisper::Context)
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

  # Creates an independent inference state for parallel transcription.
  #
  # Each `State` can run inference concurrently on the same model context.
  # The caller is responsible for closing the returned state.
  #
  # Raises `Whisper::Error` if the context is closed or state creation fails.
  def create_state : State
    raise Error.new("Context has been closed") if closed?
    state_ptr = LibWhisper.init_state(@ctx)
    raise Error.new("Failed to create whisper state") if state_ptr.nil?
    State.new(@ctx, state_ptr)
  end

  # Transcribes pre-loaded audio samples into text segments.
  #
  # *samples* must be 32-bit float PCM audio normalized to [-1.0, 1.0], mono, at 16kHz.
  # Use `#transcribe_file` to load and convert a WAV file automatically.
  #
  # - *language*: BCP-47 language code (e.g. `"en"`, `"es"`), or `nil` for auto-detection.
  # - *n_threads*: number of CPU threads for inference.
  # - *translate*: when `true`, translates speech to English regardless of source language.
  # - *token_timestamps*: when `true`, enables per-token timestamp computation.
  #
  # Raises `Whisper::Error` if the context is closed or transcription fails.
  def transcribe(samples : Array(Float32), language : String? = "en", n_threads : Int32 = 4, translate : Bool = false, token_timestamps : Bool = false) : Array(Segment)
    raise Error.new("Context has been closed") if closed?
    raise Error.new("No audio samples provided") if samples.empty?

    params = LibWhisper.full_default_params(LibWhisper::SamplingStrategy::Greedy)
    params.n_threads = n_threads
    params.translate = translate
    params.print_special = false
    params.print_progress = false
    params.print_realtime = false
    params.print_timestamps = false
    params.token_timestamps = token_timestamps

    if language
      params.language = language.to_unsafe
    end

    result = LibWhisper.full(@ctx, params, samples.to_unsafe, samples.size)
    raise Error.new("Transcription failed (error code: #{result})") if result != 0

    read_segments(include_tokens: token_timestamps)
  end

  # Transcribes audio using multiple processors for potential speedup.
  #
  # Splits input audio into chunks and processes each with `whisper_full_with_state`.
  # Results are stored in the default context state. Not thread safe if called
  # in parallel on the same context.
  #
  # Accepts the same keyword arguments as `#transcribe`, plus *n_processors*.
  def transcribe_parallel(samples : Array(Float32), n_processors : Int32 = 2, language : String? = "en", n_threads : Int32 = 4, translate : Bool = false, token_timestamps : Bool = false) : Array(Segment)
    raise Error.new("Context has been closed") if closed?
    raise Error.new("No audio samples provided") if samples.empty?

    params = LibWhisper.full_default_params(LibWhisper::SamplingStrategy::Greedy)
    params.n_threads = n_threads
    params.translate = translate
    params.print_special = false
    params.print_progress = false
    params.print_realtime = false
    params.print_timestamps = false
    params.token_timestamps = token_timestamps

    if language
      params.language = language.to_unsafe
    end

    result = LibWhisper.full_parallel(@ctx, params, samples.to_unsafe, samples.size, n_processors)
    raise Error.new("Parallel transcription failed (error code: #{result})") if result != 0

    read_segments(include_tokens: token_timestamps)
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
    samples = Whisper.load_wav_samples(path)
    transcribe(samples, **kwargs)
  end

  # Returns the detected language code from the most recent transcription.
  #
  # The language ID is retrieved from the default context state and converted
  # to a BCP-47 string (e.g. `"en"`, `"de"`).
  def detected_language : String
    raise Error.new("Context has been closed") if closed?
    lang_id = LibWhisper.full_lang_id(@ctx)
    ptr = LibWhisper.lang_str(lang_id)
    String.new(ptr)
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

  # Returns a snapshot of all model dimension queries.
  def model_info : ModelInfo
    raise Error.new("Context has been closed") if closed?
    ModelInfo.new(
      n_vocab: LibWhisper.model_n_vocab(@ctx),
      n_audio_ctx: LibWhisper.model_n_audio_ctx(@ctx),
      n_audio_state: LibWhisper.model_n_audio_state(@ctx),
      n_audio_head: LibWhisper.model_n_audio_head(@ctx),
      n_audio_layer: LibWhisper.model_n_audio_layer(@ctx),
      n_text_ctx: LibWhisper.model_n_text_ctx(@ctx),
      n_text_state: LibWhisper.model_n_text_state(@ctx),
      n_text_head: LibWhisper.model_n_text_head(@ctx),
      n_text_layer: LibWhisper.model_n_text_layer(@ctx),
      n_mels: LibWhisper.model_n_mels(@ctx),
      ftype: LibWhisper.model_ftype(@ctx),
      type: LibWhisper.model_type(@ctx),
    )
  end

  # Returns the mel spectrogram length from the default state.
  def mel_length : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.n_len(@ctx)
  end

  # Returns the model vocabulary size.
  def n_vocab : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.n_vocab(@ctx)
  end

  # Returns the maximum text context size (tokens).
  def n_text_ctx : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.n_text_ctx(@ctx)
  end

  # Returns the audio context size (frames).
  def n_audio_ctx : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.n_audio_ctx(@ctx)
  end

  # Returns the number of tokens the given text would produce.
  def token_count(text : String) : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.token_count(@ctx, text.to_unsafe)
  end

  # Tokenizes the given text into an array of token IDs.
  #
  # Returns the token IDs produced by the model's tokenizer.
  # Raises `Whisper::Error` if the text produces more tokens than *max_tokens*.
  def tokenize(text : String, max_tokens : Int32 = 512) : Array(Int32)
    raise Error.new("Context has been closed") if closed?

    tokens = Array(Int32).new(max_tokens, 0)
    result = LibWhisper.tokenize(@ctx, text.to_unsafe, tokens.to_unsafe, max_tokens)
    raise Error.new("Tokenization failed or exceeded max_tokens (result: #{result})") if result < 0

    tokens[0, result].to_a
  end

  # --- Special tokens ---

  # Returns the end-of-text token ID.
  def token_eot : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.token_eot(@ctx)
  end

  # Returns the start-of-text token ID.
  def token_sot : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.token_sot(@ctx)
  end

  # Returns the beginning-of-timestamps token ID.
  def token_beg : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.token_beg(@ctx)
  end

  # Returns the translate task token ID.
  def token_translate : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.token_translate(@ctx)
  end

  # Returns the transcribe task token ID.
  def token_transcribe : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.token_transcribe(@ctx)
  end

  # Returns the start-of-language-model token ID.
  def token_solm : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.token_solm(@ctx)
  end

  # Returns the previous-token token ID.
  def token_prev : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.token_prev(@ctx)
  end

  # Returns the no-speech token ID.
  def token_nosp : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.token_nosp(@ctx)
  end

  # Returns the not token ID.
  def token_not : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.token_not(@ctx)
  end

  # Returns the language token ID for the given language ID.
  def token_lang(lang_id : Int32) : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.token_lang(@ctx, lang_id)
  end

  # Converts a token ID to its string representation.
  def token_to_str(token : Int32) : String
    raise Error.new("Context has been closed") if closed?
    ptr = LibWhisper.token_to_str(@ctx, token)
    ptr.null? ? "" : String.new(ptr)
  end

  # --- Language auto-detection ---

  # Runs language auto-detection on the mel spectrogram and returns the
  # detected language code along with a hash of all language probabilities.
  #
  # Requires `pcm_to_mel` or equivalent to have been called first.
  def lang_auto_detect(offset_ms : Int32 = 0, n_threads : Int32 = 4) : {String, Hash(String, Float32)}
    raise Error.new("Context has been closed") if closed?

    n_langs = LibWhisper.lang_max_id + 1
    probs = Array(Float32).new(n_langs, 0.0_f32)
    top_lang_id = LibWhisper.lang_auto_detect(@ctx, offset_ms, n_threads, probs.to_unsafe)
    raise Error.new("Language auto-detection failed") if top_lang_id < 0

    top_lang = String.new(LibWhisper.lang_str(top_lang_id))
    lang_probs = Hash(String, Float32).new
    n_langs.times do |i|
      lang = String.new(LibWhisper.lang_str(i))
      lang_probs[lang] = probs[i]
    end

    {top_lang, lang_probs}
  end

  # --- Performance profiling ---

  # Returns the performance timings from the default state.
  def timings : LibWhisper::Timings
    raise Error.new("Context has been closed") if closed?
    ptr = LibWhisper.get_timings(@ctx)
    raise Error.new("No timings available") if ptr.null?
    ptr.value
  end

  # Prints performance timings to the whisper log.
  def print_timings : Nil
    raise Error.new("Context has been closed") if closed?
    LibWhisper.print_timings(@ctx)
  end

  # Resets accumulated performance timings.
  def reset_timings : Nil
    raise Error.new("Context has been closed") if closed?
    LibWhisper.reset_timings(@ctx)
  end

  # --- Low-level pipeline ---

  # Converts raw PCM audio to mel spectrogram in the default state.
  #
  # Returns 0 on success.
  def pcm_to_mel(samples : Array(Float32), n_threads : Int32 = 4) : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.pcm_to_mel(@ctx, samples.to_unsafe, samples.size, n_threads)
  end

  # Sets a custom mel spectrogram in the default state.
  #
  # *n_mel* must be 80. Returns 0 on success.
  def set_mel(data : Array(Float32), n_len : Int32, n_mel : Int32 = 80) : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.set_mel(@ctx, data.to_unsafe, n_len, n_mel)
  end

  # Runs the encoder on the mel spectrogram in the default state.
  #
  # Call `pcm_to_mel` or `set_mel` first. Returns 0 on success.
  def encode(offset : Int32 = 0, n_threads : Int32 = 4) : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.encode(@ctx, offset, n_threads)
  end

  # Runs the decoder on the given token context in the default state.
  #
  # Call `encode` first. Returns 0 on success.
  def decode(tokens : Array(Int32), n_past : Int32, n_threads : Int32 = 4) : Int32
    raise Error.new("Context has been closed") if closed?
    LibWhisper.decode(@ctx, tokens.to_unsafe, tokens.size, n_past, n_threads)
  end

  # Returns a Slice of logits from the last `decode` call on the default state.
  #
  # The slice contains `n_tokens * n_vocab` floats (row-major, last row = last token).
  def logits : Slice(Float32)
    raise Error.new("Context has been closed") if closed?
    ptr = LibWhisper.get_logits(@ctx)
    raise Error.new("No logits available") if ptr.null?
    Slice.new(ptr, LibWhisper.n_vocab(@ctx))
  end

  # --- Language class methods ---

  # Returns the largest language ID (number of available languages - 1).
  def self.lang_max_id : Int32
    LibWhisper.lang_max_id
  end

  # Returns the language ID for the given language string, or -1 if not found.
  def self.lang_id(lang : String) : Int32
    LibWhisper.lang_id(lang.to_unsafe)
  end

  # Returns the short language code for the given ID (e.g. `"de"`).
  def self.lang_str(id : Int32) : String
    ptr = LibWhisper.lang_str(id)
    ptr.null? ? "" : String.new(ptr)
  end

  # Returns the full language name for the given ID (e.g. `"german"`).
  def self.lang_str_full(id : Int32) : String
    ptr = LibWhisper.lang_str_full(id)
    ptr.null? ? "" : String.new(ptr)
  end

  # --- Benchmarking class methods ---

  # Runs a memory copy benchmark and returns the result code.
  def self.bench_memcpy(n_threads : Int32 = 4) : Int32
    LibWhisper.bench_memcpy(n_threads)
  end

  # Runs a memory copy benchmark and returns a human-readable result string.
  def self.bench_memcpy_str(n_threads : Int32 = 4) : String
    String.new(LibWhisper.bench_memcpy_str(n_threads))
  end

  # Runs a GGML matrix multiply benchmark and returns the result code.
  def self.bench_ggml_mul_mat(n_threads : Int32 = 4) : Int32
    LibWhisper.bench_ggml_mul_mat(n_threads)
  end

  # Runs a GGML matrix multiply benchmark and returns a human-readable result string.
  def self.bench_ggml_mul_mat_str(n_threads : Int32 = 4) : String
    String.new(LibWhisper.bench_ggml_mul_mat_str(n_threads))
  end

  # --- Segment reading ---

  private def read_segments(include_tokens : Bool = false) : Array(Segment)
    n = LibWhisper.full_n_segments(@ctx)
    segments = Array(Segment).new(n)

    n.times do |i|
      text_ptr = LibWhisper.full_get_segment_text(@ctx, i)
      text = text_ptr.null? ? "" : String.new(text_ptr)

      t0 = LibWhisper.full_get_segment_t0(@ctx, i) * 10
      t1 = LibWhisper.full_get_segment_t1(@ctx, i) * 10
      no_speech = LibWhisper.full_get_segment_no_speech_prob(@ctx, i)
      speaker_turn = LibWhisper.full_get_segment_speaker_turn_next(@ctx, i)

      tokens = include_tokens ? read_tokens(i) : [] of Token

      segments << Segment.new(
        text: text,
        start_ms: t0,
        end_ms: t1,
        no_speech_probability: no_speech,
        speaker_turn_next: speaker_turn,
        tokens: tokens,
      )
    end

    segments
  end

  private def read_tokens(i_segment : Int32) : Array(Token)
    n_tokens = LibWhisper.full_n_tokens(@ctx, i_segment)
    tokens = Array(Token).new(n_tokens)

    n_tokens.times do |i|
      text_ptr = LibWhisper.full_get_token_text(@ctx, i_segment, i)
      text = text_ptr.null? ? "" : String.new(text_ptr)

      data = LibWhisper.full_get_token_data(@ctx, i_segment, i)

      tokens << Token.new(
        text: text,
        id: data.id,
        probability: data.p,
        start_ms: data.t0 * 10,
        end_ms: data.t1 * 10,
      )
    end

    tokens
  end

  # Loads a 16-bit PCM WAV file and converts to float32 samples.
  # Expects: mono, 16kHz, 16-bit signed PCM (standard whisper input format).
  # Use ffmpeg to convert other formats:
  #   ffmpeg -i input.mp3 -ar 16000 -ac 1 -f wav output.wav
  def self.load_wav_samples(path : String) : Array(Float32)
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
