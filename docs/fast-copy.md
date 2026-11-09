# Fastest way to copy files into a container from Windows (WSL)

Bundle the files into one stream on the WSL side, pipe it across, and extract it inside the container.
One continuous stream instead of thousands of tiny `/mnt/d` file operations.

```bash
cd /app

# 1. stream the vendor folder into the container's named `vendor` volume
tar -cC /app/htdocs/bengkel/vendor . | bin/platform dc bengkel exec -T -u root php tar -xC /var/www/html/vendor

# 2. fix ownership (php-fpm runs as uid 1000 "www")
bin/platform dc bengkel exec -u root php chown -R www:www /var/www/html/vendor
```

`-T` disables the TTY (required when piping). The Laravel template keeps `vendor/` in a Docker named
volume (native Linux filesystem) which is why `composer install` and autoloading are fast on Windows.
