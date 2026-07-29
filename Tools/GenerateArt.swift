// Generates the placeholder sprite sheet.
// Run: swift Tools/GenerateArt.swift Resources/animals/cat.png
//
// The sheet is 6 columns by 3 rows of 24px cells. Art is authored as a 24x24
// character grid drawn 1:1, so what you read below is exactly what ships.
// On-screen size is cellSize * scale from states.json: 24 * 3 = 72 points.

import AppKit

let cellSize = 24
let artSize = 24
let pixelScale = cellSize / artSize
let columns = 6
let rows = 3

// . transparent   # outline   o white fur   b black patch   p inner ear
// e eye           n nose      m mouth       w whisker       z sleep mark
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
func closedEyes(_ grid: Grid) -> Grid {
    var output = setEyes(grid, to: "o")
    for x in [7, 8, 15, 16] {
        output[9][x] = "#"
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

let base = makeGrid(baseCat)

// Row 0: idle. A slow bob, blinking on the third frame. Frames 0 and 3 are
// both the rest pose so the four-frame cycle closes cleanly.
let idleFrames: [Grid] = [
    base,
    shift(base, dx: 0, dy: 1),
    closedEyes(shift(base, dx: 0, dy: 1)),
    base,
]

// Row 1: sleep. Eyes shut, with a rising sleep mark.
let sleepBase = closedEyes(shift(base, dx: 0, dy: 1))
let sleepFrames: [Grid] = [
    addSleepMark(sleepBase, atHeight: 4),
    addSleepMark(sleepBase, atHeight: 1),
]

// Row 2: dance. Side to side with a bob. The sway is 1px, not 2: the whisker
// tips sit one pixel from the cell edge, and a 2px shift clips them off,
// which reads as whiskers flickering rather than a cat swaying.
let danceFrames: [Grid] = [
    shift(base, dx: -1, dy: 0),
    shift(base, dx: -1, dy: 1),
    base,
    shift(base, dx: 1, dy: 1),
    shift(base, dx: 1, dy: 0),
    base,
]

let sheetRows = [idleFrames, sleepFrames, danceFrames]

let width = columns * cellSize
let height = rows * cellSize
var pixels = [UInt8](repeating: 0, count: width * height * 4)

for (rowIndex, frames) in sheetRows.enumerated() {
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

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/animals/cat.png"

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
