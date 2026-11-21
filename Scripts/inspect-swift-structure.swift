import Foundation
import SwiftParser
import SwiftSyntax

final class Inventory: SyntaxVisitor {
    var declarations: [[String: Any]] = []
    private func record(_ node: some DeclSyntaxProtocol, name: String, inheritance: InheritanceClauseSyntax?) {
        let parents = sequence(first: node.parent, next: { $0?.parent }).compactMap { $0 }
        let nested = parents.contains { $0.is(StructDeclSyntax.self) || $0.is(ClassDeclSyntax.self) || $0.is(EnumDeclSyntax.self) || $0.is(ExtensionDeclSyntax.self) }
        declarations.append(["name": name, "start": node.position.utf8Offset, "end": node.endPosition.utf8Offset,
                             "bodyStart": node.positionAfterSkippingLeadingTrivia.utf8Offset,
                             "inheritance": inheritance?.inheritedTypes.map { $0.type.trimmedDescription } ?? [], "nested": nested])
    }
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node, name: node.name.text, inheritance: node.inheritanceClause); return .visitChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node, name: node.name.text, inheritance: node.inheritanceClause); return .visitChildren
    }
}
var files: [[String: Any]] = []
for path in CommandLine.arguments.dropFirst() {
    let source = try String(contentsOfFile: path, encoding: .utf8)
    let tree = Parser.parse(source: source)
    let visitor = Inventory(viewMode: .sourceAccurate)
    visitor.walk(tree)
    let imports = tree.statements.compactMap { $0.item.as(ImportDeclSyntax.self)?.trimmedDescription }
    files.append(["path": path, "declarations": visitor.declarations, "imports": imports, "syntaxErrors": tree.hasError])
}
let output = try JSONSerialization.data(withJSONObject: files, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(output)
