require "./spec_helper"

describe Whisper::Token do
  describe "#initialize" do
    it "stores all fields" do
      token = Whisper::Token.new(text: "hello", id: 42, probability: 0.95_f32, start_ms: 100_i64, end_ms: 200_i64)
      token.text.should eq("hello")
      token.id.should eq(42)
      token.probability.should eq(0.95_f32)
      token.start_ms.should eq(100_i64)
      token.end_ms.should eq(200_i64)
    end

    it "defaults timestamps to zero" do
      token = Whisper::Token.new(text: "world", id: 7, probability: 0.5_f32)
      token.start_ms.should eq(0_i64)
      token.end_ms.should eq(0_i64)
    end
  end
end
