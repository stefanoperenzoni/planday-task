import pandas as pd
from sqlalchemy import create_engine, TIMESTAMP

file_path = './data/analytics_engineering_task.csv'
df = pd.read_csv(file_path)

engine = create_engine("postgresql://test:test@localhost:5432/planday")
conn = engine.connect()

df.to_sql('interactions', conn, if_exists='replace', index=False, schema="planday", dtype={'TIMESTAMP': TIMESTAMP()})