// touchid: ask macOS for the owner's Touch ID (password as the fallback).
//
// Exit code 0 means the owner authenticated. Anything else means access stays
// closed: 1 refused or cancelled, 2 no authentication possible on this Mac,
// 3 nobody answered in time. The reason is written to stderr.
//
//   touchid ["reason shown in the sheet"]
//
// VIVCTL_AUTH_TIMEOUT (seconds, default 60) bounds how long the sheet waits.

import Foundation
import LocalAuthentication

let reason = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Authenticate"
let timeout = Double(ProcessInfo.processInfo.environment["VIVCTL_AUTH_TIMEOUT"] ?? "") ?? 60

let context = LAContext()
var probe: NSError?
guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &probe) else {
    FileHandle.standardError.write(Data("cannot authenticate on this Mac: \(probe?.localizedDescription ?? "unknown reason")\n".utf8))
    exit(2)
}

let done = DispatchSemaphore(value: 0)
var granted = false
var failure = "refused"
context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
    granted = success
    if let error = error { failure = error.localizedDescription }
    done.signal()
}

if done.wait(timeout: .now() + timeout) == .timedOut {
    context.invalidate()
    FileHandle.standardError.write(Data("no answer within \(Int(timeout)) seconds\n".utf8))
    exit(3)
}
if !granted {
    FileHandle.standardError.write(Data("\(failure)\n".utf8))
    exit(1)
}
exit(0)
