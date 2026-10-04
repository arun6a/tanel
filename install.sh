#!/bin/bash
set -e
echo "=== Tanel Installer ==="
if command -v node &>/dev/null; then
  echo "✅ Node.js: $(node --version)"
else
  echo "📦 Installing Node.js..."
  if command -v pkg &>/dev/null; then pkg install -y nodejs
  elif command -v apt &>/dev/null; then apt update -y && apt install -y nodejs
  else echo "❌ Install Node.js manually"; exit 1; fi
fi
echo "📥 Downloading poll.cjs..."
curl -sL "https://raw.githubusercontent.com/arun6a/tanel/main/poll.cjs" -o ~/poll.cjs
echo "✅ Done. Run: BASE_URL=https://preview-chat-XXXX.space-z.ai PORT=3030 node ~/poll.cjs"
