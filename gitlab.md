# Usage Summary of GitLab 
---

[TOC]

## Installation

Host by nginx with http://domain/

* Components will be installed

 | Component | Role | Mode |
 |--------------|-----------------------|-------------------|
 | unicorn      | HTTP server for ruby  | GitLab embedded   |
 | postgresql   | Database server       | GitLab embedded   |
 | redis        | Cache                 | GitLab embedded   |
 | sidekiq      | Message Queue         | GitLab embedded   |
 | nginx        | HTTP + TLS server     | GitLab embedded   |

1. Install the necessary dependencies

    ```
    sudo yum install openssh-server, postfix, cronie
    sudo service postfix start
    sudo chkconfig postfix on
    ```

1. Download the latest [omnibus package][archives] and install

    ```
    curl -O https://downloads-packages.s3.amazonaws.com/centos-6.6/ 
    gitlab-7.9.0_omnibus.1-1.el6.x86_64.rpm
    sudo rpm -i gitlab-7.9.0_omnibus.1-1.el6.x86_64.rpm
    ```

1. Configure and start `gitlab`

    ```
    sudo gitlab-ctl reconfigure
    ```

  * Confirm

        ```
        sudo gitlab-ctl status
        ```

1. Browse to the hostname and login
  * Default initial **root** user

    ```
    Username: root
    Password: 5iveL!fe
    ```

## Upgrade

1. Download the latest [omnibus package][archives]

    ```
    wget https://downloads-packages.s3.amazonaws.com/centos-6.6/gitlab-x.x.x_xxx.rpm
    ```

1. Upgrade rpm package

    ```
    sudo rpm -Uvh gitlab-x.x.x_xxx.rpm
    ```
    
1. Reconfigure

    ```
    sudo gitlab-ctl reconfigure
    sudo gitlab-ctl restart
    ```

## Customize Port

## Enable SSL/TLS

## Disable User Register

## Relative URL Support

## References

* GitLab offical site: https://about.gitlab.com/


 | Contents | URL |
 |--------|--------|
 | All CE versions      | https://about.gitlab.com/downloads/archives/ |
 | Offical installation | https://about.gitlab.com/downloads/ |
 | Update instruction   | https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/doc/update.md |

* Host by subdirectory **/gitlab**: http://qiita.com/tnamao/items/a7bb1ca868b594eaf788

[archives]: https://about.gitlab.com/downloads/archives/
