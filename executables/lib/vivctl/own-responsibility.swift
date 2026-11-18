// own-responsibility: replace this process with Vivaldi, made responsible for itself.
//
// Usage (by the daemon only):
//   own-responsibility /Applications/Vivaldi.app/Contents/MacOS/Vivaldi --flag ...
//
// macOS decides privacy questions, Local Network access among them, for the "responsible"
// process, and a child inherits its parent's. Started by the daemon, Vivaldi would answer to the
// daemon's node, which macOS may block from the local network while Vivaldi itself is allowed:
// pages on the home network then fail with ERR_ADDRESS_UNREACHABLE and nothing in System
// Settings helps. Disclaiming responsibility makes Vivaldi its own responsible process, so the
// Vivaldi switch under Privacy & Security, Local Network is the one that counts.
//
// POSIX_SPAWN_SETEXEC replaces this process instead of forking: the pid the daemon holds stays
// Vivaldi's, and the CDP pipe on file descriptors 3 and 4 passes through unchanged.
// responsibility_spawnattrs_setdisclaim is undocumented API in libsystem, so a macOS update could
// take it away; the build then fails and the wrapper falls back to starting Vivaldi directly.
// Exit code 127 if the exec fails, as a shell would report it.

import Darwin

@_silgen_name("responsibility_spawnattrs_setdisclaim")
func responsibility_spawnattrs_setdisclaim(_ attrs: UnsafeMutablePointer<posix_spawnattr_t?>, _ disclaim: Int32) -> Int32

let args = Array(CommandLine.arguments.dropFirst())
guard let path = args.first else {
    fputs("usage: own-responsibility PROGRAM [ARGS...]\n", stderr)
    exit(64)
}

var attrs: posix_spawnattr_t?
posix_spawnattr_init(&attrs)
posix_spawnattr_setflags(&attrs, Int16(POSIX_SPAWN_SETEXEC))
if responsibility_spawnattrs_setdisclaim(&attrs, 1) != 0 {
    fputs("own-responsibility: could not disclaim responsibility, starting \(path) anyway\n", stderr)
}

var argv: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) } + [nil]
let rc = posix_spawn(nil, path, nil, &attrs, &argv, environ)
// Only reached when the exec failed.
fputs("own-responsibility: \(path): \(String(cString: strerror(rc)))\n", stderr)
exit(127)
