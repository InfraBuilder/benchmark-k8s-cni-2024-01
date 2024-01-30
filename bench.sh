#!/bin/bash

CURDIR=$(dirname $0)
[ "$CURDIR" = "." ] && CURDIR=$(pwd)

cd $CURDIR

export KUBECONFIG=$CURDIR/setup/59-kubeconfig.yaml

BENCHID=""
RUNID=""
OUTPUTDIR=""

CMDA1=""
CMDA2=""
CMDA3=""

DIRECT_A1=""
DIRECT_A2=""
DIRECT_A3=""

SVC_A1=""
SVC_A2=""
SVC_A3=""

TEST_DURATION=60
DELAY_METRICS=10

BENCHMARK_NUMBER_OF_RUNS=${BENCHMARK_NUMBER_OF_RUNS:-3}

function statexec {
    echo "statexec -f $1 -d ${DELAY_METRICS} -l id=$BENCHID -l run=$RUNID -i $TEST -mst 1704067200000"
}

function prefix {
    echo "[${BENCHID}][${RUNID}][${TEST}] $(date "+%Y-%m-%d %H:%M:%S")"
}

function log { echo "$(prefix) $@"; }

function test_prepare {
    TEST="prepare"
    OUTPUTDIR="./results/$BENCHID/$RUNID"

    log start
    [ -e $OUTPUTDIR ] && rm -rf $OUTPUTDIR
    mkdir -p $OUTPUTDIR

    if [ "${BENCHID:0:3}" = "st_" ]
    then
        ./maas.sh init-tuned > /dev/null 2>&1
    else
        ./maas.sh init > /dev/null 2>&1
    fi

    sleep 60

    log end
}

function test_setup {
    TEST="setup"
    
    log start RKE2
    ./maas.sh rke2-up > /dev/null 2>&1
    log end RKE2

    log start CNI

    if [ "${BENCHID:0:3}" = "st_" ]
    then
        ./maas.sh cni ${BENCHID:3} > /dev/null 2>&1
    else
        ./maas.sh cni ${BENCHID} > /dev/null 2>&1
    fi

    sleep 60
    
    log end CNI
}

function servercmd {
    filename="${TEST}-server"

    NUMABIND=""
    #[ "${BENCHID:0:3}" = "st_" ] && NUMABIND="numactl --cpunodebind=netdev:enp129s0f0 --membind=netdev:enp129s0f0"
    [ "${BENCHID:0:3}" = "st_" ] && NUMABIND="numactl --cpunodebind=1 --membind=1"

    echo "$CMDA2 $(statexec ${filename}.prom) -s -- $NUMABIND $@" > $OUTPUTDIR/${filename}.cmd

    $CMDA2 \
        $(statexec ${filename}.prom) -s -- \
        $NUMABIND $@ \
        > $OUTPUTDIR/${filename}.stdout \
        2> $OUTPUTDIR/${filename}.stderr

    $CMDA2 \
        cat ${filename}.prom \
        > $OUTPUTDIR/${filename}.prom \
        2>/dev/null
}
function clientcmd {
    filename="${TEST}-client"

    NUMABIND=""
    # numactl --cpunodebind 1 -s sleep 1
    #[ "${BENCHID:0:3}" = "st_" ] && NUMABIND="numactl --cpunodebind=netdev:enp129s0f0 --membind=netdev:enp129s0f0"
    [ "${BENCHID:0:3}" = "st_" ] && NUMABIND="numactl --cpunodebind=1 --membind=1"

    echo "$CMDA3 $(statexec ${filename}.prom) -dbc $(( ${DELAY_METRICS} + 1 ))  -c $DIRECT_A2 -- $NUMABIND $@" > $OUTPUTDIR/${filename}.cmd

    $CMDA3 \
        $(statexec ${filename}.prom) -dbc $(( ${DELAY_METRICS} + 1 ))  -c $DIRECT_A2 -- \
        $NUMABIND $@ \
        > $OUTPUTDIR/${filename}.stdout \
        2> $OUTPUTDIR/${filename}.stderr

    $CMDA3 \
        cat ${filename}.prom \
        > $OUTPUTDIR/${filename}.prom \
        2>/dev/null
}

