// Generates the placeholder sprite sheets, one per animal.
// Run: swift Tools/GenerateArt.swift [output-directory]
//
// Each sheet is one row of 24px cells per state, as wide as that animal's
// longest state. Art is authored as a 24x24 character grid drawn 1:1, so what
// you read below is exactly what ships. On-screen size is cellSize * scale
// from animals.json: 24 * 3 = 72 points.

import AppKit

let cellSize = 24
let artSize = 24
let pixelScale = cellSize / artSize

// . transparent   # outline   o white fur   b black patch   p inner ear
// e eye           n nose      m mouth       z sleep mark
// w mid-grey: the cat's whiskers, and the bat's body and wings
//
// Whiskers sit on rows 9/10, 12, and 14/15 with blank rows between. Three
// solid bars on consecutive rows fuse into one grey rectangle; the gaps and
// the one-pixel stagger are what make them read as separate whiskers.
let baseCat = [
    "........................",
    "....##............##....",
    "....#b#..........#b#....",
    "....#bp#........#pb#....",
    "....#bpp#......#ppb#....",
    "....#bpp########ppb#....",
    "....#bboooooooooobb#....",
    "....#oooooooooooooo#....",
    "....#ooeeooooooeeoo#....",
    ".w..#ooeeooooooeeoo#..w.",
    "..ww#oooooooooooooo#ww..",
    "....#oooooonnoooooo#....",
    ".www#oooomoooomoooo#www.",
    "....#ooooommmmooooo#....",
    "..ww#oooooooooooooo#ww..",
    ".w..#oooooooooooooo#..w.",
    "....#ooooooooooobbb#....",
    "....#oooooooooobbbb#....",
    ".....#ooooooooobbb#.....",
    "......############......",
    "........................",
    "........................",
    "........................",
    "........................",
]

// The dog is the cat's opposite in silhouette: no upright triangles, no
// whiskers. The ears hang outside the head from row 4 to row 12, the snout is
// an outlined box four rows deep, and the tongue drops out of the bottom of it
// onto the chest. The ears are white with a dark rim rather than solid black:
// a black ear beside a black outline disappears entirely on a dark menu bar,
// which is why the cat only ever uses black inside its white silhouette.
// Ears start below the crown so the top-right corner stays clear for the
// sleep mark.
let baseDog = [
    "........................",
    ".......##########.......",
    "......#oooooooooo#......",
    "....###oooooooooo###....",
    "...#op#oooooooooo#po#...",
    "..#oop#oooooooooo#poo#..",
    ".#ooop#oooooooooo#pooo#.",
    ".#ooop#ooeeooeeoo#pooo#.",
    ".#oooo#ooeeooeeoo#oooo#.",
    ".#oooo#oooooooooo#oooo#.",
    ".######oooooooooo######.",
    "......#o########o#......",
    "......#o#onnnno#o#......",
    "......#o#oonnoo#o#......",
    "......#o#oooooo#o#......",
    "......#o#ommmmo#o#......",
    "......#o###pp###o#......",
    "......#ooo#pp#ooo#......",
    "......#bboooooooo#......",
    "......############......",
    "........................",
    "........................",
    "........................",
    "........................",
]

// The bunny is the cat's silhouette taken taller: long upright ears with
// pink inners, and a face that sits two rows lower in the cell than the
// cat's so the hop can spring two pixels up without clipping the ear tips.
// The fluffy ball tail is a rounded bulge flush against the body's lower
// right: the body outline opens for the ball's whole height so the fur is
// one unbroken mass — any dark seam or white neck between two white shapes
// reads as a gap or a stalk, not a tail. It stays below the sleep mark's
// corner, and the hop's peak keeps it inside the cell.
let baseBunny = [
    "........................",
    "........................",
    "........................",
    ".....##........##.......",
    "....#pp#......#pp#......",
    "....#pp#......#pp#......",
    "....#pp#......#pp#......",
    "....#pp#......#pp#......",
    "....#pp#......#pp#......",
    "....#pp########pp#......",
    "....#oooooooooooo#......",
    "....#ooeeooooeeoo#......",
    "....#ooeeooooeeoo#......",
    "....#ooooonnooooo####...",
    "....#oooommmmoooo#ooo#..",
    "....#oooooooooooo#oooo#.",
    "....#oooooooooooo#oooo#.",
    "....#oooooooooooo#oooo#.",
    "....#oooooooooooo#ooo#..",
    ".....#oooooooooo#####...",
    "......##########........",
    "........................",
    "........................",
    "........................",
]

