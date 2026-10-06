# Déploiement VPS OVH — Stock Management

Ce document prépare le déploiement. **Il n’a pas été exécuté sur le VPS.** L’IP actuelle indiquée est `164.132.101.55`.

L’autre application (utilisateur `deploy`) **ne doit pas être arrêtée ni reconfigurée**.

Stock Management utilise un utilisateur et des ressources séparés :

| | Autre application | Stock Management |
|---|---|---|
| Utilisateur Linux | `deploy` | `stockapp` |
| Répertoire | (existant, ne pas toucher) | `/opt/stock-management/` |
| Docker Compose | projet existant | `stock-management` |
| PostgreSQL | existant | `stockapp_postgres` (réseau `stockapp_net` uniquement) |
| API | existante | `127.0.0.1:3100` (configurable) |
| Nginx | site existant | fichier **ajouté** `sites-available/stock-management.conf` |
| Domaine placeholder | — | `api-stock.example.com` |

Architecture :

```text
Internet
  → HTTPS (Nginx hôte, déjà présent)
    → 127.0.0.1:3100
      → conteneur stockapp_api
        → PostgreSQL stockapp_postgres (réseau Docker privé)
```

Le client final n’a besoin que de l’APK. Pas de Node, Docker, PostgreSQL ni accès VPS.

---

## 1. Créer l’utilisateur `stockapp`

En root ou via sudo (sans utiliser `deploy` pour les fichiers de Stock Management) :

```bash
sudo adduser --disabled-password --gecos "Stock Management" stockapp
sudo mkdir -p /opt/stock-management/{app,data/postgres,backups,logs,deploy}
sudo chown -R stockapp:stockapp /opt/stock-management
sudo chmod 750 /opt/stock-management
sudo chmod 700 /opt/stock-management/data /opt/stock-management/data/postgres /opt/stock-management/backups
```

Ne **pas** ajouter `stockapp` au groupe `docker` système : ce groupe équivaut à un accès root.

---

## 2. Docker rootless pour `stockapp`

Se connecter en `stockapp` :

```bash
sudo -iu stockapp
```

Installer le moteur rootless (uidmap / dbus déjà souvent présents sur Debian/Ubuntu) :

```bash
curl -fsSL https://get.docker.com/rootless | sh
```

Ajouter dans `~/.bashrc` (adapter le chemin si le script l’affiche autrement) :

```bash
export PATH="$HOME/bin:$PATH"
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
```

```bash
source ~/.bashrc
dockerd-rootless-setuptool.sh install
systemctl --user enable --now docker
sudo loginctl enable-linger stockapp
docker info
```

`linger` permet au Docker user et à Compose de démarrer après reboot **sans session SSH**.

Vérifier que `docker ps` fonctionne **sans sudo**.

---

## 3. Répertoires

```text
/opt/stock-management/
├── app/              code + compose + .env.production
├── data/postgres/    volume PostgreSQL (chmod 700)
├── backups/          dumps gzip (chmod 700, hors Git)
├── logs/             copies éventuelles de logs
└── deploy/           extraits de config Nginx / systemd
```

Les données PostgreSQL restent dans `data/postgres`, inaccessibles aux autres utilisateurs Unix.

---

## 4. Transférer le projet

Depuis votre PC (PowerShell), **sans** `node_modules` ni secrets :

```powershell
rsync -avz --exclude node_modules --exclude mobile/build --exclude .git --exclude .env --exclude .env.production --exclude backups `
  ./ stockapp@164.132.101.55:/opt/stock-management/app/
```

Ou copier une archive. Travailler ensuite :

```bash
sudo -iu stockapp
cd /opt/stock-management/app
```

---

## 5. Configurer `.env.production`

```bash
cp .env.production.example .env.production
nano .env.production
chmod 600 .env.production
```

Remplacer tous les placeholders :

- `POSTGRES_PASSWORD` (fort, unique, différent de l’autre appli)
- `DATABASE_URL` (même user/mot de passe/base ; encoder `@ : / %` dans le mot de passe)
- `JWT_SECRET` (≥ 32 caractères aléatoires)
- `CORS_ORIGIN=https://api-stock.example.com` (votre vrai domaine plus tard)
- `API_HOST_PORT=3100` (changer si déjà pris : `ss -lntp | grep 3100`)
- `ALLOW_REGISTER=false`

Ne jamais réutiliser le JWT ou le mot de passe PostgreSQL de l’application `deploy`.

---

## 6. Lancer PostgreSQL

```bash
cd /opt/stock-management/app
docker compose --env-file .env.production -f docker-compose.prod.yml up -d postgres
docker compose --env-file .env.production -f docker-compose.prod.yml ps
```

Aucun port `5432` n’est publié sur l’hôte.

---

## 7. Prisma migrate deploy

Les migrations partent **au démarrage du conteneur backend** (`npx prisma migrate deploy`).

Ne jamais exécuter `prisma migrate reset` sur ce serveur.

---

