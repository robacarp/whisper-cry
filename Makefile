WHISPER_CPP_VERSION := v1.8.3
WHISPER_CPP_DIR := ext/whisper.cpp
BUILD_DIR := $(WHISPER_CPP_DIR)/build
VENDOR_LIB := vendor/lib
MODEL_DIR := models
MODEL_FILE := $(MODEL_DIR)/ggml-tiny.en.bin
MODEL_URL := https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin

STATIC_LIBS := libwhisper.a libggml.a libggml-base.a libggml-cpu.a libggml-blas.a libggml-metal.a

.PHONY: all clean model demo

all: $(addprefix $(VENDOR_LIB)/,$(STATIC_LIBS))

$(WHISPER_CPP_DIR):
	git clone --depth 1 --branch $(WHISPER_CPP_VERSION) https://github.com/ggerganov/whisper.cpp.git $(WHISPER_CPP_DIR)

$(BUILD_DIR)/src/libwhisper.a: $(WHISPER_CPP_DIR)
	cmake -S $(WHISPER_CPP_DIR) -B $(BUILD_DIR) \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SHARED_LIBS=OFF \
		-DWHISPER_COREML=OFF
	cmake --build $(BUILD_DIR) --config Release -j$(shell sysctl -n hw.logicalcpu 2>/dev/null || nproc)

$(VENDOR_LIB)/%: $(BUILD_DIR)/src/libwhisper.a
	@mkdir -p $(VENDOR_LIB)
	@for lib in $(STATIC_LIBS); do \
		found=$$(find $(BUILD_DIR) -name "$$lib" -print -quit); \
		if [ -n "$$found" ]; then \
			cp "$$found" $(VENDOR_LIB)/; \
		else \
			echo "Warning: $$lib not found in build output"; \
		fi; \
	done

$(MODEL_FILE):
	@mkdir -p $(MODEL_DIR)
	curl -L -o $(MODEL_FILE) $(MODEL_URL)

model: $(MODEL_FILE)

demo: all model
	shards build --error-trace demo

clean:
	rm -rf $(BUILD_DIR) $(VENDOR_LIB)
