// Flatten a PNG to an opaque RGB PNG (no alpha) over a solid background.
// Headless CoreGraphics — no AppKit run loop required.
// Usage: flatten <in.png> <out.png> <#RRGGBB>
import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 4 else {
    FileHandle.standardError.write("usage: flatten <in> <out> <#RRGGBB>\n".data(using: .utf8)!); exit(1)
}
let inURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])

guard let srcRep = CGImageSourceCreateWithURL(inURL as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(srcRep, 0, nil) else { exit(2) }
let w = img.width, h = img.height

func rgb(_ hex: String) -> (CGFloat, CGFloat, CGFloat) {
    var s = hex; if s.hasPrefix("#") { s.removeFirst() }
    let v = UInt32(s, radix: 16) ?? 0
    return (CGFloat((v>>16)&0xff)/255, CGFloat((v>>8)&0xff)/255, CGFloat(v&0xff)/255)
}
let (r, g, b) = rgb(args[3])

let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
        bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(3) }
ctx.setFillColor(red: r, green: g, blue: b, alpha: 1)
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(4) }
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else { exit(5) }
