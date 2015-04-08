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
    echo
    echo -e "\e[91m$1\e[0m"
    echo
}

# $1: domain
# $2: optional, data dir
function set_etc_gitlab_rb() {
    GITLAB_RB='/etc/gitlab/gitlab.rb'

    pdate; echo 'Set domain'
    sed -i -e "s/^[ \t]*\(external_url\)[ \t]*.*/\1 'https:\/\/$1'/" ${GITLAB_RB}
    sed -i -e "s/gitlab.example.com/$1/" ${GITLAB_RB}
    echo; echo $GITLAB_RB; grep "$1" ${GITLAB_RB} | grep -v ^#

    pdate; echo 'Set backup keep time'
    sed -i -e "s/^[ \t]*#[ \t]*\(gitlab_rails\['backup_keep_time'\].*\)/\1/" ${GITLAB_RB} \
    || { errmsg 'Error: set backup keep time failed!'; exit 1; }
    echo; echo $GITLAB_RB; grep backup_keep_time ${GITLAB_RB} | grep -v ^#

    if [ $# -gt 1 ]; then
        pdate; echo 'Set data dir'
        sed -i -e 's|^.*[ \t]*\(git_data_dir\)[ \t]*.*|\1 "'"$2"'"|g' ${GITLAB_RB}
        echo; echo $GITLAB_RB; grep git_data_dir ${GITLAB_RB} | grep -v ^#

        pdate; echo 'Set backup data dir'
        sed -i -e "s|^.*[ \t]*\(gitlab_rails\['backup_path'\]\)[ \t]*.*|\1 = \"""$2/backups"'"|g' ${GITLAB_RB}
        echo; echo $GITLAB_RB; grep backup_path ${GITLAB_RB} | grep -v ^#
    fi
}

function config_relative_url() {
    TPLT_PATH='/opt/gitlab/embedded/cookbooks/gitlab/templates/default'

    # Modify gitlab.yml.erb
    GITLAB_YML="${TPLT_PATH}/gitlab.yml.erb"
    sed -i -e "s/^[ \t]*#[ \t]*\(relative_url_root:[ \t]*\/gitlab[ \t]*\)/    \1/" ${GITLAB_YML} \
    || { errmsg 'Error: uncomment relative_url_root failed!'; exit 1; }
    echo; echo $GITLAB_YML; grep relative_url_root $GITLAB_YML | grep -v ^#

    # Modify unicorn.rb.erb
    UNICORN="${TPLT_PATH}/unicorn.rb.erb"
    if ! grep "ENV\['RAILS_RELATIVE_URL_ROOT'\]" $UNICORN >/dev/null 2>&1; then
        echo -e "\nENV['RAILS_RELATIVE_URL_ROOT'] = \"/gitlab\"" >> $UNICORN \
        || { errmsg 'Error: add RAILS_RELATIVE_URL_ROOT failed!'; exit 1; }
    fi
    echo; echo $UNICORN; grep "ENV\['RAILS_RELATIVE_URL_ROOT'\]" $UNICORN | grep -v ^#

    # Modify gitlab-shell-config.yml.erb
    SHELL_CONFIG="${TPLT_PATH}/gitlab-shell-config.yml.erb"
    sed -i -e "s/[ \t]*\(gitlab_url:\)[ \t]*\"\(<.*>\).*\"/\1 \"\2\/gitlab\/\"/" ${SHELL_CONFIG} \
    || { errmsg 'Error: add relative path to gitlab_url'; exit 1; }
    echo; echo $SHELL_CONFIG; grep gitlab_url $SHELL_CONFIG | grep -v ^#

    # Modify nginx-gitlab-http.conf.erb
    NGINX="${TPLT_PATH}/nginx-gitlab-http.conf.erb"
    if ! grep -e "location[ \t]*/gitlab[ \t]*{" $NGINX >/dev/null 2>&1; then
        LC_GITLAB="  location \/gitlab {\n    alias \/opt\/gitlab\/embedded\/service\/gitlab-rails\/public;\n    try_files \$uri \$uri\/index.html \$uri.html @gitlab;\n  }"
        sed -i -e "s/\([ \t]*location[ \t]*\/uploads\/[ \t]*{\)/${LC_GITLAB}\n\n\1/" $NGINX \
        || { errmsg 'Error: add location /gitlab failed!'; exit 1; }
    fi
    echo; echo $NGINX; grep -e "location[ \t]*/gitlab[ \t]*{" $NGINX | grep -v ^#
}

function config_host_apache() {
    pdate; echo 'Disable gitlab embedded nginx'
    GITLAB_RB='/etc/gitlab/gitlab.rb'
    sed -i -e "s/^.*#[ \t]*\(nginx\['enable'\]\).*/\1 = false/" ${GITLAB_RB} \
    || { errmsg 'Error: disable nginx failed!'; exit 1; }
    echo; echo $GITLAB_RB; grep -e "nginx\['enable'\]" ${GITLAB_RB} | grep -v ^#

    pdate; echo 'Install apache hosting'
    SSL_CONF='/etc/httpd/conf.d/ssl.conf'
    if pask 'Install httpd mod_ssl'; then
        yum install -y httpd mod_ssl || { errmsg 'Error: install httpd mod_ssl failed!'; exit 1; }
        mkdir -p /etc/httpd/conf.d/ssl
        if ! grep -i -e "[ \t]*Include[ \t]*conf.d/ssl/\*.conf" $SSL_CONF >/dev/null 2>&1; then
            sed -i -e "s/^[ \t]*\(<\/VirtualHost>\)[ \t]*/Include conf.d\/ssl\/*.conf\n\n\1/" $SSL_CONF \
            || { errmsg 'Error: add *.conf to ssl.conf failed!'; exit 1; }
        fi
    fi
    echo; echo $SSL_CONF; grep Include ${SSL_CONF} | grep -v ^#

    if [ ! -f '/etc/httpd/conf.d/ssl/gitlab-ssl.conf' ]; then
        FPATH="$(dirname `readlink -e $0`)"
        cp "${FPATH%/*}/etc/gitlab-ssl.conf" /etc/httpd/conf.d/ssl/ \
        || { errmsg 'Error: install gitlab-ssl.conf failed!'; exit 1; }
        sed -i -e "s/gitlab.example.com/$DOMAIN/" /etc/httpd/conf.d/ssl/gitlab-ssl.conf
    fi
    ls -l /etc/httpd/conf.d/ssl/gitlab-ssl.conf

    service httpd configtest || { errmsg 'Error: apache config is error!'; exit 1; }
    service httpd restart
}

# Validate
#-------------------------------------------------------------

# Validate user
[ 'root' = "$USER" ] || { errmsg 'Try sudo!'; exit 1; }

# Validate parameters count
if [ $# -lt 2 ]; then
    echo
    echo 'Usage:'
    echo "        `basename $0` <domain> <gitlab-x.x.x_xxx.rpm> [data_dir]"
    echo
    exit 1
fi

# validate gitlab rpm package
[ -f "$2" ] || { errmsg "Error: The [$2] does not exits!"; exit 1; }
echo $2 | grep "`uname -i`" >/dev/null 2>&1 || { errmsg "Error: [$2] does not support `uname -i`!"; exit 1; }
which rpm >/dev/null 2>&1 || { errmsg 'Error: rpm command not found!'; exit 1; }

# Start installation
#-------------------------------------------------------------
DOMAIN="$1"
GITLAB_RPM="$2"
GITLAB_DATADIR=''
if [ $# -gt 2 ]; then
    pdate
    if pask "Do you want to install data dir to [$3]"; then
        if [ -d "$3" ]; then
            pask "[$3] had exist! Do you want to overwrite it" || { echo; echo 'Goodbye.'; echo; exit 1; }
        fi
    fi
    GITLAB_DATADIR="$3"
fi

pdate
#-------------------------------------------------------------
if pask 'Install the necessary dependencies'; then
    yum install -y openssh-server cronie || { errmsg 'Error: install openssh-server & cronie failed!'; exit 1; }
fi

if pask 'Install postfix'; then
    yum install -y postfix
    service postfix start
    chkconfig postfix on
fi

pdate; echo "Install gitlab rpm package '$GITLAB_RPM'"
#-------------------------------------------------------------
rpm -Uvh "$GITLAB_RPM" || {
    errmsg 'Error: install gitlab rpm package failed!'
    pask 'Continue' || exit 1
}

set_etc_gitlab_rb $DOMAIN $GITLAB_DATADIR

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
gitlab-ctl reconfigure || { errmsg 'Error: reconfigure failed!'; exit 1; }

pdate; echo 'Restart gitlab'
#-------------------------------------------------------------
echo
gitlab-ctl restart

pdate; echo 'Install completed!'
#-------------------------------------------------------------
echo 'The following processes are running.'
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
