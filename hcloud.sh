#!/bin/bash

CURDIR=$(dirname $0)
[ "$CURDIR" = "." ] && CURDIR=$(pwd)

export KUBECONFIG=$CURDIR/setup/59-kubeconfig.yaml
export SERVER_MTU=1500
export SSHUSER=root
export RESULTPREFIX="hcloud"

function init {
    echo "Setup instances on Hetzner Cloud"
    SERVEROPTS="--datacenter nbg1-dc3 --image ubuntu-22.04 --type cpx41 --without-ipv6 --ssh-key sshkey.pub "
    
    WAITPID=""
    hcloud server create --name a1 $SERVEROPTS &
    WAITPID="$WAITPID $!"
    hcloud server create --name a2 $SERVEROPTS &
    WAITPID="$WAITPID $!"
    hcloud server create --name a3 $SERVEROPTS &
    WAITPID="$WAITPID $!"

    echo "Waiting for all servers to be deployed"
    wait $WAITPID

    sleep 10

    A1IP=$(hcloud server ip a1)
    A2IP=$(hcloud server ip a2)
    A3IP=$(hcloud server ip a3)

    WAITPID=""
    $CURDIR/setup/20-os-prepare.sh ${SSHUSER}@$A1IP &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/20-os-prepare.sh ${SSHUSER}@$A2IP &
    WAITPID="$WAITPID $!"
    $CURDIR/setup/20-os-prepare.sh ${SSHUSER}@$A3IP &
    WAITPID="$WAITPID $!"

    echo "Waiting for all servers to be prepared"
    wait $WAITPID

}
function rke2-up {
    A1IP=$(hcloud server ip a1)
    A2IP=$(hcloud server ip a2)
    A3IP=$(hcloud server ip a3)

    echo "Setup RKE2 controlplane on a1 ($A1IP)"
    $CURDIR/setup/50-setup-rke2.sh cp ${SSHUSER}@$A1IP

    echo "Setup RKE2 worker on a2 ($A2IP) and a3 ($A3I)P"
    $CURDIR/setup/50-setup-rke2.sh worker ${SSHUSER}@$A2IP $A1IP
    $CURDIR/setup/50-setup-rke2.sh worker ${SSHUSER}@$A3IP $A1IP

    echo "RKE2 ready"
}

function setup-cni {

    export A1IP=$(hcloud server ip a1)
    export A2IP=$(hcloud server ip a2)
    export A3IP=$(hcloud server ip a3)

    echo "Setup CNI $1"
    $CURDIR/setup/60-setup-cni.sh $1 

    echo "Waiting for all pods to be running or completed"
    while [ "$(kubectl get pods -A --no-headers | grep -v Running | grep -v Completed)" != "" ]; do
        echo -n "."
        sleep 2
    done
    echo ""
}

function rke2-down {
    export A1IP=$(hcloud server ip a1)
    export A2IP=$(hcloud server ip a2)
    export A3IP=$(hcloud server ip a3)

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
    hcloud server delete a1 &
    WAITPID="$WAITPID $!"
    hcloud server delete a2 &
    WAITPID="$WAITPID $!"
    hcloud server delete a3 &
    WAITPID="$WAITPID $!"

    echo "Waiting for all servers to be deleted"
    wait $WAITPID
}


function debugpods {
cat <<-EOF | kubectl apply -f - >/dev/null|| { echo "Cannot create server pod"; return 1;  }
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: debug-server
  name: debug-server
spec:
  containers:
  - name: iperf
    image: infrabuilder/bench-iperf3
    args:
    - iperf3
    - -s
  nodeName: a2
EOF
cat <<-EOF | kubectl apply -f - >/dev/null|| { echo "Cannot create client pod"; return 1;  }
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: debug-client
  name: debug-client
spec:
  containers:
  - name: iperf
    image: infrabuilder/bench-iperf3
    args:
    - sh
    tty: true
  nodeName: a3
EOF

    echo -n "Waiting for server pod to be running "
    while [ "$(kubectl get pod debug-server -o jsonpath='{.status.phase}')" != "Running" ]; do
        echo -n "."
        sleep 2
    done
    echo ""

    # Print server pod IP
    echo "Server IP: $(kubectl get pod debug-server -o jsonpath='{.status.podIP}')"
    echo "Run client with : kubectl exec -it debug-client -- sh"
} 

function connect-ssh {
    SSHIP=$(hcloud server ip $1)
    shift
    exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSHUSER}@$SSHIP $@
}

function getip {
    case $1 in
        a1)
            hcloud server ip a1
            ;;
        a2)
            hcloud server ip a2
            ;;
        a3)
            hcloud server ip a3
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
        rke2-up|up|u)
            rke2-up
            ;;
        rke2-down|down|d)
            rke2-down
            ;;
        setup-cni|cni)
            setup-cni $2
            shift
            ;;
        cleanup|clean|c)
            clean
            ;;
        debugpods|debug|d)
            debugpods
            ;;
        ssh|s)
            connect-ssh $2
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