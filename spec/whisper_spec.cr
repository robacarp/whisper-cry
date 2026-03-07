require "./spec_helper"

describe Whisper do
  describe ".new" do
    it "raises Whisper::Error for nonexistent model path" do
      expect_raises(Whisper::Error, /not found/) do
        Whisper.new("/nonexistent/model.bin")
      end
    end
  end

  describe ".lang_max_id" do
    it "returns a positive integer" do
      Whisper.lang_max_id.should be > 0
    end
  end

  describe ".lang_id" do
    it "returns the language id for a known language" do
      Whisper.lang_id("en").should eq(0)
    end

    it "returns -1 for an unknown language" do
      Whisper.lang_id("zzzz").should eq(-1)
    end
  end

  describe ".lang_str" do
    it "returns the short code for a valid id" do
      Whisper.lang_str(0).should eq("en")
    end
  end

  describe ".lang_str_full" do
    it "returns the full name for a valid id" do
      Whisper.lang_str_full(0).should eq("english")
    end
  end
end
