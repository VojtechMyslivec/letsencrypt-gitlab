#!/bin/bash
## letsencrypt_wrapper.sh
#
# this script is used for adding or removing domain names to letsencrypt
# certificate for gitlab and gitlab pages

set -o pipefail
set -o nounset

# variables ======================================
SCRIPTNAME=${0##*/}
SCRIPTDIR=${0%/*}

USAGE="USAGE
    $SCRIPTNAME [log_level]

    This script will obtain and deploy certificates for Gitlab Pages
    with domain names specified in configuration file
    '$SCRIPTDIR/letsencrypt_wrapper.conf'

        log_level   info|warn|err

                    Default is 'info' which can be overriden by variable
                    'log_level' in config or as a parameter on commandline.

                    Running
                        \`$SCRIPTNAME warn\`
                    is suitable as a cron job."

# default parameters -----------------------------
log_level="info"

# path to a webroot (must be mapped in gitlab.rb by nginx custom config)
webroot_path="/var/www/letsencrypt"
# gitlab services controller
gitlab_sv="/opt/gitlab/embedded/bin/sv"
# letsencrypt-auto tool
letsencrypt="/opt/letsencrypt/letsencrypt-auto"
# extra args for letsencrypt-auto
# there needs to be at least something to use array expansion together with nounset
letsencrypt_extra_args=('--non-interactive')

# functions ======================================
# messages ---------------------------------------
message() {
    echo "$SCRIPTNAME[$1]: $2" >&2
}

# for log_level >= info = 2
info() {
    [ "$log_level_i" -ge "2" ] && \
      message "info" "$*"
}

# for log_level >= warn = 1
warning() {
    [ "$log_level_i" -ge "1" ] && \
      message "warn" "$*"
}

# for log_level >= err = 0 (everytime)
error() {
    #[ "$log_level_i" -ge "0" ] && \
      message "err" "$*"
}

# script functions -------------------------------
usage() {
[ $# -le 1 ] || {
    echo "$USAGE" >&2
    exit 1
}

if [ $# -ge 1 ]; then
    [ "$1" == "-h" -o "$1" == "--help" ] && {
        echo "$USAGE"
        exit 0
    }
    log_level="$1"
fi

# log_level handling
case "$log_level" in
    "info")
        log_level_i=2
        ;;
    "warn")
        log_level_i=1
        letsencrypt_extra_args+=("--quiet")
        ;;
    "err")
        log_level_i=0
        letsencrypt_extra_args+=("--quiet")
        ;;
    *)
        error "log_level can be set only to 'err','warn' or 'info'"
        exit 1
        ;;
esac
}


# Needs $1: start/stop
pages_service() {
    local action="$1"
    if [ "$action" == "start" ]; then
        info "Starting Pages"
    elif [ "$action" == "stop" ]; then
        info "Stoping Pages"
    else
        error "nginx_service(): argument must be 'start' or 'stop'"
        return 1
    fi
    "$gitlab_sv" "$action" gitlab-pages > /dev/null || {
        error "Failed to '$action' pages"
        return 2
    }
}

start_dummy_webserver() {
    info "Running dummy webserver"
    dummy_server_pidfile=$( mktemp )
    python3 -m http.server --bind "$pages_bind_ip" 80 &> /dev/null &
    echo "$!" > "$dummy_server_pidfile"
}

is_dummy_webserver_running() {
    pgrep -P "$$" -F "$dummy_server_pidfile" python > /dev/null
}

check_dummy_webserver() {
    is_dummy_webserver_running || {
        error "Can not start dummy web server"
        pages_service start
        return 1
    }
}

stop_dummy_webserver() {
    info "Stoping dummy webserver"
    pkill -P "$$" -F "$dummy_server_pidfile" python -term

    # in case it needs to be killed
    sleep 2
    is_dummy_webserver_running && {
        warning "Need to kill dummy webserver"
        pkill -P "$$" -F "$dummy_server_pidfile" python -kill
    }

    rm "$dummy_server_pidfile" || {
        warning "Can not remove temporary pidfile '$dummy_server_pidfile'"
    }
}


# this function will run letsencrypt-auto with webroot method
# needs csv of domains as $1 arg
obtain_cert() {
    [ "$#" -ge 1 ] || {
        error "obtain_cert(): list of domains is needed as arguments"
        return 1
    }

    (
        # to separate arguments with comma
        IFS=,
        # it will pass the return value
        "$letsencrypt" certonly \
                "${letsencrypt_extra_args[@]}" \
                --email "$email" --agree-tos \
                --webroot --webroot-path "$webroot_path" \
                --expand --domains "$*" # domains as comma-separated list
    )
}


obtain_pages_cert() {
    # obtain certificate for pages – via webroot method
    info "Obtaining Pages certificate" >&2
    obtain_cert "${pages_domains[@]}" || {
        error "Cannnot obtain certificate for Pages domains." >&2
        return 1
    }
}


# main ===========================================

# needed for dummy webserver
cd "$webroot_path" || {
    error "Can not change directory to '$webroot_path'"
    exit 1
}

source "$SCRIPTDIR/letsencrypt_wrapper.conf" || {
    error "Could not source config file."
    exit 1
}

usage "$@" || exit 1


# obtain and deploy pages certificate ------------
# pages uses go webserver which can not be configered
# to alias /.well-known at the moment
# so it is needed to use "our" dummy webserver with correct

# letsencrypt-auto standalone is not used because it can
# not be configured to listen only on specific IP address

pages_service stop || exit 3

start_dummy_webserver || exit 3

sleep 2
check_dummy_webserver || exit 3

obtain_pages_cert || {
    stop_dummy_webserver || exit 3
    pages_service start || exit 3
    exit 2
}

stop_dummy_webserver || exit 3

pages_service start || exit 3
