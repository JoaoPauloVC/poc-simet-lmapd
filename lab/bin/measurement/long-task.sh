#!/bin/sh

LOG_FILE="$(dirname "$0")/../../logs/long-task.log"

echo "$(date) - START long-task" >> "$LOG_FILE"

sleep 30

echo "$(date) - END long-task" >> "$LOG_FILE"