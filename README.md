# Financial Data Warehouse — Acme Ltd

A financial data warehouse platform built with **FastAPI** and **MongoDB**. Collects market data from multiple vendors, stores it with full temporal history, exposes it via a RESTful API, includes Apache Spark batch analytics, and provides an LLM-powered assistant (Groq + MCP) for natural-language data exploration.

---

## Quick Start

### Prerequisites

- **Docker (recommended):** Docker Desktop — includes MongoDB, Java 17, and PySpark in the API image
- **Local run:** Python 3.11+, MongoDB 7.0+, Java 17+ (for Spark), optional Groq API key (for LLM assistant)

### Install & Run (Docker)

```bash
git clone https://github.com/codrinrata/DWPROEJCT.git
cd DW
cp .env.example .env          # optional: GROQ_API_KEY, vendor keys
docker compose up --build
# Open http://localhost:8000     ← Web GUI
# Open http://localhost:8000/docs ← Swagger API
```

### Install & Run (Windows / Linux local)

```bash
python -m venv .venv
.venv\Scripts\activate          # Windows
# source .venv/bin/activate     # Linux/macOS
pip install -r requirements.txt
cp .env.example .env
python scripts/seed.py          # requires MongoDB on localhost:27017
uvicorn app.main:app --reload --port 8000
```

Or on Windows: `.\run.ps1`

### If Docker `apt-get` / Java fails

```bash
docker compose -f docker-compose.yml -f docker-compose.nospark.yml up --build
```

Spark will use a Python fallback; all other features work normally.

---

## Project Structure

```
DW/
├── README.md
├── requirements.txt
├── .env.example
├── docker-compose.yml
├── Dockerfile                      ← API image (Python + Java 17 + PySpark)
├── Dockerfile.nospark              ← Fallback image without Java
├── mcp_config.json                 ← Cursor MCP configuration
├── run.ps1                         ← Windows one-command startup
├── scripts/
│   └── seed.py                     ← MongoDB seed / backfill
├── analytics/
│   └── spark_job.py                ← Standalone Spark aggregation job
├── langflow/
│   └── amip_agent_flow.json        ← Bonus: LangFlow agent flow
└── app/
    ├── main.py                     ← FastAPI entry point + web GUI
    ├── config.py
    ├── db/
    │   ├── connection.py           ← MongoDB + indexes
    │   ├── temporal.py             ← Temporal query helpers
    │   └── repositories.py         ← assets, sources, time_series, ingestion_runs
    ├── models/
    │   └── schemas.py              ← Pydantic API models
    ├── ingestion/                  ← UC1: vendor clients + pipeline
    │   ├── pipeline.py
    │   ├── yfinance_client.py
    │   ├── nasdaq_client.py
    │   ├── bloomberg_client.py
    │   ├── simulated_vendor.py
    │   └── vendor_indicators.py
    ├── api/routes/
    │   ├── assets.py               ← Q1, Q2, Q5 + provenance
    │   ├── sources.py              ← Q3, Q4
    │   ├── analytics.py            ← UC3 analytics + Spark
    │   ├── ingestion.py            ← UC1 ingest endpoints
    │   ├── admin.py                ← Temporal demo (update / tombstone)
    │   └── assistant.py            ← UC4 LLM chat API
    ├── analytics/
    │   ├── service.py              ← Python analytics (trend, risk, forecast…)
    │   └── spark_engine.py         ← Apache Spark integration + debug
    ├── assistant/
    │   └── service.py              ← Groq LLM + grounded tools
    ├── tools/
    │   └── platform.py             ← Shared MCP / LLM tool layer
    ├── mcp_server/
    │   └── server.py               ← UC4 MCP server (12 tools)
    └── static/                     ← Web GUI (dashboard, assets, analytics, LLM)
```

---

## Web GUI

Open **http://localhost:8000** after startup.

| Tab | Features |
|-----|----------|
| **Dashboard** | Stats, compare two assets (normalized % chart) |
| **Assets** | Browse instruments, price charts, details |
| **Analytics** | Trend, risk, forecast, aggregate, recommendation |
| **Analytics → Spark** | Run Spark pipeline, **Debug Spark**, export CSV |
| **Data Sources** | Provider list and coverage |
| **LLM Assistant** | Groq-powered chat (or built-in tool mode) |
| **Run Ingestion** | Load / refresh warehouse data (sidebar) |

