from whoop_sdk import Whoop
from datetime import datetime, timedelta
import json

# Initialize and authenticate (runs OAuth flow once, saves tokens)
whoop = Whoop()
whoop.login()  # Opens browser; approve access

# Fetch recent recovery data (last 7 days, up to 25 records)
end_date = datetime.now()
start_date = end_date - timedelta(days=7)
recoveries = whoop.get_recovery(
    start=start_date.isoformat() + "Z",
    end=end_date.isoformat() + "Z",
    limit=25
)

# Print HRV, SpO2, skin temp from scored recoveries
print("Whoop Recovery Data (HRV, SpO2, Skin Temp):\n")
records = recoveries.get('records', [])
for rec in records:
    if rec.get('score_state') == 'SCORED':
        score = rec['score']
        print(f"Cycle {rec['cycle_id']}:")
        print(f"  HRV (rmssd ms): {score.get('hrv_rmssd_milli', 'N/A')}")
        print(f"  SpO2 (%): {score.get('spo2_percentage', 'N/A')}")
        print(f"  Skin Temp (°C): {score.get('skin_temp_celsius', 'N/A')}")
        print(f"  Recovery Score: {score.get('recovery_score', 'N/A')}\n")