function extract_metrics {
    PREFIX=$1

    CLIENT_SYSTEM=$(grep -E '^statexec_summary_cpu_mean_seconds{.*mode="system"' $OUTPUTDIR/${TEST}-client.prom | awk '{print $2}')
    CLIENT_USER=$(grep -E '^statexec_summary_cpu_mean_seconds{.*mode="user"' $OUTPUTDIR/${TEST}-client.prom | awk '{print $2}')
    CLIENT_MEM=$(grep -E '^statexec_summary_memory_used_bytes{' $OUTPUTDIR/${TEST}-client.prom | awk '{print $2}')
    
    SERVER_SYSTEM=$(grep -E '^statexec_summary_cpu_mean_seconds{.*mode="system"' $OUTPUTDIR/${TEST}-server.prom | awk '{print $2}')
    SERVER_USER=$(grep -E '^statexec_summary_cpu_mean_seconds{.*mode="user"' $OUTPUTDIR/${TEST}-server.prom | awk '{print $2}')
    SERVER_MEM=$(grep -E '^statexec_summary_memory_used_bytes{' $OUTPUTDIR/${TEST}-server.prom | awk '{print $2}')

    echo "${PREFIX}_CLIENT_SYSTEM=$CLIENT_SYSTEM"
    echo "${PREFIX}_CLIENT_USER=$CLIENT_USER"
    echo "${PREFIX}_CLIENT_MEM=$CLIENT_MEM"
    echo "${PREFIX}_SERVER_SYSTEM=$SERVER_SYSTEM"
    echo "${PREFIX}_SERVER_USER=$SERVER_USER"
    echo "${PREFIX}_SERVER_MEM=$SERVER_MEM"

}

function test_info {
    TEST="info"

    log start
    $CMDA2 ip a > $OUTPUTDIR/${TEST}-server.interfaces
    $CMDA2 uname -a > $OUTPUTDIR/${TEST}-server.uname
    $CMDA3 ip a > $OUTPUTDIR/${TEST}-client.interfaces
    $CMDA3 uname -a > $OUTPUTDIR/${TEST}-client.uname
    $CURDIR/assets/test-netpol.sh > $OUTPUTDIR/${TEST}-netpol
    log end

}

function test_idle {
    TEST="idle"

    log start
    servercmd sleep $TEST_DURATION &
    WAITPID=$!
    sleep 1
    clientcmd sleep $TEST_DURATION
    wait $WAITPID

    extract_metrics IDLE > $OUTPUTDIR/${TEST}.results

    log end
}

# Direct TCP Single Stream
function test_dts {
    TEST="dts"

    log start
    servercmd iperf3 -s &
    WAITPID=$!
    sleep 1
    clientcmd iperf3 -c $DIRECT_A2 -O 1 -Z -t $TEST_DURATION --dont-fragment --json
    wait $WAITPID


    # Extract results
    DTS_BW=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.bits_per_second')
    DTS_RTS=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_sent.retransmits')

    extract_metrics DTS > $OUTPUTDIR/${TEST}.results
    echo "DTS_BW=$DTS_BW" >> $OUTPUTDIR/${TEST}.results
    echo "DTS_RTS=$DTS_RTS" >> $OUTPUTDIR/${TEST}.results
    
    log end
}

# Direct TCP Multi Stream
function test_dtm {
    TEST="dtm"

    log start
    servercmd iperf3 -s &
    WAITPID=$!
    sleep 1
    clientcmd iperf3 -c $DIRECT_A2 -O 1 -P 8 -Z -t $TEST_DURATION --dont-fragment --json
    wait $WAITPID

    # Extract results
    DTM_BW=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.bits_per_second')
    DTM_RTS=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_sent.retransmits')

    extract_metrics DTM > $OUTPUTDIR/${TEST}.results
    echo "DTM_BW=$DTM_BW" >> $OUTPUTDIR/${TEST}.results
    echo "DTM_RTS=$DTM_RTS" >> $OUTPUTDIR/${TEST}.results

    log end
}

# Direct UDP Single Stream
function test_dus {
    TEST="dus"

    log start
    servercmd iperf3 -s &
    WAITPID=$!
    sleep 1
    clientcmd iperf3 -c $DIRECT_A2 -O 1 -u -b 0 -Z -t $TEST_DURATION --json
    wait $WAITPID

    # Extract results
    DUS_BW=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.bits_per_second')
    DUS_JITTER=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.jitter_ms')
    DUS_LOST=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.lost_percent')

    extract_metrics DUS > $OUTPUTDIR/${TEST}.results
    echo "DUS_BW=$DUS_BW" >> $OUTPUTDIR/${TEST}.results
    echo "DUS_JITTER=$DUS_JITTER" >> $OUTPUTDIR/${TEST}.results
    echo "DUS_LOST=$DUS_LOST" >> $OUTPUTDIR/${TEST}.results

    log end
}

