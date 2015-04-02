# Usage Manual
Host by Apache with https://domain/gitlab/  
Confirmed with GitLab 7.9.x on CentOS 6.x

### Table of Contents
* [Installation](#installation)
* [Upgrade](#upgrade)
* [Backup](#backup)
* [Restore](#restore)
* [See Also](#see-also)

## Installation

The [install.sh](scripts/install.sh) will be used to install and configure the **gitlab** package. The following components will be installed.

| Component | Role | Mode | Status |
|--------------|-----------------------|-------------------|-----------|
| Apache       | HTTP + TLS server     | Stand alone       | enabled   |
| unicorn      | HTTP server for ruby  | GitLab embedded   | enabled   |
| postgresql   | Database server       | GitLab embedded   | enabled   |
| redis        | Cache                 | GitLab embedded   | enabled   |
| sidekiq      | Message Queue         | GitLab embedded   | enabled   |
| nginx        | HTTP + TLS server     | GitLab embedded   | *disabled* |

1. Download the latest [omnibus package][archives]

    ```
    curl -O https://downloads-packages.s3.amazonaws.com/centos-6.6/gitlab-7.9.0_omnibus.1-1.el6.x86_64.rpm
    ```

1. Run [install.sh](scripts/install.sh)

    ```
    sudo install.sh domain gitlab-x.x.x_xxx.rpm
    ```
    * Output
    
        ```
        run: logrotate: (pid 23600) 1077s; run: log: (pid 622) 738877s
        nginx disabled
        run: postgresql: (pid 11427) 226987s; run: log: (pid 626) 738877s
        run: redis: (pid 11448) 226987s; run: log: (pid 625) 738877s
        run: sidekiq: (pid 11453) 226986s; run: log: (pid 627) 738877s
        run: unicorn: (pid 11526) 226981s; run: log: (pid 624) 738877s
        ```

1. Browse to the *https://domain/gitlab* and login by default initial **root** user

    ```
    Username: root
    Password: 5iveL!fe
    ```

## Upgrade

Just download the latest [omnibus package][archives] and then redo the [Installation](#Installtion)

## Backup
See https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/README.md#scheduling-a-backup

* Add the following daily scheduling backup to crontab table (One week backups will be kept)

    ```
    0 4 * * * /usr/bin/gitlab-rake gitlab:backup:create >$HOME/tmp/gitlab-backup.log 2>&1
    ```

## Restore
See https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/README.md#restoring-an-application-backup

## See Also

* Usage Summary of GitLab - [gitlab.md](./doc/gitlab.md)

[archives]: https://about.gitlab.com/downloads/archives/
