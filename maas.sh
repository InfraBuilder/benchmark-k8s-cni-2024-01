#!/bin/bash

CURDIR=$(dirname $0)
[ "$CURDIR" = "." ] && CURDIR=$(pwd)

export KUBECONFIG=$CURDIR/setup/59-kubeconfig.yaml
export SERVER_MTU=9000
export SSHUSER=ubuntu
export RESULTPREFIX="maas"

export A1IP=${A1IP:-10.1.1.11}
export A2IP=${A2IP:-10.1.1.12}
export A3IP=${A3IP:-10.1.1.13}

function init {
    # Deploy server from maas API
    echo "Setup servers via MAAS"
    PIDTOWAIT=""
    maas deploy jammy a1 &
    PIDTOWAIT="$PIDTOWAIT $!"
    maas deploy jammy a2 &
    PIDTOWAIT="$PIDTOWAIT $!"
    maas deploy jammy a3 &
    PIDTOWAIT="$PIDTOWAIT $!"

    echo Waiting for all servers to be deployed
    wait $PIDTOWAIT

    echo "Preparing servers"
    WAITPID=""
    $CURDIR/setup/10-maas-prepare-nics.sh ${SSHUSER}@$A1IP &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/10-maas-prepare-nics.sh ${SSHUSER}@$A2IP &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/10-maas-prepare-nics.sh ${SSHUSER}@$A3IP &
    WAITPID="$WAITPID $!"

    echo "Waiting for all servers NICs to be configured"
    wait $WAITPID

    TUNED=""
    [ "$1" = "tuned" ] && TUNED="tuned"

    WAITPID=""
    $CURDIR/setup/20-os-prepare.sh ${SSHUSER}@$A1IP $TUNED &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/20-os-prepare.sh ${SSHUSER}@$A2IP $TUNED &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/20-os-prepare.sh ${SSHUSER}@$A3IP $TUNED &
    WAITPID="$WAITPID $!"

    echo "Waiting for all servers to be prepared"
    wait $WAITPID
}

function rke2-up {

    echo "Setup RKE2 controlplane on a1 ($A1IP)"
    $CURDIR/setup/50-setup-rke2.sh cp ${SSHUSER}@$A1IP

    echo "Setup RKE2 worker on a2 ($A2IP) and a3 ($A3I)P"
    $CURDIR/setup/50-setup-rke2.sh worker ${SSHUSER}@$A2IP $A1IP
    $CURDIR/setup/50-setup-rke2.sh worker ${SSHUSER}@$A3IP $A1IP

    echo "RKE2 ready"
}

function setup-cni {
    echo "Setup CNI $1"
    $CURDIR/setup/60-setup-cni.sh $1 

    echo "Waiting for all pods to be running or completed"
    while [ "$(kubectl get pods -A --no-headers | grep -v Running | grep -v Completed)" != "" ]; do
        echo -n "."
        sleep 2
    done
    echo ""
}

function setup-csi {
    echo "Setup CSI $1"
    $CURDIR/setup/61-setup-csi.sh $1 

    echo "Waiting for all pods to be running or completed"
    while [ "$(kubectl get pods -A --no-headers | grep -v Running | grep -v Completed)" != "" ]; do
        echo -n "."
        sleep 2
    done
    echo ""
}

function rke2-down {
    echo "Tear down RKE2"
    WAITPID=""
    $CURDIR/setup/80-teardown-rke2.sh ${SSHUSER}@$A1IP &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/80-teardown-rke2.sh ${SSHUSER}@$A2IP &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/80-teardown-rke2.sh ${SSHUSER}@$A3IP &
    WAITPID="$WAITPID $!"

    echo "Waiting for all servers to be cleaned up"
    wait $WAITPID

    echo "RKE2 down"
}

function clean {
    WAITPID=""
    maas release a1 &
    WAITPID="$WAITPID $!"
    maas release a2 &
    WAITPID="$WAITPID $!"
    maas release a3 &
    WAITPID="$WAITPID $!"

    echo Waiting for all servers to be released
    wait $WAITPID
}

function connect-ssh {
    case $1 in
        a1)
            SSHIP=$A1IP
            ;;
        a2)
            SSHIP=$A2IP
            ;;
        a3)
            SSHIP=$A3IP
            ;;
        *)
            echo "Unknown server $1"
            exit 1
            ;;
    esac
    shift
    exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSHUSER}@$SSHIP $@
}

function getip {
    case $1 in
        a1)
            echo $A1IP
            ;;
        a2)
            echo $A2IP
            ;;
        a3)
            echo $A3IP
            ;;
        *)
            echo "Unknown server $1"
            exit 1
            ;;
    esac
}

[ "$1" = "" ] && echo "Usage: $0 (init|rke2-up|rke2-down|cni <cni>|cleanup)" && exit 1

while [ "$1" != "" ]; do
    case $1 in
        init|i)
            init
            ;;
        init-tuned|it)
            init tuned
            ;;
        rke2-up|up|u)
            rke2-up
            ;;
        rke2-down|down|d)
            rke2-down
            ;;
        cni)
            setup-cni $2
            shift
            ;;
        csi)
            setup-csi $2
            shift
            ;;
        cleanup|clean|c)
            clean
            ;;
        ssh|s)
            connect-ssh $2 ${@:3}
            shift
            ;;
        getip|ip)
            getip $2
            shift
            ;;
        *)
            echo "Unknown command '$1'"
            exit 1
            ;;
    esac
    shift
done