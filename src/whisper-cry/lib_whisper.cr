{% if flag?(:darwin) %}
  @[Link(ldflags: "#{__DIR__}/../../vendor/lib/libwhisper.a #{__DIR__}/../../vendor/lib/libggml.a #{__DIR__}/../../vendor/lib/libggml-base.a #{__DIR__}/../../vendor/lib/libggml-cpu.a #{__DIR__}/../../vendor/lib/libggml-blas.a #{__DIR__}/../../vendor/lib/libggml-metal.a -lstdc++ -framework Accelerate -framework Foundation -framework Metal -framework MetalKit")]
{% elsif flag?(:linux) %}
  @[Link(ldflags: "#{__DIR__}/../../vendor/lib/libwhisper.a #{__DIR__}/../../vendor/lib/libggml.a #{__DIR__}/../../vendor/lib/libggml-base.a #{__DIR__}/../../vendor/lib/libggml-cpu.a #{__DIR__}/../../vendor/lib/libggml-blas.a -lstdc++ -lm -lpthread -lgomp -lopenblas")]
{% end %}
lib LibWhisper
  SAMPLE_RATE = 16000
  N_FFT       =   400
  HOP_LENGTH  =   160
  CHUNK_SIZE  =    30

  alias Token = Int32
  alias Pos = Int32
  alias SeqId = Int32

  enum GgmlLogLevel
    None  = 0
    Debug = 1
    Info  = 2
    Warn  = 3
    Error = 4
    Cont  = 5
  end

  type Context = Void*
  type State = Void*

  enum SamplingStrategy
    Greedy
    BeamSearch
  end

  enum AlignmentHeadsPreset
    None
    NTopMost
    Custom
    TinyEn
    Tiny
    BaseEn
    Base
    SmallEn
    Small
    MediumEn
    Medium
    LargeV1
    LargeV2
    LargeV3
    LargeV3Turbo
  end

  struct Ahead
    n_text_layer : LibC::Int
    n_head : LibC::Int
  end

  struct Aheads
    n_heads : LibC::SizeT
    heads : Ahead*
  end

  struct ContextParams
    use_gpu : Bool
    flash_attn : Bool
    gpu_device : LibC::Int
    dtw_token_timestamps : Bool
    dtw_aheads_preset : AlignmentHeadsPreset
    dtw_n_top : LibC::Int
    dtw_aheads : Aheads
    dtw_mem_size : LibC::SizeT
  end

  struct TokenData
    id : Token
    tid : Token
    p : LibC::Float
    plog : LibC::Float
    pt : LibC::Float
    ptsum : LibC::Float
    t0 : Int64
    t1 : Int64
    t_dtw : Int64
    vlen : LibC::Float
  end

  struct VadParams
    threshold : LibC::Float
    min_speech_duration_ms : LibC::Int
    min_silence_duration_ms : LibC::Int
    max_speech_duration_s : LibC::Float
    speech_pad_ms : LibC::Int
    samples_overlap : LibC::Float
  end

  struct Timings
    sample_ms : LibC::Float
    encode_ms : LibC::Float
    decode_ms : LibC::Float
    batchd_ms : LibC::Float
    prompt_ms : LibC::Float
  end

  struct GreedyParams
    best_of : LibC::Int
  end

  struct BeamSearchParams
    beam_size : LibC::Int
    patience : LibC::Float
  end

  # Complete layout of whisper_full_params (304 bytes on 64-bit LP64).
  # Field offsets verified against whisper.h v1.8.3 using offsetof().
  # Callback function pointers are typed as Void* since Crystal doesn't
  # need to invoke them — they default to null from whisper_full_default_params.
  struct FullParams
    strategy : SamplingStrategy              # offset   0
    n_threads : LibC::Int                    # offset   4
    n_max_text_ctx : LibC::Int               # offset   8
    offset_ms : LibC::Int                    # offset  12
    duration_ms : LibC::Int                  # offset  16
    translate : Bool                         # offset  20
    no_context : Bool                        # offset  21
    no_timestamps : Bool                     # offset  22
    single_segment : Bool                    # offset  23
    print_special : Bool                     # offset  24
    print_progress : Bool                    # offset  25
    print_realtime : Bool                    # offset  26
    print_timestamps : Bool                  # offset  27
    token_timestamps : Bool                  # offset  28
    _pad1 : UInt8[3]                         # padding to align float
    thold_pt : LibC::Float                   # offset  32
    thold_ptsum : LibC::Float                # offset  36
    max_len : LibC::Int                      # offset  40
    split_on_word : Bool                     # offset  44
    _pad2 : UInt8[3]                         # padding to align int
    max_tokens : LibC::Int                   # offset  48
    debug_mode : Bool                        # offset  52
    _pad3 : UInt8[3]                         # padding to align int
    audio_ctx : LibC::Int                    # offset  56
    tdrz_enable : Bool                       # offset  60
    _pad4 : UInt8[3]                         # padding to align pointer
    suppress_regex : LibC::Char*             # offset  64
    initial_prompt : LibC::Char*             # offset  72
    carry_initial_prompt : Bool              # offset  80
    _pad5 : UInt8[7]                         # padding to align pointer
    prompt_tokens : Token*                   # offset  88
    prompt_n_tokens : LibC::Int              # offset  96
    _pad6 : UInt8[4]                         # padding to align pointer
    language : LibC::Char*                   # offset 104
    detect_language : Bool                   # offset 112
    suppress_blank : Bool                    # offset 113
    suppress_nst : Bool                      # offset 114
    _pad7 : UInt8[1]                         # padding to align float
    temperature : LibC::Float                # offset 116
    max_initial_ts : LibC::Float             # offset 120
    length_penalty : LibC::Float             # offset 124
    temperature_inc : LibC::Float            # offset 128
    entropy_thold : LibC::Float              # offset 132
    logprob_thold : LibC::Float              # offset 136
    no_speech_thold : LibC::Float            # offset 140
    greedy : GreedyParams                    # offset 144
    beam_search : BeamSearchParams           # offset 148
    _pad8 : UInt8[4]                         # padding to align pointer
    new_segment_callback : Void*             # offset 160
    new_segment_callback_user_data : Void*   # offset 168
    progress_callback : Void*                # offset 176
    progress_callback_user_data : Void*      # offset 184
    encoder_begin_callback : Void*           # offset 192
    encoder_begin_callback_user_data : Void* # offset 200
    abort_callback : Void*                   # offset 208
    abort_callback_user_data : Void*         # offset 216
    logits_filter_callback : Void*           # offset 224
    logits_filter_callback_user_data : Void* # offset 232
    grammar_rules : Void*                    # offset 240
    n_grammar_rules : LibC::SizeT            # offset 248
    i_start_rule : LibC::SizeT               # offset 256
    grammar_penalty : LibC::Float            # offset 264
    vad : Bool                               # offset 268
    _pad9 : UInt8[3]                         # padding to align pointer
    vad_model_path : LibC::Char*             # offset 272
    vad_params : VadParams                   # offset 280
  end                                        # total  304

  # --- VAD types ---

  struct VadContextParams
    n_threads : LibC::Int
    use_gpu : Bool
    gpu_device : LibC::Int
  end

  type VadContext = Void*
  type VadSegments = Void*

  # --- Initialization & cleanup ---

  fun context_default_params = whisper_context_default_params : ContextParams

  fun init_from_file_with_params = whisper_init_from_file_with_params(
    path_model : LibC::Char*,
    params : ContextParams,
  ) : Context

  fun init_from_file_with_params_no_state = whisper_init_from_file_with_params_no_state(
    path_model : LibC::Char*,
    params : ContextParams,
  ) : Context

  fun init_from_buffer_with_params = whisper_init_from_buffer_with_params(
    buffer : Void*,
    buffer_size : LibC::SizeT,
    params : ContextParams,
  ) : Context

  fun init_state = whisper_init_state(ctx : Context) : State
  fun free = whisper_free(ctx : Context) : Void
  fun free_state = whisper_free_state(state : State) : Void

  # --- Audio processing ---

  fun pcm_to_mel = whisper_pcm_to_mel(
    ctx : Context,
    samples : LibC::Float*,
    n_samples : LibC::Int,
    n_threads : LibC::Int,
  ) : LibC::Int

  fun pcm_to_mel_with_state = whisper_pcm_to_mel_with_state(
    ctx : Context,
    state : State,
    samples : LibC::Float*,
    n_samples : LibC::Int,
    n_threads : LibC::Int,
  ) : LibC::Int

  fun set_mel = whisper_set_mel(
    ctx : Context,
    data : LibC::Float*,
    n_len : LibC::Int,
    n_mel : LibC::Int,
  ) : LibC::Int

  fun set_mel_with_state = whisper_set_mel_with_state(
    ctx : Context,
    state : State,
    data : LibC::Float*,
    n_len : LibC::Int,
    n_mel : LibC::Int,
  ) : LibC::Int

  # --- Encode / Decode ---

  fun encode = whisper_encode(
    ctx : Context,
    offset : LibC::Int,
    n_threads : LibC::Int,
  ) : LibC::Int

  fun encode_with_state = whisper_encode_with_state(
    ctx : Context,
    state : State,
    offset : LibC::Int,
    n_threads : LibC::Int,
  ) : LibC::Int

  fun decode = whisper_decode(
    ctx : Context,
    tokens : Token*,
    n_tokens : LibC::Int,
    n_past : LibC::Int,
    n_threads : LibC::Int,
  ) : LibC::Int

  fun decode_with_state = whisper_decode_with_state(
    ctx : Context,
    state : State,
    tokens : Token*,
    n_tokens : LibC::Int,
    n_past : LibC::Int,
    n_threads : LibC::Int,
  ) : LibC::Int

  # --- Tokenization ---

  fun tokenize = whisper_tokenize(
    ctx : Context,
    text : LibC::Char*,
    tokens : Token*,
    n_max_tokens : LibC::Int,
  ) : LibC::Int

  fun token_count = whisper_token_count(
    ctx : Context,
    text : LibC::Char*,
  ) : LibC::Int

  # --- Inference parameters ---

  fun full_default_params = whisper_full_default_params(
    strategy : SamplingStrategy,
  ) : FullParams

  # --- Main inference ---

  fun full = whisper_full(
    ctx : Context,
    params : FullParams,
    samples : LibC::Float*,
    n_samples : LibC::Int,
  ) : LibC::Int

  fun full_with_state = whisper_full_with_state(
    ctx : Context,
    state : State,
    params : FullParams,
    samples : LibC::Float*,
    n_samples : LibC::Int,
  ) : LibC::Int

  fun full_parallel = whisper_full_parallel(
    ctx : Context,
    params : FullParams,
    samples : LibC::Float*,
    n_samples : LibC::Int,
    n_processors : LibC::Int,
  ) : LibC::Int

  # --- Results ---

  fun full_n_segments = whisper_full_n_segments(ctx : Context) : LibC::Int
  fun full_n_segments_from_state = whisper_full_n_segments_from_state(state : State) : LibC::Int

  fun full_lang_id = whisper_full_lang_id(ctx : Context) : LibC::Int
  fun full_lang_id_from_state = whisper_full_lang_id_from_state(state : State) : LibC::Int

  fun full_get_segment_text = whisper_full_get_segment_text(
    ctx : Context, i_segment : LibC::Int,
  ) : LibC::Char*

  fun full_get_segment_text_from_state = whisper_full_get_segment_text_from_state(
    state : State, i_segment : LibC::Int,
  ) : LibC::Char*

  fun full_get_segment_t0 = whisper_full_get_segment_t0(
    ctx : Context, i_segment : LibC::Int,
  ) : Int64

  fun full_get_segment_t0_from_state = whisper_full_get_segment_t0_from_state(
    state : State, i_segment : LibC::Int,
  ) : Int64

  fun full_get_segment_t1 = whisper_full_get_segment_t1(
    ctx : Context, i_segment : LibC::Int,
  ) : Int64

  fun full_get_segment_t1_from_state = whisper_full_get_segment_t1_from_state(
    state : State, i_segment : LibC::Int,
  ) : Int64

  fun full_get_segment_speaker_turn_next = whisper_full_get_segment_speaker_turn_next(
    ctx : Context, i_segment : LibC::Int,
  ) : Bool

  fun full_get_segment_speaker_turn_next_from_state = whisper_full_get_segment_speaker_turn_next_from_state(
    state : State, i_segment : LibC::Int,
  ) : Bool

  fun full_get_segment_no_speech_prob = whisper_full_get_segment_no_speech_prob(
    ctx : Context, i_segment : LibC::Int,
  ) : LibC::Float

  fun full_get_segment_no_speech_prob_from_state = whisper_full_get_segment_no_speech_prob_from_state(
    state : State, i_segment : LibC::Int,
  ) : LibC::Float

  fun full_n_tokens = whisper_full_n_tokens(
    ctx : Context, i_segment : LibC::Int,
  ) : LibC::Int

  fun full_n_tokens_from_state = whisper_full_n_tokens_from_state(
    state : State, i_segment : LibC::Int,
  ) : LibC::Int

  fun full_get_token_text = whisper_full_get_token_text(
    ctx : Context, i_segment : LibC::Int, i_token : LibC::Int,
  ) : LibC::Char*

  fun full_get_token_text_from_state = whisper_full_get_token_text_from_state(
    ctx : Context, state : State, i_segment : LibC::Int, i_token : LibC::Int,
  ) : LibC::Char*

  fun full_get_token_id = whisper_full_get_token_id(
    ctx : Context, i_segment : LibC::Int, i_token : LibC::Int,
  ) : Token

  fun full_get_token_id_from_state = whisper_full_get_token_id_from_state(
    state : State, i_segment : LibC::Int, i_token : LibC::Int,
  ) : Token

  fun full_get_token_data = whisper_full_get_token_data(
    ctx : Context, i_segment : LibC::Int, i_token : LibC::Int,
  ) : TokenData

  fun full_get_token_data_from_state = whisper_full_get_token_data_from_state(
    state : State, i_segment : LibC::Int, i_token : LibC::Int,
  ) : TokenData

  fun full_get_token_p = whisper_full_get_token_p(
    ctx : Context, i_segment : LibC::Int, i_token : LibC::Int,
  ) : LibC::Float

  fun full_get_token_p_from_state = whisper_full_get_token_p_from_state(
    state : State, i_segment : LibC::Int, i_token : LibC::Int,
  ) : LibC::Float

  # --- Language utilities ---

  fun lang_max_id = whisper_lang_max_id : LibC::Int
  fun lang_id = whisper_lang_id(lang : LibC::Char*) : LibC::Int
  fun lang_str = whisper_lang_str(id : LibC::Int) : LibC::Char*
  fun lang_str_full = whisper_lang_str_full(id : LibC::Int) : LibC::Char*

  fun lang_auto_detect = whisper_lang_auto_detect(
    ctx : Context,
    offset_ms : LibC::Int,
    n_threads : LibC::Int,
    lang_probs : LibC::Float*,
  ) : LibC::Int

  fun lang_auto_detect_with_state = whisper_lang_auto_detect_with_state(
    ctx : Context,
    state : State,
    offset_ms : LibC::Int,
    n_threads : LibC::Int,
    lang_probs : LibC::Float*,
  ) : LibC::Int

  # --- Model info ---

  fun n_len = whisper_n_len(ctx : Context) : LibC::Int
  fun n_len_from_state = whisper_n_len_from_state(state : State) : LibC::Int
  fun n_vocab = whisper_n_vocab(ctx : Context) : LibC::Int
  fun n_text_ctx = whisper_n_text_ctx(ctx : Context) : LibC::Int
  fun n_audio_ctx = whisper_n_audio_ctx(ctx : Context) : LibC::Int
  fun is_multilingual = whisper_is_multilingual(ctx : Context) : LibC::Int
  fun model_type_readable = whisper_model_type_readable(ctx : Context) : LibC::Char*

  fun model_n_vocab = whisper_model_n_vocab(ctx : Context) : LibC::Int
  fun model_n_audio_ctx = whisper_model_n_audio_ctx(ctx : Context) : LibC::Int
  fun model_n_audio_state = whisper_model_n_audio_state(ctx : Context) : LibC::Int
  fun model_n_audio_head = whisper_model_n_audio_head(ctx : Context) : LibC::Int
  fun model_n_audio_layer = whisper_model_n_audio_layer(ctx : Context) : LibC::Int
  fun model_n_text_ctx = whisper_model_n_text_ctx(ctx : Context) : LibC::Int
  fun model_n_text_state = whisper_model_n_text_state(ctx : Context) : LibC::Int
  fun model_n_text_head = whisper_model_n_text_head(ctx : Context) : LibC::Int
  fun model_n_text_layer = whisper_model_n_text_layer(ctx : Context) : LibC::Int
  fun model_n_mels = whisper_model_n_mels(ctx : Context) : LibC::Int
  fun model_ftype = whisper_model_ftype(ctx : Context) : LibC::Int
  fun model_type = whisper_model_type(ctx : Context) : LibC::Int

  # --- Token utilities ---

  fun token_to_str = whisper_token_to_str(ctx : Context, token : Token) : LibC::Char*
  fun token_eot = whisper_token_eot(ctx : Context) : Token
  fun token_sot = whisper_token_sot(ctx : Context) : Token
  fun token_solm = whisper_token_solm(ctx : Context) : Token
  fun token_prev = whisper_token_prev(ctx : Context) : Token
  fun token_nosp = whisper_token_nosp(ctx : Context) : Token
  fun token_not = whisper_token_not(ctx : Context) : Token
  fun token_beg = whisper_token_beg(ctx : Context) : Token
  fun token_lang = whisper_token_lang(ctx : Context, lang_id : LibC::Int) : Token
  fun token_translate = whisper_token_translate(ctx : Context) : Token
  fun token_transcribe = whisper_token_transcribe(ctx : Context) : Token

  # --- Logits ---

  fun get_logits = whisper_get_logits(ctx : Context) : LibC::Float*
  fun get_logits_from_state = whisper_get_logits_from_state(state : State) : LibC::Float*

  # --- Performance ---

  fun get_timings = whisper_get_timings(ctx : Context) : Timings*
  fun print_timings = whisper_print_timings(ctx : Context) : Void
  fun reset_timings = whisper_reset_timings(ctx : Context) : Void

  # --- Benchmarking ---

  fun bench_memcpy = whisper_bench_memcpy(n_threads : LibC::Int) : LibC::Int
  fun bench_memcpy_str = whisper_bench_memcpy_str(n_threads : LibC::Int) : LibC::Char*
  fun bench_ggml_mul_mat = whisper_bench_ggml_mul_mat(n_threads : LibC::Int) : LibC::Int
  fun bench_ggml_mul_mat_str = whisper_bench_ggml_mul_mat_str(n_threads : LibC::Int) : LibC::Char*

  # --- VAD ---

  fun vad_default_params = whisper_vad_default_params : VadParams
  fun vad_default_context_params = whisper_vad_default_context_params : VadContextParams

  fun vad_init_from_file_with_params = whisper_vad_init_from_file_with_params(
    path_model : LibC::Char*,
    params : VadContextParams,
  ) : VadContext

  fun vad_detect_speech = whisper_vad_detect_speech(
    vctx : VadContext,
    samples : LibC::Float*,
    n_samples : LibC::Int,
  ) : Bool

  fun vad_n_probs = whisper_vad_n_probs(vctx : VadContext) : LibC::Int
  fun vad_probs = whisper_vad_probs(vctx : VadContext) : LibC::Float*

  fun vad_segments_from_probs = whisper_vad_segments_from_probs(
    vctx : VadContext,
    params : VadParams,
  ) : VadSegments

  fun vad_segments_from_samples = whisper_vad_segments_from_samples(
    vctx : VadContext,
    params : VadParams,
    samples : LibC::Float*,
    n_samples : LibC::Int,
  ) : VadSegments

  fun vad_segments_n_segments = whisper_vad_segments_n_segments(segments : VadSegments) : LibC::Int
  fun vad_segments_get_segment_t0 = whisper_vad_segments_get_segment_t0(segments : VadSegments, i_segment : LibC::Int) : LibC::Float
  fun vad_segments_get_segment_t1 = whisper_vad_segments_get_segment_t1(segments : VadSegments, i_segment : LibC::Int) : LibC::Float

  fun vad_free_segments = whisper_vad_free_segments(segments : VadSegments) : Void
  fun vad_free = whisper_vad_free(ctx : VadContext) : Void

  # --- Logging ---

  fun log_set = whisper_log_set(
    callback : (GgmlLogLevel, LibC::Char*, Void* ->),
    user_data : Void*,
  ) : Void

  # --- Misc ---

  fun version = whisper_version : LibC::Char*
  fun print_system_info = whisper_print_system_info : LibC::Char*
end
