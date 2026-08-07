# UMD Omeka-S

Provides Docker build and local development for Omeka-S

## Local Development Setup

Create a .env file with the following contents:

```zsh
DB_HOST=mariadb
DB_NAME=<name-here>
DB_USER=<user-here>
DB_PASSWORD=<password-here>
```

Then build the docker image:

```zsh
docker build -t docker.lib.umd.edu/umd-omeka-s:latest
```

Then startup the docker compose stack with:

```zsh
source .env && docker compose up
```

Omeka-S should be available at localhost:8080