// The bat's body, drawn without wings so the flap can be layered over it. Grey
// rather than white: on a dark menu bar a black bat is a hole, and the outline
// is doing no work there.
let batFlyBody = [
    "........................",
    "........#......#........",
    "........##....##........",
    "........#p#..#p#........",
    "........#pp##pp#........",
    ".......#wppwwppw#.......",
    ".......#wwwwwwww#.......",
    ".......#weewweew#.......",
    ".......#weewweew#.......",
    ".......#wwwnnwww#.......",
    ".......#wwwmmwww#.......",
    ".......###o##o###.......",
    ".........#wwww#.........",
    ".........#wwww#.........",
    ".........#wwww#.........",
    "..........#ww#..........",
    "..........####..........",
    "..........#..#..........",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
]

// One wing each, drawn on the right and mirrored for the left. The three
// together are the flap: raised alongside the ears, spread level with the
// shoulder, swept below the feet.
let batWingUp = [
    "........................",
    "........................",
    "........................",
    "........................",
    ".................####...",
    "................#www#...",
    "................#www#...",
    "................#ww#....",
    "................#ww#....",
    "................#w#.....",
    "................##......",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
]

let batWingMid = [
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "................#######.",
    "................#wwwww#.",
    "................#wwww#..",
    "...............#www#....",
    "...............#w#......",
    "...............##.......",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
]

let batWingDown = [
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "................##......",
    "...............#w#......",
    "...............#ww#.....",
    "...............#ww#.....",
    "...............#www#....",
    "...............#www#....",
    "...............#ww#.....",
    "...............####.....",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
]

// The perch, kept out of the hanging pose so the sway can move the bat without
// dragging the thing it is holding on to.
let batPerch = [
    "........................",
    "....################....",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
]

// Hanging is drawn from scratch, not flipped: the head is at the bottom with
// the ears pointing down, the wings are folded in against the torso, and the
// feet hook up over the perch.
let batHangPose = [
    "........................",
    "........................",
    "..........#..#..........",
    ".........#wwww#.........",
    ".....#####wwww#####.....",
    ".....#www#wwww#www#.....",
    ".....#www#wwww#www#.....",
    ".....#www#wwww#www#.....",
    "......#ww#wwww#ww#......",
    ".......###wwww###.......",
    ".......#wwowwoww#.......",
    ".......#wwwmmwww#.......",
    ".......#wwwnnwww#.......",
    ".......#weewweew#.......",
    ".......#weewweew#.......",
    ".......#wwwwwwww#.......",
    ".......#wppwwppw#.......",
    "........#pp##pp#........",
    "........#p#..#p#........",
    "........##....##........",
    ".........#....#.........",
    "........................",
    "........................",
    "........................",
]

// Asleep: the same grip, with the wings drawn round the body. The seam down the
// middle is the near wing's edge — without it the wrap reads as a sack.
let batWrapped = [
    "........................",
    "........................",
    "..........#..#..........",
    ".......##########.......",
    ".......#wwwwwwww#.......",
    ".......#www#wwww#.......",
    ".......#www#wwww#.......",
    ".......#www#wwww#.......",
    ".......#www#wwww#.......",
    ".......#www#wwww#.......",
    ".......#www#wwww#.......",
    ".......#www#wwww#.......",
    ".......#www#wwww#.......",
    ".......#www#wwww#.......",
    ".......#wwwwwwww#.......",
    "........#wwwwww#........",
    "........#ppwwpp#........",
    "........#pp##pp#........",
    "........#p#..#p#........",
    "........##....##........",
    ".........#....#.........",
    "........................",
    "........................",
    "........................",
]

func color(for character: Character) -> (UInt8, UInt8, UInt8, UInt8)? {
    switch character {
    case "#": return (26, 26, 30, 255)       // near-black outline
    case "o": return (245, 245, 245, 255)    // white fur
    case "b": return (38, 38, 44, 255)       // black patch
    case "e": return (26, 26, 30, 255)       // eye
    case "n": return (232, 140, 150, 255)    // pink nose
    case "p": return (226, 158, 166, 255)    // softer pink inner ear
    case "m": return (26, 26, 30, 255)       // mouth
    case "w": return (140, 140, 150, 255)    // mid-grey whisker: dark enough
                                             // to read on a white window,
                                             // light enough on a dark one
    case "z": return (245, 245, 245, 255)    // sleep mark
    default:  return nil                     // transparent
    }
}

