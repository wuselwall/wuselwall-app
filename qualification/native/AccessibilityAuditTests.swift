import Foundation
import XCTest

// A separate UI-test bundle: never part of Runner's Sources build phase.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
  private let app = XCUIApplication(bundleIdentifier: "ch.goomba.wuselwall")

  private func request(_ path: String, _ body: [String: Any]? = nil) throws -> [String: Any] {
    let completion = expectation(description: path)
    var request = URLRequest(url: URL(string: "http://127.0.0.1:18765/\(path)")!)
    request.timeoutInterval = 5
    if let body {
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }
    var result: Result<[String: Any], Error>?
    URLSession.shared.dataTask(with: request) { data, response, error in
      defer { completion.fulfill() }
      if let error { result = .failure(error); return }
      do {
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              let data, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw NSError(domain: "NativeAudit", code: 1) }
        result = .success(object)
      } catch { result = .failure(error) }
    }.resume()
    wait(for: [completion], timeout: 6)
    return try XCTUnwrap(result).get()
  }

  private func waitForState(ready: Bool) throws -> [String: Any] {
    for _ in 0..<180 {
      if let state = try? request("state"), !ready || state["ready"] as? Bool == true || state["done"] as? Bool == true { return state }
      Thread.sleep(forTimeInterval: 0.5)
    }
    throw NSError(domain: "NativeAuditFixtureTimeout", code: 1)
  }

  private func labelCount(_ node: any XCUIElementSnapshot) -> Int {
    return (node.label.isEmpty ? 0 : 1) + node.children.reduce(0) { $0 + labelCount($1) }
  }

  private func semantics(_ node: any XCUIElementSnapshot) -> [String: Any] {
    return ["type": node.elementType.rawValue, "identifier": node.identifier, "label": node.label,
            "value": node.value.map { String(describing: $0) } ?? "",
            "enabled": node.isEnabled, "selected": node.isSelected,
            "children": node.children.map { semantics($0) }]
  }

  func testAccessibilityForEveryNativeState() throws {
    guard #available(iOS 17.0, *) else {
      XCTFail("Native qualification requires iOS 17+ accessibility audits")
      return
    }
    continueAfterFailure = true
    app.launch()
    _ = try waitForState(ready: false)
    var detector = false
    var keyboard = false
    var cases = 0
    var failures = 0
    while true {
      _ = try request("next", [:])
      let state = try waitForState(ready: true)
      if state["done"] as? Bool == true { break }
      let id = try XCTUnwrap(state["id"] as? String)
      var issues: [[String: Any]] = []
      if id == "detector-keyboard" {
        let field = app.textFields["native-keyboard-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Software keyboard did not appear")
        field.typeText("qualification")
        keyboard = try request("state")["input"] as? String == "qualification"
        if !keyboard { issues.append(["type": "ERROR", "description": "Native typing did not update Flutter"]) }
      } else {
        if id == "detector-bad" {
          XCTAssertTrue(app.descendants(matching: .any)["native-bad-action"].exists, "Bad Flutter control is absent from native semantics")
        } else {
          XCTAssertGreaterThan(labelCount(try app.snapshot()), 2, "Native audit has no meaningful Flutter labels")
        }
        // Capture every issue and report failure explicitly after recording the case.
        // Returning true here collects results; it never makes findings pass.
        try app.performAccessibilityAudit(for: .all) { issue in
          issues.append(["type": "ERROR", "auditType": issue.auditType.rawValue,
                         "description": issue.compactDescription,
                         "detail": issue.detailedDescription,
                         "identifier": issue.element?.identifier ?? ""])
          return true
        }
        if id == "detector-bad" { detector = !issues.isEmpty }
      }
      let frameworkErrors = state["frameworkErrors"] as? [String] ?? ["Missing framework error evidence"]
      let passed = id == "detector-bad" ? detector : issues.isEmpty && frameworkErrors.isEmpty
      _ = try request("result", ["id": id, "platform": "ios", "passed": passed, "issues": issues, "semantics": semantics(try app.snapshot())])
      if !passed { failures += 1 }
      cases += 1
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = id
      attachment.lifetime = .keepAlways
      add(attachment)
    }
    let report = try request("state")
    let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
    attachment.name = "native-audit-report"
    attachment.lifetime = .keepAlways
    add(attachment)
    XCTAssertEqual(cases, report["expected"] as? Int)
    XCTAssertTrue(detector, "Bad control was not rejected by Apple's native auditor")
    XCTAssertTrue(keyboard, "Native keyboard input failed")
    XCTAssertEqual(failures, 0, "Native accessibility/framework findings; see retained case attachments")
  }
}
