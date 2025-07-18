ARG NODE_VERSION=22.17.1

FROM node:${NODE_VERSION}

ENV NODE_ENV=production

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 CMD curl -fs http://localhost:3000/ || exit 1

USER test

CMD ["node", "app.js"]
