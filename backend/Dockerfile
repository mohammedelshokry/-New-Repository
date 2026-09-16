FROM node:20-alpine

WORKDIR /app

# Copy dependency definitions
COPY package*.json ./
COPY prisma ./prisma/

# Install dependencies
RUN npm install

# Generate Prisma client
RUN npx prisma generate

# Copy the rest of the source code
COPY . .

# Build TypeScript to JavaScript
RUN npm run build

# Push database schema to SQLite if dev.db doesn't exist
RUN npx prisma db push

EXPOSE 3001

CMD ["npm", "start"]
