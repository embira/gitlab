# Usage Summary of GitLab 

* Confirmed with
    * GitLab 7.9.x
    * CentOS 6.x

---

[TOC]

## Installation

Host by nginx with http://domain/

Components will be installed

| Component | Port | Role | Mode |
|--------------|--------|-----------------------|-------------------|
| unicorn      | 8080   | HTTP server for ruby  | GitLab embedded   |
| postgresql   | ????   | Database server       | GitLab embedded   |
| redis        | ????   | Cache                 | GitLab embedded   |
| sidekiq      | ????   | Message Queue         | GitLab embedded   |
| nginx        | 80/443 | HTTP + TLS server     | GitLab embedded   |


1. Install the necessary dependencies

    ```
    sudo yum install openssh-server postfix cronie
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

1. Browse to the hostname and login with default initial **root** user

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

1. Add custom port at the tail of `external_url` in `/etc/gitlab/gitlab.rb`

    ```
    external_url 'http://domain:port/'
    ```
    
1. Reconfigure

    ```
    sudo gitlab-ctl reconfigure
    ```

1. Confirm by http://domain:port/

## Enable HTTPS with nginx

See also: https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/doc/settings/nginx.md#enable-https

1. Create SSL/TLS certification & key (see [tls.md](./docs/tls.md))

1. Deploy `domain.key` & `domain.crt` to `/etc/gitlab/ssl`

    ```
    sudo mkdir -p /etc/gitlab/ssl
    sudo chmod 700 /etc/gitlab/ssl
    mv domain.{key,crt} /etc/gitlab/ssl
    ```

1. Modify `/etc/gitlab/gitlba.rb`

    ```
    external_url https://domain/
    ...
    nginx['redirect_http_to_https'] = true
    ```

1. Reconfigure and restart

    ```
    sudo gitlab-ctl reconfigure
    sudo gitlab-ctl restart
    ```

1. Confirm by
    * https://domain/
    * http://domain/ (will be redirect to https)

## Disable User Register

Just login as **root**, and then disable the *Signup enabled* option in *Admin area*.

## Relative URL Support

* Relative url support in `/opt/gitlab/embedded/service/gitlab-rails/config/application.rb` (**PAT: `gitlab-ctl reconfigure` will discard all of the following settings by manually.**)
    
    ```
    # Relative url support
    # Uncomment and customize the last line to run in a non-root path
    # WARNING: We recommend creating a FQDN to host GitLab in a root path instead of this.
    # Note that following settings need to be changed for this to work.
    # 1) In your application.rb file: config.relative_url_root = "/gitlab"
    # 2) In your gitlab.yml file: relative_url_root: /gitlab
    # 3) In your unicorn.rb: ENV['RAILS_RELATIVE_URL_ROOT'] = "/gitlab"
    # 4) In ../gitlab-shell/config.yml: gitlab_url: "http://127.0.0.1/gitlab"
    # 5) In lib/support/nginx/gitlab : do not use asset gzipping, remove block starting with "location ~ ^/(assets)/"
    #
    # To update the path, run: sudo -u git -H bundle exec rake assets:precompile RAILS_ENV=production
    #
    ```
    See also: ​http://urashita.com/archives/3074

* [Host by subdirectory](subdirectory): is the better to modify the meta template than the result configure files.

    * `/opt/gitlab/embedded/cookbooks/gitlab/templates/default/gitlab.yml.erb`

        Uncomment the **relative\_url\_root**.
    
        ```
        relative_url_root: /gitlab
        ```
    
    * `/opt/gitlab/embedded/cookbooks/gitlab/templates/default/unicorn.rb.erb`

        Add the following to the end of the file.
        
        ```
        ENV['RAILS_RELATIVE_URL_ROOT'] = "/gitlab”
        ```

    * `/opt/gitlab/embedded/cookbooks/gitlab/templates/default/gitlab-shell-config.yml.erb`
  
        Add relative path */gitlab* to the tail of `gitlab_url`.

        ```
        gitlab_url: "http://127.0.0.1:8080/gitlab"
        ```

    * `/opt/gitlab/embedded/cookbooks/gitlab/templates/default/nginx-gitlab-http.conf.erb`
    
        Add the **'location /gitlab'** setting.

        ```
        90   location /gitlab {
        91     ## Serve static files from defined root folder.
        92     ## @gitlab is a named location for the upstream fallback, see below.
        93     alias /opt/gitlab/embedded/service/gitlab-rails/public;
        94     try_files $uri $uri/index.html $uri.html @gitlab;
        95   }
        ```

    * Reconfigure

        ```
        sudo gitlab-ctl reconfigure
        ```

## References

* GitLab offical site: https://about.gitlab.com/

| Contents | URL |
|--------|--------|
| All CE versions      | https://about.gitlab.com/downloads/archives/ |
| Offical installation | https://about.gitlab.com/downloads/ |
| Update instruction   | https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/doc/update.md |
| Setting              | https://gitlab.com/gitlab-org/omnibus-gitlab/tree/master/doc/settings |

* Host by subdirectory **/gitlab**: http://qiita.com/tnamao/items/a7bb1ca868b594eaf788


[archives]: https://about.gitlab.com/downloads/archives/
[subdirectory]: http://qiita.com/tnamao/items/a7bb1ca868b594eaf788