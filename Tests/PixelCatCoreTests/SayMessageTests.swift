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
        // Unmarked lines never gain behavior; only marked lines do.
        #expect(
            SayMessage.parse("line one\nSome Random App\n")
                == SayMessage(text: "line one", clickApp: nil)
        )
    }

    @Test func markersAfterUnmarkedLinesAreStillHonored() {
        // The scan covers every line after the first, not just line 2.
        #expect(
            SayMessage.parse("hey\nsome chatter\napp: Finder")?.clickApp
                == "Finder"
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

    @Test func aRunLineParsesToAnArgv() {
        #expect(
            SayMessage.parse("hey\nrun: /usr/bin/open -a Terminal")?.clickCommand
                == ["/usr/bin/open", "-a", "Terminal"]
        )
    }

    @Test func aRelativeExecutableIsRejected() {
        // No PATH lookup: only absolute paths run.
        #expect(SayMessage.parse("hey\nrun: open -a Terminal")?.clickCommand == nil)
        #expect(SayMessage.parse("hey\nrun:")?.clickCommand == nil)
    }

    @Test func shellMetacharactersAreLiteralArguments() {
        // There is no shell: chaining syntax survives only as inert argv.
        #expect(
            SayMessage.parse("hey\nrun: /bin/echo hi; /bin/rm -rf /")?.clickCommand
                == ["/bin/echo", "hi;", "/bin/rm", "-rf", "/"]
        )
    }

    @Test func appAndRunLinesCombine() {
        let message = SayMessage.parse("hey\napp: cmux\nrun: /usr/bin/true now")
        #expect(message?.clickApp == "cmux")
        #expect(message?.clickCommand == ["/usr/bin/true", "now"])
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

    @Test func theFirstAcceptedAppLineWins() {
        #expect(
            SayMessage.parse("hey\napp: iTerm\napp: Finder")?.clickApp
                == "iTerm"
        )
    }

    @Test func theFirstAcceptedRunLineWins() {
        #expect(
            SayMessage.parse("hey\nrun: /bin/a\nrun: /bin/b")?.clickCommand
                == ["/bin/a"]
        )
    }

    @Test func aRejectedMarkedLineLeavesItsSlotOpen() {
        // An invalid marker doesn't consume the slot; a later valid one wins.
        #expect(
            SayMessage.parse("hey\nrun: relative\nrun: /bin/b")?.clickCommand
                == ["/bin/b"]
        )
        #expect(
            SayMessage.parse("hey\napp: /Evil.app\napp: Finder")?.clickApp
                == "Finder"
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
