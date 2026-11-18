// probe: the executable of the throwaway app `node-local-network --grant` builds.
//
// macOS never asks a command line tool for Local Network access, it just blocks it, but it does
// ask an app. The app is signed with the identifier node carries after `node-local-network`, so
// the permission granted here is the one node gets: macOS keys the decision on that identifier.
//
// Usage: probe HOST PORT RESULT_FILE
// Tries to connect for a minute, long enough to answer the prompt, and writes "ok" or the last
// error to RESULT_FILE. Exit code 0 once connected.

import Darwin

let args = CommandLine.arguments
guard args.count == 4, let port = UInt16(args[2]) else {
    fputs("usage: probe HOST PORT RESULT_FILE\n", stderr)
    exit(64)
}

func report(_ text: String) {
    if let f = fopen(args[3], "w") { fputs(text + "\n", f); fclose(f) }
}

var addr = sockaddr_in()
addr.sin_family = sa_family_t(AF_INET)
addr.sin_port = port.bigEndian
guard inet_pton(AF_INET, args[1], &addr.sin_addr) == 1 else {
    report("not an IPv4 address: \(args[1])")
    exit(64)
}

for _ in 0..<30 {
    let s = socket(AF_INET, SOCK_STREAM, 0)
    let rc = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
    }
    let err = errno
    close(s)
    if rc == 0 { report("ok"); exit(0) }
    report(String(cString: strerror(err)))
    sleep(2)
}
exit(1)
