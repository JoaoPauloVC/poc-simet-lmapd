#!/bin/sh

echo "$(date) - Hello World executado pelo lmapd" >> "$(dirname "$0")/../../logs/hello.log"

