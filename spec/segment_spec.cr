require "./spec_helper"

describe Whisper::Segment do
  describe "#start_seconds" do
    it "converts milliseconds to seconds" do
      seg = Whisper::Segment.new(text: "", start_ms: 1500, end_ms: 3000, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.start_seconds.should eq(1.5)
    end

    it "returns zero for zero ms" do
      seg = Whisper::Segment.new(text: "", start_ms: 0, end_ms: 1000, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.start_seconds.should eq(0.0)
    end
  end

  describe "#end_seconds" do
    it "converts milliseconds to seconds" do
      seg = Whisper::Segment.new(text: "", start_ms: 0, end_ms: 2500, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.end_seconds.should eq(2.5)
    end
  end

  describe "#duration_ms" do
    it "returns the difference between end and start" do
      seg = Whisper::Segment.new(text: "", start_ms: 1000, end_ms: 3500, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.duration_ms.should eq(2500)
    end

    it "returns zero when start equals end" do
      seg = Whisper::Segment.new(text: "", start_ms: 5000, end_ms: 5000, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.duration_ms.should eq(0)
    end
  end

  describe "#start_timestamp" do
    it "formats zero as 00:00:00.000" do
      seg = Whisper::Segment.new(text: "", start_ms: 0, end_ms: 0, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.start_timestamp.should eq("00:00:00.000")
    end

    it "formats sub-second values" do
      seg = Whisper::Segment.new(text: "", start_ms: 450, end_ms: 0, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.start_timestamp.should eq("00:00:00.450")
    end

    it "formats seconds and milliseconds" do
      seg = Whisper::Segment.new(text: "", start_ms: 5230, end_ms: 0, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.start_timestamp.should eq("00:00:05.230")
    end

    it "formats minutes, seconds, and milliseconds" do
      seg = Whisper::Segment.new(text: "", start_ms: 125_450, end_ms: 0, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.start_timestamp.should eq("00:02:05.450")
    end

    it "formats hours" do
      seg = Whisper::Segment.new(text: "", start_ms: 3_661_001, end_ms: 0, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.start_timestamp.should eq("01:01:01.001")
    end
  end

  describe "#end_timestamp" do
    it "formats the end time" do
      seg = Whisper::Segment.new(text: "", start_ms: 0, end_ms: 90_500, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.end_timestamp.should eq("00:01:30.500")
    end
  end

  describe "getters" do
    it "stores text correctly" do
      seg = Whisper::Segment.new(text: "Hello world", start_ms: 0, end_ms: 1000, no_speech_probability: 0.1_f32, speaker_turn_next: true)
      seg.text.should eq("Hello world")
    end

    it "stores no_speech_probability" do
      seg = Whisper::Segment.new(text: "", start_ms: 0, end_ms: 0, no_speech_probability: 0.85_f32, speaker_turn_next: false)
      seg.no_speech_probability.should eq(0.85_f32)
    end

    it "stores speaker_turn_next" do
      seg = Whisper::Segment.new(text: "", start_ms: 0, end_ms: 0, no_speech_probability: 0.0_f32, speaker_turn_next: true)
      seg.speaker_turn_next.should be_true
    end
  end

  describe "#tokens" do
    it "defaults to an empty array" do
      seg = Whisper::Segment.new(text: "", start_ms: 0, end_ms: 0, no_speech_probability: 0.0_f32, speaker_turn_next: false)
      seg.tokens.should be_empty
    end

    it "stores provided tokens" do
      tokens = [
        Whisper::Token.new(text: "Hello", id: 1, probability: 0.9_f32, start_ms: 0_i64, end_ms: 50_i64),
        Whisper::Token.new(text: " world", id: 2, probability: 0.85_f32, start_ms: 50_i64, end_ms: 100_i64),
      ]
      seg = Whisper::Segment.new(text: "Hello world", start_ms: 0, end_ms: 100, no_speech_probability: 0.0_f32, speaker_turn_next: false, tokens: tokens)
      seg.tokens.size.should eq(2)
      seg.tokens[0].text.should eq("Hello")
      seg.tokens[1].text.should eq(" world")
    end
  end
end
