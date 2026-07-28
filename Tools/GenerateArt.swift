// Generates the placeholder sprite sheet.
// Run: swift Tools/GenerateArt.swift Resources/cat.png
//
// The sheet is 6 columns by 3 rows of 32px cells. Art is authored as a 16x16
// character grid and scaled 2x, which keeps the source readable.

import AppKit

let cellSize = 32
let artSize = 16
let pixelScale = cellSize / artSize
let columns = 6
let rows = 3

// . transparent   # outline   o body   e eye   z sleep mark
let baseCat = [
    "................",
    "..##........##..",
    "..#o#......#o#..",
    "..#oo#....#oo#..",
    "..#ooo####ooo#..",
    ".#oooooooooooo#.",
    ".#ooeeooooeeoo#.",
    ".#ooeeooooeeoo#.",
    ".#oooooooooooo#.",
    ".#oooo####oooo#.",
    ".#ooo#oooo#ooo#.",
    "..#oooooooooo#..",
    "..#oooooooooo#.#",
    "...#oooooooo#.#.",
    "...##########...",
    "................",
]

func color(for character: Character) -> (UInt8, UInt8, UInt8, UInt8)? {
    switch character {
    case "#": return (74, 44, 26, 255)      // dark brown outline
    case "o": return (232, 152, 61, 255)    // orange body
    case "e": return (46, 122, 74, 255)     // green eye
    case "z": return (250, 250, 250, 255)   // sleep mark
    default:  return nil                    // transparent
    }
}

typealias Grid = [[Character]]

func makeGrid(_ rows: [String]) -> Grid {
    rows.map(Array.init)
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

/// Replaces the eye pixels. Passing "o" closes the eyes into the body;
/// passing "#" draws a closed-eye line.
func setEyes(_ grid: Grid, to replacement: Character) -> Grid {
    var output = grid
    for y in 0..<artSize {
        for x in 0..<artSize where output[y][x] == "e" {
            output[y][x] = replacement
        }
    }
    return output
}

func closedEyes(_ grid: Grid) -> Grid {
    // Blank both eye rows, then draw a line across the lower one.
    var output = setEyes(grid, to: "o")
    for x in [4, 5, 10, 11] {
        output[7][x] = "#"
    }
    return output
}

func addSleepMark(_ grid: Grid, atHeight y: Int) -> Grid {
    var output = grid
    guard y >= 0, y + 2 < artSize else { return output }
    for x in 12...14 {
        output[y][x] = "z"
        output[y + 2][x] = "z"
    }
    output[y + 1][13] = "z"
    return output
}

let base = makeGrid(baseCat)

// Row 0: idle. A slow bob, with a blink on frame 2.
let idleFrames: [Grid] = [
    base,
    shift(base, dx: 0, dy: 1),
    closedEyes(shift(base, dx: 0, dy: 1)),
    base,
]

// Row 1: sleep. Eyes shut, with a rising sleep mark.
let sleepBase = closedEyes(shift(base, dx: 0, dy: 1))
let sleepFrames: [Grid] = [
    addSleepMark(sleepBase, atHeight: 3),
    addSleepMark(sleepBase, atHeight: 1),
]

// Row 2: dance. Side to side with a bob.
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
    : "Resources/cat.png"

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