# Direct UDP Multi Stream
function test_dum {
    TEST="dum"

    log start
    servercmd iperf3 -s &
    WAITPID=$!
    sleep 1
    clientcmd iperf3 -c $DIRECT_A2 -O 1 -u -b 0 -P 8 -Z -t $TEST_DURATION --json
    wait $WAITPID

    # Extract results
    DUM_BW=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.bits_per_second')
    DUM_JITTER=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.jitter_ms')
    DUM_LOST=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.lost_percent')

    extract_metrics DUM > $OUTPUTDIR/${TEST}.results
    echo "DUM_BW=$DUM_BW" >> $OUTPUTDIR/${TEST}.results
    echo "DUM_JITTER=$DUM_JITTER" >> $OUTPUTDIR/${TEST}.results
    echo "DUM_LOST=$DUM_LOST" >> $OUTPUTDIR/${TEST}.results

    log end
}

# Service TCP Single Stream
function test_sts {
    TEST="sts"

    log start
    servercmd iperf3 -s &
    WAITPID=$!
    sleep 1
    clientcmd iperf3 -c $SVC_A2 -O 1 -Z -t $TEST_DURATION --dont-fragment --json
    wait $WAITPID

    # Extract results
    STS_BW=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.bits_per_second')
    STS_RTS=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_sent.retransmits')

    extract_metrics STS > $OUTPUTDIR/${TEST}.results
    echo "STS_BW=$STS_BW" >> $OUTPUTDIR/${TEST}.results
    echo "STS_RTS=$STS_RTS" >> $OUTPUTDIR/${TEST}.results

    log end
}

# Service TCP Multi Stream
function test_stm {
    TEST="stm"

    log start
    servercmd iperf3 -s &
    WAITPID=$!
    sleep 1
    clientcmd iperf3 -c $SVC_A2 -O 1 -P 8 -Z -t $TEST_DURATION --dont-fragment --json
    wait $WAITPID

    # Extract results
    STM_BW=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.bits_per_second')
    STM_RTS=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_sent.retransmits')

    extract_metrics STM > $OUTPUTDIR/${TEST}.results
    echo "STM_BW=$STM_BW" >> $OUTPUTDIR/${TEST}.results
    echo "STM_RTS=$STM_RTS" >> $OUTPUTDIR/${TEST}.results

    log end
}

# Service UDP Single Stream
function test_sus {
    TEST="sus"

    log start
    servercmd iperf3 -s &
    WAITPID=$!
    sleep 1
    clientcmd iperf3 -c $SVC_A2 -O 1 -u -b 0 -Z -t $TEST_DURATION --json
    wait $WAITPID

    # Extract results
    SUS_BW=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.bits_per_second')
    SUS_JITTER=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.jitter_ms')
    SUS_LOST=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.lost_percent')

    extract_metrics SUS > $OUTPUTDIR/${TEST}.results
    echo "SUS_BW=$SUS_BW" >> $OUTPUTDIR/${TEST}.results
    echo "SUS_JITTER=$SUS_JITTER" >> $OUTPUTDIR/${TEST}.results
    echo "SUS_LOST=$SUS_LOST" >> $OUTPUTDIR/${TEST}.results

    log end
}

# Service UDP Multi Stream
function test_sum {
    TEST="sum"

    log start
    servercmd iperf3 -s &
    WAITPID=$!
    sleep 1
    clientcmd iperf3 -c $SVC_A2 -O 1 -u -b 0 -P 8 -Z -t $TEST_DURATION --json
    wait $WAITPID

    # Extract results
    SUM_BW=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.bits_per_second')
    SUM_JITTER=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.jitter_ms')
    SUM_LOST=$(cat $OUTPUTDIR/${TEST}-client.stdout | jq -r '.end.sum_received.lost_percent')

    extract_metrics SUM > $OUTPUTDIR/${TEST}.results
    echo "SUM_BW=$SUM_BW" >> $OUTPUTDIR/${TEST}.results
    echo "SUM_JITTER=$SUM_JITTER" >> $OUTPUTDIR/${TEST}.results
    echo "SUM_LOST=$SUM_LOST" >> $OUTPUTDIR/${TEST}.results

    log end
}

