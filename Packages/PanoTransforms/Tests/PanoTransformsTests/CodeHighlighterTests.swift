import Testing

@testable import PanoTransforms

@Test func detectsCommonLanguages() {
    #expect(CodeHighlighter.detectLanguage("func greet() { let x = 1; return }") == .swift)
    #expect(CodeHighlighter.detectLanguage("const x = 1;\nfunction f() => console.log(x)") == .javascript)
    #expect(CodeHighlighter.detectLanguage("def f(x):\n    print(x)\n    return x") == .python)
    #expect(CodeHighlighter.detectLanguage("{\"a\": 1, \"b\": [2,3]}") == .json)
    #expect(CodeHighlighter.detectLanguage("<div class=\"x\">hi</div>") == .html)
    #expect(CodeHighlighter.detectLanguage("just some prose, nothing to see") == nil)
}

@Test func highlightsSwiftKeywordsStringsComments() {
    let code = "func f() { let s = \"hi\" // note\n return 42 }"
    let spans = CodeHighlighter.spans(for: code, language: .swift)
    let kinds = Set(spans.map(\.kind))
    #expect(kinds.contains(.keyword))  // func / let / return
    #expect(kinds.contains(.string))  // "hi"
    #expect(kinds.contains(.comment))  // // note
    #expect(kinds.contains(.number))  // 42

    // The keyword inside the string/comment must not be separately highlighted (no overlaps).
    let sorted = spans.sorted { $0.start < $1.start }
    for (a, b) in zip(sorted, sorted.dropFirst()) {
        #expect(a.start + a.length <= b.start)
    }
}

@Test func commentSwallowsKeywords() {
    let code = "// func let return\ncode"
    let spans = CodeHighlighter.spans(for: code, language: .swift)
    // The whole comment line is one comment span; no keyword spans inside it.
    #expect(spans.contains { $0.kind == .comment })
    #expect(!spans.contains { $0.kind == .keyword })
}

@Test func detectsJavaAndSQL() {
    let java = "public class Main {\n  public static void main(String[] args) {\n    System.out.println(1);\n  }\n}"
    #expect(CodeHighlighter.detectLanguage(java) == .java)

    let sql = "SELECT name, id FROM users WHERE active = 1 ORDER BY id"
    #expect(CodeHighlighter.detectLanguage(sql) == .sql)
    // SQL keywords highlight regardless of case.
    let spans = CodeHighlighter.spans(for: "select * from t where x = 1", language: .sql)
    #expect(spans.contains { $0.kind == .keyword })
}

@Test func detectsJavaAnnotationStyleController() {
    let java = """
        @GET
        @Path("/user/{userId}")
        @ReturnType(MobileAuth.class)
        public Response loadMobileAuthByUserId(@PathParam("userId") Long userId) {
            return new Response(service.load(userId));
        }
        """
    #expect(CodeHighlighter.detectLanguage(java) == .java)
}
