"""
SkyAI — FastAPI Application Entry Point

Run with:
  uvicorn main:app --reload --port 8000

Environment:
  Copy .env.example → .env and fill in your Amadeus credentials.
"""

from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from amadeus_client import AmadeusClient
from duffel_client import DuffelClient
from routes.search import router as search_router

# ── Logging ───────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ── Config ────────────────────────────────────────────────────────────────────

load_dotenv()

AMADEUS_CLIENT_ID = os.getenv("AMADEUS_CLIENT_ID", "")
AMADEUS_CLIENT_SECRET = os.getenv("AMADEUS_CLIENT_SECRET", "")
AMADEUS_ENV = os.getenv("AMADEUS_ENV", "test")
DUFFEL_API_KEY = os.getenv("DUFFEL_API_KEY", "")
USE_MOCK_DATA = os.getenv("USE_MOCK_DATA", "true").lower() == "true"
FLIGHT_PROVIDER = os.getenv("FLIGHT_PROVIDER", "mock")  # "mock" | "duffel" | "amadeus"
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*").split(",")


# ── Lifespan ──────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start and cleanly shut down shared resources."""
    if FLIGHT_PROVIDER == "duffel":
        if not DUFFEL_API_KEY:
            logger.warning("⚠️  DUFFEL_API_KEY not set. Add it to your .env file.")
        client = DuffelClient(api_key=DUFFEL_API_KEY)
        await client.start()
        app.state.flight_client = client
        app.state.provider = "duffel"
        logger.info("✅ SkyAI backend started (provider: Duffel)")

    elif FLIGHT_PROVIDER == "amadeus":
        if not AMADEUS_CLIENT_ID or not AMADEUS_CLIENT_SECRET:
            logger.warning("⚠️  Amadeus credentials not set.")
        client = AmadeusClient(
            client_id=AMADEUS_CLIENT_ID,
            client_secret=AMADEUS_CLIENT_SECRET,
            env=AMADEUS_ENV,
        )
        await client.start()
        app.state.flight_client = client
        app.state.provider = "amadeus"
        logger.info(f"✅ SkyAI backend started (provider: Amadeus, env: {AMADEUS_ENV})")

    else:  # mock
        app.state.flight_client = None
        app.state.provider = "mock"
        logger.info("✅ SkyAI backend started (provider: mock — using realistic fake data)")

    yield

    if hasattr(app.state, "flight_client") and app.state.flight_client:
        await app.state.flight_client.stop()
    logger.info("SkyAI backend shut down.")


# ── App ───────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="SkyAI API",
    description="Multi-agent flight finder backend",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS — allow mobile simulators and web clients during development
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────

app.include_router(search_router)


# ── Health Check ──────────────────────────────────────────────────────────────

@app.get("/health", tags=["meta"])
async def health() -> JSONResponse:
    return JSONResponse({"status": "ok", "version": "0.1.0"})


@app.get("/", tags=["meta"])
async def root() -> JSONResponse:
    return JSONResponse({
        "name": "SkyAI API",
        "docs": "/docs",
        "health": "/health",
    })
