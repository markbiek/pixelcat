import Testing
import Foundation
@testable import PixelCatCore

private func makeManifest() -> Manifest {
    Manifest(
        cellSize: 32,
        scale: 3,
        defaultState: "idle",
        decideIntervalSeconds: [8, 20],
        states: [
            "idle":  StateDefinition(row: 0, frames: 4, fps: 4,  weight: 70),
            "sleep": StateDefinition(row: 1, frames: 2, fps: 1,  weight: 20),
            "dance": StateDefinition(row: 2, frames: 6, fps: 10, weight: 10),
        ]
    )
}

@Test func startsInTheDefaultStateAndAutonomous() {
    let brain = CatBrain(manifest: makeManifest())
    #expect(brain.state == "idle")
    #expect(brain.frame == 0)
    #expect(brain.isAutonomous)
}

@Test func frameWrapsAtTheStateFrameCount() {
    var brain = CatBrain(manifest: makeManifest())
    // idle has 4 frames.
    brain.advanceFrame()
    brain.advanceFrame()
    brain.advanceFrame()
    #expect(brain.frame == 3)
    brain.advanceFrame()
    #expect(brain.frame == 0)
}

@Test func changingStateResetsTheFrame() {
    var brain = CatBrain(manifest: makeManifest())
    brain.advanceFrame()
    brain.advanceFrame()
    #expect(brain.frame == 2)
    brain.requestState("dance")
    #expect(brain.frame == 0)
}

@Test func reselectingTheCurrentStateLeavesTheFrameAlone() {
    var brain = CatBrain(manifest: makeManifest())
    brain.advanceFrame()
    brain.advanceFrame()
    #expect(brain.frame == 2)
    brain.requestState("idle")   // already idle
    #expect(brain.frame == 2)
}

@Test func decidingIntoTheCurrentStateLeavesTheFrameAlone() {
    var brain = CatBrain(manifest: makeManifest())
    brain.advanceFrame()
    #expect(brain.frame == 1)
    brain.decide(roll: 0.5)   // selects idle; the cat is already idle
    #expect(brain.frame == 1)
}

@Test func requestingAStateClearsAutonomy() {
    var brain = CatBrain(manifest: makeManifest())
    #expect(brain.isAutonomous)
    brain.requestState("dance")
    #expect(brain.state == "dance")
    #expect(!brain.isAutonomous)
}

@Test func resumingAutonomyRestoresTheFlagWithoutChangingState() {
    var brain = CatBrain(manifest: makeManifest())
    brain.requestState("dance")
    brain.resumeAutonomy()
    #expect(brain.isAutonomous)
    #expect(brain.state == "dance")
}

@Test func requestingAnUnknownStateChangesNothingAndReportsFailure() {
    var brain = CatBrain(manifest: makeManifest())
    let accepted = brain.requestState("zoomies")
    #expect(!accepted)
    #expect(brain.state == "idle")
    #expect(brain.isAutonomous)
}

@Test func currentFPSAndFrameCountFollowTheState() {
    var brain = CatBrain(manifest: makeManifest())
    #expect(brain.currentFPS == 4)
    #expect(brain.frameCount == 4)
    brain.requestState("dance")
    #expect(brain.currentFPS == 10)
    #expect(brain.frameCount == 6)
}

// States are bucketed in sorted-name order: dance (10), idle (70), sleep (20),
// total 100. So the cumulative boundaries are dance < 0.10, idle < 0.80,
// sleep < 1.00.
@Test func aLowRollSelectsTheFirstBucket() {
    var brain = CatBrain(manifest: makeManifest())
    brain.decide(roll: 0.05)
    #expect(brain.state == "dance")
}

@Test func aMidRollSelectsTheHeaviestBucket() {
    var brain = CatBrain(manifest: makeManifest())
    brain.decide(roll: 0.5)
    #expect(brain.state == "idle")
}

@Test func aHighRollSelectsTheLastBucket() {
    var brain = CatBrain(manifest: makeManifest())
    brain.decide(roll: 0.95)
    #expect(brain.state == "sleep")
}

@Test func aRollAtTheVeryTopStillSelectsAValidState() {
    var brain = CatBrain(manifest: makeManifest())
    brain.decide(roll: 0.999999)
    #expect(brain.manifest.states[brain.state] != nil)
}

@Test func decideDoesNothingWhenNotAutonomous() {
    var brain = CatBrain(manifest: makeManifest())
    brain.requestState("dance")
    brain.decide(roll: 0.95)   // would select sleep if autonomy were on
    #expect(brain.state == "dance")
}

@Test func nextDecisionDelayStaysInsideTheManifestInterval() {
    let brain = CatBrain(manifest: makeManifest())
    var rng = SystemRandomNumberGenerator()
    for _ in 0..<100 {
        let delay = brain.nextDecisionDelay(using: &rng)
        #expect(delay >= 8.0)
        #expect(delay <= 20.0)
    }
}
