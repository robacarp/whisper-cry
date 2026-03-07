class Whisper
  # Per-token data from a transcription segment.
  #
  # Each token represents a single unit produced by the Whisper decoder,
  # carrying its text, numeric ID, probability, and optional timestamps.
  struct Token
    # The text content of this token.
    getter text : String

    # The numeric token ID in the model vocabulary.
    getter id : Int32

    # Probability of this token (0.0 to 1.0).
    getter probability : Float32

    # Token start time in milliseconds (only meaningful when token timestamps are enabled).
    getter start_ms : Int64

    # Token end time in milliseconds (only meaningful when token timestamps are enabled).
    getter end_ms : Int64

    def initialize(@text, @id, @probability, @start_ms = 0_i64, @end_ms = 0_i64)
    end
  end
end