## 8. Lancer le backend

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --build
```

Le mapping est `127.0.0.1:${API_HOST_PORT} → ${PORT}` (défaut `127.0.0.1:3100 → 3000`).

---

## 9. Vérifier health

```bash
curl -sS http://127.0.0.1:3100/api/health
```

Réponse attendue : `"success": true` et `"database": "up"`.

Cela ne doit **pas** répondre depuis Internet sur le port 3100.

---

## 10. Configurer Nginx (hôte, sans toucher l’autre site)

En root, **ajouter** un fichier, ne pas remplacer `/etc/nginx/nginx.conf` :

```bash
sudo mkdir -p /var/www/certbot
sudo cp /opt/stock-management/app/deploy/nginx/stock-management.conf.http.example \
  /etc/nginx/sites-available/stock-management.conf
sudo nano /etc/nginx/sites-available/stock-management.conf
```

Remplacer `api-stock.example.com` et, si besoin, `3100`.

```bash
sudo ln -s /etc/nginx/sites-available/stock-management.conf /etc/nginx/sites-enabled/stock-management.conf
sudo nginx -t
sudo systemctl reload nginx
```

Les `server_name` de l’autre application restent inchangés.

---

## 11. DNS

Créer un enregistrement **A** :

```text
api-stock.example.com  →  164.132.101.55
```

(utiliser le vrai domaine lorsqu’il sera choisi.)

---

## 12. HTTPS (Let’s Encrypt)

Quand le DNS est propagé, **ne pas** générer de certificat fictif :

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api-stock.example.com
```

Certbot met à jour uniquement le vhost Stock Management. Tester :

```bash
curl -sS https://api-stock.example.com/api/health
```

Renouvellement : le timer systemd `certbot.timer` suffit en général. Vérifier :

```bash
sudo systemctl status certbot.timer
```

Les clés privées restent dans `/etc/letsencrypt/` (hors Git).

---

## 13. Tester l’API

```bash
curl -sS https://api-stock.example.com/api/health
curl -sS -X POST https://api-stock.example.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@stock.local","password":"CHANGEZ-MOI"}'
```

Le seed n’est **pas** lancé automatiquement. Si la base est vide, optionnellement (puis changer les mots de passe) :

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml exec backend node prisma/seed.js
```

---

## 14. Sauvegardes

Emplacement : `/opt/stock-management/backups/` (permissions `700`, fichiers `600`).

Manuel :

```bash
cd /opt/stock-management/app
chmod +x scripts/backup-postgres.sh scripts/restore-postgres.sh
./scripts/backup-postgres.sh
```

Cron quotidien (crontab de `stockapp`) :

```cron
15 2 * * * /opt/stock-management/app/scripts/backup-postgres.sh >> /opt/stock-management/logs/backup.log 2>&1
```

Conserver au moins 14 jours + une copie hors VPS. Ne pas supprimer automatiquement sans politique.

Restauration (écrase la base) :

```bash
./scripts/restore-postgres.sh /opt/stock-management/backups/stock-YYYYMMDD-HHMMSS.sql.gz
```

Tester une restauration sur une copie avant un incident réel.

---

## 15. Redémarrage après reboot

Deux mécanismes complémentaires (ne pas lancer deux stacks Compose) :

1. `restart: unless-stopped` sur les conteneurs.
2. Linger + Docker user + unité systemd **utilisateur**.

```bash
sudo -iu stockapp
mkdir -p ~/.config/systemd/user
cp /opt/stock-management/app/deploy/systemd/stock-management.user.service.example \
  ~/.config/systemd/user/stock-management.service
systemctl --user daemon-reload
systemctl --user enable --now stock-management.service
```

Vérifier après un reboot programmé :

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml ps
curl -sS http://127.0.0.1:3100/api/health
```

---

## 16. Firewall

Ports publics utiles : **22, 80, 443**.

Ne pas ouvrir **3100** ni **5432**.

Ne pas exécuter de `ufw reset` : l’autre application dépend déjà du firewall.

Contrôle (sans tout casser) :

```bash
sudo ss -lntp | grep -E ':80|:443|:3100|:5432'
```

`3100` doit écouter uniquement sur `127.0.0.1`. `5432` ne doit pas apparaître sur l’interface publique.

Si UFW est déjà actif :

```bash
sudo ufw status
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

N’ajoutez `ufw enable` que si le firewall n’est pas déjà en production.

---

## 17. Flutter production

Development (émulateur) :

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Production (APK) — **obligatoire**, sinon le build release refuse localhost / 10.0.2.2 :

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api-stock.example.com/api \
  --dart-define=APP_ENV=production
```

Remplacer le domaine par le vrai hostname HTTPS.

Fichier : `mobile/build/app/outputs/flutter-apk/app-release.apk`

Keystore : `mobile/android/key.properties.example` (ne jamais committer le `.jks` ni `key.properties`).

---

## Dépannage

| Symptôme | Piste |
|---|---|
| Port 3100 déjà pris | Changer `API_HOST_PORT` et le `proxy_pass` Nginx |
| Health 503 database | PostgreSQL pas healthy, `DATABASE_URL` incorrecte |
| JWT au démarrage | Secret trop court / placeholder |
| CORS | Doit être l’origine HTTPS exacte, pas `*` |
| 3100 visible sur Internet | Bind `API_HOST_BIND=127.0.0.1` et recharger Compose |
| Collision avec l’autre appli | Vérifier noms `stockapp_*` et réseau `stockapp_net` |
