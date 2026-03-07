require "./whisper-cry"

model_path = ARGV[0]? || "models/ggml-tiny.en.bin"

unless File.exists?(model_path)
  STDERR.puts "Model not found: #{model_path}"
  STDERR.puts "Run `make model` to download the tiny English model."
  exit 1
end

puts "whisper.cpp version: #{Whisper.new(model_path).version}"
puts "System info: #{Whisper.new(model_path).system_info}"

whisper = Whisper.new(model_path)

puts "Model type: #{whisper.model_type}"
puts "Multilingual: #{whisper.multilingual?}"

info = whisper.model_info
puts "Model info:"
puts "  Vocab size: #{info.n_vocab}"
puts "  Audio ctx:  #{info.n_audio_ctx}"
puts "  Text ctx:   #{info.n_text_ctx}"
puts "  Mels:       #{info.n_mels}"

if audio_path = ARGV[1]?
  unless File.exists?(audio_path)
    STDERR.puts "Audio file not found: #{audio_path}"
    exit 1
  end

  puts "\nTranscribing: #{audio_path}"
  segments = whisper.transcribe_file(audio_path)

  segments.each do |segment|
    puts "#{segment.start_timestamp} --> #{segment.end_timestamp}"
    puts "  #{segment.text}"
  end
else
  puts "\nNo audio file provided. Pass a WAV file as the second argument to transcribe."
  puts "Usage: demo [model_path] [audio.wav]"
end

whisper.close
puts "\nDone."
