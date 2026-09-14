FROM node:22-alpine AS build
WORKDIR /workspace
COPY package.json package-lock.json tsconfig.json ./
COPY apps/api/package.json apps/api/package.json
COPY packages/contracts/package.json packages/contracts/package.json
RUN npm ci
COPY apps/api apps/api
COPY packages/contracts packages/contracts
COPY database database
RUN npm run build

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /workspace/package.json /workspace/package-lock.json ./
COPY --from=build /workspace/apps/api/package.json apps/api/package.json
COPY --from=build /workspace/packages/contracts/package.json packages/contracts/package.json
RUN npm ci --omit=dev
COPY --from=build /workspace/apps/api/dist apps/api/dist
COPY --from=build /workspace/packages/contracts/dist packages/contracts/dist
COPY --from=build /workspace/database database
EXPOSE 3000
CMD ["node", "apps/api/dist/src/main.js"]