function test_cleanup {
    TEST="cleanup"

    log start
    ./maas.sh cleanup > /dev/null 2>&1
    sleep 10
    log end
}

function reset_result_vars {
    unset IDLE_CLIENT_SYSTEM IDLE_CLIENT_USER IDLE_CLIENT_MEM IDLE_SERVER_SYSTEM IDLE_SERVER_USER IDLE_SERVER_MEM
    unset DTS_CLIENT_SYSTEM DTS_CLIENT_USER DTS_CLIENT_MEM DTS_SERVER_SYSTEM DTS_SERVER_USER DTS_SERVER_MEM DTS_BW DTS_RTS 
    unset DTM_CLIENT_SYSTEM DTM_CLIENT_USER DTM_CLIENT_MEM DTM_SERVER_SYSTEM DTM_SERVER_USER DTM_SERVER_MEM DTM_BW DTM_RTS
    unset DUS_CLIENT_SYSTEM DUS_CLIENT_USER DUS_CLIENT_MEM DUS_SERVER_SYSTEM DUS_SERVER_USER DUS_SERVER_MEM DUS_BW DUS_JITTER DUS_LOST
    unset DUM_CLIENT_SYSTEM DUM_CLIENT_USER DUM_CLIENT_MEM DUM_SERVER_SYSTEM DUM_SERVER_USER DUM_SERVER_MEM DUM_BW DUM_JITTER DUM_LOST
    unset STS_CLIENT_SYSTEM STS_CLIENT_USER STS_CLIENT_MEM STS_SERVER_SYSTEM STS_SERVER_USER STS_SERVER_MEM STS_BW STS_RTS
    unset STM_CLIENT_SYSTEM STM_CLIENT_USER STM_CLIENT_MEM STM_SERVER_SYSTEM STM_SERVER_USER STM_SERVER_MEM STM_BW STM_RTS
    unset SUS_CLIENT_SYSTEM SUS_CLIENT_USER SUS_CLIENT_MEM SUS_SERVER_SYSTEM SUS_SERVER_USER SUS_SERVER_MEM SUS_BW SUS_JITTER SUS_LOST
    unset SUM_CLIENT_SYSTEM SUM_CLIENT_USER SUM_CLIENT_MEM SUM_SERVER_SYSTEM SUM_SERVER_USER SUM_SERVER_MEM SUM_BW SUM_JITTER SUM_LOST
}

