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

@Test func detectsJavaAndSQL() {
    let java = "public class Main {\n  public static void main(String[] args) {\n    System.out.println(1);\n  }\n}"
    #expect(CodeHighlighter.detectLanguage(java) == .java)
    #expect(CodeHighlighter.detectLanguage("SELECT name, id FROM users WHERE active = 1 ORDER BY id") == .sql)
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

@Test func javaGenericsNotMistakenForHTML() {
    let java = """
        @Override
        public Tuple<String, Operator> load(Long userId) {
            if (StringUtils.isNotEmpty(x)) { return new Tuple<>(a, b); }
            return null;
        }
        """
    #expect(CodeHighlighter.detectLanguage(java) == .java)
    #expect(CodeHighlighter.detectLanguage("<!doctype html><html><body><div>hi</div></body></html>") == .html)
}
