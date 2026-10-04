#!/bin/bash
# ============================================================================
#  Tanel Setup Script — run this on the Z.ai Code sandbox
#  Adds remote terminal command queue endpoints to the ai-proxy (port 3030)
# ============================================================================
set -e

AI_PROXY="/home/z/my-project/mini-services/ai-proxy/server.js"
PASSWORD="tanel-2024"

echo "=== Tanel Setup ==="
echo ""

# 1. Check if ai-proxy exists
if [ ! -f "$AI_PROXY" ]; then
  echo "❌ ai-proxy not found at $AI_PROXY"
  echo "   Make sure you're running this in a Z.ai Code sandbox."
  exit 1
fi

# 2. Check if tanel is already installed
if grep -q "remote-cmd" "$AI_PROXY" 2>/dev/null; then
  echo "⚠️  Tanel is already installed on this sandbox."
else
  # 3. Add the command queue variables + endpoints
  # We need to insert:
  #   a) Queue variables after the CORS/json/html helpers
  #   b) Endpoints before the 404 response

  # Create a patch file
  cat > /tmp/tanel-patch.js << 'PATCH'
// ---- Tanel: remote terminal command queue ----
const cmdQueue=[];
let lastResult={result:null};
PATCH

  # Insert queue variables after 'const html=' line
  sed -i "/^const html=/a\\
$(cat /tmp/tanel-patch.js)" "$AI_PROXY"

  # Insert endpoints before the 404 return
  cat > /tmp/tanel-endpoints.js << 'ENDPOINTS'
  // ---- Tanel: remote terminal endpoints ----
  if(m==='GET'&&pathname==='/api/remote-cmd/pending'){ const cmd=cmdQueue.shift(); return json({cmd:cmd||null}); }
  if(m==='POST'&&pathname==='/api/remote-cmd/queue'){ try{ const b=await readJson(req); if(b?.password!=='tanel-2024')return json({error:'Unauthorized'},401); if(b?.cmd){ cmdQueue.push(b.cmd); return json({success:true,queued:cmdQueue.length}); } return json({error:'Missing cmd'},400); }catch(e){ return json({error:e.message},500); } }
  if(m==='POST'&&pathname==='/api/remote-cmd/result'){ try{ const b=await readJson(req); lastResult=b; return json({success:true}); }catch(e){ return json({error:e.message},500); } }
  if(m==='GET'&&pathname==='/api/remote-cmd/result'){ return json(lastResult||{result:null}); }
ENDPOINTS

  # Find the 404 return line and insert before it
  sed -i "/return json({success:false,error:'Not found'/i\\
$(cat /tmp/tanel-endpoints.js)" "$AI_PROXY"

  # Also update the availableEndpoints list
  sed -i "s/'POST \/api\/tts'/'POST \/api\/tts','GET \/api\/remote-cmd\/pending','POST \/api\/remote-cmd\/queue','POST \/api\/remote-cmd\/result','GET \/api\/remote-cmd\/result'/g" "$AI_PROXY"

  # Also add ZAI_TOKEN if missing
  sed -i "s/if(c.apiKey)process.env.ZAI_API_KEY=c.apiKey;/if(c.apiKey)process.env.ZAI_API_KEY=c.apiKey; if(c.token)process.env.ZAI_TOKEN=c.token; if(c.userId)process.env.ZAI_USER_ID=c.userId;/" "$AI_PROXY"

  echo "✅ Endpoints added to ai-proxy"
fi

# 4. Restart the ai-proxy
echo "🔄 Restarting ai-proxy..."
pkill -f "supervise-ai-proxy" 2>/dev/null || true
pkill -f "bun server.js" 2>/dev/null || true
sleep 2

( setsid nohup bash /home/z/my-project/.zscripts/supervise-ai-proxy.sh </dev/null >>/home/z/my-project/ai-proxy.log 2>&1 & )
sleep 5

# 5. Verify it's running
if curl -s http://localhost:3030/health | grep -q "ok" 2>/dev/null; then
  echo "✅ ai-proxy is running on port 3030"
else
  echo "❌ ai-proxy failed to start. Check /home/z/my-project/ai-proxy.log"
  exit 1
fi

# 6. Derive the external URL
# Try to read it from the chat_id in the environment or config
CONFIG="/etc/.z-ai-config"
if [ -f "$CONFIG" ]; then
  CHAT_ID=$(python3 -c "import json;print(json.load(open('$CONFIG')).get('chatId',''))" 2>/dev/null || echo "")
  if [ -n "$CHAT_ID" ]; then
    # Strip "chat-" prefix
    CHAT_ID=$(echo "$CHAT_ID" | sed 's/^chat-//')
    BASE_URL="https://preview-chat-${CHAT_ID}.space-z.ai"
  fi
fi

if [ -z "$BASE_URL" ]; then
  echo ""
  echo "⚠️  Could not auto-detect the external URL."
  echo "   Find your sandbox URL (https://preview-chat-XXXX.space-z.ai)"
  echo "   and tell the user to use that as BASE_URL."
  BASE_URL="https://preview-chat-YOUR_CHAT_ID.space-z.ai"
fi

# 7. Test the endpoints
echo "🧪 Testing endpoints..."
RESULT=$(curl -s -X POST "http://localhost:3030/api/remote-cmd/queue" \
  -H 'Content-Type: application/json' \
  -d '{"password":"tanel-2024","cmd":"echo tanel_test_123"}' 2>/dev/null)

if echo "$RESULT" | grep -q "success" 2>/dev/null; then
  echo "✅ Queue endpoint works!"
else
  echo "❌ Queue endpoint failed: $RESULT"
fi

# 8. Print the connection command for the user
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ Tanel is ready!                                          ║"
echo "║                                                              ║"
echo "║  📋 Run this on your terminal (any device with Node.js):     ║"
echo "║                                                              ║"
echo "║  curl -sL https://raw.githubusercontent.com/arun6a/tanel/main/poll.cjs \\  ║"
echo "║    | BASE_URL=$BASE_URL PORT=3030 node                       ║"
echo "║                                                              ║"
echo "║  Then the sandbox can run commands on your terminal!         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "💡 To send a command from the sandbox:"
echo "   curl -s -X POST http://localhost:3030/api/remote-cmd/queue \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"password\":\"tanel-2024\",\"cmd\":\"whoami\"}'"
echo ""
echo "   sleep 2"
echo ""
echo "   curl -s http://localhost:3030/api/remote-cmd/result"
