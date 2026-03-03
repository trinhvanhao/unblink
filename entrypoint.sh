#!/bin/sh
mkdir -p /data/unblink
chown -R appuser:appuser /data/unblink

# Drop to appuser and run the command
exec gosu appuser "$@"
