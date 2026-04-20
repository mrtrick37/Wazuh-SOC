# Wazuh SOC Backend

Express.js backend service that handles admin operations for the Wazuh SOC, including dashboard updates and health checks.

This is the canonical guide for backend deployment, service management, and nginx proxy setup.

## Quick Start (Development)

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Run with ts-node (development)
npm run dev

# Or run compiled production build
npm start
```

The server listens on `http://localhost:3001` by default.

## Production Deployment

Use the automated setup script:

```bash
cd /home/phendrick/git/Wazuh-SOC/backend
./setup-production.sh
```

This script will:
1. Build the backend
2. Install the systemd service
3. Enable and start the service
4. Verify the backend is running
5. Display nginx configuration to apply

### Manual Setup (if not using script)

#### 1. Build the backend

```bash
npm install
npm run build
```

#### 2. Install systemd service

Copy the service file:
```bash
sudo cp wazuh-soc-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable wazuh-soc-backend
sudo systemctl start wazuh-soc-backend
```

#### 3. Configure Nginx

Add the proxy configuration to your nginx server block (`/etc/nginx/sites-available/default` or your vhost):

```nginx
# Proxy backend API requests to the Node.js backend server
location /api/admin/ {
    proxy_pass http://localhost:3001/api/admin/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_cache_bypass $http_upgrade;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}

# Health check endpoint
location /health {
    proxy_pass http://localhost:3001/health;
    access_log off;
}
```

Verify and reload nginx:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Service Management

```bash
# Status
sudo systemctl status wazuh-soc-backend

# Start/Stop/Restart
sudo systemctl start wazuh-soc-backend
sudo systemctl stop wazuh-soc-backend
sudo systemctl restart wazuh-soc-backend

# View logs
sudo journalctl -u wazuh-soc-backend -f
sudo journalctl -u wazuh-soc-backend -n 50

# Disable autostart
sudo systemctl disable wazuh-soc-backend
```

## API Endpoints

### GET `/health`

Health check endpoint for monitoring.

**Response:**
```json
{ "status": "ok" }
```

### POST `/api/admin/update`

Trigger a dashboard update. Spawns the update script and returns output.

**Request body:**
```json
{
  "skipGitPull": false,
  "skipBuild": false,
  "nonInteractive": true
}
```

**Response (success):**
```json
{
  "success": true,
  "message": "Update completed successfully",
  "output": "git pull...\nnpm install...\n..."
}
```

**Response (error):**
```json
{
  "success": false,
  "message": "Update failed with exit code 1",
  "output": "...",
  "error": "..."
}
```

## Environment Variables

- `PORT` - Server port (default: 3001)

## Security Notes

- Current implementation has basic admin check (demo only)
- In production, add JWT token verification
- Ensure the update script has proper sudo permissions configured
- Consider rate limiting and request validation
