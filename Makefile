.PHONY: resolve verify verify-project build app source example test format lint \
	verify-artifacts checksums verify-checksums notarize clean

CHECKOUT_ID := $(shell pwd -P | tr -d '\n' | shasum -a 256 | cut -c 1-12)
SCRATCH_PATH ?= /private/tmp/epubzip-build-$(shell id -u)-$(CHECKOUT_ID)
SWIFT_ENV = CLANG_MODULE_CACHE_PATH="$(SCRATCH_PATH)/clang-module-cache" SWIFTPM_MODULECACHE_OVERRIDE="$(SCRATCH_PATH)/swift-module-cache"
SWIFT_PATHS = --disable-sandbox --scratch-path "$(SCRATCH_PATH)" --cache-path "$(SCRATCH_PATH)/package-cache" --config-path "$(SCRATCH_PATH)/config" --security-path "$(SCRATCH_PATH)/security"

resolve: verify-project
	$(SWIFT_ENV) swift package $(SWIFT_PATHS) resolve

verify: verify-project lint

verify-project:
	./Scripts/verify-project.sh

build: verify-project
	SCRATCH_PATH="$(SCRATCH_PATH)" ./Scripts/build-cli.sh

app: verify-project
	SCRATCH_PATH="$(SCRATCH_PATH)" ARCHS="$(ARCHS)" ./Scripts/build-app.sh

source: verify-project
	./Scripts/build-source.sh

example: verify-project
	mkdir -p dist
	$(SWIFT_ENV) swift run $(SWIFT_PATHS) --arch arm64 epubzip pack --force -o "$(CURDIR)/dist/MinimalBook.epub" "$(CURDIR)/Examples/MinimalBook"
	$(SWIFT_ENV) swift run $(SWIFT_PATHS) --arch arm64 epubzip check "$(CURDIR)/dist/MinimalBook.epub"

test:
	$(SWIFT_ENV) swift test $(SWIFT_PATHS)

format:
	swift format -i -r Package.swift Sources Tests

lint:
	swift format lint -r Package.swift Sources Tests

verify-artifacts:
	./Scripts/verify-artifacts.sh

checksums:
	./Scripts/create-checksums.sh "$(CURDIR)/dist"

verify-checksums:
	cd dist && shasum -a 256 -c SHA256SUMS

notarize:
	@test -n "$(DMG)" || { echo 'Usage: make notarize DMG=dist/<signed-not-notarized.dmg>' >&2; exit 64; }
	./Scripts/notarize.sh "$(DMG)"

clean:
	./Scripts/clean.sh "$(SCRATCH_PATH)"
