"""Quick verification of all 7 scenarios."""
import sys, os, json

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, PROJECT_ROOT)

from dotenv import load_dotenv
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

from railtracks_agents.lambda_handler import lambda_handler

scenarios = [
    ("Normal healthy", {"user_id":"s1","heart_rate":72,"spo2":97,"steps":6500,"sleep_hours":7.5,"pill_count":15,"last_movement_minutes":30,"hrv_percent":68,"mood_score":4.0}),
    ("Sleep+HRV low", {"user_id":"s2","heart_rate":68,"spo2":95,"steps":3200,"sleep_hours":4,"pill_count":10,"last_movement_minutes":60,"hrv_percent":35,"mood_score":3.5}),
    ("Inactivity", {"user_id":"s3","heart_rate":75,"spo2":96,"steps":800,"sleep_hours":6.5,"pill_count":8,"last_movement_minutes":300,"hrv_percent":55}),
    ("Low pills+miss", {"user_id":"s4","heart_rate":70,"spo2":97,"steps":5000,"sleep_hours":7,"pill_count":2,"last_movement_minutes":45,"medication_name":"Blood Pressure","doses_missed_consecutive_days":3}),
    ("Critical vitals", {"user_id":"s5","heart_rate":135,"spo2":88,"steps":1200,"sleep_hours":5.5,"pill_count":6,"last_movement_minutes":90}),
    ("Low mood", {"user_id":"s6","heart_rate":72,"spo2":96,"steps":2000,"sleep_hours":6,"pill_count":12,"last_movement_minutes":60,"mood_score":2.0}),
    ("FALL", {"user_id":"s7","heart_rate":85,"spo2":95,"steps":100,"sleep_hours":6,"pill_count":8,"last_movement_minutes":15,"fall_detected":True}),
]

all_pass = True
for name, data in scenarios:
    event = {"body": json.dumps(data), "requestContext": {"http": {"method": "POST"}}, "headers": {"content-type": "application/json"}}
    result = lambda_handler(event, None)
    body = json.loads(result.get("body", "{}"))
    status = result["statusCode"]
    risk = body.get("overall_risk", "?")
    agents = body.get("agents_invoked", [])
    has_summary = bool(body.get("summary"))
    ok = status == 200
    if not ok:
        all_pass = False
    label = "PASS" if ok else "FAIL"
    print(f"  {label} | {name:16s} | risk={risk:6s} | agents={len(agents):2d} | summary={'yes' if has_summary else 'no'}")

print()
if all_pass:
    print("  ALL 7 SCENARIOS PASSED")
else:
    print("  SOME SCENARIOS FAILED")