typealias Grid = [[Character]]

func makeGrid(_ lines: [String]) -> Grid {
    // Hand-counted ASCII art is exactly where this file goes wrong, so the
    // dimensions are checked rather than trusted.
    precondition(
        lines.count == artSize,
        "art must have \(artSize) rows, found \(lines.count)"
    )
    for (index, line) in lines.enumerated() {
        precondition(
            line.count == artSize,
            "art row \(index) must be \(artSize) columns, found \(line.count)"
        )
    }
    return lines.map(Array.init)
}

func shift(_ grid: Grid, dx: Int, dy: Int) -> Grid {
    var output = Grid(
        repeating: Array(repeating: Character("."), count: artSize),
        count: artSize
    )
    for y in 0..<artSize {
        for x in 0..<artSize {
            let sourceY = y - dy
            let sourceX = x - dx
            guard sourceY >= 0, sourceY < artSize, sourceX >= 0, sourceX < artSize else {
                continue
            }
            output[y][x] = grid[sourceY][sourceX]
        }
    }
    return output
}

/// Shifts only the rows from `fromRow` down, so a hanging pose can swing from
/// its grip instead of sliding sideways with the thing it is holding.
func shiftBelow(_ grid: Grid, dx: Int, fromRow: Int) -> Grid {
    var output = grid
    for y in fromRow..<artSize {
        var row = Array(repeating: Character("."), count: artSize)
        for x in 0..<artSize {
            let sourceX = x - dx
            guard sourceX >= 0, sourceX < artSize else { continue }
            row[x] = grid[y][sourceX]
        }
        output[y] = row
    }
    return output
}

/// Draws `layer` over `base`, treating transparent cells in the layer as
/// "leave whatever is underneath".
func overlay(_ base: Grid, _ layer: Grid) -> Grid {
    var output = base
    for y in 0..<artSize {
        for x in 0..<artSize where layer[y][x] != "." {
            output[y][x] = layer[y][x]
        }
    }
    return output
}

/// Flips a grid left to right, so one drawn wing can serve as both.
func mirrored(_ grid: Grid) -> Grid {
    grid.map { $0.reversed() }
}

/// Draws a tail as a two-pixel-thick stroke of fur along `spine`, haloed in
/// outline wherever it meets empty space. Two pixels in both directions, not
/// just across: a diagonal drawn one pixel thick is a wire, not a tail.
/// Stamping the tail onto an unmoved body is the whole point — a wag has to be
/// the tail moving, not the dog.
func addTail(_ grid: Grid, spine: [(Int, Int)]) -> Grid {
    var output = grid
    for (x, y) in spine {
        for dy in -1...2 {
            for dx in -1...2 {
                let pixelX = x + dx
                let pixelY = y + dy
                guard pixelY >= 0, pixelY < artSize, pixelX >= 0, pixelX < artSize else {
                    continue
                }
                if output[pixelY][pixelX] == "." {
                    output[pixelY][pixelX] = "#"
                }
            }
        }
    }
    for (x, y) in spine {
        for dy in 0...1 {
            for dx in 0...1 {
                let pixelX = x + dx
                let pixelY = y + dy
                guard pixelY >= 0, pixelY < artSize, pixelX >= 0, pixelX < artSize else {
                    continue
                }
                output[pixelY][pixelX] = "o"
            }
        }
    }
    return output
}

/// Replaces every eye pixel with `replacement`.
func setEyes(_ grid: Grid, to replacement: Character) -> Grid {
    var output = grid
    for y in 0..<artSize {
        for x in 0..<artSize where output[y][x] == "e" {
            output[y][x] = replacement
        }
    }
    return output
}

/// Blanks the eyes into the fur, then draws a contented closed-eye line.
/// The lids are placed per animal: each one's eyes sit somewhere different.
func closedEyes(_ grid: Grid, row: Int, columns: [Int]) -> Grid {
    var output = setEyes(grid, to: "o")
    for x in columns {
        output[row][x] = "#"
    }
    return output
}

