.PHONY: resolve build app test format lint clean

SCRATCH_PATH ?= /private/tmp/epubzip-build-$(shell id -u)
SWIFT_ENV = CLANG_MODULE_CACHE_PATH=$(SCRATCH_PATH)/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=$(SCRATCH_PATH)/swift-module-cache
SWIFT_PATHS = --disable-sandbox --scratch-path $(SCRATCH_PATH) --cache-path $(SCRATCH_PATH)/package-cache --config-path $(SCRATCH_PATH)/config --security-path $(SCRATCH_PATH)/security

resolve:
	$(SWIFT_ENV) swift package $(SWIFT_PATHS) resolve

build:
	$(SWIFT_ENV) swift build $(SWIFT_PATHS) -c release --product epubzip
	@bin_dir=$$($(SWIFT_ENV) swift build $(SWIFT_PATHS) -c release --show-bin-path); \
		mkdir -p dist; \
		cp "$$bin_dir/epubzip" dist/epubzip; \
		echo "$(CURDIR)/dist/epubzip"

app:
	SCRATCH_PATH=$(SCRATCH_PATH) ARCHS="$(ARCHS)" ./Scripts/build-app.sh

test:
	$(SWIFT_ENV) swift test $(SWIFT_PATHS)

format:
	swift format -i -r Package.swift Sources Tests

lint:
	swift format lint -r Package.swift Sources Tests

clean:
	rm -rf $(SCRATCH_PATH) dist
