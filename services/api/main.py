"""API service entry point for the user-facing payment workflow."""

import logging
import os
import time
from typing import Any

import httpx
import redis
from fastapi import FastAPI, HTTPException, status
from prometheus_client import Counter, Histogram
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel, Field

from services.api.middleware.rate_limit import RateLimitMiddleware

# Without this, application loggers (e.g. services.api.middleware.rate_limit)
# propagate to the root logger, which has no handler under uvicorn and drops
# everything below WARNING - so rate-limit context never reaches stdout/Loki.
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(levelname)s:%(name)s:%(message)s",
)

app = FastAPI(title="Cloud-Native SRE Platform - API Service")

PAYMENTS_URL = os.getenv("PAYMENTS_URL", "http://localhost:8001")
RATE_LIMIT_REQUESTS = int(os.getenv("RATE_LIMIT_REQUESTS", "60"))
RATE_LIMIT_WINDOW_SECONDS = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))

# Prefer one portable URL contract. The host/port fallback keeps existing local
# Kubernetes deployments working while they migrate to REDIS_URL.
REDIS_URL = os.getenv("REDIS_URL")
if REDIS_URL:
    redis_client = redis.Redis.from_url(REDIS_URL, decode_responses=True)
else:
    redis_client = redis.Redis(
        host=os.getenv("REDIS_HOST", "redis"),
        port=int(
            os.getenv("REDIS_SERVICE_PORT", os.getenv("REDIS_PORT_NUMBER", "6379"))
        ),
        decode_responses=True,
    )

# These metrics deliberately cover only the user-facing API operation. Their
# labels are bounded, and operational endpoints never enter the SLO denominator.
user_requests = Counter(
    "sre_api_user_requests_total",
    "User-facing API requests grouped by response status class.",
    ["status_class"],
)
user_request_duration = Histogram(
    "sre_api_user_request_duration_seconds",
    "User-facing API request duration grouped by response status class.",
    ["status_class"],
    buckets=(0.05, 0.1, 0.25, 0.5, 0.75, 1.0, 2.0, 5.0),
)

# Add rate limiting middleware
app.add_middleware(
    RateLimitMiddleware,
    redis_client=redis_client,
    max_requests=RATE_LIMIT_REQUESTS,
    window_seconds=RATE_LIMIT_WINDOW_SECONDS,
    tenant_header="X-Tenant",
)

# Mount metrics endpoint
Instrumentator().instrument(app).expose(app, endpoint="/metrics")


class PaymentRequest(BaseModel):
    amount: float = Field(gt=0, description="Payment amount must be greater than zero")
    currency: str = "USD"
    tenant_id: str = "default"


class PaymentResponse(BaseModel):
    payment_id: str
    status: str
    amount: float
    currency: str


@app.middleware("http")
async def record_user_request_metrics(request, call_next):
    """Record bounded SLO metrics for the `/pay` operation only."""
    if request.url.path != "/pay":
        return await call_next(request)

    started = time.perf_counter()
    try:
        response = await call_next(request)
    except Exception:
        status_class = "5xx"
        user_requests.labels(status_class=status_class).inc()
        user_request_duration.labels(status_class=status_class).observe(
            time.perf_counter() - started
        )
        raise

    status_class = f"{response.status_code // 100}xx"
    user_requests.labels(status_class=status_class).inc()
    user_request_duration.labels(status_class=status_class).observe(
        time.perf_counter() - started
    )
    return response


@app.get("/healthz")
async def health_check() -> dict[str, str]:
    """Process liveness endpoint; it deliberately has no dependency check."""
    return {"status": "healthy", "service": "api"}


@app.get("/readyz")
async def readiness_check() -> dict[str, str]:
    """Readiness endpoint verifies the Redis dependency used by rate limiting."""
    try:
        redis_client.ping()
    except redis.RedisError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Redis is unavailable",
        ) from exc
    return {"status": "ready", "service": "api"}


@app.post("/pay", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
async def create_payment(payment: PaymentRequest) -> dict[str, Any]:
    """
    Create a payment by calling the Payments service.
    This is the main integration point between API and Payments.
    """
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(
                f"{PAYMENTS_URL}/process",
                json={
                    "amount": payment.amount,
                    "currency": payment.currency,
                    "tenant_id": payment.tenant_id,
                },
            )
            response.raise_for_status()
            return response.json()
    except httpx.TimeoutException as exc:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Payments service timeout",
        ) from exc
    except httpx.HTTPStatusError as exc:
        if 400 <= exc.response.status_code < 500:
            raise HTTPException(
                status_code=exc.response.status_code,
                detail="Payments rejected the request",
            ) from exc
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Payments service returned an error",
        ) from exc
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Payments service is unavailable",
        ) from exc


@app.get("/")
async def root() -> dict[str, Any]:
    """Root endpoint."""
    return {
        "service": "cloud-native-sre-platform-api",
        "version": "0.0.1",
        "endpoints": ["/healthz", "/readyz", "/pay"],
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
