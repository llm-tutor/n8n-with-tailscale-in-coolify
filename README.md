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
- **Custom Runner Image** with multi-stage Dockerfile — includes Rclone, Python AI/ML libraries, and patched task executor
- **Dual Runtime Support** — JavaScript and Python task runners configured via `n8n-task-runners.json`
- **AI/ML in Code Nodes** — pre-installed `openai`, `google-genai`, `langchain`, and `langgraph` in the Python runner
- **Isolated Task Runners** for secure and stable execution of Code nodes
- **Tailscale Mesh Networking** for secure access to local services
- **Worker Scaling** with Redis-based message queue
- **Subnet Routing** for comprehensive local network access
- **Health Checks** and dependency management
- **Security Hardening** with encryption and strict database isolation

## Architecture

In this v2-optimized deployment, code execution is completely isolated. The Main interface handles web traffic, the Worker acts as a task broker distributing queue jobs, and the **custom-built Runner** (see `Dockerfile`) securely executes the actual node logic with both JavaScript and Python runtimes. The runner's behavior is governed by `n8n-task-runners.json`, which controls allowed environment variables and runtime security flags.
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
                                           │ Custom Runner   │
                                           │ (JS + Python)   │
                                           │ + Rclone + AI   │
                                           └─────────────────┘
```

## Custom Runner Dockerfile

The `n8n-runner` service uses a **custom multi-stage Dockerfile** that extends the official `n8nio/runners` image with additional tooling:

| Stage | Purpose |
|-------|---------|
| **Builder** | Downloads and extracts the latest **Rclone** binary (cloud storage integration) |
| **Final** | Injects Rclone, copies `n8n-task-runners.json`, installs Python AI dependencies, and patches the task executor |

### What the Dockerfile does

1. **Rclone injection** — The standalone Rclone binary is copied into `/usr/local/bin/rclone`, enabling Code nodes to interact with cloud storage providers (S3, GCS, Dropbox, Google Drive, etc.) directly from the runner.
2. **Runner configuration** — `n8n-task-runners.json` is copied to `/etc/n8n-task-runners.json` (read by the n8n runner launcher to configure JS and Python runtimes).
3. **Python dependencies** — Packages from `requirements.txt` are installed into the Python runner's virtual environment using `uv pip`.
4. **Environment patch** — The runner's `task_executor.py` is patched so that allowed environment variables (API keys, etc.) are **not wiped** before task execution — without this patch, `n8n-task-runners.json`'s `allowed-env` list has no effect.

## Task Runner Configuration (`n8n-task-runners.json`)

This file defines the runtime behavior for both JavaScript and Python task runners. Each runner entry specifies:

| Field | Description |
|-------|-------------|
| `runner-type` | `"javascript"` or `"python"` |
| `command` | Full path to the runtime executable |
| `args` | Security flags and entry-point script |
| `health-check-server-port` | Internal port for runner health checks (`5681` for JS, `5682` for Python) |
| `allowed-env` | Whitelist of environment variables passed through to the runner sandbox |
| `env-overrides` | Hardcoded environment values injected into the sandbox |

### JavaScript Runner

- Uses Node.js with security flags: `--disallow-code-generation-from-strings` and `--disable-proto=delete`
- `env-overrides` set `NODE_FUNCTION_ALLOW_BUILTIN=*` and `NODE_FUNCTION_ALLOW_EXTERNAL=*`, giving Code nodes full access to Node.js built-ins and npm packages

### Python Runner

- Uses Python with isolation flags: `-I` (isolated mode), `-B` (no .pyc), `-X disable_remote_debug`
- `env-overrides` set `N8N_RUNNERS_STDLIB_ALLOW=*` and `N8N_RUNNERS_EXTERNAL_ALLOW=*`, giving Code nodes full access to the Python standard library and installed packages
- **AI/ML enabled** — the `allowed-env` list includes API keys for Google AI, OpenAI, and OpenCode, plus a custom `EXECUTION_DIAKEFO_STUDIO_FOLDER` path variable

### AI/ML in Python Code Nodes

The Python runner comes pre-loaded with AI/ML libraries (see `requirements.txt`):

| Package | Purpose |
|---------|---------|
| `openai` | OpenAI API client (GPT-4, embeddings, etc.) |
| `google-genai` | Google Gemini API client |
| `langchain` | LLM application framework |
| `langgraph` | Stateful multi-actor LLM applications |
| `requests` | HTTP client for custom API calls |

To use these in Code nodes, set the corresponding environment variables in Coolify or your `.env`:

```bash
GOOGLE_API_KEY_FREE=<your-google-ai-key>
GOOGLE_API_KEY_PRO=<your-google-ai-pro-key>
OPENAI_API_KEY=<your-openai-key>
OPENCODE_GO_API_KEY=<your-opencode-key>
EXECUTION_DIAKEFO_STUDIO_FOLDER=/files/diakefo_studio/
```

> **Note**: These variables will only reach the Python runner if they are listed in `n8n-task-runners.json` → `allowed-env`. The JavaScript runner does **not** receive AI keys by default (its `allowed-env` list is limited to generic n8n variables).

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
N8N_DATA_TABLES_MAX_SIZE_BYTES=524288000  # 500 MB max total size for Data Tables (optional, default shown)
```

