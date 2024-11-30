#!/bin/sh

### BEGIN INIT INFO
# Provides:          aesdsocket
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start aesdsocket daemon
# Description:       Start aesdsocket in daemon mode
### END INIT INFO

DAEMON_PATH="./aesdsocket"
DAEMON_NAME="aesdsocket"
DAEMON_OPTS="-d"
PIDFILE="/var/run/$DAEMON_NAME.pid"

start() {
    echo "Starting $DAEMON_NAME..."
    start-stop-daemon --start --background --make-pidfile --pidfile $PIDFILE \
        --exec $DAEMON_PATH -- $DAEMON_OPTS
    echo "$DAEMON_NAME started."
}

stop() {
    echo "Stopping $DAEMON_NAME..."
    start-stop-daemon --stop --pidfile $PIDFILE
    echo "$DAEMON_NAME stopped."
}

status() {
    if [ -f $PIDFILE ]; then
        PID=$(cat $PIDFILE)
        if ps -p $PID > /dev/null; then
            echo "$DAEMON_NAME is running (PID $PID)."
            exit 0
        else
            echo "$DAEMON_NAME is not running, but pidfile exists."
            exit 1
        fi
    else
        echo "$DAEMON_NAME is not running."
        exit 3
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 1  # Ensure the process has time to terminate before restarting
        start
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 2
        ;;
esac