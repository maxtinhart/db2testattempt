import psycopg2

db_url = "postgresql://postgres:mLECEMtAAFvnFJCurkQEOKISJsWhMzRa@iriguchi.proxy.rlwy.net:30949/railway"

print("Connecting to Railway database...")
conn = psycopg2.connect(db_url)
cur = conn.cursor()

print("Creating database schema...")
with open("schema.sql", "r") as f:
    cur.execute(f.read())
conn.commit()

print("Importing class_dataset.csv...")
with open("class_dataset.csv", "r") as f:
    cur.copy_expert("COPY raw_class_dataset_staging FROM STDIN WITH (FORMAT csv, HEADER true)", f)
conn.commit()

cur.close()
conn.close()

print("Done! Database tables created and dataset loaded successfully.")
