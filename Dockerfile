FROM node:18-alpine

# Set working directory inside the container
WORKDIR /usr/src/app

# Copy package files and install only production dependencies
COPY package*.json ./
RUN npm install --only=production

# Copy the rest of the application code
COPY . .

# Expose the port the app listens on
EXPOSE 4000

# Start the Node.js application
CMD ["node", "index.js"]