**Coolify Setup:**
1. Navigate to your application's **Environment** tab in Coolify
2. Add each variable above with your generated values
3. To enable AI features in Python Code nodes, also add the optional AI/ML API keys (see [AI/ML in Python Code Nodes](#aiml-in-python-code-nodes))
4. Use the secret generation commands above to create secure passwords
5. Deploy your application

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
├── tailscale/         # Tailscale state
└── config/            # Rclone configuration (mounted into runner)
```

## Repository File Overview

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Full stack service definitions (N8N, Worker, Runner, Postgres, Redis, Tailscale) |
| `Dockerfile` | Custom multi-stage build for the N8N Runner (adds Rclone, Python AI deps, patches executor) |
| `n8n-task-runners.json` | Runner runtime configuration — JS/Python commands, security flags, allowed env vars |
| `requirements.txt` | Python packages installed into the runner's virtual environment |
| `README.md` | This documentation |
| `LICENSE` | License file |
| `.env.template` | Template for environment variables (create your own `.env` file) |

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
- `N8N_DATA_TABLES_MAX_SIZE_BYTES` - Defined on **both** `n8n` (main) and `n8n-worker` services. In queue mode, workflows dispatched to the worker also write to Data Tables — without it on the worker, those executions would fail with a size-limit error. Default: `524288000` (500 MB).

### AI/ML API Keys (optional)
- `GOOGLE_API_KEY_FREE` - Google Gemini API key (free tier). Used by Python Code nodes via `google-genai`.
- `GOOGLE_API_KEY_PRO` - Google Gemini API key (pro tier). Used alongside the free key for higher rate limits.
- `OPENAI_API_KEY` - OpenAI API key (GPT-4, embeddings). Used by Python Code nodes via `openai` / `langchain`.
- `OPENCODE_GO_API_KEY` - OpenCode API key for code generation tasks.
- `EXECUTION_DIAKEFO_STUDIO_FOLDER` - Working directory for AI-generated files (default: `/files/diakefo_studio/`).

> **Important**: These variables must be listed in `n8n-task-runners.json` → `allowed-env` to be accessible inside Python Code nodes. They are already configured by default in this repository.

### Optional Customization
- `TZ` - Timezone identifier (default: Etc/GMT+6). Examples: America/New_York, Europe/London, UTC, Asia/Tokyo
- `EXECUTIONS_DATA_MAX_AGE` - Execution retention hours (default: 168)
- `N8N_METRICS` - Enable metrics (default: true)
- `N8N_DATA_TABLES_MAX_SIZE_BYTES` - Maximum total storage size for Data Tables in bytes (default: `524288000` / 500 MB). Set per-environment; applies to both the main N8N and worker services.

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