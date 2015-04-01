#!/bin/sh
# Created at: 2015-03-31 15:57:35
#-------------------------------------------------------------

# Global setting
#-------------------------------------------------------------
function pdate() {
    echo 
    printf '%.1s' '-'{0..50}
    echo "---[`date +'%Y%m%d-%H:%M:%S'`]---"
}

# $1: message
# return 0 for yes or 1 for no
function pask() {
    local lflag
    while :; do
        read -p "$1 ... [y/n]? " lflag
        if [ 'y' = "$lflag" ]; then
            return 0
        elif [ 'n' = "$lflag" ]; then
            echo 'Skip.'
            return 1
        else
            echo 'Please enter "y" to continue or "n" to skip.'
        fi
    done
}

# $1: message
function errmsg() {
    echo -e "\e[91m$1\e[0m"
}

function config_relative_url() {
    TPLT_PATH='/opt/gitlab/embedded/cookbooks/gitlab/templates/default'

    # Modify gitlab.yml.erb
    GITLAB_YML="${TPLT_PATH}/gitlab.yml.erb"
    sed -i -e "s/^[ \t]*#[ \t]*\(relative_url_root:[ \t]*\/gitlab[ \t]*\)/    \1/" ${GITLAB_YML} \
    || { echo; errmsg 'Error: uncomment relative_url_root failed!'; echo; exit 1; }
    grep -H relative_url_root $GITLAB_YML

    # Modify unicorn.rb.erb
    UNICORN="${TPLT_PATH}/unicorn.rb.erb"
    if ! grep "ENV\['RAILS_RELATIVE_URL_ROOT'\]" $UNICORN >/dev/null 2>&1; then
        echo -e "\nENV['RAILS_RELATIVE_URL_ROOT'] = \"/gitlab\"" >> $UNICORN \
        || { echo; errmsg 'Error: add RAILS_RELATIVE_URL_ROOT failed!'; echo; exit 1; }
    fi
    grep -H "ENV\['RAILS_RELATIVE_URL_ROOT'\]" $UNICORN

    # Modify gitlab-shell-config.yml.erb
    SHELL_CONFIG="${TPLT_PATH}/gitlab-shell-config.yml.erb"
    sed -i -e "s/[ \t]*\(gitlab_url:\)[ \t]*\"\(<.*>\).*\"/\1 \"\2\/gitlab\/\"/" ${SHELL_CONFIG} \
    || { echo; errmsg 'Error: add relative path to gitlab_url'; echo; exit 1; }
    grep -H gitlab_url $SHELL_CONFIG

    # Modify nginx-gitlab-http.conf.erb
    NGINX="${TPLT_PATH}/nginx-gitlab-http.conf.erb"
    if ! grep -e "location[ \t]*/gitlab[ \t]*{" $NGINX >/dev/null 2>&1; then
        LC_GITLAB="  location \/gitlab {\n    alias \/opt\/gitlab\/embedded\/service\/gitlab-rails\/public;\n    try_files \$uri \$uri\/index.html \$uri.html @gitlab;\n  }"
        sed -i -e "s/\([ \t]*location[ \t]*\/uploads\/[ \t]*{\)/${LC_GITLAB}\n\n\1/" $NGINX \
        || { echo; errmsg 'Error: add location /gitlab failed!'; echo; exit 1; }
    fi
    grep -H -e "location[ \t]*/gitlab[ \t]*{" $NGINX
}

