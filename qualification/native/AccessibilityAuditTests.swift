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

  private func frame(_ rect: CGRect) -> [String: Double] {
    return ["x": Double(rect.minX), "y": Double(rect.minY),
            "width": Double(rect.width), "height": Double(rect.height)]
  }

  private func issueElement(_ element: XCUIElement?) -> Any {
    guard let element else { return NSNull() }
    return [
      "type": element.elementType.rawValue,
      "identifier": element.identifier,
      "label": element.label,
      "frame": frame(element.frame),
      "debugDescription": element.debugDescription,
    ] as [String: Any]
  }

  private func semantics(_ node: any XCUIElementSnapshot) -> [String: Any] {
    return ["type": node.elementType.rawValue, "identifier": node.identifier, "label": node.label,
            "value": node.value.map { String(describing: $0) } ?? "",
            "enabled": node.isEnabled, "selected": node.isSelected,
            "frame": frame(node.frame),
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
        let field = app.descendants(matching: .any)["native-keyboard-field"]
        if field.waitForExistence(timeout: 5) {
          // The semantic wrapper can be exposed by Flutter as another element
          // type, so query by identifier and make a real native tap before
          // typing. Do not autofocus or synthesize focus in Flutter.
          field.tap()
          if app.keyboards.firstMatch.waitForExistence(timeout: 5) {
            // Send native keystrokes to the responder reached by the tap;
            // Flutter may expose the identifier on a semantic wrapper.
            app.typeText("qualification")
            for _ in 0..<20 {
              if (try? request("state")["input"] as? String) == "qualification" {
                keyboard = true
                break
              }
              Thread.sleep(forTimeInterval: 0.1)
            }
            if !keyboard {
              issues.append(["type": "ERROR", "description": "Native typing did not update Flutter"])
            }
          } else {
            issues.append(["type": "ERROR", "description": "Software keyboard did not appear after tapping the Flutter field"])
          }
        } else {
          issues.append(["type": "ERROR", "description": "Native keyboard field was absent from accessibility semantics"])
        }
      } else {
        if id == "detector-bad" {
          XCTAssertTrue(app.descendants(matching: .any)["native-bad-action"].exists, "Bad Flutter control is absent from native semantics")
        } else {
          XCTAssertGreaterThan(labelCount(try app.snapshot()), 2, "Native audit has no meaningful Flutter labels")
        }
        // Capture every issue and report failure explicitly after recording the case.
        // Returning true here collects results; it never makes findings pass.
        try app.performAccessibilityAudit(for: .all) { issue in
          issues.append([
            "type": "ERROR",
            "auditType": issue.auditType.rawValue,
            "description": issue.compactDescription,
            "detail": issue.detailedDescription,
            "identifier": issue.element?.identifier ?? "",
            "element": issueElement(issue.element),
          ])
          return true
        }
        if id == "detector-bad" { detector = !issues.isEmpty }
      }
      let frameworkErrors = state["frameworkErrors"] as? [String] ?? ["Missing framework error evidence"]
      let passed: Bool
      if id == "detector-bad" {
        passed = detector
      } else if id == "detector-keyboard" {
        passed = keyboard && issues.isEmpty && frameworkErrors.isEmpty
      } else {
        passed = issues.isEmpty && frameworkErrors.isEmpty
      }
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