function compute_results {
    # Compute results
    RUNS=$(cd ./results/$BENCHID; ls -1 |grep -E "^[0-9]+$")
    for i in $RUNS
    do
        reset_result_vars
        source ./results/$BENCHID/$i/all.results

        (
            echo -en "$IDLE_CLIENT_SYSTEM\t$IDLE_CLIENT_USER\t$IDLE_CLIENT_MEM\t$IDLE_SERVER_SYSTEM\t$IDLE_SERVER_USER\t$IDLE_SERVER_MEM\t"
            echo -en "$DTS_CLIENT_SYSTEM\t$DTS_CLIENT_USER\t$DTS_CLIENT_MEM\t$DTS_SERVER_SYSTEM\t$DTS_SERVER_USER\t$DTS_SERVER_MEM\t$DTS_BW\t$DTS_RTS\t"
            echo -en "$DTM_CLIENT_SYSTEM\t$DTM_CLIENT_USER\t$DTM_CLIENT_MEM\t$DTM_SERVER_SYSTEM\t$DTM_SERVER_USER\t$DTM_SERVER_MEM\t$DTM_BW\t$DTM_RTS\t"
            echo -en "$DUS_CLIENT_SYSTEM\t$DUS_CLIENT_USER\t$DUS_CLIENT_MEM\t$DUS_SERVER_SYSTEM\t$DUS_SERVER_USER\t$DUS_SERVER_MEM\t$DUS_BW\t$DUS_JITTER\t$DUS_LOST\t"
            echo -en "$DUM_CLIENT_SYSTEM\t$DUM_CLIENT_USER\t$DUM_CLIENT_MEM\t$DUM_SERVER_SYSTEM\t$DUM_SERVER_USER\t$DUM_SERVER_MEM\t$DUM_BW\t$DUM_JITTER\t$DUM_LOST\t"
            echo -en "$STS_CLIENT_SYSTEM\t$STS_CLIENT_USER\t$STS_CLIENT_MEM\t$STS_SERVER_SYSTEM\t$STS_SERVER_USER\t$STS_SERVER_MEM\t$STS_BW\t$STS_RTS\t"
            echo -en "$STM_CLIENT_SYSTEM\t$STM_CLIENT_USER\t$STM_CLIENT_MEM\t$STM_SERVER_SYSTEM\t$STM_SERVER_USER\t$STM_SERVER_MEM\t$STM_BW\t$STM_RTS\t"
            echo -en "$SUS_CLIENT_SYSTEM\t$SUS_CLIENT_USER\t$SUS_CLIENT_MEM\t$SUS_SERVER_SYSTEM\t$SUS_SERVER_USER\t$SUS_SERVER_MEM\t$SUS_BW\t$SUS_JITTER\t$SUS_LOST\t"
            echo -en "$SUM_CLIENT_SYSTEM\t$SUM_CLIENT_USER\t$SUM_CLIENT_MEM\t$SUM_SERVER_SYSTEM\t$SUM_SERVER_USER\t$SUM_SERVER_MEM\t$SUM_BW\t$SUM_JITTER\t$SUM_LOST\t"
            echo        
        ) >> ./results/$BENCHID/results-spreadsheet.csv
        
        (
            LABELS='id="'$BENCHID'",run="'$i'"'

            if [ ! -z "$IDLE_CLIENT_SYSTEM" ]; then
                echo 'benchmark_cpu_seconds{'$LABELS',test="idle",role="client",mode="system"} '${IDLE_CLIENT_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="idle",role="client",mode="user"} '${IDLE_CLIENT_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="idle",role="client"} '${IDLE_CLIENT_MEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="idle",role="server",mode="system"} '${IDLE_SERVER_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="idle",role="server",mode="user"} '${IDLE_SERVER_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="idle",role="server"} '${IDLE_SERVER_MEM}' 1704067200000'
            fi

            if [ ! -z "$DTS_CLIENT_SYSTEM" ]; then
                echo 'benchmark_cpu_seconds{'$LABELS',test="dts",role="client",mode="system"} '${DTS_CLIENT_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dts",role="client",mode="user"} '${DTS_CLIENT_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="dts",role="client"} '${DTS_CLIENT_MEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dts",role="server",mode="system"} '${DTS_SERVER_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dts",role="server",mode="user"} '${DTS_SERVER_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="dts",role="server"} '${DTS_SERVER_MEM}' 1704067200000'
                echo 'benchmark_iperf_bandwidth_bits_per_second{'$LABELS',test="dts"} '${DTS_BW}' 1704067200000'
                echo 'benchmark_iperf_retransmits_count{'$LABELS',test="dts"} '${DTS_RTS}' 1704067200000'
            fi

            if [ ! -z "$DTM_CLIENT_SYSTEM" ]; then
                echo 'benchmark_cpu_seconds{'$LABELS',test="dtm",role="client",mode="system"} '${DTM_CLIENT_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dtm",role="client",mode="user"} '${DTM_CLIENT_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="dtm",role="client"} '${DTM_CLIENT_MEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dtm",role="server",mode="system"} '${DTM_SERVER_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dtm",role="server",mode="user"} '${DTM_SERVER_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="dtm",role="server"} '${DTM_SERVER_MEM}' 1704067200000'
                echo 'benchmark_iperf_bandwidth_bits_per_second{'$LABELS',test="dtm"} '${DTM_BW}' 1704067200000'
                echo 'benchmark_iperf_retransmits_count{'$LABELS',test="dtm"} '${DTM_RTS}' 1704067200000'
            fi

            if [ ! -z "$DUS_CLIENT_SYSTEM" ]; then
                echo 'benchmark_cpu_seconds{'$LABELS',test="dus",role="client",mode="system"} '${DUS_CLIENT_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dus",role="client",mode="user"} '${DUS_CLIENT_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="dus",role="client"} '${DUS_CLIENT_MEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dus",role="server",mode="system"} '${DUS_SERVER_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dus",role="server",mode="user"} '${DUS_SERVER_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="dus",role="server"} '${DUS_SERVER_MEM}' 1704067200000'
                echo 'benchmark_iperf_bandwidth_bits_per_second{'$LABELS',test="dus"} '${DUS_BW}' 1704067200000'
                echo 'benchmark_iperf_jitter_milliseconds{'$LABELS',test="dus"} '${DUS_JITTER}' 1704067200000'
                echo 'benchmark_iperf_lost_percent{'$LABELS',test="dus"} '${DUS_LOST}' 1704067200000'
            fi

            if [ ! -z "$DUM_CLIENT_SYSTEM" ]; then
                echo 'benchmark_cpu_seconds{'$LABELS',test="dum",role="client",mode="system"} '${DUM_CLIENT_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dum",role="client",mode="user"} '${DUM_CLIENT_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="dum",role="client"} '${DUM_CLIENT_MEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dum",role="server",mode="system"} '${DUM_SERVER_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="dum",role="server",mode="user"} '${DUM_SERVER_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="dum",role="server"} '${DUM_SERVER_MEM}' 1704067200000'
                echo 'benchmark_iperf_bandwidth_bits_per_second{'$LABELS',test="dum"} '${DUM_BW}' 1704067200000'
                echo 'benchmark_iperf_jitter_milliseconds{'$LABELS',test="dum"} '${DUM_JITTER}' 1704067200000'
                echo 'benchmark_iperf_lost_percent{'$LABELS',test="dum"} '${DUM_LOST}' 1704067200000'
            fi 

            if [ ! -z "$STS_CLIENT_SYSTEM" ]; then
                echo 'benchmark_cpu_seconds{'$LABELS',test="sts",role="client",mode="system"} '${STS_CLIENT_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="sts",role="client",mode="user"} '${STS_CLIENT_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="sts",role="client"} '${STS_CLIENT_MEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="sts",role="server",mode="system"} '${STS_SERVER_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="sts",role="server",mode="user"} '${STS_SERVER_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="sts",role="server"} '${STS_SERVER_MEM}' 1704067200000'
                echo 'benchmark_iperf_bandwidth_bits_per_second{'$LABELS',test="sts"} '${STS_BW}' 1704067200000'
                echo 'benchmark_iperf_retransmits_count{'$LABELS',test="sts"} '${STS_RTS}' 1704067200000'
            fi

            if [ ! -z "$STM_CLIENT_SYSTEM" ]; then
                echo 'benchmark_cpu_seconds{'$LABELS',test="stm",role="client",mode="system"} '${STM_CLIENT_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="stm",role="client",mode="user"} '${STM_CLIENT_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="stm",role="client"} '${STM_CLIENT_MEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="stm",role="server",mode="system"} '${STM_SERVER_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="stm",role="server",mode="user"} '${STM_SERVER_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="stm",role="server"} '${STM_SERVER_MEM}' 1704067200000'
                echo 'benchmark_iperf_bandwidth_bits_per_second{'$LABELS',test="stm"} '${STM_BW}' 1704067200000'
                echo 'benchmark_iperf_retransmits_count{'$LABELS',test="stm"} '${STM_RTS}' 1704067200000'
            fi

            if [ ! -z "$SUS_CLIENT_SYSTEM" ]; then
                echo 'benchmark_cpu_seconds{'$LABELS',test="sus",role="client",mode="system"} '${SUS_CLIENT_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="sus",role="client",mode="user"} '${SUS_CLIENT_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="sus",role="client"} '${SUS_CLIENT_MEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="sus",role="server",mode="system"} '${SUS_SERVER_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="sus",role="server",mode="user"} '${SUS_SERVER_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="sus",role="server"} '${SUS_SERVER_MEM}' 1704067200000'
                echo 'benchmark_iperf_bandwidth_bits_per_second{'$LABELS',test="sus"} '${SUS_BW}' 1704067200000'
                echo 'benchmark_iperf_jitter_milliseconds{'$LABELS',test="sus"} '${SUS_JITTER}' 1704067200000'
                echo 'benchmark_iperf_lost_percent{'$LABELS',test="sus"} '${SUS_LOST}' 1704067200000'
            fi

            if [ ! -z "$SUM_CLIENT_SYSTEM" ]; then
                echo 'benchmark_cpu_seconds{'$LABELS',test="sum",role="client",mode="system"} '${SUM_CLIENT_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="sum",role="client",mode="user"} '${SUM_CLIENT_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="sum",role="client"} '${SUM_CLIENT_MEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="sum",role="server",mode="system"} '${SUM_SERVER_SYSTEM}' 1704067200000'
                echo 'benchmark_cpu_seconds{'$LABELS',test="sum",role="server",mode="user"} '${SUM_SERVER_USER}' 1704067200000'
                echo 'benchmark_mem_bytes{'$LABELS',test="sum",role="server"} '${SUM_SERVER_MEM}' 1704067200000'
                echo 'benchmark_iperf_bandwidth_bits_per_second{'$LABELS',test="sum"} '${SUM_BW}' 1704067200000'
                echo 'benchmark_iperf_jitter_milliseconds{'$LABELS',test="sum"} '${SUM_JITTER}' 1704067200000'
                echo 'benchmark_iperf_lost_percent{'$LABELS',test="sum"} '${SUM_LOST}' 1704067200000'
            fi
        ) >> ./results/$BENCHID/results.prom
    done
}