/// Draws a small "z" in the clear space to the cat's right. Four rows rather
/// than three: at three the diagonal collapses and it reads as an "I".
func addSleepMark(_ grid: Grid, atHeight y: Int) -> Grid {
    var output = grid
    guard y >= 0, y + 3 < artSize else { return output }
    for x in 20...23 {
        output[y][x] = "z"
        output[y + 3][x] = "z"
    }
    output[y + 1][22] = "z"
    output[y + 2][21] = "z"
    return output
}

/// One sprite sheet: the state rows in the order its manifest declares them.
struct Animal {
    let name: String
    let rows: [[Grid]]
}

// MARK: - Cat

func makeCat() -> Animal {
    let base = makeGrid(baseCat)
    func lidded(_ grid: Grid) -> Grid {
        closedEyes(grid, row: 9, columns: [7, 8, 15, 16])
    }

    // Row 0: idle. A slow bob, blinking on the third frame. Frames 0 and 3 are
    // both the rest pose so the four-frame cycle closes cleanly.
    let idleFrames: [Grid] = [
        base,
        shift(base, dx: 0, dy: 1),
        lidded(shift(base, dx: 0, dy: 1)),
        base,
    ]

    // Row 1: sleep. Eyes shut, with a rising sleep mark.
    let sleepBase = lidded(shift(base, dx: 0, dy: 1))
    let sleepFrames: [Grid] = [
        addSleepMark(sleepBase, atHeight: 4),
        addSleepMark(sleepBase, atHeight: 1),
    ]

    // Row 2: dance. Side to side with a bob. The sway is 1px, not 2: the
    // whisker tips sit one pixel from the cell edge, and a 2px shift clips them
    // off, which reads as whiskers flickering rather than a cat swaying.
    let danceFrames: [Grid] = [
        shift(base, dx: -1, dy: 0),
        shift(base, dx: -1, dy: 1),
        base,
        shift(base, dx: 1, dy: 1),
        shift(base, dx: 1, dy: 0),
        base,
    ]

    return Animal(name: "cat", rows: [idleFrames, sleepFrames, danceFrames])
}

// MARK: - Dog

func makeDog() -> Animal {
    let base = makeGrid(baseDog)
    func lidded(_ grid: Grid, row: Int) -> Grid {
        closedEyes(grid, row: row, columns: [9, 10, 13, 14])
    }

    // Four tail positions, sweeping through five rows of the empty space below
    // and to the right of the dog. The sweep runs downward as well as up: the
    // rows under the body are free, and a short sweep reads as a twitch. The
    // tip stops three columns short of the cell edge so no position clips.
    let tailSweep = [
        [(17, 18), (18, 18), (19, 19), (20, 19)],
        [(17, 18), (18, 18), (19, 18), (20, 18)],
        [(17, 17), (18, 17), (19, 16), (20, 16)],
        [(17, 17), (18, 16), (19, 15), (20, 14)],
    ]
    let resting = addTail(base, spine: tailSweep[2])

    // Row 0: idle. The same bob and blink as the cat.
    let idleFrames: [Grid] = [
        resting,
        shift(resting, dx: 0, dy: 1),
        lidded(shift(resting, dx: 0, dy: 1), row: 8),
        resting,
    ]

    // Row 1: sleep. The dog settles three rows down, which is what clears the
    // top-right corner for the mark: the ears reach into the margin the cat
    // leaves free, so the mark only fits above a lowered head.
    let sleeping = lidded(shift(resting, dx: 0, dy: 3), row: 10)
    let sleepFrames: [Grid] = [
        addSleepMark(sleeping, atHeight: 3),
        addSleepMark(sleeping, atHeight: 1),
    ]

    // Row 2: wag. The body is identical in all six frames; only the tail moves.
    let wagFrames = [0, 1, 2, 3, 2, 1].map { addTail(base, spine: tailSweep[$0]) }

    return Animal(name: "dog", rows: [idleFrames, sleepFrames, wagFrames])
}

// MARK: - Bunny

