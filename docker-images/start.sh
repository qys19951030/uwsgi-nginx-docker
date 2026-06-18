#! /usr/bin/env sh
set -e

DEFAULT_PRE_START_PATH=/app/prestart.sh

FOUND_PRE_START=""

if [ -n "$UWSGI_INI" ] ; then
    UWSGI_INI_DIR=$(dirname "$UWSGI_INI")
    CUSTOM_PRE_START_PATH="$UWSGI_INI_DIR/prestart.sh"
    if [ "$CUSTOM_PRE_START_PATH" != "$DEFAULT_PRE_START_PATH" ] ; then
        echo "Checking for script in $CUSTOM_PRE_START_PATH"
        if [ -f "$CUSTOM_PRE_START_PATH" ] ; then
            FOUND_PRE_START="$CUSTOM_PRE_START_PATH"
        else
            echo "There is no script $CUSTOM_PRE_START_PATH"
        fi
    fi
fi

if [ -z "$FOUND_PRE_START" ] ; then
    PRE_START_PATH="$DEFAULT_PRE_START_PATH"
else
    PRE_START_PATH="$FOUND_PRE_START"
fi

if [ -z "$FOUND_PRE_START" ] ; then
    echo "Checking for script in $PRE_START_PATH"
fi

if [ -f "$PRE_START_PATH" ] ; then
    echo "Running script $PRE_START_PATH"
    . "$PRE_START_PATH"
else
    echo "There is no script $PRE_START_PATH"
fi

# Start Supervisor, with Nginx and uWSGI
exec /usr/bin/supervisord
