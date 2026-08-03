APP      := PixelCat
BUNDLE   := $(APP).app
CONTENTS := $(BUNDLE)/Contents
BIN      := .build/release/$(APP)

.PHONY: all build bundle assemble release run test art clean

all: bundle

build:
	swift build -c release

bundle: build
	$(MAKE) assemble

assemble:
	rm -rf $(BUNDLE)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources/animals
	cp $(BIN) $(CONTENTS)/MacOS/$(APP)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	cp Resources/animals.json $(CONTENTS)/Resources/
	cp Resources/animals/*.png Resources/animals/*.json $(CONTENTS)/Resources/animals/
	@echo "Built $(BUNDLE)"

# A downloadable zip: universal binary, ad-hoc signed. Not notarized —
# downloaders approve the first launch in System Settings (see README).
release:
	swift build -c release --arch arm64 --arch x86_64
	$(MAKE) assemble BIN=.build/apple/Products/Release/$(APP)
	codesign --force -s - $(BUNDLE)
	ditto -c -k --keepParent $(BUNDLE) $(APP).zip
	@echo "Built $(APP).zip"

run: bundle
	@pkill -x $(APP) || true
	open $(BUNDLE)

test:
	swift test

art:
	swift Tools/GenerateArt.swift

clean:
	rm -rf .build $(BUNDLE)
