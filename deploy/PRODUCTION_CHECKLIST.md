# Checklist production — Stock Management

Rien n’est coché tant que ce n’est pas **fait sur le VPS**. Ce fichier ne prouve pas un déploiement.

## Isolation

- [ ] utilisateur Linux `stockapp` créé
- [ ] `stockapp` n’est **pas** dans le groupe `docker` système
- [ ] Docker rootless installé pour `stockapp`
- [ ] `loginctl enable-linger stockapp`
- [ ] répertoires `/opt/stock-management/{app,data,backups,logs,deploy}`
- [ ] permissions : `750` sur la racine, `700` sur `data/` et `backups/`
- [ ] aucun fichier mélangé avec le home / compose de `deploy`

## Base de données

- [ ] PostgreSQL `stockapp_postgres` uniquement sur `stockapp_net`
- [ ] aucun publish de `5432` sur l’hôte
- [ ] volume persistant `/opt/stock-management/data/postgres`
- [ ] user / mot de passe / base dédiés
- [ ] `npx prisma migrate deploy` (démarrage du conteneur)
- [ ] **pas** de `prisma migrate reset`

## Backend

- [ ] `.env.production` chmod 600, secrets réels (pas les placeholders)
- [ ] `NODE_ENV=production`
- [ ] `JWT_SECRET` ≥ 32 caractères, unique
- [ ] `ALLOW_REGISTER=false`
- [ ] `CORS_ORIGIN` HTTPS explicite (pas `*`)
- [ ] API bind `127.0.0.1:${API_HOST_PORT}` (défaut 3100)
- [ ] healthcheck `http://127.0.0.1:3100/api/health`
- [ ] logs sans mot de passe / token / `DATABASE_URL`
- [ ] conteneur non-root (`USER stockapp`)

## Nginx / DNS / HTTPS

- [ ] fichier **ajouté** `/etc/nginx/sites-available/stock-management.conf`
- [ ] `/etc/nginx/nginx.conf` **non remplacé**
- [ ] sites de l’autre application intacts
- [ ] DNS A vers `164.132.101.55` (ou IP actuelle)
- [ ] certificat Let’s Encrypt pour le vrai domaine
- [ ] `https://…/api/health` OK
- [ ] aucune clé privée dans Git

## Firewall / restart

- [ ] 22 / 80 / 443 publics seulement (pour ce besoin)
- [ ] 3100 non public
- [ ] 5432 non public
- [ ] `restart: unless-stopped`
- [ ] systemd user `stock-management.service` enabled
- [ ] test après reboot

## Sauvegardes

- [ ] `./scripts/backup-postgres.sh` OK
- [ ] dumps dans `/opt/stock-management/backups/`
- [ ] cron ou équivalent
- [ ] copie hors serveur
- [ ] restore testé au moins une fois

## Client

- [ ] APK release avec `--dart-define=API_BASE_URL=https://<domaine>/api`
- [ ] keystore hors Git
- [ ] test login / achat / vente / stock depuis un téléphone
- [ ] le client n’a pas Node, Docker ni le code source
