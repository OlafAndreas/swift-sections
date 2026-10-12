/// A custom section, named exactly as in the `@section` attribute for the current object format.
///
///     #if canImport(Darwin)
///     let handlers = SectionName("__DATA_CONST,__swift5_hndlr")
///     #else
///     let handlers = SectionName("swift5_hndlr")
///     #endif
///
/// The name is split and null-terminated once, here, so that nothing on the enumeration
/// path allocates or builds a `String`. Mach-O segment and section names are limited to
/// 16 bytes each; a longer name is a silent empty section, so it traps in debug builds.
public struct SectionName: Sendable, Hashable {
    /// The full name, null-terminated.
    let cName: [CChar]
    /// Mach-O segment, null-terminated. Empty on other formats.
    let segment: [CChar]
    /// Mach-O section, null-terminated. Equal to `cName` on other formats.
    let section: [CChar]

    public init(_ name: StaticString) {
        let bytes: [UInt8] = name.withUTF8Buffer { Array($0) }
        cName = bytes.map { CChar(bitPattern: $0) } + [0]
        if let comma = bytes.firstIndex(of: UInt8(ascii: ",")) {
            segment = bytes[..<comma].map { CChar(bitPattern: $0) } + [0]
            section = bytes[(comma + 1)...].map { CChar(bitPattern: $0) } + [0]
            assert(segment.count <= 17 && section.count <= 17, "Mach-O segment and section names are limited to 16 bytes")
        } else {
            segment = [0]
            section = cName
        }
    }

    /// The name as written.
    public var description: String { String(decoding: cName.dropLast().map { UInt8(bitPattern: $0) }, as: UTF8.self) }
}
