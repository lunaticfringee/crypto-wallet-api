from fastapi import FastAPI
import os
from observability.logging_config import logger
from observability.metrics_config import setup_metrics
from observability.tracing_config import setup_tracing

app = FastAPI()
setup_metrics(app)
setup_tracing(app)

@app.get("/health")
def health():
    return {"status": "ok"}

BLOCKED_ADDRESSES = {"0x0000000000000000000000000000000000dead"}

@app.get("/check/{address}")
def check_address(address: str):
    is_blocked = address.lower() in BLOCKED_ADDRESSES
    logger.info("Compliance check performed", extra={"address": address, "blocked": is_blocked})
    return {"address": address, "risk_status": "blocked" if is_blocked else "clear"}