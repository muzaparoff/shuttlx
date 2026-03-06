#!/bin/bash
# .claude/hooks/sync-docs.sh
# PostToolUse hook: reminds Claude to keep docs in sync after code changes
#
# This hook fires after every Edit/Write tool call on Swift files.
# It outputs a reminder to Claude's context so it doesn't forget
# to update CLAUDE.md, memory files, and rules when making changes.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only trigger for Swift files in the ShuttlX project
if [[ ! "$FILE_PATH" =~ \.swift$ ]]; then
  exit 0
fi

# Count how many Swift files changed in this session (approximate via git)
CHANGED=$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && git diff --name-only 2>/dev/null | grep '\.swift$' | wc -l | tr -d ' ')

# If multiple files changed, remind about docs
if [[ "$CHANGED" -gt 3 ]]; then
  echo "reminder: $CHANGED Swift files modified — remember to update CLAUDE.md, memory files, and .claude/rules/ if architecture changed" >&2
fi

exit 0