function bench_cni {
    BENCHID="$1"
    shift

    CMDA1="kubectl exec -it cni-benchmark-a1 -- "
    CMDA2="kubectl exec -it cni-benchmark-a2 -- "
    CMDA3="kubectl exec -it cni-benchmark-a3 -- "

    SVC_A1="cni-benchmark-a1"
    SVC_A2="cni-benchmark-a2"
    SVC_A3="cni-benchmark-a3"

    [ -d ./results/$BENCHID ] && rm -rf ./results/$BENCHID

    for RUNID in $(seq 1 ${BENCHMARK_NUMBER_OF_RUNS}); do

        test_prepare

        test_setup

        kubectl apply -f ./assets/benchmark-resources.yaml

        kubectl wait --for=condition=Ready pod/cni-benchmark-a1 --timeout=300s
        kubectl wait --for=condition=Ready pod/cni-benchmark-a2 --timeout=300s
        kubectl wait --for=condition=Ready pod/cni-benchmark-a3 --timeout=300s

        DIRECT_A1="$(kubectl get pod cni-benchmark-a1 -o jsonpath='{.status.podIP}')"
        DIRECT_A2="$(kubectl get pod cni-benchmark-a2 -o jsonpath='{.status.podIP}')"
        DIRECT_A3="$(kubectl get pod cni-benchmark-a3 -o jsonpath='{.status.podIP}')"
        
        test_info

        test_idle
        
        test_dts
        test_dtm
        test_dus
        test_dum
        
        test_sts
        test_stm
        test_sus
        test_sum

        cat $OUTPUTDIR/*.results > $OUTPUTDIR/all.results

        test_cleanup
    done

    compute_results
}

function bench_baremetal {
    BENCHID="$1"
    EXEC_CMD="./maas.sh ssh"

    CMDA1="./maas.sh ssh a1"
    CMDA2="./maas.sh ssh a2"
    CMDA3="./maas.sh ssh a3"

    DIRECT_A1="$(./maas.sh getip a1)"
    DIRECT_A2="$(./maas.sh getip a2)"
    DIRECT_A3="$(./maas.sh getip a3)"

    [ -d ./results/$BENCHID ] && rm -rf ./results/$BENCHID

    for RUNID in $(seq 1 ${BENCHMARK_NUMBER_OF_RUNS}); do

        test_prepare
        
        test_idle
        
        test_dts
        test_dtm
        test_dus
        test_dum
        
        # There is no service mode for baremetal as there is no k8s
        # test_sts
        # test_stm
        # test_sus
        # test_sum

        cat $OUTPUTDIR/*.results > $OUTPUTDIR/all.results

        test_cleanup
    done

    compute_results
}

case $1 in 
    baremetal|bm)
        bench_baremetal baremetal
        ;;
    tuned-baremetal|tbm)
        BENCHSUFFIX=""
        [ ! -z "$2" ] && BENCHSUFFIX="_${2}"
        bench_baremetal st_baremetal${BENCHSUFFIX}
        ;;
    cni)
        bench_cni $2 ${@:2}
        ;;
    tuned-cni|tcni)
        bench_cni st_$2 ${@:3}
        ;;
    *)
        echo "Usage: $0 (baremetal|cni <cni>)"
        exit 1
        ;;
esac
