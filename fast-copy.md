# Fastest way to copy files into Docker from Windows

The quickest way to avoid the WSL translation overhead is to bundle files into a single stream on the Windows side, pipe that stream across the boundary, and extract it directly inside the container.

Instead of thousands of tiny file requests, Docker receives one large continuous block.

## Command

Run this in your Debian WSL terminal:

```bash
cd /app/stacks/laravel-apps/bengkel

# 1. Archive, stream, and extract 8,500 files into the container instantly
tar -cC /mnt/d/app/htdocs/bengkel/vendor . | docker compose -f docker-compose-dev.yml exec -T -u root bengkel-app tar -xC /var/www/html/vendor

# 2. Fix the non-root execution permissions immediately afterward
docker compose -f docker-compose-dev.yml exec -u root bengkel-app chown -R www:www /var/www/html/vendor
```

## Why this is so fast

- `tar -cC ... .` packages the files from Windows directly into memory without writing them to disk first.
- The pipe (`|`) sends one continuous stream across the WSL boundary instead of thousands of small file operations.
- `tar -xC ...` extracts the files natively inside the container's Linux filesystem, which is much faster than repeated Windows-to-WSL file calls.

This approach can move thousands of vendor files across in seconds instead of minutes.