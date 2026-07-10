# Variables
COMPOSE_FILE = srcs/docker-compose.yml
DATA_DIR = /home/$(USER)/data
VOLUMES = mariadb_data wordpress_data

.PHONY: all build up down clean fclean re

all: build up

# Create data directories
$(DATA_DIR)/mariadb:
	mkdir -p $(DATA_DIR)/mariadb

$(DATA_DIR)/wordpress:
	mkdir -p $(DATA_DIR)/wordpress

# Create named volumes
volumes:
	docker volume create --driver local --opt type=none --opt o=bind --opt device=$(DATA_DIR)/mariadb mariadb_data
	docker volume create --driver local --opt type=none --opt o=bind --opt device=$(DATA_DIR)/wordpress wordpress_data

# Build images
build: $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress volumes
	docker compose -f $(COMPOSE_FILE) build

# Start services
up: volumes
	docker compose -f $(COMPOSE_FILE) up -d

# Stop services
down:
	docker compose -f $(COMPOSE_FILE) down

# Clean containers and images
clean:
	docker compose -f $(COMPOSE_FILE) down
	docker system prune -af

# Full clean including volumes
fclean: clean
	docker volume rm -f $(VOLUMES)
	sudo rm -rf $(DATA_DIR)

# Rebuild everything
re: fclean all
