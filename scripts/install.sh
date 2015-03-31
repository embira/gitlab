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
    echo "\t`basename $0` <domain> <gitlab-x.x.x_xxx.rpm>"
    echo
    exit 1
fi

# validate gitlab rpm package
[ -f "$2" ] || { echo; errmsg "The [$2] does not exits!"; echo; exit 1; }

# Start installation
#-------------------------------------------------------------
DOMAIN=$1
GITLAB_RPM=$2

pdate; echo 'Install the necessary dependencies'
#-------------------------------------------------------------
yum install -y openssh-server cronie

if pask 'Install postfix'; then
    yum install -y postfix
    service postfix start
    chkconfig postfix on
fi

pdate; echo "Install gitlab rpm package '$GITLAB_RPM'"
#-------------------------------------------------------------
rpm -ivh "$GITLAB_RPM" || { echo; errmsg 'Error: install failed!'; echo; exit 1; }

pdate; echo 'Configure for relative url /gitlab support'
#-------------------------------------------------------------
TPLT_PATH='/opt/gitlab/embedded/cookbooks/gitlab/templates/default'

# Modify gitlab.yml.erb
sed -i -e "s/^[ \t]*#\([ \t]*relative_url_root:[ \t]*/gitlab[ \t]*\)/\1/" ${TPLT_PATH}/gitlab.yml.erb \
|| { echo; errmsg 'Error: uncomment relative_url_root failed!'; echo; exit 1; }

# Modify unicorn.rb.erb
UNICORN="${TPLT_PATH}/unicorn.rb.erb"
if ! grep "ENV['RAILS_RELATIVE_URL_ROOT']" $UNICORN >/dev/null 2>&1; then
    echo -e "\nENV['RAILS_RELATIVE_URL_ROOT'] = \"/gitlab\”" >> $UNICORN \
    || { echo; errmsg 'Error: add RAILS_RELATIVE_URL_ROOT failed!'; echo; exit 1; }
fi

# Modify gitlab-shell-config.yml.erb
sed -i -e "s/([ \t]*gitlab_url: [ \t]*\"http:\/\/.*:8080).*\"/\1\/gitlab\"/" ${TPLT_PATH}/gitlab-shell-config.yml.erb \
|| { echo; errmsg 'Error: add relative path to gitlab_url'; echo; exit 1; }

# Modify nginx-gitlab-http.conf.erb
NGINX="${TPLT_PATH}/nginx-gitlab-http.conf.erb"
if ! grep -e "location[ \t]*/gitlab[ \t]*{" $NGINX >/dev/null 2>&1; then
    sed -i "$i\\\n  location /gitlab {\n    alias /opt/gitlab/embedded/service/gitlab-rails/public;\n    try_files \$uri \$uri/index.html \$uri.html @gitlab;\n  }" $NGINX \
    || { echo; errmsg 'Error: add location /gitlab failed!'; echo; exit 1; }
fi

pdate; echo 'Disable gitlab embedded nginx'
#-------------------------------------------------------------
# disable gitlab embedded nginx 
sed -i -e "s/^.*#[ \t]*(nginx['enable']).*/\1 = false/" /etc/gitlab/gitlab.rb \
|| { echo; errmsg 'Error: disable nginx failed!'; echo; exit 1; }

pdate; echo 'Install into apache'
#-------------------------------------------------------------
if pask 'Install apache mod_ssl'; then
    yum install -y httpd mod_ssl || { echo; errmsg 'Error: install httpd mod_ssl failed!'; echo; exit 1; }
    mkdir -p /etc/httpd/conf.d/ssl
    SSL_CONF='/etc/httpd/conf.d/ssl.conf'
    if ! grep -i -e "[ \t]*Include[ \t]*conf.d/ssl/*.conf" $SSL_CONF; then
        sed -i -e "s/^[ \t]*(<\/VirtualHost>)[ \t]*/Include conf.d/ssl/*.conf\n\1/" $SSL_CONF \
        || { echo; errmsg 'Error: add *.conf to ssl.conf failed!'; echo; exit 1; }
    fi
fi
cp ../etc/gitlab-ssl.conf /etc/httpd/conf.d/ssl/
service httpd configtest || { echo; errmsg 'Error: apache config is error!'; echo; exit 1; }
service httpd restart

pdate; echo 'Reconfigure'
#-------------------------------------------------------------
gitlab-ctl reconfigure || { echo; errmsg 'Error: reconfigure failed!'; echo; exit 1; }
gitlab-ctl restart

pdate; echo 'Install completed!'
#-------------------------------------------------------------
echo 'The following process is running.'
gitlab-ctl status
echo
echo "Enjoy with https://$DOMAIN/gitlab/"
echo

#{+----------------------------------------- Embira Footer 1.7 -------+
# | vim<600:set et sw=4 ts=4 sts=4:                                   |
# | vim600:set et sw=4 ts=4 sts=4 ff=unix cindent fdm=indent fdn=1:   |
# +-------------------------------------------------------------------+}