func makeBunny() -> Animal {
    // Experiment: mid-grey border instead of the near-black outline.
    let base = makeGrid(baseBunny.map { $0.replacingOccurrences(of: "#", with: "w") })
    func lidded(_ grid: Grid) -> Grid {
        closedEyes(grid, row: 12, columns: [7, 8, 13, 14])
    }

    // Row 0: idle. The same bob and blink as the cat.
    let idleFrames: [Grid] = [
        base,
        shift(base, dx: 0, dy: 1),
        lidded(shift(base, dx: 0, dy: 1)),
        base,
    ]

    // Row 1: sleep. Settled one row down, eyes shut, mark rising.
    let sleeping = lidded(shift(base, dx: 0, dy: 1))
    let sleepFrames: [Grid] = [
        addSleepMark(sleeping, atHeight: 4),
        addSleepMark(sleeping, atHeight: 1),
    ]

    // Row 2: hop. Crouch, spring two pixels, land. The peak is why the
    // base art sits low in its cell: the ear tips need the headroom.
    let hopFrames: [Grid] = [
        base,
        shift(base, dx: 0, dy: 1),
        shift(base, dx: 0, dy: -1),
        shift(base, dx: 0, dy: -2),
        shift(base, dx: 0, dy: -1),
        base,
    ]

    return Animal(name: "bunny", rows: [idleFrames, sleepFrames, hopFrames])
}

// MARK: - Bat

func makeBat() -> Animal {
    let flyBody = makeGrid(batFlyBody)
    let wings = [batWingUp, batWingMid, batWingDown].map(makeGrid)
    func flapping(_ wing: Grid) -> Grid {
        overlay(overlay(flyBody, wing), mirrored(wing))
    }

    // Row 0: fly. Up, spread, down, spread — one whole flap per loop, with the
    // body held perfectly still so the wings are unmistakably what is moving.
    let flyFrames = [wings[0], wings[1], wings[2], wings[1]].map(flapping)

    // Row 1: hang. Its own pose, not the flying one turned over. Only the rows
    // below the feet sway, so the bat swings from the perch it is gripping.
    let perch = makeGrid(batPerch)
    let hangPose = makeGrid(batHangPose)
    // Shifted twice from different rows, so the head swings two pixels while
    // the shoulders move one and the grip does not move at all. A single
    // one-pixel shift of the whole body reads as sliding, not swinging.
    let hangFrames = [-1, 0, 1, 0].map { dx in
        let shoulders = shiftBelow(hangPose, dx: dx, fromRow: 4)
        return overlay(shiftBelow(shoulders, dx: dx, fromRow: 12), perch)
    }

    // Row 2: sleep. Same grip, wings drawn round the body, mark rising.
    let wrapped = overlay(makeGrid(batWrapped), perch)
    let sleepFrames: [Grid] = [
        addSleepMark(wrapped, atHeight: 4),
        addSleepMark(wrapped, atHeight: 1),
    ]

    return Animal(name: "bat", rows: [flyFrames, hangFrames, sleepFrames])
}

// MARK: - Writing the sheets

func render(_ animal: Animal, into directory: String) {
    let columns = animal.rows.map(\.count).max() ?? 0
    let width = columns * cellSize
    let height = animal.rows.count * cellSize
    var pixels = [UInt8](repeating: 0, count: width * height * 4)

    for (rowIndex, frames) in animal.rows.enumerated() {
        for (frameIndex, grid) in frames.enumerated() {
            let originX = frameIndex * cellSize
            let originY = rowIndex * cellSize
            for artY in 0..<artSize {
                for artX in 0..<artSize {
                    guard let rgba = color(for: grid[artY][artX]) else { continue }
                    for dy in 0..<pixelScale {
                        for dx in 0..<pixelScale {
                            let x = originX + artX * pixelScale + dx
                            let y = originY + artY * pixelScale + dy
                            let offset = (y * width + x) * 4
                            pixels[offset]     = rgba.0
                            pixels[offset + 1] = rgba.1
                            pixels[offset + 2] = rgba.2
                            pixels[offset + 3] = rgba.3
                        }
                    }
                }
            }
        }
    }

    guard let provider = CGDataProvider(data: Data(pixels) as CFData),
          let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
          )
    else {
        FileHandle.standardError.write(Data("could not build the sprite sheet image\n".utf8))
        exit(1)
    }

    let outputPath = "\(directory)/\(animal.name).png"
    let representation = NSBitmapImageRep(cgImage: cgImage)
    guard let png = representation.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("could not encode PNG\n".utf8))
        exit(1)
    }

    do {
        try png.write(to: URL(fileURLWithPath: outputPath))
        print("wrote \(outputPath) at \(width)x\(height)")
    } catch {
        FileHandle.standardError.write(Data("could not write \(outputPath): \(error)\n".utf8))
        exit(1)
    }
}

let outputDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/animals"

for animal in [makeCat(), makeDog(), makeBunny(), makeBat()] {
    render(animal, into: outputDirectory)
}
