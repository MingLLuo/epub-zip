.PHONY: resolve build app test format lint clean

SCRATCH_PATH ?= /private/tmp/epubzip-build-$(shell id -u)
SWIFT_ENV = CLANG_MODULE_CACHE_PATH=$(SCRATCH_PATH)/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=$(SCRATCH_PATH)/swift-module-cache
SWIFT_PATHS = --disable-sandbox --scratch-path $(SCRATCH_PATH) --cache-path $(SCRATCH_PATH)/package-cache --config-path $(SCRATCH_PATH)/config --security-path $(SCRATCH_PATH)/security

resolve:
	$(SWIFT_ENV) swift package $(SWIFT_PATHS) resolve

build:
	$(SWIFT_ENV) swift build $(SWIFT_PATHS) -c release --product epubzip
	@bin_dir=$$($(SWIFT_ENV) swift build $(SWIFT_PATHS) -c release --show-bin-path); \
		stage="$(SCRATCH_PATH)/epubzip-0.1.0-arm64"; \
		rm -rf "$$stage"; \
		mkdir -p "$$stage" dist; \
		cp "$$bin_dir/epubzip" "$$stage/epubzip"; \
		cp Resources/CLI-README.txt "$$stage/README.txt"; \
		chmod 755 "$$stage/epubzip"; \
		rm -f "dist/epubzip-0.1.0-arm64-cli.zip"; \
		ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent "$$stage" "dist/epubzip-0.1.0-arm64-cli.zip"; \
		echo "$(CURDIR)/dist/epubzip-0.1.0-arm64-cli.zip"

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
