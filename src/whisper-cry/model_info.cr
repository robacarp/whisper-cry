class Whisper
  # Snapshot of model dimension queries.
  #
  # Bundles all model introspection values into a single struct
  # for convenient access without repeated FFI calls.
  struct ModelInfo
    getter n_vocab : Int32
    getter n_audio_ctx : Int32
    getter n_audio_state : Int32
    getter n_audio_head : Int32
    getter n_audio_layer : Int32
    getter n_text_ctx : Int32
    getter n_text_state : Int32
    getter n_text_head : Int32
    getter n_text_layer : Int32
    getter n_mels : Int32
    getter ftype : Int32
    getter type : Int32

    def initialize(@n_vocab, @n_audio_ctx, @n_audio_state, @n_audio_head, @n_audio_layer,
                   @n_text_ctx, @n_text_state, @n_text_head, @n_text_layer,
                   @n_mels, @ftype, @type)
    end
  end
end
