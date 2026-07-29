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
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources/animals
	cp $(BIN) $(CONTENTS)/MacOS/$(APP)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	cp Resources/animals.json $(CONTENTS)/Resources/
	cp Resources/animals/*.png Resources/animals/*.json $(CONTENTS)/Resources/animals/
	@echo "Built $(BUNDLE)"

run: bundle
	@pkill -x $(APP) || true
	open $(BUNDLE)

test:
	swift test

art:
	swift Tools/GenerateArt.swift

clean:
	rm -rf .build $(BUNDLE)
