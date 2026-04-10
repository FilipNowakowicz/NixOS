result=$(curl -sf --max-time 5 "wttr.in/Warsaw?format=%c+%t")
[ -n "$result" ] && echo "$result" || echo "? --"
