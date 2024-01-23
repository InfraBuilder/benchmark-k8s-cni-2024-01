#!/bin/bash

[ "$1" = "" ] && echo "Usage: $0 user@host" && exit 1

SSH_HOST=$1

CURDIR=$(dirname $0)
[ "$CURDIR" = "." ] && CURDIR=$(pwd)

QSSH="ssh -A -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"



case $2 in
    tuned)
        echo "Preparing host $SSH_HOST with tuned settings"
        cat $CURDIR/21-os-prepare-ubuntu.sh | $QSSH ${SSH_HOST} sudo bash
        cat $CURDIR/22-system-tuning.sh | $QSSH ${SSH_HOST} sudo bash
        ;;
    *)
        echo "Preparing host $SSH_HOST with default settings"
        cat $CURDIR/21-os-prepare-ubuntu.sh | $QSSH ${SSH_HOST} sudo bash
        ;;
esac