function config_host_apache() {
    pdate; echo 'Disable gitlab embedded nginx'
    GITLAB_RB='/etc/gitlab/gitlab.rb'
    sed -i -e "s/^.*#[ \t]*\(nginx\['enable'\]\).*/\1 = false/" ${GITLAB_RB} \
    || { echo; errmsg 'Error: disable nginx failed!'; echo; exit 1; }
    sed -i -e "s/gitlab.example.com/$DOMAIN/" ${GITLAB_RB}
    grep -H -e "nginx\['enable'\]" ${GITLAB_RB}

    pdate; echo 'Install apache hosting'
    SSL_CONF='/etc/httpd/conf.d/ssl.conf'
    if pask 'Install apache mod_ssl'; then
        yum install -y httpd mod_ssl || { echo; errmsg 'Error: install httpd mod_ssl failed!'; echo; exit 1; }
        mkdir -p /etc/httpd/conf.d/ssl
        if ! grep -i -e "[ \t]*Include[ \t]*conf.d/ssl/\*.conf" $SSL_CONF >/dev/null 2>&1; then
            sed -i -e "s/^[ \t]*\(<\/VirtualHost>\)[ \t]*/Include conf.d\/ssl\/*.conf\n\n\1/" $SSL_CONF \
            || { echo; errmsg 'Error: add *.conf to ssl.conf failed!'; echo; exit 1; }
        fi
    fi
    grep -H Include ${SSL_CONF}

    if [ ! -f '/etc/httpd/conf.d/ssl/gitlab-ssl.conf' ]; then
        FPATH="$(dirname `readlink -e $0`)"
        cp "${FPATH%/*}/etc/gitlab-ssl.conf" /etc/httpd/conf.d/ssl/ \
        || { echo; errmsg 'Error: install gitlab-ssl.conf failed!'; echo; exit 1; }
        sed -i -e "s/gitlab.example.com/$DOMAIN/" /etc/httpd/conf.d/ssl/gitlab-ssl.conf
    fi
    ls -l /etc/httpd/conf.d/ssl/gitlab-ssl.conf

    service httpd configtest || { echo; errmsg 'Error: apache config is error!'; echo; exit 1; }
    service httpd restart
}

# Validate
#-------------------------------------------------------------

# Validate user
[ 'root' = "$USER" ] || { echo; echo 'Try sudo!'; echo; exit 1; }

# validate os
if ! grep -ie '.*CentOS.* 6.[0-9]\+ .*' /etc/system-release >/dev/null 2>&1; then
    echo
    echo 'Only for CentOS 6.x .'
    echo "But this system is `[ cat /etc/system-release 2>/dev/null ] || echo unknown`."
    echo
    exit 1
fi

# Validate system platform
if [ "`uname -i`" != 'x86_64' ]; then
    echo
    echo 'Only for x86_64 platform.'
    echo "But this platform is `uname -i`."
    echo
    exit 1
fi

# Validate parameters count
if [ $# -ne 2 ]; then
    echo
    echo 'Usage:'
    echo "        `basename $0` <domain> <gitlab-x.x.x_xxx.rpm>"
    echo
    exit 1
fi

# validate gitlab rpm package
[ -f "$2" ] || { echo; errmsg "The [$2] does not exits!"; echo; exit 1; }

# Start installation
#-------------------------------------------------------------
DOMAIN=$1
GITLAB_RPM=$2

pdate
#-------------------------------------------------------------
if pask 'Install the necessary dependencies'; then
    yum install -y openssh-server cronie \
    || { echo; errmsg 'Error: install openssh-server & cronie failed!'; echo; exit 1; }
fi

if pask 'Install postfix'; then
    yum install -y postfix
    service postfix start
    chkconfig postfix on
fi

pdate; echo "Install gitlab rpm package '$GITLAB_RPM'"
#-------------------------------------------------------------
rpm -Uvh "$GITLAB_RPM" || {
    echo 
    errmsg 'Error: install gitlab rpm package failed!'
    echo
    pask 'Continue' || exit 1
}

# Configure for relative url support
#-------------------------------------------------------------
pdate
if pask 'Configure for relative url /gitlab support'; then
    config_relative_url
    echo
    if pask 'Configure for hosting by apache'; then
        config_host_apache
    fi
fi

pdate; echo 'Reconfigure gitlab'
#-------------------------------------------------------------
gitlab-ctl reconfigure || { echo; errmsg 'Error: reconfigure failed!'; echo; exit 1; }

pdate; echo 'Restart gitlab'
#-------------------------------------------------------------
echo
gitlab-ctl restart

pdate; echo 'Install completed!'
#-------------------------------------------------------------
echo 'The following process is running.'
echo
gitlab-ctl status

pdate
echo 'Maybe, you wanna disable the "Signup enabled" option from "Admin area" by root.'
echo
echo "Enjoy with https://$DOMAIN/gitlab/"
echo

#{+----------------------------------------- Embira Footer 1.7 -------+
# | vim<600:set et sw=4 ts=4 sts=4:                                   |
# | vim600:set et sw=4 ts=4 sts=4 ff=unix cindent fdm=indent fdn=1:   |
# +-------------------------------------------------------------------+}
