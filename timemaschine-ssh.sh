#!/bin/sh

## READ THE CONFIG FILE
source timemaschine-ssh.conf

createTunnel() {
    if [[ -n "$KEYFILE" && -e "$KEYFILE" ]]; then
        REMOTE_LOGIN="-i $KEYFILE $REMOTE_USER@$REMOTE_HOST"
    else
        REMOTE_LOGIN="$REMOTE_USER@$REMOTE_HOST"
    fi

    if [ "$QUIET" = "false" ]; then echo "Connecting to server: $REMOTE_HOST" >&2; fi

    # Create tunnel to port 548 on remote host and make it avaliable at port $LOCAL_AFP_PORT at localhost
    # Also tunnel ssh for connection testing purposes
    ssh -gNf -L "$LOCAL_AFP_PORT:$AFP_HOST:548" -C "$REMOTE_LOGIN"

    if [[ $? -eq 0 ]]; then
        # Register AFP as service via dns-sd
        dns-sd -R "$LABEL" _afpovertcp._tcp . "$LOCAL_AFP_PORT" > /dev/null &

        if [ "$QUIET" = "false" ]; then echo "Tunnel to $REMOTE_HOST created successfully"; fi
        exit 0
    else
        if [ "$QUIET" = "false" ]; then echo "An error occurred creating a tunnel to $REMOTE_HOST RC was $?"; fi
        exit 1
    fi
}

killTunnel() {
    MYPID=`getPid`
    for i in $MYPID; do kill $i; done
    if [ "$QUIET" = "false" ]; then echo "All processes killed"; fi
}

status() {
    MYPID=`getPid`
    if [[ -z "$MYPID" ]]; then
        if [ "$QUIET" = "false" ]; then echo "Tunnel to $REMOTE_HOST is NOT ACTIVE"; fi
        exit 0
    fi
    if [ "$QUIET" = "false" ]; then echo "Tunnel to $REMOTE_HOST is ACTIVE"; fi
    exit 1
}

getPid() {
    MYPID=`ps aux | egrep -w "$REMOTE_HOST|dns-sd -R $LABEL" | grep -v egrep | awk '{print $2}'`
    echo $MYPID
}

help() {
    SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
    echo "$SCRIPT_NAME

$SCRIPT_NAME is a small shell script that tunnels the AFP port of your disk station
(and propably every other NAS with AFP and SSH services running) over ssh to your client computer.

Put your settings in the config section in the script itself!

Options
 -q, --quiet                 quiet mode
 -k, --kill                  kill all $SCRIPT_NAME processes
 -r, --restart               restart
 -h, --help                  show this screen
"
exit 0
}

# Yippieeh, commandline parameters

while [ $# -gt 0 ]; do    # Until you run out of parameters . . .
    case "$1" in
        -s|--status)
            status
        ;;
        -k|--kill)
            killTunnel
            exit 0
        ;;
        -q|--quiet)
            QUIET=true
        ;;
        -h|--help)
            help
        ;;
        -r|--restart)
            killTunnel
        ;;
        *)
 
        ;;
    esac
    shift       # Check next set of parameters.
done

MYPID=`getPid`
if [[ -z "$MYPID" ]]; then
    createTunnel
else
    if [ "$QUIET" = "false" ]; then echo "Tunnel to $REMOTE_HOST is already active"; fi
fi
