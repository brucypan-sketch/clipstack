import Foundation

var failures = 0
var passes = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if condition {
        passes += 1
        print("ok   - \(message)")
    } else {
        failures += 1
        print("FAIL - \(message) (line \(line))")
    }
}

func finish() -> Never {
    if failures > 0 {
        print("\(failures) FAILURES, \(passes) passed")
        exit(1)
    }
    print("ALL PASSED (\(passes) checks)")
    exit(0)
}
