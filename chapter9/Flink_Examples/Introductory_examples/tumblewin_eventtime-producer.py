import pandas as pd
import time
from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

df = pd.read_csv(
    '/mnt/e/Data/NYCBikes/tripsny.tsv',
    sep='\t',
    dtype=str
)

df = df.sort_values('start_time').reset_index(drop=True)

df['start_time_dt'] = pd.to_datetime(df['start_time'], format='mixed')

total_event_seconds = 2220 * 24 * 3600
desired_real_seconds = 10 * 60  # 10 minutes
SPEED_FACTOR = total_event_seconds / desired_real_seconds
print(f"SPEED_FACTOR: {SPEED_FACTOR:.0f}")
print(f"Total rows to send: {len(df)}")

t0_real = time.time()
t0_event = df['start_time_dt'].iloc[0]

for i, (_, row) in enumerate(df.iterrows()):

    if i % 1000 == 0:
        print(f"Sent {i} rows, current event time: {row['start_time']}")

    event_dt = row['start_time_dt']
    event_offset = (event_dt - t0_event).total_seconds()
    real_offset = event_offset / SPEED_FACTOR

    sleep_time = (t0_real + real_offset) - time.time()
    if sleep_time > 0:
        time.sleep(sleep_time)

    payload = {
        k: (None if pd.isna(v) else v)
        for k, v in row.drop('start_time_dt').items()
    }

    producer.send('raw-trips', value=payload)

producer.flush()
print(f"Done. Total rows sent: {len(df)}")
