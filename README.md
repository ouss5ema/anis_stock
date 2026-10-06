# StockManager

Application mobile de gestion de stock pour un distributeur commercial (tabac, recharges télécom et autres catégories).

Le stock n’est jamais modifié directement sur le produit. Il évolue uniquement par achat, vente, annulation ou ajustement, dans une transaction Prisma, avec un mouvement d’historique.

## 1. Présentation

StockManager permet d’enregistrer quotidiennement :

- les réceptions fournisseur (achats) ;
- les ventes clients ;
- le suivi du stock (faible / rupture) ;
- les ajustements d’inventaire (administrateur) ;
- le tableau de bord du jour, 7 jours ou 30 jours.

Comptes de démonstration (seed) :

- `admin@stock.local` / `Admin123!`
- `user@stock.local` / `User123!`

## 2. Architecture

```text
stock-management/
├── backend/                 API Express + Prisma
├── mobile/                  Application Flutter
├── docker-compose.yml       PostgreSQL (+ API locale)
├── docker-compose.prod.yml  PostgreSQL + API (bind 127.0.0.1:3100)
├── nginx/                   Référence seulement (VPS déjà avec Nginx)
├── deploy/                  VPS, Nginx hôte, systemd, checklist
├── scripts/                 Sauvegarde / restauration PostgreSQL
└── README.md
```

Flux production :

```text
Internet → Nginx (HTTPS) → Express → PostgreSQL
```

## 3. Stack

- Backend : Node.js 20+, Express 5, Prisma 6, PostgreSQL 16, JWT, Zod, Helmet
- Mobile : Flutter 3, Dart 3, Riverpod, go_router, Dio, Decimal
- Montants : `Decimal(12,3)` affichés en DT, ex. `25.500 DT`

## 4. Installation locale

Prérequis : Node.js 20+, npm 10+, Flutter 3.24+, Docker Desktop.

## 5. PostgreSQL

```bash
docker compose up -d postgres
```

Identifiants locaux par défaut : `stock` / `stock`, base `stock_management`, port `5432`.

Si 5432 est occupé :

```env
POSTGRES_HOST_PORT=5433
```

dans le `.env` à la racine, et `DATABASE_URL` backend vers `localhost:5433`.

## 6. Prisma

```bash
cd backend
copy .env.example .env
npm install
npx prisma generate
npx prisma migrate deploy
npm run prisma:seed
```

Ne pas utiliser `npx prisma migrate reset` en production : cela détruit les données.

## 7. Backend

```bash
cd backend
npm run dev
```

Santé :

```bash
curl http://localhost:3000/api/health
```

Production locale :

```bash
cd backend
npm start
```

## 8. Flutter

```bash
cd mobile
flutter pub get
flutter run
```

## 9. Variables d’environnement

`backend/.env` (voir `backend/.env.example`) :

```env
DATABASE_URL=postgresql://stock:stock@localhost:5432/stock_management?schema=public
JWT_SECRET=replace-with-a-long-random-secret
JWT_EXPIRES_IN=7d
PORT=3000
NODE_ENV=development
CORS_ORIGIN=*
ALLOW_REGISTER=true
```

Ne jamais commiter de secrets réels.

Flutter :

```bash
# Émulateur Android
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api

# Appareil physique
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api

# Production
flutter run --dart-define=API_BASE_URL=https://api.example.com/api --dart-define=APP_ENV=production
```

Chrome utilise `http://localhost:3000/api` par défaut.

## 10. Docker

Développement :

```bash
docker compose up -d postgres
```

API + PostgreSQL locaux :

```bash
docker compose up -d --build
```

Production :

```bash
cp env.production.example .env.production
# ou : cp .env.production.example .env.production
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --build
```

Sur le VPS OVH partagé, Nginx n’est **pas** dans Compose : le reverse proxy hôte pointe vers `127.0.0.1:3100`. Voir `deploy/VPS.md`.

Ne pas réutiliser les mots de passe de développement.

## 11. Tests

```bash
cd backend
npm test

cd ../mobile
flutter analyze
flutter test
```

## 12. APK debug

```bash
cd mobile
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Fichier : `mobile/build/app/outputs/flutter-apk/app-debug.apk`

## 13. APK release

Créer un keystore (hors Git) : voir `mobile/android/key.properties.example`.

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://api-stock.example.com/api --dart-define=APP_ENV=production
```

Fichier : `mobile/build/app/outputs/flutter-apk/app-release.apk`

Sans `key.properties`, Gradle signe avec le keystore debug (test interne uniquement).

## 14. Configuration production

- `JWT_SECRET` unique et long
- `CORS_ORIGIN` restreint
- `ALLOW_REGISTER=false` sauf besoin explicite
- `NODE_ENV=production`
- URL Flutter uniquement via `--dart-define=API_BASE_URL`

## 15. VPS

Procédure complète : `deploy/VPS.md`. Checklist : `deploy/PRODUCTION_CHECKLIST.md`.

Rien n’est déployé automatiquement. IP actuelle documentée : `164.132.101.55`. Utilisateur Linux dédié : `stockapp` (séparé de `deploy`).

## 16. Nginx

Sur le VPS existant : ajouter `deploy/nginx/stock-management.conf.*.example` dans `sites-available`. Ne pas remplacer `/etc/nginx/nginx.conf`. Placeholder : `api-stock.example.com`.

## 17. HTTPS

Let’s Encrypt / Certbot : étapes dans `deploy/VPS.md` (DNS, certificat, renouvellement, test).

## 18. Backup PostgreSQL

```bash
cd /opt/stock-management/app
./scripts/backup-postgres.sh
./scripts/restore-postgres.sh /opt/stock-management/backups/stock-YYYYMMDD-HHMMSS.sql.gz
```

Fréquence recommandée : quotidienne + copie hors serveur. Ne pas supprimer les anciennes sauvegardes sans politique de rétention.

## 19. Maintenance

- logs backend : JSON, sans mot de passe / token / `DATABASE_URL`
- migrations : `npx prisma migrate deploy`
- redémarrage : `restart: unless-stopped` dans Docker
- healthcheck : `GET /api/health`

## 20. Dépannage

| Symptôme | Piste |
|---|---|
| Flutter n’atteint pas l’API | Vérifier `--dart-define=API_BASE_URL` (émulateur `10.0.2.2`, Chrome `localhost`) |
| Port 5432 occupé | `POSTGRES_HOST_PORT=5433` |
| Token expiré | Redirection vers la connexion, message « Session expirée » |
| Vente refusée | Quantité > stock : le stock n’est pas modifié |
| Annulation d’achat refusée | Une partie du stock a déjà été vendue |

## API principale

- `GET /api/health`
- `POST /api/auth/login` `POST /api/auth/register` `GET /api/auth/me`
- CRUD `/api/categories` `/api/products` `/api/suppliers` `/api/customers`
- `GET /api/products/:id/history`
- CRUD `/api/purchases` `/api/sales` (DELETE = annulation)
- `GET /api/stock/movements`
- `POST /api/stock/adjustments` (ADMIN)
- `GET /api/dashboard?period=today|7d|30d`
