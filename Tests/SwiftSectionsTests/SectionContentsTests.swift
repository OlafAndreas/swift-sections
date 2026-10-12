import Testing
import SwiftSections
#if canImport(Darwin)
import Darwin
#endif

@Suite struct SectionContentsTests {

    private func pairs(_ buffers: [UnsafeRawBufferPointer]) -> Set<[UInt32]> {
        var found: Set<[UInt32]> = []
        for buffer in buffers {
            for pair in buffer.bindMemory(to: Pair.self) { found.insert([pair.0, pair.1]) }
        }
        return found
    }

    @Test func findsTheSectionInTheImageThatDefinesIt() {
        let buffers = SectionContents.loaded(testSection)
        #expect(buffers.count == 1, "exactly one image defines the fixture section")
        #expect(buffers.first?.count == 2 * MemoryLayout<Pair>.stride)
        #expect(pairs(buffers) == [[1, 2], [3, 4]])
    }

    @Test func unknownSectionIsEmpty() {
        #expect(SectionContents.loaded(missingSection).isEmpty)
    }

    @Test func observeReplaysLoadedImagesThenStops() {
        final class Sink: @unchecked Sendable { var buffers: [UnsafeRawBufferPointer] = [] }
        let sink = Sink()
        let token = SectionContents.observe(testSection) { sink.buffers.append($0) }
        #expect(pairs(sink.buffers) == [[1, 2], [3, 4]])
        let seen = sink.buffers.count
        #if canImport(Darwin)
        // Loading an unrelated image must not invoke the observer.
        let handle = dlopen("/usr/lib/libz.1.dylib", RTLD_NOW)
        #expect(handle != nil)
        #endif
        #expect(sink.buffers.count == seen)
        token.cancel()
        #expect(sink.buffers.count == seen)
    }

    @Test func namesSplitForMachO() {
        let name = SectionName("__DATA_CONST,__abc")
        #expect(name.description == "__DATA_CONST,__abc")
        #expect(name == SectionName("__DATA_CONST,__abc"))
        #expect(name != SectionName("abc"))
    }
}
