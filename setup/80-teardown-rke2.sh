#!/bin/bash

[ "$1" = "" ] && echo "Usage: $0 <sshuser@ip>" && exit 1

QSSH="ssh -A -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
CURDIR=$(dirname $0)
[ "$CURDIR" = "." ] && CURDIR=$(pwd)

$QSSH $1 sudo rke2-uninstall.sh