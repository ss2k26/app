# 🛠️ Universal Container Platform Deployment Guide

This guide details the steps to initialize, manage, and scale the unified architecture layout. The workspace uses a root-level `/app` anchor path to maintain identical execution syntax across local development and external production servers.

---

## 📂 Architecture Mapping Summary

```text
/app/ (or D:\app\)
├── data/                          # Database engine files (e.g., data/mysql56)
├── htdocs/                        # Laravel source code roots (e.g., htdocs/bengkel)
└── stacks/                        # Infrastructure & app orchestration stacks
    ├── shared-services/           # Global proxy, shared database & base images
    │   ├── base-images/           # Custom environment core Dockerfiles
    │   ├── mysql56/               # Shared legacy database configurations
    │   ├── proxy-traefik/         # Consolidated Traefik v3.7 gateway engines
    │   └── dashboard-portainer/   # Management dashboard container folder
    └── laravel-apps/              # Individual container configuration deployments
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
docker network create --subnet=172.18.0.0/16 shared-db-network
```

---

## 🐳 Step 3: Build Custom PHP 7.2 Base Image

Before running the applications, compile the custom Debian 13 apt-based PHP 7.2 foundation image once into your local container image store:

```bash
cd /app/stacks/shared-services/base-images/php72-debian13
docker compose build
```

Jika ada perubahan pada `Dockerfile` atau konfigurasi base image, build ulang tanpa menggunakan cache:

```bash
docker compose build --no-cache
```

---

## 🗄️ Step 4: Shared Infrastructure Startup

Choose one MySQL 5.6 profile. Development uses a low-memory configuration; production is capped at 2 GB and uses a larger InnoDB buffer pool:

### 💻 Development
```bash
cd /app/stacks/shared-services/mysql56
docker compose -f docker-compose-dev.yml up -d
```

### 🌐 Production (2 GB memory limit)
```bash
cd /app/stacks/shared-services/mysql56
docker compose -f docker-compose-prod.yml up -d
```

Both profiles use the same persistent database directory (`/app/data/mysql56`) and container names. Stop the active profile before switching; do not run both profiles simultaneously. Config files are bind-mounted outside MySQL's config directory, then copied inside the container with mode `0644` before the official MySQL entrypoint starts. This avoids MySQL 5.6 ignoring world-writable config files when the stack is stored on a Windows drive and accessed through WSL.

To stop a profile without removing the persistent database data:
```bash
docker compose -f docker-compose-dev.yml down
# or
docker compose -f docker-compose-prod.yml down
```

---

## 🚀 Step 5: Traefik v3.7 Router Setup & Windows Trust Mapping

Navigate to your shared proxy setup and spin up your target routing layer:

```bash
cd /app/stacks/shared-services/proxy-traefik
docker compose -f docker-compose-dev.yml up -d
```

### 🔒 Removing SSL Security Warnings (Automated Double-Click Setup)
Once you have started your local development proxy container stack for the first time, navigate to your Windows root application directory and **double-click the `run-cert-install.bat` file**. Accept the Windows Administrator validation prompt to automatically register the Root CA and establish a fully trusted secure green browser experience.


### 📋 Automated Windows Domain Registration
Whenever you create a new application directory inside your portable `/stacks/laravel-apps/` path, navigate to the system root workspace folder on Windows and **double-click the `run-hosts-update.bat` file**. The utility automatically determines the current host drive letter and directory layout relative to its location to map your `.test` domains.

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

---

## 🎛️ Management Ecosystem

### Terminal Monitoring (Lazydocker)
Run the automated shortcut utility to monitor containers, resources, and shared memory socket pipes natively in the command prompt:
```bash
ld
```

### Web Administration Dashboard (Portainer CE)
Execute the specific layout definition that matches your active proxy stack framework:

* **Dev Environment:**
  ```bash
  cd /app/stacks/shared-services/dashboard-portainer
  docker compose -f docker-compose-dev.yml up -d
  ```
* **Production Environment:**
  ```bash
  docker compose -f docker-compose-prod.yml up -d
  ```
* **Staging Public IP Environment:**
  ```bash
  docker compose -f docker-compose-ip.yml up -d
  ```
