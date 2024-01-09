#!/bin/bash

CURDIR=$(dirname $0)
[ "$CURDIR" = "." ] && CURDIR=$(pwd)

VMSERVER=${VMSERVER:-http://localhost:8428}

# See https://docs.victoriametrics.com/Single-server-VictoriaMetrics.html#how-to-import-data-in-prometheus-exposition-format

case $1 in 
    sample|s)
        echo "Sample"
        TMPFILE=$(mktemp)
        # Time at 2024-01-01 00:00:00 UTC in ms
        TIME2024JAN1=$(( 1704067200 * 1000 ))
        (
            echo 'sample{benchmark="sample",cni="none",instance="knb2",job="infrabuilder"} 1.0 '$TIME2024JAN1
            echo 'sample{benchmark="sample",cni="none",instance="knb2",job="infrabuilder"} 0.5 '$(( $TIME2024JAN1 + 1000 ))
            echo 'sample{benchmark="sample",cni="none",instance="knb2",job="infrabuilder"} 0.7 '$(( $TIME2024JAN1 + 2000 ))
            echo 'sample{benchmark="sample",cni="none",instance="knb2",job="infrabuilder"} 0.2 '$(( $TIME2024JAN1 + 3000 ))
            echo 'sample{benchmark="sample",cni="none",instance="knb2",job="infrabuilder"} 0.1 '$(( $TIME2024JAN1 + 4000 ))
            echo 'sample{benchmark="sample",cni="none",instance="knb2",job="infrabuilder"} 0.6 '$(( $TIME2024JAN1 + 5000 ))
        ) > $TMPFILE

        curl -v -X POST ${VMSERVER}/api/v1/import/prometheus -T $TMPFILE

        echo "http://localhost:3000/d/cni-bench/cni-benchmark?orgId=1&from=${TIME2024JAN1}&to=$(( $TIME2024JAN1 + 300 * 1000 ))"

        rm $TMPFILE
        ;;

    exomonitor|exo|e)
        curl -v -X POST ${VMSERVER}/api/v1/import/prometheus -T $CURDIR/exomonitor_metrics_sample.txt
        ;;

    *)
        # Check if file exists
        if [ -f "$1" ]; then
            curl -v -X POST ${VMSERVER}/api/v1/import/prometheus -T $1
        else
            echo "File $1 does not exist, cannot import data"
            exit 1
        fi
        ;;
esac
