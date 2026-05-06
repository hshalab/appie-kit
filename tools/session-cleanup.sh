#!/bin/bash
# Session Cleanup — Remove stale/orphaned OpenClaw sessions
# Usage: ./session-cleanup.sh [days-threshold]
# Default: cleans sessions older than 7 days

set -e

SESSION_DIR="${HOME}/.openclaw/sessions"
DAYS_THRESHOLD="${1:-7}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "🧹 Session Cleanup Started - $(hostname) - $TIMESTAMP"
echo "   Threshold: ${DAYS_THRESHOLD} days"
echo ""

# Check if session directory exists
if [ ! -d "$SESSION_DIR" ]; then
    echo "   Session directory not found: $SESSION_DIR"
    echo "   Nothing to clean."
    exit 0
fi

# Count total sessions
TOTAL=$(find "$SESSION_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "   Total sessions found: $TOTAL"

if [ "$TOTAL" -eq 0 ]; then
    echo "   No sessions to clean."
    exit 0
fi

# Count stale sessions (older than threshold)
STALE=$(find "$SESSION_DIR" -type f -mtime +"$DAYS_THRESHOLD" 2>/dev/null | wc -l | tr -d ' ')
ACTIVE=$((TOTAL - STALE))

echo "   Active sessions: $ACTIVE"
echo "   Stale sessions (>${DAYS_THRESHOLD}d): $STALE"
echo ""

# Calculate disk usage before cleanup
if [ "$STALE" -gt 0 ]; then
    BEFORE=$(du -sh "$SESSION_DIR" 2>/dev/null | cut -f1)
    echo "   Disk usage before: $BEFORE"

    # Clean stale sessions
    echo ""
    echo "   Cleaning stale sessions..."
    DELETED=0
    while IFS= read -r -d '' session_file; do
        rm -f "$session_file" 2>/dev/null && DELETED=$((DELETED + 1))
    done < <(find "$SESSION_DIR" -type f -mtime +"$DAYS_THRESHOLD" -print0 2>/dev/null)

    AFTER=$(du -sh "$SESSION_DIR" 2>/dev/null | cut -f1)
    echo ""
    echo "   Deleted: $DELETED session(s)"
    echo "   Disk usage after: $AFTER"
    echo "   Active sessions remaining: $((TOTAL - DELETED))"
else
    echo "   Nothing to clean — all sessions are recent."
fi

echo ""
echo "✅ Session cleanup complete"