---

## Apache Spark Analytics (UC3)

Docker image includes **Java 17 + PySpark**. The Spark pipeline:

1. Exports all time series to CSV from MongoDB  
2. Runs Spark `groupBy` aggregations (count, min, max, avg per asset + vendor)  
3. Returns results in the GUI or API  

### GUI

**Analytics** tab → **Apache Spark** → **Run Spark Pipeline** or **Debug Spark**

### API

```bash
# Check Java + PySpark
curl http://localhost:8000/api/v1/analytics/spark-status

# Step-by-step diagnostics (no full pipeline)
curl http://localhost:8000/api/v1/analytics/spark-debug

# Export + Spark aggregation
curl -X POST "http://localhost:8000/api/v1/analytics/spark-run?source=all"
```

Expect `"engine": "pyspark"` when Spark is working. If you see `"engine": "stdlib"`, open **Debug steps** in the GUI or check `debugSteps` in the API response.

### Standalone Spark job

```bash
curl -o data/export/timeseries_export.csv \
  "http://localhost:8000/api/v1/analytics/export/csv?source=all"

python analytics/spark_job.py data/export/timeseries_export.csv
```

### Python analytics (interactive, not Spark)

The upper **Analytics** section uses **Python** (`AnalyticsService`) — one asset at a time:

- Trend, risk, forecast, aggregate, recommendation  
- Reads directly from MongoDB (no Spark)

---

## REST API (UC2: Q1–Q5)

Base URL: `http://localhost:8000/api/v1`

| Query | Endpoint |
|-------|----------|
| Q1 | `GET /assets` |
| Q2 | `GET /assets/{assetId}` |
| Q3 | `GET /sources` |
| Q4 | `GET /sources/{dataSourceId}` |
| Q5 | `GET /assets/{assetId}/timeseries?dataSourceId=yfinance` |

Point-in-time queries: append `?as_of=2024-01-01T00:00:00Z` to Q1–Q4.

### Additional endpoints

```
GET      /assets/{assetId}/provenance     Data provenance per vendor
GET      /sources/coverage               Point counts per source/asset

POST     /ingest/run                      Full ingestion (all vendors)
GET      /ingest/status                   Vendor configuration
GET      /ingest/runs                     Ingestion audit log

GET      /analytics/trend                 Price trend
GET      /analytics/compare               Compare assets
GET      /analytics/risk                  Risk metrics
GET      /analytics/forecast              Linear forecast
GET      /analytics/aggregate             Min/max/avg/count
GET      /analytics/recommendation        Buy/hold/sell signal
GET      /analytics/spark-summary         Aggregation preview
GET      /analytics/spark-debug           Spark/Java diagnostics
POST     /analytics/spark-run             Spark batch pipeline
GET      /analytics/export/csv            CSV export for Spark

POST     /assistant/chat                  LLM assistant (Groq)
GET      /assistant/status                 Assistant mode + tools

PUT      /admin/assets/{id}               Temporal update (new version)
DELETE   /admin/assets/{id}               Soft-delete (tombstone)
DELETE   /admin/sources/{id}              Soft-delete data source
GET      /admin/assets/{id}/at?as_of=...  Point-in-time asset

GET      /health                          Health check
```

Full interactive docs: **http://localhost:8000/docs**

---

## Temporal Database Design

MongoDB collections: `assets`, `data_sources`, `time_series`, `ingestion_runs`

Every asset and data source record has:

```
validFrom / validTo    → validity interval
isDeleted              → tombstone flag
recordId               → unique version id
```

Rules enforced:

- No in-place UPDATE of business data — changes append a new version  
- No hard DELETE — deletion appends a tombstone marker  
- Point-in-time queries via `?as_of=`  

Time series points use `$setOnInsert` upsert (append-only per timestamp + source).

---

## Data Ingestion (UC1)

| Vendor | `dataSourceId` | Default mode |
|--------|----------------|--------------|
| Yahoo Finance | `yfinance` | Live (yfinance) or bundled sample |
| Nasdaq Data Link | `nasdaq-dl` | **Simulated** EOD feed (Nasdaq API often unavailable) |
| Bloomberg | `bloomberg` | **Simulated** institutional feed |

