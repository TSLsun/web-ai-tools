#!/bin/bash
PLIST="$HOME/Library/LaunchAgents/com.tslsun.newssummarizer.plist"
LOG="/tmp/newssummarizer.log"
ERR="/tmp/newssummarizer.error.log"

cmd="${1:-status}"

case "$cmd" in
  start)
    launchctl load "$PLIST" && echo "started" ;;
  stop)
    launchctl unload "$PLIST" && echo "stopped" ;;
  restart)
    launchctl unload "$PLIST" 2>/dev/null; launchctl load "$PLIST" && echo "restarted" ;;
  status)
    if lsof -i :8765 -sTCP:LISTEN -t &>/dev/null; then
      echo "running (port 8765)"
    else
      echo "stopped"
    fi ;;
  log)
    tail -f "$LOG" ;;
  err)
    tail -f "$ERR" ;;
  *)
    echo "usage: $0 {start|stop|restart|status|log|err}" ;;
esac
