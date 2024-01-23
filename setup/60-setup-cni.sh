#!/bin/bash

CURDIR=$(dirname $0)
[ "$CURDIR" = "." ] && CURDIR=$(pwd)

[ "$1" = "" ] && echo "Usage: $0 <cni-config>" && echo "Configs :" && ls -1 $CURDIR/cni-configs | sed -e 's/.sh$//' -e 's/^/ - /' && exit 1

CNI=$1
[ ! -f $CURDIR/cni-configs/$CNI.sh ] && echo "CNI config $CNI not found" && exit 1

$CURDIR/cni-configs/$CNI.sh ${@:2}

