#! /usr/bin/env sh
set -e

DEFAULT_PRE_START_PATH=/app/prestart.sh

if [ -n "$UWSGI_INI" ] ; then
    UWSGI_INI_DIR=$(dirname "$UWSGI_INI")
    CUSTOM_PRE_START_PATH="$UWSGI_INI_DIR/prestart.sh"
    echo "Checking for script in $CUSTOM_PRE_START_PATH"
    if [ -f "$CUSTOM_PRE_START_PATH" ] ; then
        PRE_START_PATH="$CUSTOM_PRE_START_PATH"
    else
        echo "There is no script $CUSTOM_PRE_START_PATH"
        PRE_START_PATH="$DEFAULT_PRE_START_PATH"
    fi
else
    PRE_START_PATH="$DEFAULT_PRE_START_PATH"
fi

echo "Checking for script in $PRE_START_PATH"
if [ -f "$PRE_START_PATH" ] ; then
    echo "Running script $PRE_START_PATH"
    . "$PRE_START_PATH"
else
    echo "There is no script $PRE_START_PATH"
fi

# Start Supervisor, with Nginx and uWSGI
exec /usr/bin/supervisord
