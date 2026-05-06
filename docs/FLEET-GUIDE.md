# Fleet Guide

A guide for running multi-agent setups with OpenClaw.

## Architecture Overview

### Orchestrator + Workers Model

```
                    ┌──────────────┐
                    │ Orchestrator │
                    │  (Appie-1)   │
                    └──────┬───────┘
                           │ assigns, reviews, consolidates
              ┌────────────┼────────────┐
              │            │            │
        ┌─────┴─────┐ ┌───┴────┐ ┌────┴─────┐
        │  Worker 1  │ │Worker 2│ │ Worker 3  │
        │ (CMO/Herald)│ │ (CTO)  │ │  (CFO)   │
        └───────────┘ └────────┘ └──────────┘
```

**Roles:**
- **Orchestrator** — assigns tasks, reviews output, consolidates intel, handles user-facing communication
- **Workers** — execute specific tasks, report results back up

**Benefits:**
- Separation of concerns — each agent has a clear role
- Cost optimization — workers use cheaper models
- Fault isolation — one agent crashing doesn't take down the fleet

---

## Communication Over Tailscale

### Why Tailscale
- No public SSH ports — security by default
- Stable IPs — agents always reachable at the same address
- Works through NAT — no port forwarding needed
- WireGuard-encrypted — all traffic is secured

### Setup
1. Install Tailscale on all machines (Mac, VPS, etc.)
2. Authenticate each device to your Tailscale network
3. Use Tailscale IPs (100.x.x.x) for all inter-agent communication
4. Set up SSH config aliases for convenience:

```
Host worker-1
    HostName 100.x.x.x
    User root
    IdentityFile ~/.ssh/id_ed25519

Host worker-2
    HostName 100.x.x.x
    User root
    IdentityFile ~/.ssh/id_ed25519
```

---

## Shared Brain Pattern

### GitHub Repo as Shared Memory

A shared GitHub repo serves as the "brain" — a common reference point for all agents.

**What to include:**
- `SOUL.md` — personality and behavior (synced across all agents)
- `IDENTITY.md` — fleet roster, IPs, roles
- `MEMORY.md` — shared long-term memory index
- `AGENTS.md` — operational protocols

**Sync protocol:**
1. Orchestrator pushes updates to the shared brain repo
2. Workers pull before each session (or on heartbeat)
3. Workers push their learnings back after significant tasks
4. Orchestrator reviews and consolidates worker contributions

### Per-Agent Workspace
Each agent also has its own local workspace for:
- Agent-specific configuration
- Local memory files
- Task-specific state
- Client-specific context (if applicable)

---

## Rate Limit Management

### Model Tiers by Agent Role

| Agent Role | Model Tier | Heartbeat Model | Rationale |
|------------|-----------|-----------------|-----------|
| Orchestrator | High (Opus, GPT-4) | — | Direct user interaction, needs quality |
| CMO/Herald | Medium (Sonnet) | Low (Haiku) | Content creation, periodic checks |
| CTO/DevOps | Medium (Sonnet) | Low (Haiku) | Code tasks, infrastructure |
| CFO/Analytics | Low (Haiku) | Low (Haiku) | Data processing, reports |

### Separate Rate Limit Buckets
- Each agent uses a different API key or model → separate rate limit buckets
- This prevents one agent's heavy usage from throttling others
- Monitor usage per agent to balance load

### Heartbeat Frequency
- **Orchestrator:** User-driven (no autonomous heartbeat)
- **Workers:** 1 hour interval with cheapest model
- Heartbeats are for checking status, not heavy work

---

## Context Size Optimization

### The Problem
Large workspace files (SOUL.md, AGENTS.md, etc.) consume context window space. On VPS agents with limited resources, this directly impacts performance and cost.

### Rules
- Keep workspace files under **15KB total** for VPS agents
- `SOUL.md`: < 3KB (personality, not full biography)
- `AGENTS.md`: < 5KB (protocols, not documentation)
- `MEMORY.md`: < 3KB (index only, not full memory)
- `TOOLS.md`: < 4KB (reference, not manuals)

### Strategies
1. **Strip to essentials** — each file should be the minimum viable version
2. **No redundant information** — if it's in SOUL.md, don't repeat it in AGENTS.md
3. **Use references** — "see docs/LEARNINGS.md for details" instead of inlining
4. **Archive resolved items** — don't keep old tasks in active files
5. **Separate by concern** — client data stays in client-specific files, not shared workspace

---

## Security

### SSH
- SSH keys only — disable password authentication
- Restrict SSH to Tailscale IPs only — no public ports
- Use `AllowUsers` in sshd_config to limit access
- Rotate keys periodically

### Environment Variables
- `.env` files: `chmod 600` always
- Never commit `.env` to git (`.gitignore` them)
- Different `.env` per agent — don't share secrets across fleet
- If a secret is exposed, rotate immediately

### Gateway
- Bind to `127.0.0.1` or Tailscale IP — **never** `0.0.0.0`
- Use `security-scan.sh` to audit regularly
- Monitor access logs for unexpected connections

### General
- `trash` > `rm` (recoverable beats permanent)
- No secrets in code, chat, or shared brain repo
- Audit git history if a secret was accidentally committed

---

## Health Monitoring

### Per-Agent Health Checks
Run `health-check.sh` on each agent to verify:
- OpenClaw gateway is running
- Telegram bot is responsive
- System resources (disk, memory, CPU)
- Tailscale connectivity

### Fleet-Wide Monitoring
The orchestrator can check worker health via:
```bash
# SSH to each worker and run health check
ssh worker-1 'bash ~/health-check.sh'
ssh worker-2 'bash ~/health-check.sh'
```

### Alerting
- Workers should report failures in their Telegram bot
- Orchestrator consolidates alerts for the user
- Critical failures (gateway down, disk full) trigger immediate notification

### Recommended Monitoring Schedule
| Check | Frequency | Who |
|-------|-----------|-----|
| Gateway status | Every heartbeat | Each agent |
| Disk space | Daily | Each agent |
| Security scan | Daily | Orchestrator |
| Session cleanup | Weekly | Each agent |
| SSH key audit | Monthly | Orchestrator |
