import requests
from ingestion.smard_client import fetch_smard_timestamps, fetch_smard_data, ms_to_datetime
from datetime import datetime, timezone

"""
r = requests.get("https://www.smard.de/app/chart_data/410/DE/410_DE_hour_1627855200000.json")


print(r)

print(r.text)
"""


#start_txt = "2019-12-31"
#end_txt = "2020-01-02"
#start = datetime.strptime(start_txt, "%Y-%m%d").replace(tzinfo=timezone.utc)
#end = datetime.strptime(end_txt, "%Y-%m%d").replace(tzinfo=timezone.utc)

#Kontrollwerte für die Abfrage:
start = datetime(2019, 12, 31, tzinfo = timezone.utc)
end = datetime(2023, 1, 1, tzinfo = timezone.utc)
filter_id = 1226

timestamps = fetch_smard_timestamps(filter_id, resolution = "day")
print("Yearly Resolution Timestamps")
in_time = []
for ts in timestamps:
    new = ms_to_datetime(ts)
    if start <= new <= end:
        in_time.append(ts)
        print(new)
        

data = fetch_smard_data(filter_id, in_time[0], resolution = "day")
#print(f"Timestamps: {timestamps}")
#print(f"Data: {data}")
one = ms_to_datetime(timestamps[0])
two = ms_to_datetime(timestamps[1])
print(f"start: {one}, end {two}")
for pt in data: 
    time = ms_to_datetime(pt[0])
    if start <= time <= end:
        print(f"Time: {time}, Data: {pt[1]}")
print("Done")
