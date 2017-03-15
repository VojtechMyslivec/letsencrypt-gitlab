# letsencrypt-gitlab

A wrapper to obtain letsencrypt certificate for Gitlab and Gitlab Pages

Needed tools:
- [gitlab](https://about.gitlab.com/downloads/)
- [certbot](https://github.com/certbot/certbot)

## Gitlab certificate

It is needed to add a custom configuration in `gitlab.rb`:

```conf
nginx['custom_gitlab_server_config'] = "location ^~ /.well-known {
    root /var/www/letsencrypt;
  }"
nginx['ssl_certificate'] = "/etc/letsencrypt/live/git.example.cz/fullchain.pem"
nginx['ssl_certificate_key'] = "/etc/letsencrypt/live/git.example.cz/privkey.pem"
```
