require "./spec_helper"

describe Whisper::Vad::SpeechSegment do
  describe "#initialize" do
    it "stores start and end times" do
      seg = Whisper::Vad::SpeechSegment.new(start_seconds: 1.5_f32, end_seconds: 3.2_f32)
      seg.start_seconds.should eq(1.5_f32)
      seg.end_seconds.should eq(3.2_f32)
    end
  end

  describe "#duration_seconds" do
    it "returns the difference between end and start" do
      seg = Whisper::Vad::SpeechSegment.new(start_seconds: 1.0_f32, end_seconds: 4.5_f32)
      seg.duration_seconds.should eq(3.5_f32)
    end

    it "returns zero when start equals end" do
      seg = Whisper::Vad::SpeechSegment.new(start_seconds: 2.0_f32, end_seconds: 2.0_f32)
      seg.duration_seconds.should eq(0.0_f32)
    end
  end
end

describe Whisper::Vad do
  describe ".new" do
    it "raises for nonexistent model path" do
      expect_raises(Whisper::Error, /not found/) do
        Whisper::Vad.new("/nonexistent/vad-model.onnx")
      end
    end
  end
end
