import SwiftSections

typealias Pair = (UInt32, UInt32)

#if canImport(Darwin)
@section("__DATA_CONST,__sect_test") @used private let first: Pair = (1, 2)
@section("__DATA_CONST,__sect_test") @used private let second: Pair = (3, 4)
let testSection = SectionName("__DATA_CONST,__sect_test")
#elseif os(Linux) || os(Android) || os(FreeBSD)
@section("sect_test") @used private let first: Pair = (1, 2)
@section("sect_test") @used private let second: Pair = (3, 4)
let testSection = SectionName("sect_test")
#elseif os(Windows)
@section(".sctst$B") @used private let first: Pair = (1, 2)
@section(".sctst$B") @used private let second: Pair = (3, 4)
let testSection = SectionName(".sctst$B")
#endif

let missingSection = SectionName("__DATA_CONST,__sect_nope")
