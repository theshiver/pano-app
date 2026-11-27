import Testing

@testable import PanoCore

@Test func parsesValidVersions() {
    #expect(AppVersion("v1.1")?.components == [1, 1])
    #expect(AppVersion("V2.0.1")?.components == [2, 0, 1])
    #expect(AppVersion("1.1.0")?.components == [1, 1, 0])
    #expect(AppVersion("1.10.2")?.components == [1, 10, 2])
    #expect(AppVersion("1.2+build4")?.components == [1, 2])
    #expect(AppVersion(" 1.3.0 \n")?.description == "1.3.0")
}

@Test func equalityAndHashingIgnoreTrailingZeros() {
    let a = AppVersion("v1.1")
    let b = AppVersion("1.1.0")
    let c = AppVersion("1.1.0.0")
    #expect(a != nil)
    #expect(a == b)
    #expect(b == c)
    #expect(a?.hashValue == b?.hashValue)
    #expect(b?.hashValue == c?.hashValue)
}

@Test func orderingFollowsNumericSemver() {
    let ordered = ["1.0", "1.1", "1.1.1", "1.2", "1.10", "2.0"].compactMap(AppVersion.init)
    #expect(ordered.count == 6)
    for index in 0..<(ordered.count - 1) {
        #expect(ordered[index] < ordered[index + 1])
        #expect(!(ordered[index + 1] < ordered[index]))
    }
}

@Test func rejectsInvalidAndPrereleaseVersions() {
    #expect(AppVersion("") == nil)
    #expect(AppVersion("dev") == nil)
    #expect(AppVersion("1.2-beta.1") == nil)
    #expect(AppVersion("1..2") == nil)
    #expect(AppVersion("v") == nil)
    #expect(AppVersion("1.-1") == nil)
    #expect(AppVersion("1.2.") == nil)
}
