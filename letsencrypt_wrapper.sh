#!/bin/bash
## letsencrypt_wrapper.sh
#
# this script is used for adding or removing domain names to letsencrypt
# certificate for gitlab and gitlab pages

set -o pipefail
set -o nounset

SCRIPTNAME=${0##*/}
SCRIPTDIR=${0%/*}

USAGE="USAGE
    $SCRIPTNAME [log_level]

    This script will obtain anddeploy certificates for Gitlab
    and Gitlab Pages with domain names specified in configuration
    file '$SCRIPTDIR/letsencrypt_wrapper.conf'

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
# DANGEROUS! it will be expanded without quotes
letsencrypt_extra_args=""

# functions --------------------------------------
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

# usage ------------------------------------------
source "$SCRIPTDIR/letsencrypt_wrapper.conf" || {
    error "Could not source config file."
    exit 1
}

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
        letsencrypt_extra_args+=" --quiet"
        ;;
    "err")
        log_level_i=0
        letsencrypt_extra_args+=" --quiet"
        ;;
    *)
        error "log_level can be set only to 'err','warn' or 'info'"
        exit 1
        ;;
esac

# needed for dummy webserver
cd "$webroot_path" || {
    error "Can not change directory to '$webroot_path'"
    exit 1
}


# main -------------------------------------------

# obtain certificate for gitlab – via webroot method
info "Obtaining Gitlab certificate" >&2
"$letsencrypt" certonly \
  --non-interactive \
  $letsencrypt_extra_args \
  --email "$email" --agree-tos \
  --webroot --webroot-path "$webroot_path" \
  --expand --domains "$gitlab_domains" || {
    error "Failed to obtain certificate for Gitlab domains" >&2
    exit 2
}

info "Restarting nginx" >&2
"$gitlab_sv" restart nginx > /dev/null || {
    error "Failed to restart nginx"
    exit 3
}

