# letsencrypt-gitlab

A wrapper to obtain letsencrypt certificate for Gitlab and Gitlab Pages

Needed tools:
- [gitlab](https://about.gitlab.com/downloads/)
- [certbot](https://github.com/certbot/certbot)
- [python3](https://www.python.org/)

## Gitlab certificate

It is needed to add a custom configuration in `gitlab.rb`:

```conf
nginx['custom_gitlab_server_config'] = "location ^~ /.well-known {
    root /var/www/letsencrypt;
  }"
nginx['ssl_certificate'] = "/etc/letsencrypt/live/git.example.cz/fullchain.pem"
nginx['ssl_certificate_key'] = "/etc/letsencrypt/live/git.example.cz/privkey.pem"
```

## Gitlab pages certificate

It is needed to add a custom configuration in `gitlab.rb`:

```conf
nginx['listen_addresses'] = ['1.2.3.4']

pages_external_url 'https://pages.example.cz'
pages_nginx['enable'] = false
gitlab_pages['external_http'] = '2.3.4.5:80'
gitlab_pages['external_https'] = '2.3.4.5:443'
gitlab_pages['cert'] = "/etc/letsencrypt/live/pages.example.cz/fullchain.pem"
gitlab_pages['cert_key'] = "/etc/letsencrypt/live/pages.example.cz/privkey.pem"
```

There is an [open issue](https://gitlab.com/gitlab-org/gitlab-pages/issues/10)
for Gitlab *Pages with https*. Actually the `/dev/urandom` device is missing in Pages *chroot*.
Workaround is to create it manually with:

```sh
chroot="/var/opt/gitlab/gitlab-rails/shared/pages"
mkdir -p "$chroot/dev"
mknod -m 666 "$chroot/dev/urandom" c 1 9
```

## Cron job

A suitable cron job for renewing certificate is

```cron
0 5 * * * root /opt/letsencrypt-gitlab/letsencrypt_wrapper.sh warn
```
