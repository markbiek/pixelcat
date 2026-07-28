APP      := PixelCat
BUNDLE   := $(APP).app
CONTENTS := $(BUNDLE)/Contents
BIN      := .build/release/$(APP)

.PHONY: all build bundle run test art clean

all: bundle

build:
	swift build -c release

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BIN) $(CONTENTS)/MacOS/$(APP)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	cp Resources/cat.png Resources/states.json $(CONTENTS)/Resources/
	@echo "Built $(BUNDLE)"

run: bundle
	@pkill -x $(APP) || true
	open $(BUNDLE)

test:
	swift test

art:
	swift Tools/GenerateArt.swift Resources/cat.png

clean:
	rm -rf .build $(BUNDLE)
