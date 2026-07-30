import Testing
@testable import PixelCatCore

@Suite struct SayMessageTests {
    @Test func aSingleLineIsJustText() {
        #expect(
            SayMessage.parse("hello there\n")
                == SayMessage(text: "hello there", clickCommand: nil)
        )
    }

    @Test func aMarkedSecondLineBecomesTheClickCommand() {
        #expect(
            SayMessage.parse("build done\nrun: open -a Terminal\n")
                == SayMessage(text: "build done", clickCommand: "open -a Terminal")
        )
    }

    @Test func anUnmarkedSecondLineIsInert() {
        // Multi-line text relayed into the file must never gain a command.
        #expect(
            SayMessage.parse("line one\nrm -rf /\n")
                == SayMessage(text: "line one", clickCommand: nil)
        )
    }

    @Test func aBareMarkerYieldsNoCommand() {
        #expect(SayMessage.parse("hey\nrun:")?.clickCommand == nil)
        #expect(SayMessage.parse("hey\nrun:   ")?.clickCommand == nil)
    }

    @Test func blankLinesBetweenTextAndCommandAreSkipped() {
        #expect(
            SayMessage.parse("hey\n\n  \nrun: open -a iTerm")
                == SayMessage(text: "hey", clickCommand: "open -a iTerm")
        )
    }

    @Test func linesBeyondTheSecondAreIgnored() {
        #expect(
            SayMessage.parse("hey\nrun: open -a iTerm\nrun: rm -rf /")?.clickCommand
                == "open -a iTerm"
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
            SayMessage.parse("  hi  \n  run: open -a kitty  ")
                == SayMessage(text: "hi", clickCommand: "open -a kitty")
        )
    }
}
