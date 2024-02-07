#!/bin/bash

CURDIR=$(dirname $0)
[ "$CURDIR" = "." ] && CURDIR=$(pwd)

[ "$1" = "" ] && echo "Usage: $0 <csi-config>" && echo "Configs :" && ls -1 $CURDIR/csi-configs | sed -e 's/.sh$//' -e 's/^/ - /' && exit 1

CSI=$1
[ ! -f $CURDIR/csi-configs/$CSI.sh ] && echo "CSI config $CNI not found" && exit 1

$CURDIR/csi-configs/$CSI.sh ${@:2}

