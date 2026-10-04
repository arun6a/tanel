const https = require('https');
const { execSync } = require('child_process');

// Read config from environment or args
const BASE_URL = process.env.BASE_URL || process.argv[2] || '';
const PORT = process.env.PORT || '3030';
const PASSWORD = process.env.PASSWORD || 'tanel-2024';

if (!BASE_URL) {
  console.error('❌ Missing BASE_URL');
  console.error('');
  console.error('Usage:');
  console.error('  curl -sL https://raw.githubusercontent.com/arun6a/tanel/main/poll.cjs \\');
  console.error('    | BASE_URL=https://preview-chat-XXXX.space-z.ai PORT=3030 node');
  console.error('');
  console.error('Or:');
  console.error('  node poll.cjs https://preview-chat-XXXX.space-z.ai 3030');
  process.exit(1);
}

// Extract hostname from URL
let hostname = BASE_URL;
if (hostname.startsWith('https://')) hostname = hostname.slice(8);
if (hostname.startsWith('http://')) hostname = hostname.slice(7);
hostname = hostname.replace(/\/+$/, '');

function log(msg, type) {
  const ts = new Date().toLocaleTimeString();
  const icons = { cmd: '>>', ok: 'OK', err: 'XX', info: 'ii', post: '>>', wait: '..', warn: '!!' };
  const colors = { cmd: '\x1b[36m', ok: '\x1b[32m', err: '\x1b[31m', info: '\x1b[34m', post: '\x1b[35m', wait: '\x1b[90m', warn: '\x1b[33m' };
  const reset = '\x1b[0m';
  const icon = icons[type] || '--';
  const color = colors[type] || '';
  console.log(color + '[' + ts + '] ' + icon + ' ' + msg + reset);
}

function poll() {
  const path = '/api/remote-cmd/pending?XTransformPort=' + PORT;
  https.get({ hostname: hostname, path: path, method: 'GET' }, (res) => {
    let body = '';
    res.on('data', c => body += c);
    res.on('end', () => {
      try {
        const d = JSON.parse(body);
        if (d.cmd) {
          log(d.cmd.slice(0, 100), 'cmd');
          let output = '';
          let success = true;
          try {
            // Block dangerous commands
            const blocked = ['rm -rf /', 'mkfs', 'dd if=', 'shutdown', 'reboot', 'init 0'];
            for (const bl of blocked) {
              if (d.cmd.includes(bl)) { output = 'BLOCKED: dangerous command'; success = false; break; }
            }
            if (success) {
              output = execSync(d.cmd, { timeout: 15000, encoding: 'utf-8', cwd: process.env.HOME || process.cwd() });
            }
          } catch (e) {
            output = e.stdout || e.stderr || e.message;
            success = false;
          }

          // Print output line by line
          var lines = output.split('\n').filter(function(l) { return l.trim(); });
          if (lines.length === 0) {
            log('(no output)', 'wait');
          } else {
            for (var i = 0; i < lines.length; i++) {
              log(lines[i].slice(0, 200), success ? 'ok' : 'err');
            }
          }

          // Post result back
          var postData = JSON.stringify({ cmd: d.cmd, result: output, success: success });
          var req = https.request({
            hostname: hostname,
            path: '/api/remote-cmd/result?XTransformPort=' + PORT,
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(postData) }
          }, function() {
            log('result posted to sandbox', 'post');
          });
          req.on('error', function(e) { log('POST failed: ' + e.message, 'err'); });
          req.write(postData);
          req.end();
        }
      } catch (e) {
        log('parse error: ' + e.message, 'err');
      }
      setTimeout(poll, 1000);
    });
  }).on('error', function(e) {
    log('sandbox unreachable, retrying in 3s...', 'warn');
    setTimeout(poll, 3000);
  });
}

// Clear screen + show banner
process.stdout.write('\x1b[2J\x1b[H');
console.log('\x1b[1m\x1b[36m=========================================');
console.log('  Tanel - Terminal Tunnel');
console.log('  Connected to: ' + hostname);
console.log('  Polling every 1 second');
console.log('=========================================\x1b[0m');
console.log('');
log('Ready. Waiting for commands from sandbox...', 'info');
console.log('');
poll();
