function pdate() {
    echo 
    printf '%.1s' '-'{0..50}
    echo "---[`date +'%Y%m%d-%H:%M:%S'`]---"
}

pdate; echo 'Stop httpd'
service httpd stop

pdate; echo 'Backup gitlab'
/usr/bin/gitlab-rake gitlab:backup:create

pdate; echo 'Restart gitlab'
gitlab-ctl restart

pdate; echo 'Start httpd'
service httpd start
