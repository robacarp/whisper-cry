class Whisper
  # A single transcription segment returned by `Whisper#transcribe`.
  #
  # Each segment represents a contiguous span of recognized speech with
  # timing information and confidence metadata.
  struct Segment
    # The transcribed text for this segment.
    getter text : String

    # Segment start time in milliseconds from the beginning of the audio.
    getter start_ms : Int64

    # Segment end time in milliseconds from the beginning of the audio.
    getter end_ms : Int64

    # Probability that this segment contains no speech (0.0 to 1.0).
    # Higher values suggest background noise, silence, or music rather than speech.
    getter no_speech_probability : Float32

    # When `true`, indicates the next segment is from a different speaker.
    # Useful for diarization or dialog formatting.
    getter speaker_turn_next : Bool

    # Per-token data for this segment (empty unless token-level data was requested).
    getter tokens : Array(Token)

    def initialize(@text, @start_ms, @end_ms, @no_speech_probability, @speaker_turn_next, @tokens = [] of Token)
    end

    # Segment start time in seconds.
    def start_seconds : Float64
      @start_ms / 1000.0
    end

    # Segment end time in seconds.
    def end_seconds : Float64
      @end_ms / 1000.0
    end

    # Segment duration in milliseconds.
    def duration_ms : Int64
      @end_ms - @start_ms
    end

    # Formatted start time as `"HH:MM:SS.mmm"`.
    def start_timestamp : String
      format_timestamp(@start_ms)
    end

    # Formatted end time as `"HH:MM:SS.mmm"`.
    def end_timestamp : String
      format_timestamp(@end_ms)
    end

    private def format_timestamp(ms : Int64) : String
      hours = ms // 3_600_000
      minutes = (ms % 3_600_000) // 60_000
      seconds = (ms % 60_000) // 1_000
      millis = ms % 1_000

      "%02d:%02d:%02d.%03d" % {hours, minutes, seconds, millis}
    end
  end
end
