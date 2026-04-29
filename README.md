# CivicFlow AI! Incident Intelligence System

A full-stack web application for managing and analyzing transit incidents using AI. The backend is powered by **FastAPI** + **Oracle Database**, the frontend uses **React 19** with **TanStack Router**, and AI analysis is provided by **Google Gemini 2.5 Flash**.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Tech Stack](#3-tech-stack)
4. [Prerequisites](#4-prerequisites)
5. [Project Structure](#5-project-structure)
6. [Database Setup (Oracle)](#6-database-setup-oracle)
7. [Backend Setup](#7-backend-setup)
8. [Frontend Setup](#8-frontend-setup)
9. [Environment Variables](#9-environment-variables)
10. [API Reference](#10-api-reference)
11. [Database Schema](#11-database-schema)
12. [AI Analysis Flow](#12-ai-analysis-flow)
13. [Running the Full Stack](#13-running-the-full-stack)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Project Overview

CivicFlow AI is a transit incident management dashboard that allows operators to:

- **View all transit incidents** pulled from an Oracle database
- **Trigger AI-powered analysis** on any incident using Google Gemini
- **Cache AI responses** so the same incident is not analyzed twice (saves API quota)
- **Track daily API usage** against a configurable limit (default: 20 calls/day)
- Get structured AI outputs: severity prediction, root cause, recommended actions, passenger-facing messages, and an executive summary

---

## 2. Architecture

```
┌─────────────────────┐        HTTP         ┌──────────────────────┐
│   React Frontend    │ ◄─────────────────► │  FastAPI Backend     │
│  (TanStack Router)  │                     │  (Python / Uvicorn)  │
└─────────────────────┘                     └──────────┬───────────┘
                                                       │
                                          ┌────────────┴────────────┐
                                          │                         │
                                   ┌──────▼──────┐       ┌─────────▼────────┐
                                   │  Oracle DB  │       │  Google Gemini   │
                                   │  (Schema)   │       │  2.5 Flash API   │
                                   └─────────────┘       └──────────────────┘
```

- The **frontend** calls the backend REST API to fetch incidents and request AI analysis.
- The **backend** checks Oracle for a cached AI result before calling Gemini.
- Every Gemini API call is logged in the `API_USAGE` table for daily rate-limiting.

---

## 3. Tech Stack

| Layer    | Technology                                                  |
|----------|-------------------------------------------------------------|
| Frontend | React 19, TanStack Router, TanStack Query, Tailwind CSS v4, Radix UI, Recharts, Vite 7 |
| Backend  | Python 3, FastAPI 0.128, Uvicorn, python-dotenv             |
| Database | Oracle DB (any edition), `oracledb` Python driver v3.4      |
| AI       | Google Gemini 2.5 Flash (`google-genai` SDK v1.47)          |

---

## 4. Prerequisites

Before you begin, make sure you have the following installed:

- **Python 3.10+** — [python.org](https://www.python.org/downloads/)
- **Node.js 18+** and **npm** — [nodejs.org](https://nodejs.org/)
- **Oracle Database** (local, Docker, or cloud — Oracle Free tier works)
- **Oracle Instant Client** (required by the `oracledb` Python driver in thick mode, if needed)
- A **Google Gemini API key** — [aistudio.google.com](https://aistudio.google.com/app/apikey)

---

## 5. Project Structure

```
civicflow-ai-main/
├── backend/
│   ├── main.py               # FastAPI app — all routes and logic
│   └── requirements.txt      # Python dependencies (pinned versions)
├── database/
│   └── civicflow_ai_schema.sql  # Full Oracle schema (run this first)
├── civicflow_ai_schema.sql   # Duplicate schema file (same content)
├── frontend/
│   ├── package.json          # Node dependencies and scripts
│   └── package-lock.json     # Lockfile
├── .gitignore
├── LICENSE
└── README.md
```

> **Note:** The frontend source files (components, routes, pages) are not included in this zip. You will need to scaffold or add them separately — see [Frontend Setup](#8-frontend-setup).

---

## 6. Database Setup (Oracle)

### Step 1 — Connect to your Oracle instance

Use SQL*Plus, SQL Developer, or any Oracle client:

```sql
sqlplus YOUR_USER/YOUR_PASSWORD@YOUR_HOST:1521/YOUR_SERVICE
```

### Step 2 — Run the schema script

```sql
@/path/to/civicflow-ai-main/database/civicflow_ai_schema.sql
```

Or paste the file contents directly into your SQL client. This will create the following tables:

| Table              | Purpose                                              |
|--------------------|------------------------------------------------------|
| `APP_ROLE`         | User roles (e.g., Admin, Operator)                   |
| `APP_USER`         | Application users with role assignments              |
| `INCIDENT_CATEGORY`| Lookup table for incident categories                 |
| `INCIDENT_SEVERITY`| Lookup table for severity levels (with numeric order)|
| `INCIDENT_STATUS`  | Lookup table for incident statuses                   |
| `TRANSIT_ROUTE`    | Transit routes (bus, subway, etc.)                   |
| `STATION`          | Station locations                                    |
| `RESPONSE_TEAM`    | Response teams and their contact details             |
| `INCIDENT`         | Core incident records (linked to all lookup tables)  |
| `INCIDENT_UPDATE`  | Log of updates made to each incident                 |
| `AI_ANALYSIS`      | Cached Gemini AI analysis results per incident       |
| `PUBLIC_ALERT`     | Published public-facing alerts for incidents         |
| `API_USAGE`        | Timestamped log of every Gemini API call made        |

### Step 3 — Seed lookup tables (optional but recommended)

Before creating incidents, populate the lookup tables:

```sql
INSERT INTO APP_ROLE (role_name) VALUES ('Admin');
INSERT INTO APP_ROLE (role_name) VALUES ('Operator');

INSERT INTO INCIDENT_SEVERITY (severity_name, severity_level) VALUES ('Low', 1);
INSERT INTO INCIDENT_SEVERITY (severity_name, severity_level) VALUES ('Medium', 2);
INSERT INTO INCIDENT_SEVERITY (severity_name, severity_level) VALUES ('High', 3);
INSERT INTO INCIDENT_SEVERITY (severity_name, severity_level) VALUES ('Critical', 4);

INSERT INTO INCIDENT_STATUS (status_name) VALUES ('Open');
INSERT INTO INCIDENT_STATUS (status_name) VALUES ('In Progress');
INSERT INTO INCIDENT_STATUS (status_name) VALUES ('Resolved');

INSERT INTO INCIDENT_CATEGORY (category_name) VALUES ('Signal Failure');
INSERT INTO INCIDENT_CATEGORY (category_name) VALUES ('Track Obstruction');
INSERT INTO INCIDENT_CATEGORY (category_name) VALUES ('Power Outage');

COMMIT;
```

---

## 7. Backend Setup

### Step 1 — Navigate to the backend folder

```bash
cd civicflow-ai-main/backend
```

### Step 2 — Create a virtual environment

```bash
python -m venv venv
```

Activate it:

- **Windows:** `venv\Scripts\activate`
- **macOS/Linux:** `source venv/bin/activate`

### Step 3 — Install dependencies

```bash
pip install -r requirements.txt
```

Key packages installed:

| Package           | Version  | Purpose                            |
|-------------------|----------|------------------------------------|
| `fastapi`         | 0.128.8  | Web framework                      |
| `uvicorn`         | 0.39.0   | ASGI server                        |
| `oracledb`        | 3.4.2    | Oracle DB Python driver            |
| `google-genai`    | 1.47.0   | Google Gemini SDK                  |
| `python-dotenv`   | 1.2.1    | Load `.env` variables              |
| `pydantic`        | 2.13.3   | Data validation                    |

### Step 4 — Create a `.env` file

In the `backend/` folder, create a file named `.env`:

```env
ORACLE_USER=your_oracle_username
ORACLE_PASSWORD=your_oracle_password
ORACLE_DSN=localhost:1521/XEPDB1
GEMINI_API_KEY=your_gemini_api_key_here
```

Replace the values with your actual credentials. `ORACLE_DSN` format is `host:port/service_name`.

### Step 5 — Run the backend server

```bash
uvicorn main:app --reload
```

The API will be available at: `http://localhost:8000`

To confirm it's working, open `http://localhost:8000` in your browser — you should see:

```json
{"message": "CivicFlow AI backend is running 🚀"}
```

---

## 8. Frontend Setup

### Step 1 — Navigate to the frontend folder

```bash
cd civicflow-ai-main/frontend
```

### Step 2 — Install dependencies

```bash
npm install
```

### Step 3 — Configure the API URL

The frontend needs to know where the backend is running. Create a `.env` file in the `frontend/` folder:

```env
VITE_API_URL=http://localhost:8000
```

> If your backend runs on a different port or host, update this value accordingly.

### Step 4 — Start the development server

```bash
npm run dev
```

The frontend will be available at: `http://localhost:5173` (default Vite port)

### Available scripts

| Command           | Description                          |
|-------------------|--------------------------------------|
| `npm run dev`     | Start development server with HMR    |
| `npm run build`   | Build for production                 |
| `npm run preview` | Preview the production build locally |
| `npm run lint`    | Run ESLint                           |
| `npm run format`  | Format code with Prettier            |

---

## 9. Environment Variables

### Backend (`backend/.env`)

| Variable          | Required | Description                                              |
|-------------------|----------|----------------------------------------------------------|
| `ORACLE_USER`     | ✅       | Oracle database username                                 |
| `ORACLE_PASSWORD` | ✅       | Oracle database password                                 |
| `ORACLE_DSN`      | ✅       | Oracle connection string, e.g. `localhost:1521/XEPDB1`   |
| `GEMINI_API_KEY`  | ✅       | Your Google Gemini API key from AI Studio                |

### Frontend (`frontend/.env`)

| Variable       | Required | Description                           |
|----------------|----------|---------------------------------------|
| `VITE_API_URL` | ✅       | Base URL of the backend API server    |

---

## 10. API Reference

All endpoints are served from the FastAPI backend.

### `GET /`
Health check. Returns a confirmation that the backend is running.

**Response:**
```json
{"message": "CivicFlow AI backend is running 🚀"}
```

---

### `GET /test-db`
Tests the Oracle database connection.

**Response (success):**
```json
{"message": "Database connected successfully ✅"}
```

**Response (failure):**
```json
{"error": "ORA-01017: invalid username/password"}
```

---

### `GET /incidents`
Returns all incidents from the `INCIDENT` table, ordered by most recent first.

**Response:**
```json
[
  {
    "incident_id": 1,
    "title": "Signal failure on Line 2",
    "description": "Eastbound signal system failed at Union Station...",
    "start_time": "2024-11-15 08:23:00"
  }
]
```

---

### `GET /usage`
Returns today's Gemini API usage stats.

**Response:**
```json
{
  "daily_limit": 20,
  "requests_used_today": 3,
  "remaining_today": 17
}
```

---

### `GET /analyze-incident/{incident_id}`
Triggers AI analysis for the given incident. Checks the cache first — if an analysis already exists in `AI_ANALYSIS`, it is returned immediately without calling Gemini.

**Path parameter:** `incident_id` (integer)

**Response (from cache):**
```json
{
  "incident_id": 1,
  "source": "cache",
  "severity": "High",
  "category": "Signal Failure",
  "root_cause": "Electrical fault in relay box at Union Station...",
  "recommended_action": ["Dispatch maintenance crew", "Switch to manual signalling"],
  "passenger_message": "Delays expected on Line 2 eastbound. Use alternate routes.",
  "executive_summary": "Signal failure at Union causing cascading 20-minute delays...",
  "confidence": 91.0,
  "model": "gemini-2.5-flash",
  "created_at": "2024-11-15 09:00:00",
  "api_called": false,
  "remaining_today": 17
}
```

**Response (fresh Gemini call):** Same shape, but `"source": "gemini"` and `"api_called": true`.

**Response (daily limit reached):**
```json
{
  "error": "Daily Gemini API limit reached",
  "used": 20,
  "limit": 20
}
```

---

## 11. Database Schema

### Key relationships

```
APP_ROLE ──────────────── APP_USER
                               │
INCIDENT_CATEGORY ─────┐      │ created_by
INCIDENT_SEVERITY ─────┼──► INCIDENT ◄─── TRANSIT_ROUTE
INCIDENT_STATUS ───────┘      │            STATION
                               │            RESPONSE_TEAM
                               │
                    ┌──────────┼──────────────┐
                    │          │              │
             INCIDENT_UPDATE  AI_ANALYSIS  PUBLIC_ALERT

API_USAGE (standalone — logs every Gemini call with a timestamp)
```

### `INCIDENT` table (core)

| Column                    | Type         | Notes                          |
|---------------------------|--------------|--------------------------------|
| `incident_id`             | NUMBER (PK)  | Auto-generated identity        |
| `incident_title`          | VARCHAR2(200)| Short title                    |
| `incident_description`    | CLOB         | Full description               |
| `category_id`             | FK           | → `INCIDENT_CATEGORY`          |
| `severity_id`             | FK           | → `INCIDENT_SEVERITY`          |
| `status_id`               | FK           | → `INCIDENT_STATUS`            |
| `route_id`                | FK (nullable)| → `TRANSIT_ROUTE`              |
| `station_id`              | FK (nullable)| → `STATION`                    |
| `assigned_team_id`        | FK (nullable)| → `RESPONSE_TEAM`              |
| `start_time`              | TIMESTAMP    | When the incident began        |
| `estimated_recovery_time` | TIMESTAMP    | Optional ETA                   |
| `actual_recovery_time`    | TIMESTAMP    | When it was actually resolved  |
| `created_by`              | FK           | → `APP_USER`                   |

### `AI_ANALYSIS` table

| Column                  | Type          | Notes                              |
|-------------------------|---------------|------------------------------------|
| `analysis_id`           | NUMBER (PK)   | Auto-generated                     |
| `incident_id`           | FK            | → `INCIDENT` (cascade delete)      |
| `ai_predicted_severity` | VARCHAR2(50)  | e.g., "High"                       |
| `ai_predicted_category` | VARCHAR2(100) | e.g., "Signal Failure"             |
| `ai_likely_root_cause`  | CLOB          | Detailed explanation               |
| `ai_recommended_action` | CLOB          | Numbered list, parsed into array   |
| `ai_passenger_message`  | CLOB          | Public-facing message              |
| `ai_executive_summary`  | CLOB          | Summary for management             |
| `ai_confidence_score`   | NUMBER(5,2)   | 0–100 score                        |
| `model_name`            | VARCHAR2(100) | e.g., "gemini-2.5-flash"           |

---

## 12. AI Analysis Flow

When `GET /analyze-incident/{id}` is called, the backend follows this logic:

```
1. Check daily API usage → if >= 20, return error immediately

2. Query AI_ANALYSIS for an existing result for this incident_id
   └── If found → return cached result (api_called: false)

3. Fetch incident title + description from INCIDENT table
   └── If not found → return 404-style error

4. Build a structured prompt and send to Gemini 2.5 Flash

5. Parse the 7-field response:
   Severity / Category / Root Cause / Recommended Action /
   Passenger Message / Executive Summary / Confidence Score

6. Insert parsed result into AI_ANALYSIS
7. Insert a timestamp row into API_USAGE
8. COMMIT and return the result (api_called: true)
```

The `recommended_action` field is returned as a **list** — the backend strips numbering (e.g., `"1. Deploy crew"` → `"Deploy crew"`) so the frontend can render it as bullet points.

---

## 13. Running the Full Stack

Open two terminal windows:

**Terminal 1 — Backend:**
```bash
cd civicflow-ai-main/backend
source venv/bin/activate   # or venv\Scripts\activate on Windows
uvicorn main:app --reload
```

**Terminal 2 — Frontend:**
```bash
cd civicflow-ai-main/frontend
npm run dev
```

Then open `http://localhost:5173` in your browser.

To verify the backend is connected to the database, visit `http://localhost:8000/test-db`.

---

## 14. Troubleshooting

### `ORA-12541: TNS:no listener`
The Oracle database is not running or the DSN is wrong. Check your `ORACLE_DSN` in `.env` and make sure the Oracle listener is active.

### `DPI-1047: Cannot locate a 64-bit Oracle Client library`
The `oracledb` driver needs Oracle Instant Client in thick mode. Either:
- Install Oracle Instant Client and set `LD_LIBRARY_PATH` (Linux/macOS) or add it to `PATH` (Windows)
- Or switch to thin mode by calling `oracledb.init_oracle_client()` if you have the full client

### `google.api_core.exceptions.InvalidArgument` or 403
Your `GEMINI_API_KEY` is missing, invalid, or the model name is wrong. Double-check the key in `.env`.

### CORS errors in the browser
The backend allows all origins (`allow_origins=["*"]`). If you're still seeing CORS errors, make sure the backend is actually running and the `VITE_API_URL` in the frontend `.env` matches the backend address exactly (including the port).

### Daily limit reached immediately
The `API_USAGE` table may have stale rows, or `MAX_DAILY_CALLS` is set too low. You can reset today's usage:
```sql
DELETE FROM API_USAGE WHERE call_time >= TRUNC(SYSDATE);
COMMIT;
```
Or increase the limit in `main.py`: change `MAX_DAILY_CALLS = 20` to your desired value.

### Frontend shows no incidents
Make sure you have rows in the `INCIDENT` table. Use the seed script in [Step 3 of Database Setup](#step-3----seed-lookup-tables-optional-but-recommended) and insert a test incident, then confirm `GET /incidents` returns data.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
