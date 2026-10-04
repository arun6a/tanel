# Tanel — Terminal Tunnel for Z.ai Code Sandbox

Connect any terminal (Android, Linux, Mac, Windows) to any Z.ai Code sandbox via a polling tunnel. No SSH, no Serveo, no ngrok — just one command.

## How it works

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│  Z.ai Sandbox    │         │  Polling Tunnel   │         │  Your Terminal   │
│  (the "brain")   │         │  (HTTP queue)     │         │  (any device)    │
│                  │         │                    │         │                  │
│  1. Run setup    │         │  3. Command queue  │         │  2. Run poll.cjs │
│     script       │         │     (on sandbox)   │         │     (on device)  │
│                  │         │                    │         │                  │
│  4. Queue cmds   │────────→│  5. Device polls   │←────────│  6. Picks up cmd │
│     via curl     │         │     every 1s       │         │     runs it      │
│                  │         │                    │         │     posts result │
│  7. Read result  │←────────│  8. Result stored  │────────→│                  │
│     via curl     │         │                    │         │                  │
└─────────────────┘         └──────────────────┘         └─────────────────┘
```

## Quick start (2 commands)

### On the Z.ai sandbox (in the chat):
```
curl -sL https://raw.githubusercontent.com/arun6a/tanel/main/setup.sh | bash
```

This adds the command queue endpoints to the sandbox's ai-proxy. It outputs:
```
✅ Tanel is ready!
📋 Run this on your terminal:
   curl -sL https://raw.githubusercontent.com/arun6a/tanel/main/poll.cjs | node
   BASE_URL=https://preview-chat-XXXX.space-z.ai PORT=3030
```

### On your terminal (any device):
```
curl -sL https://raw.githubusercontent.com/arun6a/tanel/main/poll.cjs | BASE_URL=https://preview-chat-XXXX.space-z.ai PORT=3030 node
```

That's it. The sandbox can now run commands on your terminal.

## Sending commands (from the sandbox)

```bash
# Queue a command
curl -s -X POST "http://localhost:3030/api/remote-cmd/queue" \
  -H 'Content-Type: application/json' \
  -d '{"password":"tanel-2024","cmd":"whoami"}'

# Wait 2s, then read the result
sleep 2
curl -s "http://localhost:3030/api/remote-cmd/result"
```

## What you need

| Requirement | Details |
|---|---|
| **Z.ai Code sandbox** | Any active chat — provides the public URL + ai-proxy |
| **Node.js** on your terminal | v18+ (for the poll.cjs client) |
| **`curl`** on your terminal | To download poll.cjs |

## Security

- Password protected: `tanel-2024` (change in setup.sh + poll.cjs)
- Dangerous commands blocked: `rm -rf /`, `mkfs`, `dd if=`, `shutdown`, `reboot`
- 15-second command timeout
- No inbound ports needed on the terminal (only outbound HTTPS)

## Files

| File | Purpose |
|---|---|
| `setup.sh` | Run on the sandbox — adds remote-cmd endpoints to ai-proxy |
| `poll.cjs` | Run on any terminal — polls the sandbox for commands |
| `install.sh` | One-command installer for AndroidIDE/Termux (installs Node.js + starts polling) |

## API Endpoints (on the sandbox ai-proxy, port 3030)

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/remote-cmd/pending` | Terminal polls this for commands |
| POST | `/api/remote-cmd/queue` | Sandbox queues a command |
| POST | `/api/remote-cmd/result` | Terminal posts the result |
| GET | `/api/remote-cmd/result` | Sandbox reads the result |

## License
MIT
