# whisper_cry

Crystal bindings for [whisper.cpp](https://github.com/ggerganov/whisper.cpp). Version tracks whisper.cpp releases (currently v1.8.3).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     whisper_cry:
       github: robacarp/whisper_cry
   ```

2. Run `shards install`

3. Build the native libraries:

   ```sh
   cd lib/whisper_cry && make
   ```

   This clones whisper.cpp v1.8.3, builds it as a static library, and copies the `.a` files into `vendor/lib/`. Requires `cmake` and a C++ compiler.

## Usage

```crystal
require "whisper_cry"

whisper = Whisper.new("/path/to/ggml-base.en.bin")
segments = whisper.transcribe_file("audio.wav")

segments.each do |segment|
  puts "#{segment.start_timestamp} --> #{segment.end_timestamp}"
  puts segment.text
end

whisper.close
```

Audio files must be 16-bit PCM WAV, mono, 16kHz. Convert with ffmpeg:

```sh
ffmpeg -i input.mp3 -ar 16000 -ac 1 -f wav output.wav
```
