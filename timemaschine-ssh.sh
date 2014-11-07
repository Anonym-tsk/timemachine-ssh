#!/bin/sh

## READ THE CONFIG FILE
source $(dirname $0)/timemaschine-ssh.conf

SSH_COMMAND="ssh -gNf -L $LOCAL_AFP_PORT:$AFP_HOST:548"

log() {
    if [ "$QUIET" = "false" ]; then
        echo "$1"
    fi
}

######### SSH tunnel methods #########

getPidSshCommand() {
    echo `ps aux | egrep -w "$SSH_COMMAND" | grep -v egrep | awk '{print $2}'`
}

startSshTunnel() {
    log "Starting ssh tunnel to $REMOTE_HOST..."

    local PID=`getPidSshCommand`
    if [[ -n "$PID" ]]; then
        log "Tunnel to $REMOTE_HOST already active"
    else
        if [[ -n "$KEYFILE" && -e "$KEYFILE" ]]; then
            REMOTE_LOGIN="-i $KEYFILE $REMOTE_USER@$REMOTE_HOST"
        else
            REMOTE_LOGIN="$REMOTE_USER@$REMOTE_HOST"
        fi

        log "Connecting to server: $REMOTE_HOST..."

        # Create tunnel
        $SSH_COMMAND -C "$REMOTE_LOGIN"

        if [[ $? -eq 0 ]]; then
            log "Tunnel to $REMOTE_HOST created successfully"
        else
            log "An error occurred creating a tunnel to $REMOTE_HOST. RC was $?"
            exit 1
        fi
    fi
}

stopSshTunnel() {
    local PID=`getPidSshCommand`
    if [[ -z "$PID" ]]; then
        log "Tunnel to $REMOTE_HOST is not active"
    else
        kill "$PID"
        log "Tunnel to $REMOTE_HOST killed successfully"
    fi
}

######### End SSH tunnel methods #########

######### dns-sd methods #########

getPidDnsSdCommand() {
    echo `ps aux | egrep -w "dns-sd -R $LABEL" | grep -v egrep | awk '{print $2}'`
}

startDnsSd() {
    log "Starting dns-sd service..."

    local PID=`getPidDnsSdCommand`
    if [[ -n "$PID" ]]; then
        log "Service already active"
    else
        # Register AFP as service via dns-sd
        dns-sd -R "$LABEL" _afpovertcp._tcp . $LOCAL_AFP_PORT > /dev/null &

        if [[ $? -eq 0 ]]; then
            log "Service started successfully"
        else
            log "An error occurred starting dns-sd service. RC was $?"
            exit 1
        fi
    fi
}

stopDnsSd() {
    local PID=`getPidDnsSdCommand`
    if [[ -z "$PID" ]]; then
        log "Service dns-sd is not active"
    else
        kill "$PID"
        log "Service dns-sd killed successfully"
    fi
}

######### End dns-sd methods #########

######### Public methods #########

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
 -c, --check                 check service and restart if needed
 -h, --help                  show this screen
"

    exit 0
}

status() {
    local DNS_SD_PID=`getPidDnsSdCommand`
    if [[ -z "$DNS_SD_PID" ]]; then
        log "Service dns-sd is not active"
    else
        log "Service dns-sd is active"
    fi

    local SSH_PID=`getPidSshCommand`
    if [[ -z "$SSH_PID" ]]; then
        log "Tunnel to $REMOTE_HOST is not active"
    else
        log "Tunnel to $REMOTE_HOST is active"
    fi

    exit 0
}

start() {
    startSshTunnel
    startDnsSd
    exit 0
}

stop() {
    stopDnsSd
    stopSshTunnel
    exit 0
}

restart() {
    stopDnsSd
    stopSshTunnel
    startSshTunnel
    startDnsSd
    exit 0
}

check() {
    local SSH_PID=`getPidSshCommand`
    if [[ -z "$SSH_PID" ]]; then
        stopDnsSd
        startSshTunnel
        startDnsSd
    else
        local DNS_SD_PID=`getPidDnsSdCommand`
        if [[ -z "$DNS_SD_PID" ]]; then
            startDnsSd
        else
            log "Service already active"
        fi
    fi

    exit 0
}

######### End public methods #########

# Until you run out of parameters...
while [ $# -gt 0 ]; do
    case "$1" in
        -q|--quiet)
            QUIET=true
        ;;
        -h|--help)
            help
        ;;
        -s|--status)
            status
        ;;
        -k|--kill)
            stop
        ;;
        -r|--restart)
            restart
        ;;
        -c|--check)
            check
        ;;
        *)
            help
        ;;
    esac
    shift
done

start
