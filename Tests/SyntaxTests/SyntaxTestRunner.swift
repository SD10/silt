/// SyntaxTestRunner.swift
///
/// Copyright 2017, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.
import Drill
@testable import Lithosphere
import Crust
import XCTest
import Foundation
import FileCheck
import Rainbow
import Seismography

var stdoutStream = FileHandle.standardOutput

enum Action {
  case describingTokens
  case dumpingParse
  case dumpingShined
}

class SyntaxTestRunner: XCTestCase {
  var engine: DiagnosticEngine!

  override func setUp() {
    Rainbow.enabled = false
    engine = DiagnosticEngine()
    engine.register(XCTestFailureConsumer())
  }

  func testSyntax() {

    let filesURL = URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .appendingPathComponent("Resources")
    let siltFiles: [URL]
    do {
        siltFiles = try
          FileManager.default.contentsOfDirectory(at: filesURL,
            includingPropertiesForKeys: nil)
    } catch {
      XCTFail("Could not read silt files in directory: \(error)")
      return
    }

    for file in siltFiles.filter({ $0.pathExtension == "silt" }) {
      guard let siltFile = try? String(contentsOfFile: file.path,
                                       encoding: .utf8) else {
        XCTFail("Could not read silt file at path \(file.absoluteString)")
        return
      }

      let syntaxFile = file.appendingPathExtension("syntax").path
      if FileManager.default.fileExists(atPath: syntaxFile) {
        XCTAssert(fileCheckOutput(against: .filePath(syntaxFile)) {
          describe(siltFile, at: file.absoluteString, by: .describingTokens)
        }, "failed while dumping syntax file \(syntaxFile)")
      } else {
        print("No corresponding syntax file found at \(syntaxFile)")
      }

      let astFile = file.appendingPathExtension("ast").path
      if FileManager.default.fileExists(atPath: astFile) {
        XCTAssert(fileCheckOutput(against: .filePath(astFile)) {
          describe(siltFile, at: file.absoluteString, by: .dumpingParse)
        }, "failed while dumping AST file \(astFile)")
      } else {
        print("No corresponding syntax file found at \(syntaxFile)")
      }

      if FileManager.default.fileExists(atPath: astFile) {
        let shineFile = file.appendingPathExtension("shined").path
        XCTAssert(fileCheckOutput(against: .filePath(shineFile)) {
          describe(siltFile, at: file.absoluteString, by: .dumpingShined)
        }, "failed while dumping Shined file \(shineFile)")
      } else {
        print("No corresponding syntax file found at \(syntaxFile)")
      }
    }
  }

  func describe(_ input: String, at path: String, by action: Action) {
    let lexer = Lexer(input: input, filePath: path)
    let tokens = lexer.tokenize()
    XCTAssert(tokens.map { $0.sourceText }.joined() == input,
              "Lexed tokens did not faithfully recreate input?")

    let layoutTokens = layout(tokens)
    XCTAssert(layoutTokens.map { $0.sourceText }.joined() == input,
              "Layout affected token stream!?")

    switch action {
    case .dumpingShined:
      for token in layoutTokens {
        token.writeSourceText(to: &stdoutStream, includeImplicit: true)
      }
    case .describingTokens:
      TokenDescriber.describe(tokens, to: &stdoutStream)
    case .dumpingParse:
      let parser = Parser(diagnosticEngine: engine, tokens: layoutTokens)
      guard let tlm = parser.parseTopLevelModule() else {
        XCTFail("Parsing top level module failed!")
        return
      }
      SyntaxDumper(stream: &stdoutStream).dump(tlm)
    }

    XCTAssert(tokens.map { $0.sourceText }.joined() == input)
  }

  #if !os(macOS)
  static var allTests = testCase([
    ("testSyntax", testSyntax),
  ])
  #endif
}
