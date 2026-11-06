# 🛠️ Universal Container Platform Deployment Guide

This guide details the steps to initialize, manage, and scale the unified architecture layout. The workspace uses a root-level `/app` anchor path to maintain identical execution syntax across local development and external production servers.

---

## 📂 Architecture Mapping Summary

```text
/app/ (or D:\app\)
├── data/                       # Database engine files (e.g., data/mysql56)
├── htdocs/                     # Laravel source code roots (e.g., htdocs/bengkel)
└── stacks/                     # Infrastructure & app orchestration stacks
    ├── shared-services/        # Global proxy, shared database & base images
    │   ├── base-images/        # Custom environment core Dockerfiles
    │   ├── mysql56/            # Shared legacy database configurations
    │   └── proxy-traefik/      # Consolidated Traefik v3.7 gateway engines
    └── laravel-apps/           # Individual container configuration deployments
```

---

## 🔗 Step 1: Environment Path Initialization

Run the appropriate command on your machine target to link physical resource targets directly to the unified root level pointer:

### 💻 Local Development (Windows 10 WSL / Debian 13)
```bash
sudo ln -s /mnt/d/app /app
```

### 🌐 Cloud Engine Staging (Ubuntu VPS)
```bash
sudo ln -s /home/ubuntu/app /app
```

---

## 🌐 Step 2: Global Switch Provisioning

Run the initial network mapping sequence. This creates a global network switch allowing isolated application containers to resolve your global proxies and shared databases:

```bash
docker network create shared-db-network
```

---

## 🐳 Step 3: Build Custom PHP 7.2 Base Image

Before running the applications, compile the custom Debian 13 apt-based PHP 7.2 foundation image once into your local container image store:

```bash
cd /app/stacks/shared-services/base-images/php72-debian13
docker compose build
```

---

## 🗄️ Step 4: Shared Infrastructure Startup

Navigate to the dedicated database orchestration folder and boot up the persistent engine daemon:

```bash
cd /app/stacks/shared-services/mysql56
docker compose up -d
```

---

## 🚀 Step 5: Traefik v3.7 Router Setup & Windows Trust Mapping

Navigate to your shared proxy setup and spin up your target routing layer:

```bash
cd /app/stacks/shared-services/proxy-traefik
docker compose -f docker-compose-dev.yml up -d
```

### 🔒 Removing SSL Security Warnings (One-Time Setup)
1. Open your Windows Host File Explorer and locate: `D:\app\stacks\shared-services\proxy-traefik\`
2. Verify Docker has successfully auto-generated the following file tokens:
   * `mysite.test.pem` *(Local site certificate file)*
   * `mysite.test-key.pem` *(Private security handshake key)*
   * `rootCA.pem` *(The Root Certificate Authority foundation file)*
3. **Install the Windows Root Trust:**
   * Right-click `rootCA.pem` and rename its file extension from `.pem` to **`.crt`**.
   * Double-click `rootCA.crt` ➡️ Click **Install Certificate** ➡️ Select **Local Machine**.
   * Select **"Place all certificates in the following store"** ➡️ Click **Browse**.
   * Select **Trusted Root Certification Authorities** ➡️ Click **OK** ➡️ **Finish**.

---

## 🏁 Step 6: Application Deployment & First-Time Launch

### 🛠️ Initializing a New Target Workspace (e.g., Bengkel App)
Run this compilation sequence when launching your Laravel container ecosystem for the first time:

```bash
cd /app/stacks/laravel-apps/bengkel

# Build and initiate the custom web core containers
docker compose -f docker-compose-dev.yml up -d

# Provision code dependencies swiftly inside the fast internal volume layout
docker compose exec bengkel-app composer install
```

### 🔄 Managing Application Environments
Pivot across your custom deployment strategies seamlessly by invoking their corresponding orchestration definitions. All environments utilize high-performance Unix Sockets running inside RAM:

* **To boot up local Development (`*.test` domains + Trusted SSL):**
  ```bash
  docker compose -f docker-compose-dev.yml up -d
  ```
* **To boot up Production Domain (Real public domains + Let's Encrypt validation):**
  ```bash
  docker compose -f docker-compose-prod.yml up -d
  ```
* **To boot up Raw IP Ports (Public VPS IP target staging + Long-term SSL certs):**
  ```bash
  docker compose -f docker-compose-ip.yml up -d
  ```

### 🛑 Container Teardown
To safely stop application execution and cleanly wipe out the temporary in-memory socket allocations without losing persistent database files:
```bash
docker compose -f docker-compose-dev.yml down -v
```