```bash
curl -X POST "http://localhost:8000/api/v1/ingest/run?period=1y"
```

Response includes `bySourceMode`: `live`, `simulated`, or `sample`.

**Provenance:** every time series point stores `dataSourceId` + `ingestedAt`. Audit log: `GET /api/v1/ingest/runs`.

**Heterogeneous indicators** differ per vendor (e.g. yfinance `adjusted_close`, Nasdaq `trade_count`, Bloomberg `bid`/`ask`).

### Instruments (10 asset classes)

AAPL, MSFT, GOOGL (stocks) · BTC-USD, ETH-USD (crypto) · GSPC (index) · EURUSD (fx) · GC (futures/metals) · TLT (bond) · US10Y (interest rate)

---

## AI Assistant (UC4)

Two integration paths, same grounded tools (`app/tools/platform.py`):

1. **In-app assistant** — GUI **LLM Assistant** tab or `POST /api/v1/assistant/chat`  
2. **MCP server** — `python -m app.mcp_server` (configure via `mcp_config.json` in Cursor)

### Groq setup (free tier)

```env
GROQ_API_KEY=gsk_...
GROQ_MODEL=llama-3.3-70b-versatile
```

Without a key, **built-in mode** still routes prompts to warehouse tools.

### MCP tools (12)

`list_assets`, `get_asset_details`, `list_data_sources`, `get_data_source_details`, `get_timeseries`, `summarize_trend`, `compare_assets`, `assess_risk`, `forecast_price`, `explain_change`, `get_recommendation`, `get_aggregate`

### Example prompts

- *"What US stocks do we have?"*  
- *"Compare AAPL and MSFT over 90 days"*  
- *"What is the risk of BTC-USD?"*  
- *"Explain AAPL's change last week"*

---

## Requirements Coverage

| # | Requirement | Status | Implementation |
|---|-------------|--------|----------------|
| — | NoSQL database | ✅ | MongoDB 7 (`assets`, `data_sources`, `time_series`) |
| — | Temporal / versioned data | ✅ | Append versions, tombstones, `?as_of=` |
| — | Heterogeneous instruments | ✅ | 7 instrument classes, flexible `indicators` |
| UC1 | External data ingestion | ✅ | yfinance + simulated Nasdaq/Bloomberg |
| — | Data provenance | ✅ | `dataSourceId`, `ingestedAt`, `/ingest/runs` |
| UC2 | REST API Q1–Q5 | ✅ | FastAPI + OpenAPI |
| UC3 | Analytics + Spark | ✅ | Python analytics + PySpark pipeline |
| UC4 | LLM via MCP | ✅ | Groq assistant + MCP server |
| — | Web GUI | ✅ | `app/static/` |
| — | Runnable + docs | ✅ | Docker Compose, this README, `REPORT.md` |
| Bonus | LangFlow agent | ✅ | `langflow/amip_agent_flow.json` |

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `MONGODB_URI` | MongoDB connection (set automatically in Docker) |
| `GROQ_API_KEY` | Groq LLM for assistant (optional) |
| `NASDAQ_API_KEY` | Live Nasdaq ingest (optional) |
| `BLOOMBERG_API_KEY` | Live Bloomberg ingest (optional) |
| `USE_SIMULATED_VENDORS` | `true` (default) — simulated Nasdaq/Bloomberg |
| `JAVA_HOME` | Required for Spark on local Windows/Linux (Docker sets this) |
| `API_BASE_URL` | MCP server → API URL (default `http://localhost:8000`) |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `localhost:8000` not loading | `docker compose up --build` or check `uvicorn` + MongoDB |
| Spark shows Python fallback | Run **Debug Spark** in GUI; install Java 17 or rebuild Docker image |
| Docker `apt-get` fails | Use `docker-compose.nospark.yml` overlay |
| Empty charts | Click **Run Ingestion** or `POST /api/v1/ingest/run` |
| LLM not responding | Set `GROQ_API_KEY` in `.env` or use built-in mode |

---

**Built with:** FastAPI · MongoDB · PySpark · Python 3.12 · yfinance · Groq · MCP  
**Course:** Data Warehouses — Acme Market Intelligence Platform (AMIP)
