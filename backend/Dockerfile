FROM node:20-alpine

RUN apk add --no-cache openssl libc6-compat \
  && addgroup -S stockapp \
  && adduser -S stockapp -G stockapp

WORKDIR /app

COPY package.json package-lock.json* ./
COPY prisma ./prisma

RUN npm ci --omit=dev && npx prisma generate

COPY src ./src

RUN chown -R stockapp:stockapp /app

USER stockapp

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/api/health').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["sh", "-c", "npx prisma migrate deploy && node src/server.js"]
