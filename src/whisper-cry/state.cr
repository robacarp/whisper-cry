class Whisper
  # Independent inference state for parallel transcription.
  #
  # Multiple `State` instances can run inference concurrently on the same
  # model context. Each state maintains its own mel spectrogram, encoder
  # output, and decoder state.
  #
  # ```
  # whisper = Whisper.new("/path/to/model.bin")
  # state = whisper.create_state
  # # ... use state for inference ...
  # state.close
  # whisper.close
  # ```
  class State
    getter? closed : Bool = false

    protected def initialize(@ctx : LibWhisper::Context, @state : LibWhisper::State)
    end

    def finalize
      close
    end

    # Frees the underlying whisper state. Safe to call multiple times.
    def close
      return if closed?
      LibWhisper.free_state(@state)
      @closed = true
    end

    # Runs full inference with this state on the given audio samples.
    #
    # *samples* must be 32-bit float PCM audio normalized to [-1.0, 1.0], mono, at 16kHz.
    def transcribe(samples : Array(Float32), language : String? = "en", n_threads : Int32 = 4, translate : Bool = false, token_timestamps : Bool = false) : Array(Segment)
      raise Whisper::Error.new("State has been closed") if closed?
      raise Whisper::Error.new("No audio samples provided") if samples.empty?

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

      result = LibWhisper.full_with_state(@ctx, @state, params, samples.to_unsafe, samples.size)
      raise Whisper::Error.new("Transcription failed (error code: #{result})") if result != 0

      read_segments(include_tokens: token_timestamps)
    end

    # Returns the mel spectrogram length from this state.
    def mel_length : Int32
      raise Whisper::Error.new("State has been closed") if closed?
      LibWhisper.n_len_from_state(@state)
    end

    # Returns the detected language ID from the most recent transcription on this state.
    def detected_language : String
      raise Whisper::Error.new("State has been closed") if closed?
      lang_id = LibWhisper.full_lang_id_from_state(@state)
      ptr = LibWhisper.lang_str(lang_id)
      String.new(ptr)
    end

    # --- Low-level pipeline ---

    # Converts raw PCM audio to mel spectrogram in this state.
    def pcm_to_mel(samples : Array(Float32), n_threads : Int32 = 4) : Int32
      raise Whisper::Error.new("State has been closed") if closed?
      LibWhisper.pcm_to_mel_with_state(@ctx, @state, samples.to_unsafe, samples.size, n_threads)
    end

    # Sets a custom mel spectrogram in this state.
    def set_mel(data : Array(Float32), n_len : Int32, n_mel : Int32 = 80) : Int32
      raise Whisper::Error.new("State has been closed") if closed?
      LibWhisper.set_mel_with_state(@ctx, @state, data.to_unsafe, n_len, n_mel)
    end

    # Runs the encoder on the mel spectrogram in this state.
    def encode(offset : Int32 = 0, n_threads : Int32 = 4) : Int32
      raise Whisper::Error.new("State has been closed") if closed?
      LibWhisper.encode_with_state(@ctx, @state, offset, n_threads)
    end

    # Runs the decoder on the given token context in this state.
    def decode(tokens : Array(Int32), n_past : Int32, n_threads : Int32 = 4) : Int32
      raise Whisper::Error.new("State has been closed") if closed?
      LibWhisper.decode_with_state(@ctx, @state, tokens.to_unsafe, tokens.size, n_past, n_threads)
    end

    # Returns a Slice of logits from the last `decode` call on this state.
    def logits : Slice(Float32)
      raise Whisper::Error.new("State has been closed") if closed?
      ptr = LibWhisper.get_logits_from_state(@state)
      raise Whisper::Error.new("No logits available") if ptr.null?
      Slice.new(ptr, LibWhisper.n_vocab(@ctx))
    end

    # Runs language auto-detection on this state's mel spectrogram.
    def lang_auto_detect(offset_ms : Int32 = 0, n_threads : Int32 = 4) : {String, Hash(String, Float32)}
      raise Whisper::Error.new("State has been closed") if closed?

      n_langs = LibWhisper.lang_max_id + 1
      probs = Array(Float32).new(n_langs, 0.0_f32)
      top_lang_id = LibWhisper.lang_auto_detect_with_state(@ctx, @state, offset_ms, n_threads, probs.to_unsafe)
      raise Whisper::Error.new("Language auto-detection failed") if top_lang_id < 0

      top_lang = String.new(LibWhisper.lang_str(top_lang_id))
      lang_probs = Hash(String, Float32).new
      n_langs.times do |i|
        lang = String.new(LibWhisper.lang_str(i))
        lang_probs[lang] = probs[i]
      end

      {top_lang, lang_probs}
    end

    private def read_segments(include_tokens : Bool = false) : Array(Segment)
      n = LibWhisper.full_n_segments_from_state(@state)
      segments = Array(Segment).new(n)

      n.times do |i|
        text_ptr = LibWhisper.full_get_segment_text_from_state(@state, i)
        text = text_ptr.null? ? "" : String.new(text_ptr)

        t0 = LibWhisper.full_get_segment_t0_from_state(@state, i) * 10
        t1 = LibWhisper.full_get_segment_t1_from_state(@state, i) * 10
        no_speech = LibWhisper.full_get_segment_no_speech_prob_from_state(@state, i)
        speaker_turn = LibWhisper.full_get_segment_speaker_turn_next_from_state(@state, i)

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
      n_tokens = LibWhisper.full_n_tokens_from_state(@state, i_segment)
      tokens = Array(Token).new(n_tokens)

      n_tokens.times do |i|
        text_ptr = LibWhisper.full_get_token_text_from_state(@ctx, @state, i_segment, i)
        text = text_ptr.null? ? "" : String.new(text_ptr)

        data = LibWhisper.full_get_token_data_from_state(@state, i_segment, i)

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
  end
end
