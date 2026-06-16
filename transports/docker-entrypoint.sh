#!/bin/sh
set -e

APP_DIR=${APP_DIR:-/app/data}
RUN_USER=appuser

# VIRTU FORK: the container starts as root so it can adopt bind-mounted volumes (which arrive
# owned by an arbitrary host UID). Chown every persistent dir bifrost writes to — APP_DIR and the
# separate BIFROST_LOGS_DIR mount — to appuser, then su-exec down to appuser to run the server.
# Without this, host-owned mounts are unwritable by appuser (logstore init -> permission denied).
fix_permissions() {
    for d in "$APP_DIR" "$BIFROST_LOGS_DIR"; do
        [ -n "$d" ] || continue
        mkdir -p "$d"
        chown -R "$RUN_USER:$RUN_USER" "$d" 2>/dev/null \
            || echo "Warning: could not chown $d (run the container as root, or pre-chown the host dir)"
    done
    # When BIFROST_LOGS_DIR is unset, rotating logs live under APP_DIR/logs.
    mkdir -p "$APP_DIR/logs"
    chown -R "$RUN_USER:$RUN_USER" "$APP_DIR/logs" 2>/dev/null || true
}

# Fix permissions before starting the application
fix_permissions

# Parse command line arguments and set environment variables
parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            --port|-port)
                if [ -n "$2" ]; then
                    export APP_PORT="$2"
                    shift 2
                else
                    echo "Error: --port requires a value"
                    exit 1
                fi
                ;;
            --host|-host)
                if [ -n "$2" ]; then
                    export APP_HOST="$2"
                    shift 2
                else
                    echo "Error: --host requires a value"
                    exit 1
                fi
                ;;
            *)
                # Keep other arguments for the main application
                set -- "$@" "$1"
                shift
                ;;
        esac
    done
}

# Parse arguments if any are provided
if [ $# -gt 1 ]; then
    parse_args "$@"
fi

# Build the command with environment variables and standard arguments. Drop to appuser via
# su-exec when running as root (after the chowns above); if already non-root, exec directly.
set -- /app/main -app-dir "$APP_DIR" -port "$APP_PORT" -host "$APP_HOST" -log-level "$LOG_LEVEL" -log-style "$LOG_STYLE"
if [ "$(id -u)" = "0" ]; then
    exec su-exec "$RUN_USER" "$@"
fi
exec "$@"
