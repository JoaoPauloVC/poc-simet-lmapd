#!/bin/sh

echo "$(date) - Hello World executado pelo lmapd" >> "$(dirname "$0")/../../hello.log"

