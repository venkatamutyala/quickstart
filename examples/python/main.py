"""Minimal example: connect to Postgres + S3 (Garage) using standard env vars.

Reads DATABASE_URL and AWS_* from the environment — exactly what `make env` exports
(or `make example` injects). Demonstrates the round-trip an app would do.
"""
import os
import boto3
import psycopg
from botocore.config import Config

# --- Postgres ---
with psycopg.connect(os.environ["DATABASE_URL"]) as conn, conn.cursor() as cur:
    cur.execute("SELECT version()")
    print("postgres:", cur.fetchone()[0].split(",")[0])
    cur.execute("CREATE TABLE IF NOT EXISTS example_app (id serial primary key, note text)")
    cur.execute("INSERT INTO example_app (note) VALUES (%s) RETURNING id", ("hello from example",))
    print("postgres: inserted row id", cur.fetchone()[0])

# --- S3 (Garage) ---
s3 = boto3.client(
    "s3",
    endpoint_url=os.environ["AWS_ENDPOINT_URL"],
    region_name=os.environ["AWS_REGION"],
    config=Config(s3={"addressing_style": "path"}),  # Garage needs path-style
)
bucket, key = os.environ["S3_BUCKET"], "example/hello.txt"
s3.put_object(Bucket=bucket, Key=key, Body=b"hello from example app")
body = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
print("s3: round-trip ok:", body == b"hello from example app")

print("\nExample app connected to both backends successfully.")
