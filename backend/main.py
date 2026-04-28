from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import oracledb
import os
from dotenv import load_dotenv
from google import genai

load_dotenv()

app = FastAPI(title="CivicFlow AI Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

ORACLE_USER = os.getenv("ORACLE_USER")
ORACLE_PASSWORD = os.getenv("ORACLE_PASSWORD")
ORACLE_DSN = os.getenv("ORACLE_DSN")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

client = genai.Client(api_key=GEMINI_API_KEY)

MAX_DAILY_CALLS = 20


def read_lob(value):
    return value.read() if value else None


def action_text_to_list(action_text):
    if not action_text:
        return []

    actions = []
    for line in action_text.split("\n"):
        line = line.strip()
        if line:
            cleaned = line.split(".", 1)[-1].strip()
            actions.append(cleaned)

    return actions


def get_connection():
    try:
        return oracledb.connect(
            user=ORACLE_USER,
            password=ORACLE_PASSWORD,
            dsn=ORACLE_DSN
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
def home():
    return {"message": "CivicFlow AI backend is running 🚀"}


@app.get("/test-db")
def test_db():
    try:
        conn = get_connection()
        conn.close()
        return {"message": "Database connected successfully ✅"}
    except Exception as e:
        return {"error": str(e)}


@app.get("/incidents")
def get_incidents():
    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT incident_id, incident_title, incident_description, start_time
            FROM INCIDENT
            ORDER BY start_time DESC
        """)

        rows = cursor.fetchall()

        result = []
        for row in rows:
            result.append({
                "incident_id": row[0],
                "title": row[1],
                "description": read_lob(row[2]),
                "start_time": str(row[3])
            })

        cursor.close()
        conn.close()

        return result

    except Exception as e:
        return {"error": str(e)}


@app.get("/usage")
def usage():
    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT COUNT(*)
            FROM API_USAGE
            WHERE call_time >= TRUNC(SYSDATE)
        """)

        count = cursor.fetchone()[0]

        cursor.close()
        conn.close()

        return {
            "daily_limit": MAX_DAILY_CALLS,
            "requests_used_today": count,
            "remaining_today": MAX_DAILY_CALLS - count
        }

    except Exception as e:
        return {"error": str(e)}


@app.get("/analyze-incident/{incident_id}")
def analyze_incident(incident_id: int):
    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT COUNT(*)
            FROM API_USAGE
            WHERE call_time >= TRUNC(SYSDATE)
        """)
        usage_today = cursor.fetchone()[0]

        if usage_today >= MAX_DAILY_CALLS:
            cursor.close()
            conn.close()
            return {
                "error": "Daily Gemini API limit reached",
                "used": usage_today,
                "limit": MAX_DAILY_CALLS
            }

        cursor.execute("""
            SELECT ai_predicted_severity,
                   ai_predicted_category,
                   ai_likely_root_cause,
                   ai_recommended_action,
                   ai_passenger_message,
                   ai_executive_summary,
                   ai_confidence_score,
                   model_name,
                   created_at
            FROM AI_ANALYSIS
            WHERE incident_id = :id
            ORDER BY created_at DESC
            FETCH FIRST 1 ROWS ONLY
        """, {"id": incident_id})

        cached = cursor.fetchone()

        if cached:
            root_cause = read_lob(cached[2])
            raw_action = read_lob(cached[3])
            passenger_message = read_lob(cached[4])
            executive_summary = read_lob(cached[5])

            cursor.close()
            conn.close()

            return {
                "incident_id": incident_id,
                "source": "cache",
                "severity": cached[0],
                "category": cached[1],
                "root_cause": root_cause,
                "recommended_action": action_text_to_list(raw_action),
                "passenger_message": passenger_message,
                "executive_summary": executive_summary,
                "confidence": cached[6],
                "model": cached[7],
                "created_at": str(cached[8]),
                "api_called": False,
                "remaining_today": MAX_DAILY_CALLS - usage_today
            }

        cursor.execute("""
            SELECT incident_title, incident_description
            FROM INCIDENT
            WHERE incident_id = :id
        """, {"id": incident_id})

        row = cursor.fetchone()

        if not row:
            cursor.close()
            conn.close()
            return {"error": "Incident not found"}

        title = row[0]
        description = read_lob(row[1]) or ""

        prompt = f"""
        Analyze this transit incident:

        Title: {title}
        Description: {description}

        Return the response in this exact format:

        Severity:
        Category:
        Root Cause:
        Recommended Action:
        Passenger Message:
        Executive Summary:
        Confidence Score:
        """

        model_name = "gemini-2.5-flash"

        response = client.models.generate_content(
            model=model_name,
            contents=prompt
        )

        text = response.text

        def extract(label):
            try:
                start = text.index(label) + len(label)
                labels = [
                    "Severity:",
                    "Category:",
                    "Root Cause:",
                    "Recommended Action:",
                    "Passenger Message:",
                    "Executive Summary:",
                    "Confidence Score:"
                ]
                end_positions = [
                    text.find(next_label, start)
                    for next_label in labels
                    if text.find(next_label, start) != -1
                ]
                end = min(end_positions) if end_positions else len(text)
                return text[start:end].strip()
            except:
                return None

        severity = extract("Severity:") or "Unknown"
        category = extract("Category:") or "Unknown"
        root_cause = extract("Root Cause:") or "N/A"
        raw_action = extract("Recommended Action:") or "N/A"
        passenger_msg = extract("Passenger Message:") or "N/A"
        summary = extract("Executive Summary:") or "N/A"
        confidence = extract("Confidence Score:") or "85"

        actions = action_text_to_list(raw_action)

        try:
            confidence = float(confidence.replace("%", "").strip())
        except:
            confidence = 85.0

        cursor.execute("""
            INSERT INTO AI_ANALYSIS (
                incident_id,
                ai_predicted_severity,
                ai_predicted_category,
                ai_likely_root_cause,
                ai_recommended_action,
                ai_passenger_message,
                ai_executive_summary,
                ai_confidence_score,
                model_name
            )
            VALUES (
                :id, :sev, :cat, :rc, :act, :msg, :sum, :conf, :model
            )
        """, {
            "id": incident_id,
            "sev": severity,
            "cat": category,
            "rc": root_cause,
            "act": raw_action,
            "msg": passenger_msg,
            "sum": summary,
            "conf": confidence,
            "model": model_name
        })

        cursor.execute("""
            INSERT INTO API_USAGE (call_time)
            VALUES (CURRENT_TIMESTAMP)
        """)

        conn.commit()

        cursor.close()
        conn.close()

        return {
            "incident_id": incident_id,
            "source": "gemini",
            "severity": severity,
            "category": category,
            "root_cause": root_cause,
            "recommended_action": actions,
            "passenger_message": passenger_msg,
            "executive_summary": summary,
            "confidence": confidence,
            "model": model_name,
            "api_called": True,
            "remaining_today": MAX_DAILY_CALLS - (usage_today + 1)
        }

    except Exception as e:
        return {"error": str(e)}