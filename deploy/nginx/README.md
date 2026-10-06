Fichiers Nginx **hôte** pour Stock Management.

- `stock-management.conf.http.example` — premier vhost (HTTP + ACME)
- `stock-management.conf.https.example` — après Certbot (référence)

Copier vers `/etc/nginx/sites-available/stock-management.conf`.

Ne pas remplacer `/etc/nginx/nginx.conf`.
Ne pas supprimer les vhosts de l’autre application.
Le `proxy_pass` doit correspondre à `API_HOST_PORT` (défaut `127.0.0.1:3100`).
