import os
import time
import psycopg2

DB_URI = os.getenv("DB_URI")

def wait_for_database():
    """Wait for PostgreSQL to be available before continuing."""
    parsed_uri = urlparse(DB_URI)
    db_name = parsed_uri.path[1:]  # Remove leading '/' from path
    db_user = parsed_uri.username
    db_password = parsed_uri.password
    db_host = parsed_uri.hostname
    db_port = parsed_uri.port

    while True:
        try:
            # Attempt to connect to the database
            conn = psycopg2.connect(
                dbname=db_name,
                user=db_user,
                password=db_password,
                host=db_host,
                port=db_port
            )
            conn.close()
            print("✅ PostgreSQL is available!")
            break
        except psycopg2.OperationalError:
            print("⏳ Waiting for PostgreSQL to be available...")
            time.sleep(5)  # Wait 5 seconds before retrying

if __name__ == "__main__":
    wait_for_database()
