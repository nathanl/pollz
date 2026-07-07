#!/usr/bin/env sh

set -e

export PGDATA="$PGHOST/data"
export LOG_PATH="$PGHOST/LOG"

dbname="$DEV_DATABASE_NAME"

show_help() {
    echo "USAGE:"
    echo "    pg.sh [SUBCOMMAND]"
    echo ""
    echo "SUBCOMMANDS:"
    echo "    bootstrap    Create user database and 'postgres' user"
    echo "    dump [PATH]  Dump development database to [PATH]"
    echo "    help         Print this message"
    echo "    init         Initialize local database cluster"
    echo "    load [PATH]  Load development database from [PATH]"
    echo "    restart      Force-kill and restart local database server"
    echo "    start        Start local database server"
    echo "    stop         Stop local database server"
}

init() {
    mkdir -p "$PGHOST"
    mkdir -p "$PGDATA"
    chmod -R 0700 "$PGHOST"
    initdb "$PGDATA" --auth=trust --encoding=UTF8 --locale=C.UTF-8 >/dev/null
}

bootstrap() {
    createdb "$(whoami)"
    psql -c "create role postgres with createdb login password 'postgres';"
    psql -c "alter user postgres with superuser;"
    if command -v pg_config >/dev/null 2>&1; then
        timescaledb-tune --quiet --yes -conf-path "$PGDATA"
    fi
    mix deps.get
    mix ecto.setup
}

server_running() {
    # Read the PID from the lockfile and check whether the process actually exists.
    # A plain file-existence check would give false positives after a crash (stale PID file).
    [ -f "$PGDATA/postmaster.pid" ] && kill -0 "$(head -1 "$PGDATA/postmaster.pid")" 2>/dev/null
}

start() {
    PG_OPTIONS="-c listen_addresses= -c unix_socket_directories=$PGHOST -c shared_preload_libraries=\"timescaledb,pg_stat_statements\" -c timezone=UTC"
    pg_ctl -D "$PGDATA" -l "$LOG_PATH" -o "$PG_OPTIONS" -w start
}

restart() {
    # Force-kill postgres immediately (graceful stop blocks when clients hold connections).
    # Safe for local dev — the data directory survives a kill -9.
    if server_running; then
        kill -9 "$(head -1 "$PGDATA/postmaster.pid")" 2>/dev/null || true
        sleep 1
    fi
    start
}

load() {
    read -p "This will replace your local development database. Proceed? (Y/n) " choice
    choice=${choice:-Y}
    if [ "$choice" = "Y" ] || [ "$choice" = "y" ]; then
        mix do ecto.drop, ecto.create
        psql $dbname < "$1" 1> /dev/null 2> /dev/null
        echo "Data has been loaded from $1"
    fi
}

case "$1" in
    "bootstrap")
        bootstrap
        ;;
    "dump")
        pg_dump -d $dbname > "$2" 2> /dev/null
        echo "Data has been dumped to $2"
        ;;
    "help")
        show_help
        ;;
    "init")
        init
        ;;
    "load")
        load "$2"
        ;;
    "start")
        if [ ! -d "$PGDATA" ]; then
            init
            start
            bootstrap
        else
            if ! server_running; then
                start
            fi
        fi
        ;;
    "stop")
        pg_ctl -l "$LOG_PATH" -o "-c listen_addresses= -c unix_socket_directories=$PGHOST" stop
        ;;
    "restart")
        restart
        ;;
    *)
        printf "Error: Must provide one of [bootstrap/help/init/restart/start/stop/dump/load]\n\n"
        show_help
        ;;
esac

exit 0
