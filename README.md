Odoo Docker Template by rianmz

This project template provides a robust and customizable way to run Odoo using Docker. It includes a custom Dockerfile and a docker-compose setup to manage Odoo and its PostgreSQL database with separate configuration and a custom entrypoint script.
Prerequisites

    Docker and Docker Compose installed on your system.

Project Structure

This project uses a modular structure to keep configurations separate from the core Docker files.

.
├── .env                  # Environment variables for configuration
├── docker-compose.yml    # Defines services and orchestration
├── entrypoint.sh         # Custom script to configure Odoo
├── Dockerfile            # Custom Docker image build instructions
├── config/               # Odoo configuration files
│   └── odoo.conf
├── extra-addons/         # Directory for your custom Odoo modules
└── postgresql/           # Directory for PostgreSQL data persistence

Configuration

This template is configured using environment variables and custom files to make it easy to manage.
1. .env File

This file stores all your environment variables. You can easily change the Odoo version, database credentials, and ports here without modifying the docker-compose.yml directly.

.env

#db
DB_HOST=db
DB_USER=db_user
DB_PASS=db_pass
DB_NAME=db_example
DB_VERSION=14

#odoo
ODOO_PORT=1005
ODOO_ADMIN_PASSWD=odoo-example
ODOO_NAME=example-odoo
ODOO_IMAGE=example-odoo
ODDO_VERSION=14

DB_FILTER=^%d$|.*

2. docker-compose.yml File

This file orchestrates the two main services: odoo and db. It builds the custom Odoo image, links the two services, and maps ports and volumes.

docker-compose.yml

version: '3'
services:
  db:
    image: postgres:${DB_VERSION}
    container_name: ${DB_NAME}
    user: root
    environment:
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASS}
      - POSTGRES_DB=postgres
    restart: always          
    volumes:
        - ./postgresql:/var/lib/postgresql/data


  odoo:
    build: 
      context: .
      dockerfile: Dockerfile
      args:
        - ODDO_VERSION=${ODDO_VERSION}
    image: ${ODOO_IMAGE}
    user: root
    container_name: ${ODOO_NAME}
    ports:
      - "${ODOO_PORT}:8069"
    tty: true
    command: --
    environment:
      - HOST=db
      - USER=${DB_USER}
      - PASSWORD=${DB_PASS}
      - ADMIN_PASSWD=${ODOO_ADMIN_PASSWD}
    volumes:
      - ./extra-addons:/mnt/extra-addons
      - ./conf:/etc/odoo 
    restart: unless-stopped
    depends_on:
      - db

3. Dockerfile

This file builds your custom Odoo image. It is designed to use a custom entrypoint script.

Dockerfile

ARG ODDO_VERSION

FROM odoo:$ODDO_VERSION

COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["odoo"]

4. entrypoint.sh

This script runs every time the Odoo container starts. It's responsible for dynamically setting up the Odoo configuration, including the admin password, addons path, and database filter.

entrypoint.sh

#!/bin/bash

set -e

if [ -v PASSWORD_FILE ]; then
    PASSWORD="$(< $PASSWORD_FILE)"
fi

: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}
: ${ADMIN_PASSWD:='admin_password'}  # Set the default admin password
: ${ADDONS_PATH:='/mnt/extra-addons'}  # Set the default addons path
: ${DATA_DIR:='/etc/odoo'}  # Set the default data directory
: ${DB_FILTER:='.*'} # <<<<<<<< Tambahkan dbfilter untuk multi-database

# Set or update the admin password directly in the Odoo configuration file
ODOO_RC="/etc/odoo/odoo.conf"

# if [ -f "$ODOO_RC" ]; then
#     if ! grep -q -E "^\s*\[options\]\s*$" "$ODOO_RC"; then
#         echo "[options]" > "$ODOO_RC"
#     fi
# else
#     echo "File $ODOO_RC not found."
# fi

if ! grep -q -E "^\s*\[options\]\s*$" "$ODOO_RC"; then
    echo "[options]" > "$ODOO_RC"
fi

if grep -q -E "^\s*\badmin_passwd\b\s*=" "$ODOO_RC"; then
    # Admin password already exists in the configuration file, update it
    sed -i "s/^\s*\badmin_passwd\b\s*=.*/admin_passwd = ${ADMIN_PASSWD}/" "$ODOO_RC"
else
    # Admin password does not exist, add it to the configuration file
    echo "admin_passwd = ${ADMIN_PASSWD}" >> "$ODOO_RC"
fi

# Set or update addons_path in the Odoo configuration file
if grep -q -E "^\s*\baddons_path\b\s*=" "$ODOO_RC"; then
    # addons_path already exists in the configuration file, update it
    sed -i "s#^\s*\baddons_path\b\s*=.*#addons_path = ${ADDONS_PATH}#" "$ODOO_RC"
else
    # addons_path does not exist, add it to the configuration file
    echo "addons_path = ${ADDONS_PATH}" >> "$ODOO_RC"
fi

# Set or update data_dir in the Odoo configuration file
if grep -q -E "^\s*\bdata_dir\b\s*=" "$ODOO_RC"; then
    # data_dir already exists in the configuration file, update it
    sed -i "s#^\s*\bdata_dir\b\s*=.*#data_dir = ${DATA_DIR}#" "$ODOO_RC"
else
    # data_dir does not exist, add it to the configuration file
    echo "data_dir = ${DATA_DIR}" >> "$ODOO_RC"
fi

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC"; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" | cut -d " " -f3 | sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            wait-for-psql.py "${DB_ARGS[@]}" --timeout=30
            exec odoo "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        wait-for-psql.py "${DB_ARGS[@]}" --timeout=30
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1

5. config/odoo.conf

This is the Odoo configuration file that will be mounted into the container. The entrypoint.sh script will modify this file at runtime.

config/odoo.conf

[options]

admin_passwd = odoo-example
addons_path = /mnt/extra-addons
data_dir = /etc/odoo

How to Run

    Make sure you are in the main directory of the project.

    Run the following command to build the Odoo image and start the containers in the background:

    docker-compose up -d --build

    Access Odoo by opening your browser and navigating to http://localhost:1005 (or the port you specified in your .env file).

To stop the containers, use:

docker-compose down

Key Customizations

This template includes a few important customizations:

    Custom Dockerfile and entrypoint.sh: The entrypoint.sh script automatically sets the admin_passwd, addons_path, and data_dir based on the variables from your .env file, providing a consistent and robust setup.

    Multi-Database Support: The DB_FILTER setting in the entrypoint.sh script is added to support a multi-database setup by default.

    Separation of Concerns: All configurations are managed through .env and a dedicated config folder, making the setup clean and easy to maintain.