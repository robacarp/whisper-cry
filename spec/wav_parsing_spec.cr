require "./spec_helper"

# Builds a minimal WAV file in memory.
# Defaults to a valid format: mono, 16kHz, 16-bit PCM.
private def build_wav(
  riff_id : String = "RIFF",
  wave_id : String = "WAVE",
  audio_format : Int16 = 1_i16,
  channels : Int16 = 1_i16,
  sample_rate : Int32 = 16000_i32,
  bits_per_sample : Int16 = 16_i16,
  samples : Array(Int16) = [0_i16, 1000_i16, -1000_i16, 32767_i16],
  include_fmt : Bool = true,
  include_data : Bool = true,
) : Bytes
  io = IO::Memory.new

  chunks_io = IO::Memory.new

  if include_fmt
    fmt_io = IO::Memory.new
    fmt_io.write_bytes(audio_format, IO::ByteFormat::LittleEndian)
    fmt_io.write_bytes(channels, IO::ByteFormat::LittleEndian)
    fmt_io.write_bytes(sample_rate, IO::ByteFormat::LittleEndian)

    byte_rate = sample_rate * channels * (bits_per_sample // 8)
    fmt_io.write_bytes(byte_rate, IO::ByteFormat::LittleEndian)

    block_align = (channels * (bits_per_sample // 8)).to_i16
    fmt_io.write_bytes(block_align, IO::ByteFormat::LittleEndian)
    fmt_io.write_bytes(bits_per_sample, IO::ByteFormat::LittleEndian)

    fmt_data = fmt_io.to_slice
    chunks_io.print("fmt ")
    chunks_io.write_bytes(fmt_data.size.to_u32, IO::ByteFormat::LittleEndian)
    chunks_io.write(fmt_data)
  end

  if include_data
    data_size = (samples.size * (bits_per_sample // 8)).to_u32
    chunks_io.print("data")
    chunks_io.write_bytes(data_size, IO::ByteFormat::LittleEndian)
    samples.each do |s|
      chunks_io.write_bytes(s, IO::ByteFormat::LittleEndian)
    end
  end

  inner = chunks_io.to_slice

  io.print(riff_id)
  io.write_bytes((4 + inner.size).to_u32, IO::ByteFormat::LittleEndian)
  io.print(wave_id)
  io.write(inner)

  io.to_slice
end

private def write_temp_wav(name : String, data : Bytes) : String
  tmpfile = File.tempfile(name, ".wav") do |file|
    file.write(data)
  end
  tmpfile.path
end

describe "Whisper.load_wav_samples" do
  it "parses a valid WAV file and returns Float32 samples" do
    wav = build_wav(samples: [0_i16, 16384_i16, -16384_i16, 32767_i16])
    path = write_temp_wav("valid", wav)

    result = Whisper.load_wav_samples(path)

    result.size.should eq(4)
    result[0].should eq(0.0_f32)
    result[1].should be_close(0.5_f32, 0.001)
    result[2].should be_close(-0.5_f32, 0.001)
    result[3].should be_close(1.0_f32, 0.001)
  ensure
    File.delete?(path) if path
  end

  it "raises for missing RIFF header" do
    io = IO::Memory.new
    io.print("NOT_")
    io.write_bytes(0_u32, IO::ByteFormat::LittleEndian)
    io.print("WAVE")
    path = write_temp_wav("bad_riff", io.to_slice)

    expect_raises(Whisper::Error, /RIFF/) do
      Whisper.load_wav_samples(path)
    end
  ensure
    File.delete?(path) if path
  end

  it "raises for non-PCM format" do
    wav = build_wav(audio_format: 3_i16)
    path = write_temp_wav("float_fmt", wav)

    expect_raises(Whisper::Error, /PCM/) do
      Whisper.load_wav_samples(path)
    end
  ensure
    File.delete?(path) if path
  end

  it "raises for stereo audio" do
    wav = build_wav(channels: 2_i16)
    path = write_temp_wav("stereo", wav)

    expect_raises(Whisper::Error, /mono/) do
      Whisper.load_wav_samples(path)
    end
  ensure
    File.delete?(path) if path
  end

  it "raises for wrong sample rate" do
    wav = build_wav(sample_rate: 44100_i32)
    path = write_temp_wav("44khz", wav)

    expect_raises(Whisper::Error, /16kHz/) do
      Whisper.load_wav_samples(path)
    end
  ensure
    File.delete?(path) if path
  end

  it "raises for wrong bit depth" do
    wav = build_wav(bits_per_sample: 8_i16)
    path = write_temp_wav("8bit", wav)

    expect_raises(Whisper::Error, /16-bit/) do
      Whisper.load_wav_samples(path)
    end
  ensure
    File.delete?(path) if path
  end

  it "raises for file not found" do
    expect_raises(Whisper::Error, /not found/) do
      Whisper.load_wav_samples("/nonexistent/audio.wav")
    end
  end

  it "raises when data chunk is missing" do
    wav = build_wav(include_data: false)
    path = write_temp_wav("no_data", wav)

    expect_raises(Whisper::Error, /data/) do
      Whisper.load_wav_samples(path)
    end
  ensure
    File.delete?(path) if path
  end

  it "raises when fmt chunk is missing" do
    wav = build_wav(include_fmt: false)
    path = write_temp_wav("no_fmt", wav)

    expect_raises(Whisper::Error, /fmt/) do
      Whisper.load_wav_samples(path)
    end
  ensure
    File.delete?(path) if path
  end
end
