1. **Monitor Agent** (Bedrock Claude): Polls Whoop API hourly via Lambda— "HRV 35 + low steps = walk reminder needed."
2. **Reason Agent** (LangGraph): Chains: Check med log (DynamoDB) → "Missed statins; refill low."
3. **Execute Agent**:
    - Texts "Time to walk 10min" (Twilio API).
    - Refills via mock Shoppers Drug Mart/Sun Life pharmacy API.
    - Notifies kids/ER if fall detected (HR spike + no movement).
    - Books video call: "Call son John?" from family KB (OpenSearch RAG).

**Tech Stack** (Your TCS Expertise):

| Component | Tools | Senior Action |
| --- | --- | --- |
| Data Ingestion | Whoop API + S3 | Fitness metrics + voice transcripts. |
| Orchestration | LangChain/LangGraph on Bedrock | Memory of prefs/meds. |
| Frontend | Next.js voice UI | "Remind me meds?" chat. |
| Deployment | AWS Lambda/SageMaker | Real-time (<30s alerts). |