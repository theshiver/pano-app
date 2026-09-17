import PanoStore
import Testing

@testable import PanoCore

@Test func detectsRealStripeSecretKey() {
    #expect(SensitiveScanner.classify("sk_live_51H8xExampleKey1234567890abcdef") == .secret)
    #expect(SensitiveScanner.classify("ghp_16CharsOfTokenABCDEFGHIJ1234567890") == .secret)
    #expect(SensitiveScanner.classify("AKIAIOSFODNN7EXAMPLE") == .secret)
}

@Test func doesNotFlagProseThatStartsLikeAKey() {
    #expect(SensitiveScanner.classify("sk- means secret key in our docs") == .none)
    #expect(SensitiveScanner.classify("The AKIA prefix identifies an access key") == .none)
}

@Test func detectsRealJWT() {
    // A standard HS256 example token (jwt.io); header {"alg":"HS256","typ":"JWT"}.
    let jwt =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        + ".eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ"
        + ".SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    #expect(SensitiveScanner.classify(jwt) == .secret)
}

@Test func rejectsThreeDottedWordsThatAreNotJWT() {
    #expect(SensitiveScanner.classify("one.two.three") == .none)
    #expect(SensitiveScanner.classify("www.example.com") == .none)
}

@Test func detectsLuhnValidCard() {
    #expect(SensitiveScanner.classify("4242 4242 4242 4242") == .financial)  // Stripe test Visa
    #expect(SensitiveScanner.classify("5555555555554444") == .financial)  // Mastercard test
}

@Test func rejectsSixteenDigitsThatFailLuhn() {
    #expect(SensitiveScanner.classify("1234567812345678") == .none)
}

@Test func detectsValidIBAN() {
    #expect(SensitiveScanner.classify("DE89 3704 0044 0532 0130 00") == .financial)
    #expect(SensitiveScanner.classify("TR330006100519786457841326") == .financial)
}

@Test func rejectsIBANWithBadChecksum() {
    #expect(SensitiveScanner.classify("DE89 3704 0044 0532 0130 01") == .none)
}

@Test func plainTextIsNotSensitive() {
    #expect(SensitiveScanner.classify("just some copied text") == .none)
    #expect(SensitiveScanner.classify(nil) == .none)
    #expect(SensitiveScanner.classify("") == .none)
}
