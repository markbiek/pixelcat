import Testing
@testable import PixelCatCore

@Suite struct SayMessageTests {
    @Test func aSingleLineIsJustText() {
        #expect(
            SayMessage.parse("hello there\n")
                == SayMessage(text: "hello there", clickApp: nil)
        )
    }

    @Test func aMarkedSecondLineBecomesTheClickApp() {
        #expect(
            SayMessage.parse("build done\napp: Terminal\n")
                == SayMessage(text: "build done", clickApp: "Terminal")
        )
    }

    @Test func anUnmarkedSecondLineIsInert() {
        // Multi-line text relayed into the file must never gain behavior.
        #expect(
            SayMessage.parse("line one\nSome Random App\n")
                == SayMessage(text: "line one", clickApp: nil)
        )
    }

    @Test func aBareMarkerYieldsNoApp() {
        #expect(SayMessage.parse("hey\napp:")?.clickApp == nil)
        #expect(SayMessage.parse("hey\napp:   ")?.clickApp == nil)
    }

    @Test func pathShapedAppValuesAreRejected() {
        // `open -a` would treat these as bundle paths, not names.
        #expect(SayMessage.parse("hey\napp: /tmp/Evil.app")?.clickApp == nil)
        #expect(SayMessage.parse("hey\napp: ../Evil.app")?.clickApp == nil)
    }

    @Test func appNamesMayContainSpaces() {
        #expect(
            SayMessage.parse("psst\napp: Visual Studio Code")?.clickApp
                == "Visual Studio Code"
        )
    }

    @Test func blankLinesBetweenTextAndAppAreSkipped() {
        #expect(
            SayMessage.parse("hey\n\n  \napp: iTerm")
                == SayMessage(text: "hey", clickApp: "iTerm")
        )
    }

    @Test func linesBeyondTheSecondAreIgnored() {
        #expect(
            SayMessage.parse("hey\napp: iTerm\napp: Finder")?.clickApp
                == "iTerm"
        )
    }

    @Test func returnsNilForBlankContents() {
        #expect(SayMessage.parse("") == nil)
        #expect(SayMessage.parse("  \n\n ") == nil)
    }

    @Test func textIsTruncatedToThePhraseCap() {
        let long = String(repeating: "a", count: 150)
        #expect(SayMessage.parse(long)?.text.count == Phrase.maxLength)
    }

    @Test func surroundingWhitespaceIsTrimmed() {
        #expect(
            SayMessage.parse("  hi  \n  app: kitty  ")
                == SayMessage(text: "hi", clickApp: "kitty")
        )
    }
}
