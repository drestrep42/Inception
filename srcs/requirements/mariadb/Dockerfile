# 1. BASE IMAGE
# Pulls a clean, stable, and minimal Debian Linux operating system. 
# This serves as the foundation environment that we will install MariaDB onto.
FROM debian:bookworm

# 2. INSTALLATION & CLEANUP
# apt-get update: Refreshes the package installer's list of available software.
# apt-get install -y mariadb-server: Installs the actual MariaDB database system without prompting for yes/no.
# rm -rf /var/lib/apt/lists/*: Deletes temporary installer files to keep the final Docker image as small as possible.
RUN apt-get update && apt-get install -y \
    mariadb-server \
    && rm -rf /var/lib/apt/lists/*

# 3. DIRECTORY & PERMISSIONS SETUP
# mkdir -p: Safely creates the runtime directory needed for the MariaDB socket file.
# chown -R: Gives ownership of that directory 0to the 'mysql' user so the database daemon can write to it.
# chmod 755: Adjusts read/write/execute permissions so the owner can fully manage it, while others can read/execute.
RUN mkdir -p /var/run/mysqld \
    && chown -R mysql:mysql /var/run/mysqld \
    && chmod 755 /var/run/mysqld

# 4. CONFIGURATION INJECTION
# Copies your custom database configuration from your local computer into the container's 
# configuration folder, overriding default settings (like binding to 0.0.0.0 to allow outside connections).
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/

# 5. INITIALIZATION SCRIPT INJECTION
# Copies your custom bash script into a standard system directory (/usr/local/bin/) 
# so it can be easily executed from anywhere inside the container.
COPY tools/init_db.sh /usr/local/bin/

# 6. SCRIPT EXECUTABILITY
# Modifies permissions on your script to make it "executable" (+x). 
# Without this step, Linux will block the container from running the script.
RUN chmod +x /usr/local/bin/init_db.sh

# 7. PORT EXPOSURE
# Documents that the container will listen on network port 3306 (the standard MySQL/MariaDB port). 
# Note: This doesn't actually publish the port to your host machine; it acts as internal documentation.
EXPOSE 3306

# 8. CONTAINER STARTUP COMMAND
# Configures the exact command that executes the moment the container spawns. 
# It triggers your 'init_db.sh' script to configure and start the database.
ENTRYPOINT ["init_db.sh"]