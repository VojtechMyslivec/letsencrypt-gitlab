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
    $SCRIPTNAME -h
    $SCRIPTNAME [-qv]

    This script will obtain and deploy certificates for Gitlab Pages
    with domain names specified in configuration file
    '$SCRIPTDIR/letsencrypt_wrapper.conf'

OPTIONS
    -h      Prints this message and exits

    -q      Quiet mode, suitable for cron (overrides '-v')
    -v      Verbose mode, useful for testing (overrides '-q')

EXAMPLES
    Run this script as a cron job:
        $SCRIPTNAME -q"


# default parameters -----------------------------
VERBOSE='false'

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


info() {
    if [ "$VERBOSE" == 'true' ]; then
        message "info" "$*"
    fi
}


warning() {
    message "warn" "$*"
}

error() {
    message "err" "$*"
}


# script functions -------------------------------
usage() {
    while getopts ':hqv' OPT; do
        case "$OPT" in
            h)
                echo "$USAGE"
                exit 0
                ;;

            q)
                letsencrypt_extra_args+=("--quiet")
                VERBOSE='false'
                ;;

            v)
                VERBOSE='true'
                ;;

            \?)
                error "Illegal option '-$OPTARG'"
                exit 1
                ;;
        esac
    done
    shift $(( OPTIND-1 ))

    [ $# -eq 0 ] || {
        echo "$USAGE" >&2
        exit 1
    }
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


# this function will run letsencrypt-auto in standalone method
# needs list of domains as arguments
obtain_cert() {
    [ "$#" -ge 1 ] || {
        error "obtain_cert(): list of domains is needed as arguments"
        return 1
    }

    (
        # to separate arguments with comma
        IFS=,
        "$letsencrypt" certonly \
                --standalone --http-01-address "$pages_bind_ip" \
                "${letsencrypt_extra_args[@]}" \
                --email "$email" --agree-tos \
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
source "$SCRIPTDIR/letsencrypt_wrapper.conf" || {
    error "Could not source config file."
    exit 1
}

usage "$@" || exit 1


# obtain and deploy pages certificate ------------
# Pages' webserver can not be configured to alias /.well-known to use webroot
# method so it is needed to stop pages webserver and run certbot in standalone
# mode

pages_service stop || exit 3

obtain_pages_cert || {
    pages_service start || exit 3
    exit 2
}

pages_service start || exit 3
