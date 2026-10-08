ARG NODE_VERSION=24.21.0

FROM node:${NODE_VERSION}

ENV NODE_ENV=production

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 CMD [ "curl", "-fs", "http://localhost:3000/" ]

USER 10001

CMD ["node", "app.js"]
