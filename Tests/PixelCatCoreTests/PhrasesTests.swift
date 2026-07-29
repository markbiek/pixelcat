import Testing
@testable import PixelCatCore

@Suite struct PhrasesTests {
    // MARK: Line parsing

    @Test func parsesAnUntaggedLine() {
        #expect(Phrase.parse(line: "mew") == Phrase(stateTag: nil, text: "mew"))
    }

    @Test func parsesAStateTaggedLine() {
        #expect(
            Phrase.parse(line: "sleep: five more minutes")
                == Phrase(stateTag: "sleep", text: "five more minutes")
        )
    }

    @Test func lowercasesTheTag() {
        #expect(Phrase.parse(line: "Sleep: zzz")?.stateTag == "sleep")
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(Phrase.parse(line: "  mew \n") == Phrase(stateTag: nil, text: "mew"))
        #expect(
            Phrase.parse(line: "dance:   watch this  ")
                == Phrase(stateTag: "dance", text: "watch this")
        )
    }

    @Test func aPrefixWithSpacesIsNotATag() {
        // A colon mid-sentence must not eat the phrase.
        #expect(
            Phrase.parse(line: "note to self: nap")
                == Phrase(stateTag: nil, text: "note to self: nap")
        )
    }

    @Test func returnsNilForBlankLines() {
        #expect(Phrase.parse(line: "") == nil)
        #expect(Phrase.parse(line: "   ") == nil)
    }

    @Test func returnsNilForATagWithNoText() {
        #expect(Phrase.parse(line: "sleep:") == nil)
        #expect(Phrase.parse(line: "sleep:   ") == nil)
    }

    @Test func truncatesTextToTheMaximumLength() {
        let long = String(repeating: "a", count: 250)
        let phrase = Phrase(stateTag: nil, text: long)
        #expect(phrase.text.count == Phrase.maxLength)
    }

    // MARK: Round-tripping

    @Test func lineRendersBackToTheParseableFormat() {
        #expect(Phrase(stateTag: nil, text: "mew").line == "mew")
        #expect(Phrase(stateTag: "sleep", text: "zzz").line == "sleep: zzz")
        // Round trip
        let phrase = Phrase(stateTag: "dance", text: "watch this")
        #expect(Phrase.parse(line: phrase.line) == phrase)
    }

    // MARK: Document parsing

    @Test func parsesADocumentSkippingBlanksAndKeepingOrder() {
        let contents = """
        mew

        sleep: zzz
        dance: watch this
        """
        #expect(PhraseBook.parse(contents) == [
            Phrase(stateTag: nil, text: "mew"),
            Phrase(stateTag: "sleep", text: "zzz"),
            Phrase(stateTag: "dance", text: "watch this"),
        ])
    }

    // MARK: Eligibility and selection

    private let pool = [
        Phrase(stateTag: nil, text: "mew"),
        Phrase(stateTag: "sleep", text: "zzz"),
        Phrase(stateTag: "dance", text: "watch this"),
    ]

    @Test func eligibleKeepsUntaggedAndMatchingTagOnly() {
        #expect(PhraseBook.eligible(pool, state: "sleep") == [
            Phrase(stateTag: nil, text: "mew"),
            Phrase(stateTag: "sleep", text: "zzz"),
        ])
    }

    @Test func anUnknownTagIsSimplyNeverEligible() {
        // Forgiving posture: a tag that matches no state of the current
        // animal is not an error, the line just never comes up.
        #expect(PhraseBook.eligible(pool, state: "fly") == [
            Phrase(stateTag: nil, text: "mew"),
        ])
    }

    @Test func pickIndexesEligiblePhrasesByRoll() {
        #expect(
            PhraseBook.pick(from: pool, state: "sleep", roll: 0.0)
                == Phrase(stateTag: nil, text: "mew")
        )
        #expect(
            PhraseBook.pick(from: pool, state: "sleep", roll: 0.99)
                == Phrase(stateTag: "sleep", text: "zzz")
        )
    }

    @Test func pickReturnsNilWhenNothingIsEligible() {
        let taggedOnly = [Phrase(stateTag: "sleep", text: "zzz")]
        #expect(PhraseBook.pick(from: taggedOnly, state: "dance", roll: 0.5) == nil)
    }

    @Test func pickClampsOutOfRangeRolls() {
        #expect(PhraseBook.pick(from: pool, state: "idle", roll: 1.5) != nil)
        #expect(PhraseBook.pick(from: pool, state: "idle", roll: -0.5) != nil)
    }
}
