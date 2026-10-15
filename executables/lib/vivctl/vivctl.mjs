#!/usr/bin/env node
// vivctl: manage Vivaldi tabs and tab stacks from the command line.
//
// The entry point. Two roles, chosen by the first argument:
//   daemon     starts Vivaldi on a private CDP pipe and serves a fixed set of
//              operations on a unix socket (started for you by `vivctl start`)
//   <anything> a client: sends one request to the daemon and prints the answer
//
// Why a daemon: Vivaldi's tab stacks are only reachable through its private UI
// APIs (vivaldi.tabsPrivate), which exist inside the browser's own UI page. The
// only way in from outside is the Chrome DevTools Protocol. The pipe variant of
// it (--remote-debugging-pipe) opens no network port at all: only the process
// that spawned the browser holds the two file descriptors. So the daemon is the
// sole holder, and everything else gets the whitelist below, never raw CDP.
// See README.md in this directory for the threat model.
//
// The code is split by responsibility:
//   common.mjs        configuration, errors, input validation, the socket request
//   client.mjs        the command line, `start` and `init`
//   daemon.mjs        starts Vivaldi on the pipe and serves the socket
//   lock.mjs          the Touch ID lock and its lease
//   ops.mjs           the whitelist of operations
//   browser.mjs       CDP over the pipe, calls into Vivaldi's UI pages
//   pages.mjs         the web page behind a tab, and verified input
//   ui-scripts.mjs    code that runs in Vivaldi's UI page
//   page-scripts.mjs  code that runs in web pages

import {UserError} from './common.mjs';
import {client} from './client.mjs';
import {daemon} from './daemon.mjs';

const [cmd, ...rest] = process.argv.slice(2);
try {
  cmd === 'daemon' ? await daemon() : await client(cmd, rest);
} catch (e) {
  console.error(`vivctl: ${e instanceof UserError ? e.message : e.stack || e.message}`);
  process.exit(1);
}
