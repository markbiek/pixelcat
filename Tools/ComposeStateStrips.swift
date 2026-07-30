// Composes the README's per-animal state strips from the sprite sheets:
// one representative frame per state, scaled 5x nearest-neighbor, side by
// side on a light grey background.
// Run from the repo root: swift Tools/ComposeStateStrips.swift
// Writes docs/images/<animal>-states.png; pass a directory to override.
import AppKit

let cell = 24
let scale = 5
let pad = 10
let gap = 20
let sheetDir = "Resources/animals"
let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "docs/images"

// (animal, [(row, frame, stateName)]) — frame picked to show the state's
// signature look, not just frame 0 (which often matches idle).
let specs: [(String, [(Int, Int, String)])] = [
    ("cat", [(0, 0, "idle"), (1, 0, "sleep"), (2, 0, "dance")]),
    ("dog", [(0, 0, "idle"), (1, 0, "sleep"), (2, 3, "wag")]),
    ("bunny", [(0, 0, "idle"), (1, 0, "sleep"), (2, 3, "hop")]),
    ("bat", [(0, 0, "fly"), (1, 1, "hang"), (2, 0, "sleep")]),
    ("blob", [(0, 0, "idle"), (1, 0, "sleep"), (2, 2, "melt"), (3, 1, "ripple")]),
    ("capybara", [(0, 0, "idle"), (1, 0, "sleep"), (2, 0, "chew")]),
]

func load(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        FileHandle.standardError.write(Data("cannot load \(path)\n".utf8))
        exit(1)
    }
    return image
}

func compose(_ cells: [CGImage], to path: String) {
    let width = pad * 2 + cells.count * cell * scale + (cells.count - 1) * gap
    let height = pad * 2 + cell * scale
    guard let ctx = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { exit(1) }
    ctx.setFillColor(CGColor(red: 211/255, green: 211/255, blue: 211/255, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.interpolationQuality = .none
    for (index, image) in cells.enumerated() {
        let x = pad + index * (cell * scale + gap)
        ctx.draw(image, in: CGRect(x: x, y: pad, width: cell * scale, height: cell * scale))
    }
    guard let composed = ctx.makeImage(),
          let png = NSBitmapImageRep(cgImage: composed)
              .representation(using: .png, properties: [:])
    else { exit(1) }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    } catch {
        FileHandle.standardError.write(Data("could not write \(path): \(error)\n".utf8))
        exit(1)
    }
}

for (animal, states) in specs {
    let sheet = load("\(sheetDir)/\(animal).png")
    let cells = states.map { row, frame, _ in
        guard let cut = sheet.cropping(
            to: CGRect(x: frame * cell, y: row * cell, width: cell, height: cell)
        ) else {
            FileHandle.standardError.write(Data("cell out of range for \(animal)\n".utf8))
            exit(1)
        }
        return cut
    }
    compose(cells, to: "\(outDir)/\(animal)-states.png")
}
