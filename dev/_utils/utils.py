import uuid
import time
import os
import psycopg2
import json
import sys
from urllib.parse import urlparse
from database import Database

class Utils:
    def __init__(self):
        self.database = Database()
        self.op_id = None
        self.op_start_time = None
        self.env = {
            'DEBUG': os.getenv('DEBUG', 'false').lower(),
            'DB_URI': os.getenv('DB_URI')
        }


    def wait_for_database(self):
        """Wait for PostgreSQL to be available before continuing."""
        parsed_uri = urlparse(self.env['DB_URI'])
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
                self.log('info', 'PostgreSQL is available')
                break
            except psycopg2.OperationalError:
                sleep_time = 5
                self.log('info', 'Waiting for PostgreSQL to be available', {'sleep_time_seconds': sleep_time})
                time.sleep(sleep_time)  # Wait x seconds before retrying


    def log(self, level, message, body=dict()):
        # Skip if it's a debug message but debug is not enabled
        if level == "debug" and self.env['DEBUG'] == "false":
            return

        if level == 'error':
            stream = sys.stderr
        else:
            stream = sys.stdout

        log_message = {
            "level": level,
            "operation_id": self.op_id,
            "message": message,
            "body": body
        }

        try:
            log_json = json.dumps(log_message, separators=(',', ':'))
            print(log_json, file=stream)
        except (TypeError, ValueError) as e:
            print(f'{{"level":"error","operation_id":"{self.op_id}","message":"Unable to log as JSON","body":{{"log_message":"{log_message}"}}}}', file=sys.stderr)

        if level == "error":
            sys.exit(1)


    def operation_start(self):
        """Generates an operation ID, waits for the database, and records the start time."""
        # Reset operation ID
        self.op_id = None
        # Wait for the database to be available
        self.wait_for_database()
        # Generate operation ID
        self.op_id = str(uuid.uuid4())
        # Log operation start
        self.log('info', 'Operation start')
        # Record initial time in milliseconds
        self.start_time = int(time.time() * 1000)


    def operation_end(self):
        """Calculates the elapsed time from the start time and logs the operation end."""
        # Get current time in milliseconds (operation end time)
        end_time = int(time.time() * 1000)
        # Calculate timespan
        timespan = end_time - self.start_time
        # Log operation end
        self.log('info', 'Operation end', {'timespan_ms': timespan})
