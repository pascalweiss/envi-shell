#!/usr/bin/env swift
//
// keychain-touchid.swift — Touch ID–gated master-password storage for bw-run.
//
// macOS-only helper. Stores the Bitwarden master password in the login Keychain
// once, then hands it back only after a successful Touch ID check, so `bw-run`
// can unlock the AI vault without the human re-typing the master password each
// TTL. Runs interpreted (no compiled binary is checked in); needs the Swift
// toolchain (Xcode Command Line Tools). ~1s start, but only once per unlock.
//
//   keychain-touchid.swift store   <account>          # secret read from stdin (raw, no newline added)
//   keychain-touchid.swift get     <account> [timeout] # Touch ID prompt, then prints secret to stdout
//   keychain-touchid.swift delete  <account>          # removes the item
//   keychain-touchid.swift check   <account>          # exit 0 if item exists (no prompt), 1 otherwise
//   keychain-touchid.swift canauth                    # exit 0 if biometrics are available (no prompt)
//
// [timeout] on `get` is optional seconds (float). 0 or omitted = wait forever.
//
// Security model — read this before trusting it. macOS only enforces a biometric
// keychain ACL (kSecAccessControl .biometryAny) for apps signed with an Apple
// Developer Team ID and a keychain-access-groups entitlement. An unsigned CLI
// tool cannot create such items (errSecMissingEntitlement -34018), and ad-hoc
// signing that entitlement gets the process killed. So the item here is an
// ORDINARY login-keychain generic password (accessible WhenUnlockedThisDeviceOnly,
// never synced), and the Touch ID requirement is enforced at the APP level: this
// tool calls LAContext.evaluatePolicy and only reads the item on success. The
// login-keychain ACL still gates other apps (they hit a keychain-password
// prompt), but this is a weaker guarantee than an OS-enforced biometric ACL.
// The dedicated AI-only Bitwarden account keeps the blast radius small either way.
//
// Exit codes: 0 ok, 1 error, 2 usage, 3 user cancelled / auth failed, 4 not found.

import Foundation
import Security
import LocalAuthentication

let SERVICE = "envi-bw-run"

func fail(_ msg: String, _ code: Int32 = 1) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(code)
}

func baseQuery(_ account: String) -> [String: Any] {
    return [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: SERVICE,
        kSecAttrAccount as String: account,
    ]
}

// Show the Touch ID sheet and block until the user responds. Exits (3) on
// cancel/failure; returns only on success. A positive timeout invalidates the
// context (dismissing the sheet) and exits (3) if untouched in time; this is the
// backstop for non-interactive callers. The interactive caller usually kills this
// process on a keypress before the timeout fires.
func requireTouchID(reason: String, timeout: Double) {
    let ctx = LAContext()
    var canErr: NSError?
    guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &canErr) else {
        fail("biometrics unavailable: \(canErr?.localizedDescription ?? "unknown")", 3)
    }
    let sem = DispatchSemaphore(value: 0)
    var ok = false
    var evalErr: Error?
    ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, err in
        ok = success
        evalErr = err
        sem.signal()
    }
    if timeout > 0 {
        if sem.wait(timeout: .now() + timeout) == .timedOut {
            ctx.invalidate()
            fail("timed out waiting for Touch ID", 3)
        }
    } else {
        sem.wait()
    }
    guard ok else {
        if let e = evalErr as NSError?,
           e.code == LAError.userCancel.rawValue || e.code == LAError.appCancel.rawValue || e.code == LAError.systemCancel.rawValue {
            fail("cancelled by user", 3)
        }
        fail("biometric authentication failed: \(evalErr?.localizedDescription ?? "unknown")", 3)
    }
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    fail("usage: keychain-touchid.swift <store|get|delete|check|canauth> [account]", 2)
}
let mode = args[1]

func requireAccount() -> String {
    guard args.count >= 3, !args[2].isEmpty else {
        fail("mode '\(mode)' needs an <account> argument", 2)
    }
    return args[2]
}

switch mode {
case "canauth":
    let ctx = LAContext()
    var e: NSError?
    exit(ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &e) ? 0 : 1)

case "store":
    let account = requireAccount()
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard !data.isEmpty else { fail("store: empty secret on stdin", 2) }

    SecItemDelete(baseQuery(account) as CFDictionary)   // idempotent overwrite
    var attrs = baseQuery(account)
    attrs[kSecValueData as String] = data
    attrs[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    let status = SecItemAdd(attrs as CFDictionary, nil)
    if status != errSecSuccess {
        fail("store: SecItemAdd failed (OSStatus \(status))", 1)
    }

case "get":
    let account = requireAccount()
    let timeout = args.count >= 4 ? (Double(args[3]) ?? 0) : 0
    requireTouchID(reason: "Unlock the Bitwarden AI vault", timeout: timeout)
    var q = baseQuery(account)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var out: CFTypeRef?
    let status = SecItemCopyMatching(q as CFDictionary, &out)
    switch status {
    case errSecSuccess:
        guard let data = out as? Data else { fail("get: unexpected result type", 1) }
        FileHandle.standardOutput.write(data)
    case errSecItemNotFound:
        fail("get: no stored password for \(account)", 4)
    default:
        fail("get: SecItemCopyMatching failed (OSStatus \(status))", 1)
    }

case "delete":
    let account = requireAccount()
    let status = SecItemDelete(baseQuery(account) as CFDictionary)
    if status == errSecSuccess { exit(0) }
    if status == errSecItemNotFound { exit(4) }
    fail("delete: SecItemDelete failed (OSStatus \(status))", 1)

case "check":
    let account = requireAccount()
    var q = baseQuery(account)
    q[kSecReturnData as String] = false
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    let status = SecItemCopyMatching(q as CFDictionary, nil)
    exit(status == errSecSuccess ? 0 : 1)

default:
    fail("unknown mode '\(mode)'", 2)
}
