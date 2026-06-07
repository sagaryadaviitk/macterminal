import AppKit

extension NSColor {
    convenience init?(hex: String) {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("#"), value.count == 7 else {
            return nil
        }

        let scanner = Scanner(string: String(value.dropFirst()))
        var number: UInt64 = 0
        guard scanner.scanHexInt64(&number) else {
            return nil
        }

        self.init(
            calibratedRed: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255,
            alpha: 1
        )
    }
}
