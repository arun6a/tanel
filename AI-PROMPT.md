# Tanel — AI Prompt for new Z.ai Code sandbox

Paste this as your first message:

I want to set up Tanel — a terminal tunnel that lets me run commands on my terminal from this sandbox.

STEP 1 — Run: curl -sL https://raw.githubusercontent.com/arun6a/tanel/main/setup.sh | bash

STEP 2 — Give me the connection command it outputs (I'll run it on my terminal)

STEP 3 — After I run it, test: curl -s -X POST http://localhost:3030/api/remote-cmd/queue -H 'Content-Type: application/json' -d '{"password":"tanel-2024","cmd":"whoami"}' && sleep 2 && curl -s http://localhost:3030/api/remote-cmd/result

STEP 4 — You now have remote terminal access. Send commands via the queue + read results.
