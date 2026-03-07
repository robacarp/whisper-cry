require "./spec_helper"

describe Whisper do
  describe ".new" do
    it "raises Whisper::Error for nonexistent model path" do
      expect_raises(Whisper::Error, /not found/) do
        Whisper.new("/nonexistent/model.bin")
      end
    end
  end
end
