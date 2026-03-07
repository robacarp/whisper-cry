# whisper-cry

Crystal bindings for [whisper.cpp](https://github.com/ggml-org/whisper.cpp), providing local speech-to-text transcription using OpenAI's Whisper models. Version tracks whisper.cpp releases (currently v1.8.3).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     whisper-cry:
       github: robacarp/whisper-cry
   ```

2. Run `shards install`

3. Build the native libraries:

   ```sh
   cd lib/whisper-cry && make
   ```

   This clones whisper.cpp v1.8.3, builds it as a static library, and copies the `.a` files into `vendor/lib/`. Requires `cmake` and a C++ compiler. See the [whisper.cpp build documentation](https://github.com/ggml-org/whisper.cpp#building-the-project) for platform-specific details and options.

4. Download a Whisper model (e.g. the base English model):

   ```sh
   curl -L -o ggml-base.en.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
   ```

   See the [whisper.cpp models directory](https://github.com/ggml-org/whisper.cpp/tree/master/models) for all available models.

5. Optimize the model for your hardware (optional but recommended):

  The Whisper.cpp project has documentation and scripting support for optimizing models for different hardware, quantization, etc.

  - MacOS [CoreML](https://github.com/ggml-org/whisper.cpp?tab=readme-ov-file#core-ml-support)
  - [OpenVINO](https://github.com/ggml-org/whisper.cpp?tab=readme-ov-file#openvino-support)
  - [Nvidia](https://github.com/ggml-org/whisper.cpp?tab=readme-ov-file#nvidia-gpu-support)

## Usage

```crystal
require "whisper-cry"

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

### API

#### `Whisper.new(model_path, use_gpu = false)`

Loads a GGML-format model file and initializes the inference context. Set `use_gpu: true` to enable Metal acceleration on macOS. Raises `Whisper::Error` if the model file is missing or fails to load.

#### `#transcribe_file(path, language = "en", n_threads = 4, translate = false)`

Transcribes a WAV file and returns an `Array(Whisper::Segment)`. The file must be 16-bit signed PCM, mono, 16kHz.

#### `#transcribe(samples, language = "en", n_threads = 4, translate = false)`

Transcribes pre-loaded `Float32` audio samples (normalized to `[-1.0, 1.0]`, mono, 16kHz). Useful when you already have audio data in memory.

Options:
- **language**: BCP-47 code (e.g. `"en"`, `"es"`), or `nil` for auto-detection
- **n_threads**: CPU threads for inference
- **translate**: when `true`, translates to English regardless of source language

#### `#close`

Frees the underlying whisper context. Safe to call multiple times. Also called automatically by `#finalize`.

#### `#version`, `#model_type`, `#multilingual?`, `#system_info`

Query the whisper.cpp version string, loaded model type (e.g. `"base"`), multilingual support, and available CPU features.

### `Whisper::Segment`

Each segment represents a span of recognized speech:

| Method | Returns |
|---|---|
| `#text` | Transcribed text |
| `#start_ms` / `#end_ms` | Timing in milliseconds |
| `#start_seconds` / `#end_seconds` | Timing in seconds |
| `#duration_ms` | Segment duration in milliseconds |
| `#start_timestamp` / `#end_timestamp` | Formatted as `"HH:MM:SS.mmm"` |
| `#no_speech_probability` | `Float32` (0.0-1.0), higher = likely not speech |
| `#speaker_turn_next` | `true` if next segment is a different speaker |

## Development

Run tests:

```sh
crystal spec
```

Tests cover `Segment` formatting/conversion, WAV file parsing and validation, and `Whisper` initialization error handling. No model file is needed to run the test suite.

## License

[MIT](LICENSE)
