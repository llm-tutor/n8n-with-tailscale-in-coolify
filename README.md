# N8N v2 + Tailscale Docker Compose

Production-ready N8N deployment (Version 2.x compatible) with Tailscale integration for secure local network access. Designed for [Coolify](https://coolify.io/) deployment.

## Purpose

This configuration enables an online N8N instance to trigger processes not only on the web but also towards a local network for secure local processing. This approach is ideal for automation scenarios that require:

- **Privacy-focused processing** - sensitive data remains on local infrastructure
- **Local hardware utilization** - leverage existing GPU/compute resources without costly cloud services  
- **Hybrid automation workflows** - combine cloud services with local processing capabilities
- **Cost optimization** - avoid expensive online processing services by using local resources

The setup is designed for **Coolify deployment** and optimized for **low-cost instances** (compatible with providers like Hetzner's cheapest tiers), making powerful automation accessible without significant infrastructure investment. 

## Features

- **N8N v2 Architecture** with decoupled Draft/Publish states and safe autosaving
- **Isolated Task Runners** for secure and stable execution of Code nodes
- **Tailscale Mesh Networking** for secure access to local services
- **Worker Scaling** with Redis-based message queue
- **Subnet Routing** for comprehensive local network access
- **Health Checks** and dependency management
- **Security Hardening** with encryption and strict database isolation

## Architecture

In this v2-optimized deployment, code execution is completely isolated. The Main interface handles web traffic, the Worker acts as a task broker distributing queue jobs, and the Runner securely executes the actual node logic.
```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │      Redis      │    │    Tailscale    │
│   (Database)    │    │  (Message Queue)│    │ (Network Mesh)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐    ┌─────────────────┐
                    │   N8N Main      │    │   N8N Worker    │
                    │ (Web Interface) │    │  (Task Broker)  │
                    └─────────────────┘    └────────┬────────┘
                                                    │
                                           ┌────────┴────────┐
                                           │   N8N Runner    │
                                           │(Node Execution) │
                                           └─────────────────┘
```

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Tailscale account with generated auth key
- Domain configured for external access

### Environment Setup

1. **For Coolify Deployment:**
   - Use the Coolify dashboard to set environment variables
   - All required and optional variables are listed below
   - Copy values from the `.env.template` file for reference

2. **For Manual Docker Compose Deployment:**
   ```bash
   cp .env.template .env
   # Edit .env with your actual values
   docker compose up -d
   ```

3. **Generate secrets (run individually to avoid bash history):**
   
```bash
   openssl rand -base64 32  # For POSTGRES_PASSWORD
   openssl rand -base64 32  # For REDIS_PASSWORD
   openssl rand -base64 32  # For N8N_ENCRYPTION_KEY
   openssl rand -base64 64  # For N8N_JWT_SECRET
   openssl rand -hex 32     # For N8N_RUNNERS_AUTH_TOKEN
   ```

### Environment Variables

Set the following environment variables in **Coolify's Environment tab** or in your `.env` file for manual deployments:

**Required Secrets:**
```bash
# Required Secrets
TS_AUTHKEY=<tailscale-reusable-auth-key>
POSTGRES_PASSWORD=<strong-database-password>
REDIS_PASSWORD=<strong-redis-password>
N8N_ENCRYPTION_KEY=<32-character-base64-key>
N8N_JWT_SECRET=<64-character-base64-key>
N8N_RUNNERS_AUTH_TOKEN=<32-character-hex-string>
WEBHOOK_URL=[https://n8n.yourdomain.com](https://n8n.yourdomain.com)

# Optional Configuration
TZ=<timezone-identifier>  # e.g., America/New_York, Europe/London, UTC (default: Etc/GMT+6)
```

**Coolify Setup:**
1. Navigate to your application's **Environment** tab in Coolify
2. Add each variable above with your generated values
3. Use the secret generation commands above to create secure passwords
4. Deploy your application

**Manual Deployment:**
Copy `.env.template` to `.env` and fill in your values, then run `docker-compose up -d`.

### Directory Setup

```bash
mkdir -p /root/data/n8n/{.n8n,custom-nodes,shared-files,backups,postgres,redis,tailscale}
chown -R 1000:1000 /root/data/n8n
```

**Note**: This directory structure and `1000:1000` user ownership is specifically designed for compatibility with **Coolify App templates** on Hetzner instances, ensuring proper container permissions and data persistence.

### Deploy

**In Coolify:**
1. Create a new application from Git repository
2. Select the **Docker Compose** deployment type
3. Set all required environment variables in the **Environment** tab
4. Deploy the application
5. Visit your N8N URL and create the **owner** account

**Manual Deployment:**
```bash
docker compose pull
docker compose up -d
```

## Tailscale Configuration

### 1. Generate Auth Key
- Navigate to [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
- Create **reusable key** with **90-day expiration**
- Set description: `n8n-production`

### 2. Enable Subnet Routing
After deployment:
1. Go to [Tailscale Admin Panel](https://login.tailscale.com/admin/machines)
2. Find the deployed machine
3. Click **Edit route settings**
4. **Approve** all advertised routes:
   - `192.168.0.0/16`
   - `10.0.0.0/8`
   - `172.16.0.0/12`

## Network Access Patterns

### Local Services via Tailscale
```javascript
// N8N HTTP Request node examples

// Direct Tailscale IP access
URL: "[http://100.64.1.100:3000](http://100.64.1.100:3000)"

// Subnet routing access  
URL: "[http://192.168.1.50:8080](http://192.168.1.50:8080)"
```

### Supported Networks
- **Local networks**: 192.168.x.x, 10.x.x.x, 172.16-31.x.x
- **Tailscale mesh**: 100.x.x.x addresses
- **Container network**: Internal service communication

## Local Network Setup and Integration

### Local Tailscale Client Installation
To enable N8N automation of local processes, install Tailscale on target local machines:

1. **Download Tailscale** for the target platform (Windows, macOS, Linux).
2. **Sign in** using the same Tailscale account as the N8N deployment.
3. **Verify connectivity** between N8N server and local machines:
   ```bash
   # Find local machine's Tailscale IP
   tailscale ip -4
   
   # Test from N8N server
   ping 100.x.x.x
   ```

### Local Process Automation Architecture
**Recommended Pattern**: Use **webhook servers** as intermediary layers rather than direct process execution. This provides security isolation, access control, and flexibility.

#### Basic Webhook Server Pattern
```javascript
// Local HTTP server listening on Tailscale interface
// N8N workflow sends: POST [http://100.](http://100.)x.x.x:3000/api/action

{
  "action": "process_file",
  "params": {
    "file_path": "/path/to/file",
    "output_format": "json"
  }
}
```

#### Common Use Cases
- **GPU Processing**: Image generation, ML inference, video processing
- **Hardware Control**: IoT devices, cameras, sensors, actuators
- **System Administration**: Backups, monitoring, maintenance scripts

### Security Considerations for Local Integration
- **Network Isolation**: Bind local services only to Tailscale interfaces (`100.x.x.x:port`).
- **Process Isolation**: Run local services with minimal privileges.
- **Data Protection**: Use HTTPS for local services when handling sensitive data.

## Resource Requirements

| Service | Memory | Purpose |
|---------|---------|---------|
| PostgreSQL | ~50-100MB | Database storage |
| Redis | ~10-50MB | Message queue |
| N8N Main | ~150-300MB | Web interface & API |
| N8N Worker | ~100-200MB | Task routing and queue management |
| N8N Runner | ~50-100MB | Isolated code execution |
| Tailscale | ~5-20MB | Network mesh |
| **Total** | **~365-770MB** | Full stack |

Compatible with **2GB+ RAM** instances.

## Security Features

- **Isolated Execution:** Code nodes run in a detached `n8n-runner` container, preventing memory leaks or crashes from affecting the main web service.
- **Encrypted workflows** with `N8N_ENCRYPTION_KEY`
- **JWT authentication** with configurable secrets
- **File access restrictions** to designated directories
- **Network isolation** with custom bridge network
- **Automatic execution cleanup** (7-day retention)

## Ports and Services

| Port | Service | Access |
|------|---------|--------|
| 5678 | N8N Web Interface | External (via reverse proxy) |
| 5432 | PostgreSQL | Internal only |
| 6379 | Redis | Internal only |
| - | Tailscale | Mesh network |

## Volume Mounts
```
/root/data/n8n/
├── .n8n/              # N8N configuration and workflows
├── custom-nodes/      # Custom node installations  
├── shared-files/      # Workflow file storage
├── backups/           # Backup destination
├── postgres/          # Database files
├── redis/             # Redis persistence
└── tailscale/         # Tailscale state
```

## Environment Variables Reference

### Required
- `TS_AUTHKEY` - Tailscale authentication key
- `POSTGRES_PASSWORD` - Database password
- `REDIS_PASSWORD` - Redis password
- `N8N_ENCRYPTION_KEY` - Workflow encryption (32 chars)
- `N8N_JWT_SECRET` - Authentication secret (64 chars)
- `N8N_RUNNERS_AUTH_TOKEN` - Secure token linking the worker and the runner
- `WEBHOOK_URL` - External N8N URL for webhooks

### Architecture Flags (Hardcoded in Compose)
- `N8N_RUNNERS_MODE=external` - Forces n8n to look for the detached runner container
- `N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0` - Allows the worker to accept internal connections from the runner
- `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true` - Ensures manual runs in the UI are pushed to the worker/runner stack

### Optional Customization
- `TZ` - Timezone identifier (default: Etc/GMT+6). Examples: America/New_York, Europe/London, UTC, Asia/Tokyo
- `EXECUTIONS_DATA_MAX_AGE` - Execution retention hours (default: 168)
- `N8N_METRICS` - Enable metrics (default: true)

## Health Checks

All services include health checks with automatic restart:
- **PostgreSQL**: Database connectivity
- **Redis**: Service ping
- **Tailscale**: Network status  
- **N8N**: Depends on all dependencies

## Troubleshooting

### Service Won't Start
```bash
# Check container logs
docker compose logs <service-name>

# Verify environment variables
docker compose config

# Check file permissions
ls -la /root/data/n8n/
```

### Tailscale Connectivity Issues
```bash
# Check Tailscale status
docker compose exec tailscale tailscale status

# Test local network access
docker compose exec n8n ping 192.168.1.1
```

## Scaling

### Add More Runners (Execution Capacity)
In N8N v2, the primary bottleneck for heavy tasks (like processing large arrays in Code nodes) is the runner. To increase execution capacity, scale the runner service, not the worker:
```yaml
  n8n-runner-2:
    <<: *n8n-runner  # Inherit configuration
    container_name: n8n-runner-2
```

### Performance Tuning
- Increase runner count for code-heavy workloads.
- Adjust PostgreSQL memory settings if database queries become the bottleneck.
- Monitor Redis memory usage to ensure the BullMQ queue does not overflow.


## Backup Strategy

### Critical Data
- `/root/data/n8n/postgres/` - Database
- `/root/data/n8n/.n8n/` - Workflows and config
- Environment variables (secrets)

### Automated Backup
```bash
#!/bin/bash
tar -czf backup-$(date +%Y%m%d).tar.gz /root/data/n8n/
```

## Related Documentation

- [N8N v2 Release Notes](https://docs.n8n.io/release-notes/)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Coolify Docs](https://coolify.io/docs/get-started/introduction)

---

**⚠️ Important**: Store all secrets securely. Losing the `N8N_ENCRYPTION_KEY` will result in loss of encrypted workflow data.