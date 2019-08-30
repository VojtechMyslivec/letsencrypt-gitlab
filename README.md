# letsencrypt-gitlab

A wrapper to obtain letsencrypt certificate for Gitlab Pages

Needed tools:
- [gitlab](https://about.gitlab.com/downloads/)
- [certbot](https://github.com/certbot/certbot)


## Gitlab Pages certificate

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


## Cron job

A suitable cron job for renewing certificate is

```cron
0 5 * * * root /opt/letsencrypt-gitlab/letsencrypt_wrapper.sh warn
```
