require "./spec_helper"

describe Whisper::ModelInfo do
  describe "#initialize" do
    it "stores all model dimension fields" do
      info = Whisper::ModelInfo.new(
        n_vocab: 51864,
        n_audio_ctx: 1500,
        n_audio_state: 512,
        n_audio_head: 8,
        n_audio_layer: 6,
        n_text_ctx: 448,
        n_text_state: 512,
        n_text_head: 8,
        n_text_layer: 6,
        n_mels: 80,
        ftype: 1,
        type: 2,
      )

      info.n_vocab.should eq(51864)
      info.n_audio_ctx.should eq(1500)
      info.n_audio_state.should eq(512)
      info.n_audio_head.should eq(8)
      info.n_audio_layer.should eq(6)
      info.n_text_ctx.should eq(448)
      info.n_text_state.should eq(512)
      info.n_text_head.should eq(8)
      info.n_text_layer.should eq(6)
      info.n_mels.should eq(80)
      info.ftype.should eq(1)
      info.type.should eq(2)
    end
  end
end
