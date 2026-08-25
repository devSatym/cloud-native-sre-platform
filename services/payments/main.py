"""Payments service for the deliberately small in-memory demonstration workload."""

import asyncio
import os
import uuid
from typing import Any

from fastapi import FastAPI, HTTPException, status
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel, Field

app = FastAPI(title="Cloud-Native SRE Platform - Payments Service")

Instrumentator().instrument(app).expose(app, endpoint="/metrics")

# Fault injection flags (for resilience testing)
FAIL_MODE = os.getenv("FAIL_MODE", "0") == "1"
SLOW_MODE = os.getenv("SLOW_MODE", "0") == "1"

# In-memory storage is intentional for this small reliability demonstration; no
# PostgreSQL dependency is deployed or implied by the payment workflow.
payments_store: dict[str, dict[str, Any]] = {}


class PaymentProcessRequest(BaseModel):
    amount: float = Field(gt=0, description="Payment amount must be greater than 0")
    currency: str = Field(default="USD", pattern="^[A-Z]{3}$", description="ISO 4217 currency code")
    tenant_id: str = "default"


class PaymentProcessResponse(BaseModel):
    payment_id: str
    status: str
    amount: float
    currency: str


@app.get("/healthz")
async def health_check() -> dict[str, str]:
    """Process liveness endpoint."""
    return {"status": "healthy", "service": "payments"}


@app.get("/readyz")
async def readiness_check() -> dict[str, str]:
    """Payments has no external persistent dependency in this demo workload."""
    return {"status": "ready", "service": "payments"}


@app.post(
    "/process", response_model=PaymentProcessResponse, status_code=status.HTTP_201_CREATED
)
async def process_payment(payment: PaymentProcessRequest) -> dict[str, Any]:
    """
    Process a payment request.
    Records are intentionally in-memory for this small reliability demonstration.
    """
    # Fault injection: Simulate slow responses
    if SLOW_MODE:
        await asyncio.sleep(2)

    # Fault injection: Simulate failures
    if FAIL_MODE:
        raise HTTPException(status_code=500, detail="FAIL_MODE enabled")

    payment_id = str(uuid.uuid4())

    payment_record = {
        "payment_id": payment_id,
        "status": "completed",
        "amount": payment.amount,
        "currency": payment.currency,
        "tenant_id": payment.tenant_id,
    }

    # Store in memory (temporary)
    payments_store[payment_id] = payment_record

    return {
        "payment_id": payment_id,
        "status": "completed",
        "amount": payment.amount,
        "currency": payment.currency,
    }


@app.get("/payments/{payment_id}")
async def get_payment(payment_id: str) -> dict[str, Any]:
    """Retrieve a payment by ID."""
    if payment_id not in payments_store:
        raise HTTPException(status_code=404, detail="payment not found")

    return payments_store[payment_id]


@app.get("/")
async def root() -> dict[str, Any]:
    """Root endpoint."""
    return {
        "service": "cloud-native-sre-platform-payments",
        "version": "0.0.1",
        "endpoints": ["/healthz", "/readyz", "/process", "/payments/{id}"],
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8001)
