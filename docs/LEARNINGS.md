# Technical Learnings

Battle-tested patterns, pitfalls, and solutions from running AI agents with OpenClaw.

## Memory Architecture

### The Problem
A single `MEMORY.md` file bloats over time. Long contexts degrade recall quality — the model has to search through irrelevant information to find what matters.

### Solution: 3-Tier Memory System

| Tier | Location | Size | Purpose |
|------|----------|------|---------|
| Hot | `MEMORY.md` | < 200 lines | Index — points to topic files |
| Warm | `memory/topics/*.md` | Unlimited | Detailed notes on specific topics |
| Cold | Vector DB (Pinecone, etc.) | Unlimited | Semantic search over all content |

**Rules:**
- `MEMORY.md` is an **index only** — it lists topics with brief descriptions and pointers
- Topic files hold the actual detail (one file per subject)
- Read topic files **on demand** (JIT), not all upfront
- **Pre-compaction flush** is critical — before context gets compacted, flush important state to files

### Pre-Compaction Protocol
1. Review all pending tasks and decisions
2. Write anything important to `memory/YYYY-MM-DD.md` or topic files
3. Update `MEMORY.md` index if new topics were created
4. Only then allow context compaction

---

## Deployment Patterns

### API Deploy vs Webhook
- **API deploy** is more reliable than webhook — webhooks may cache old code
- Use a `deploy.sh` script for guaranteed fresh deploys
- GitHub webhook works for auto-deploy, but verify after deploy

### Vercel
- **Encrypted env vars corrupt JWT tokens** — always use plain type environment variables
- After changing env vars, redeploy (they don't hot-reload)

### General
- Always verify deployment succeeded by checking the live endpoint
- Keep a rollback plan ready before deploying

---

## SSH / Networking

### Tailscale
- Use Tailscale for all remote access — no public SSH ports
- Tailscale IPs are stable and don't change
- Works through NAT without port forwarding

### SSH Keys
- Always use SSH keys, disable password authentication
- Key permissions: `chmod 600 ~/.ssh/id_*` and `chmod 700 ~/.ssh`
- Use `~/.ssh/config` for host aliases

### Node.js on Remote
- `nvm` doesn't need `sudo` for Node.js installation
- Install nvm per-user, not system-wide

---

## Voice (TTS / STT)

### Piper TTS — Local Text-to-Speech
```bash
echo "Hello world" | /path/to/piper-tts/tts.sh > output.wav
```
- Fast, offline, no API needed
- Good enough for notifications and simple speech

### Faster-Whisper — Local Speech-to-Text
```bash
/path/to/faster-whisper/transcribe.sh /path/to/audio.ogg
```
- Processes audio in 3-4 seconds locally
- Supports multiple languages
- No cloud dependency

---

## Task Execution Pitfalls

### Multiple Projects Active
- **ALWAYS ask which project** before assuming context
- State the project name in your first response to confirm
- Keep project contexts separate (different workspace dirs)

### Chained Tool Calls
- Chained tool calls don't allow easy user interruption
- Break large tasks into confirmable chunks
- Checkpoint after the first major file write
- Let the user see progress before continuing

### Large Changes
- Outline the plan first for multi-file changes
- Write one file, confirm, then proceed to the next
- Don't batch 10+ file writes without checkpoints

---

## Security Patterns

### Gateway Security
- Gateway **MUST** bind to `127.0.0.1` or Tailscale IP only
- **Never** bind to `0.0.0.0` (publicly accessible)
- Regularly audit with `security-scan.sh`

### File Permissions
- `.env` files: always `chmod 600`
- SSH keys: always `chmod 600` (private) and `chmod 644` (public)
- Config files with secrets: `chmod 600`

### Safe Deletion
- `trash` > `rm` — always prefer recoverable deletion
- When in doubt, don't delete — archive instead

### Secret Management
- No secrets in code or chat, ever
- Use `.env` files (gitignored) for secrets
- Rotate credentials if exposed
- Scan git history if a secret was accidentally committed

---

## Multi-Agent / Fleet Management

### Architecture
- **Orchestrator** assigns, coordinates, and reviews
- **Workers** execute tasks and report back
- All intel flows up to the orchestrator

### Rate Limits
- Use separate rate limit buckets for each agent (different model tiers)
- A cheaper model for VPS-based agents keeps costs manageable
- Heartbeat frequency: 1 hour with cheaper model for worker agents

### Context Size
- Context size kills VPS performance
- Keep workspace files (SOUL.md, AGENTS.md, etc.) under 15KB total
- Load files JIT, not all upfront

### Networking
- SSH restricted to Tailscale only, no public ports
- Each agent gets its own Telegram bot
- Shared brain via GitHub repo (synced periodically)

### Communication
- Worker agents report status to orchestrator
- Orchestrator consolidates and presents unified view
- Don't duplicate work across agents

---

## i18n / Translation System Pattern

### Content Structure
```javascript
const content = {
  title: { nl: 'Welkom', en: 'Welcome' },
  description: { nl: 'Beschrijving', en: 'Description' }
};
```

### React Provider/Hook Pattern
```jsx
// Provider wraps the app
<LanguageProvider>
  <App />
</LanguageProvider>

// Hook consumes in components
const { t, language, setLanguage } = useLanguage();
```

### Auto-Detection
1. Check `localStorage` for saved preference
2. Fall back to `navigator.language`
3. Default to primary language if no match
4. Save selection to `localStorage` for persistence

---

## Rate Limits & API Patterns

### Known Limits
| Service | Limit | Notes |
|---------|-------|-------|
| Airtable | 5 req/sec | Batch writes, serialize bursts |
| Brevo | 300 emails/day | Free plan limit |
| OpenAI | Varies by tier | Check dashboard for current limits |

### Best Practices
- **Batch API writes** when possible — fewer requests, more reliable
- **Serialize bursts** — don't fire 20 requests simultaneously
- **Respect 429 / Retry-After** headers — back off when told
- **Queue-based approach** for high-volume operations
- Log rate limit hits for monitoring

### Error Handling
- Always handle rate limit errors gracefully
- Implement exponential backoff for retries
- Circuit breaker pattern for repeated failures
