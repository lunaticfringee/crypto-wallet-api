from dotenv import load_dotenv
import os
from fastapi import FastAPI, HTTPException
import requests
from tenacity import retry, stop_after_attempt, wait_exponential, RetryError

from observability.logging_config import logger
from observability.metrics_config import setup_metrics
from observability.tracing_config import setup_tracing

COMPLIANCE_SERVICE_URL = "http://compliance-service:8001"

load_dotenv()
INFURA_URL = os.getenv("INFURA_URL")

app = FastAPI()
setup_metrics(app)
setup_tracing(app)

@app.get("/health")
def health():
    return {"status": "ok", "version": "v2"}

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=1, max=10))
def fetch_price_from_coingecko(coin: str):
    response = requests.get(
        f"https://api.coingecko.com/api/v3/simple/price?ids={coin}&vs_currencies=usd",
        timeout=5
    )
    response.raise_for_status()
    return response.json()

@app.get("/price/{coin}")
def get_price(coin: str):
    try:
        data = fetch_price_from_coingecko(coin)
    except RetryError:
        logger.error("CoinGecko Unavailable after retries", extra={"coin": coin})
        raise HTTPException(status_code=503, detail="price service temporarily unavailable")

    if not data:
        logger.info("Coin Not Found", extra={"coin" : coin})
        raise HTTPException(status_code=404, detail="coin not found")
    else:
         logger.info("Price Fetched Successfully", extra={"coin" : coin})
    return data

@app.get("/wallet/{address}/balance")
def get_balance(address: str):
    try:
        compliance_response = requests.get(
            f"{COMPLIANCE_SERVICE_URL}/check/{address}",
            timeout=3
        )
        compliance_response.raise_for_status()
        compliance_data = compliance_response.json()
    except requests.exceptions.RequestException:
        logger.error("Compliance service unavailable", extra={"address": address})
        raise HTTPException(status_code=503, detail="compliance check unavailable, cannot proceed")

    if compliance_data["risk_status"] == "blocked":
        logger.warning("Blocked address balance check attempted", extra={"address": address})
        raise HTTPException(status_code=403, detail="address flagged by compliance check")

    payload = {
        "jsonrpc": "2.0",
        "method": "eth_getBalance",
        "params": [address, "latest"],
        "id": 1
    }
    response = requests.post(INFURA_URL, json=payload)
    get_balance_json_response = response.json()
    eth_real_balance = int(get_balance_json_response["result"], 16) / 10**18
    return {
        "address": address,
        "balance_eth": eth_real_balance
    }
