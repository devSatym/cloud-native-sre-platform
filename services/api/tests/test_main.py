"""Unit tests for the API service entrypoint."""

from unittest.mock import Mock, patch

import pytest
from fastapi.testclient import TestClient
from redis.exceptions import RedisError

from ..main import app, redis_client

client = TestClient(app)


@pytest.mark.unit
def test_healthz():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "service": "api"}


@pytest.mark.unit
def test_readyz_checks_redis():
    with patch.object(redis_client, "ping", return_value=True):
        response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json() == {"status": "ready", "service": "api"}


@pytest.mark.unit
def test_readyz_returns_503_when_redis_is_unavailable():
    with patch.object(redis_client, "ping", side_effect=RedisError("unavailable")):
        response = client.get("/readyz")
    assert response.status_code == 503


@pytest.mark.unit
def test_metrics_endpoint_available():
    response = client.get("/metrics")
    assert response.status_code == 200


@pytest.mark.unit
def test_root():
    """`/` is rate-limited like any other endpoint, so mock Redis for the check."""
    mock_pipeline = Mock()
    mock_pipeline.execute.return_value = [0, 0, True, True]
    with patch.object(redis_client, "pipeline", return_value=mock_pipeline):
        response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {
        "service": "cloud-native-sre-platform-api",
        "version": "0.0.1",
        "endpoints": ["/healthz", "/readyz", "/pay"],
    }


@pytest.mark.unit
def test_pay_forwards_a_valid_request_to_payments():
    mock_pipeline = Mock()
    mock_pipeline.execute.return_value = [0, 0, True, True]

    class FakeResponse:
        def raise_for_status(self):
            return None

        def json(self):
            return {
                "payment_id": "payment-123",
                "status": "completed",
                "amount": 10.0,
                "currency": "USD",
            }

    class FakeAsyncClient:
        def __init__(self, **_kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_args):
            return False

        async def post(self, _url, json):
            assert json == {"amount": 10.0, "currency": "USD", "tenant_id": "tenant-a"}
            return FakeResponse()

    with (
        patch.object(redis_client, "pipeline", return_value=mock_pipeline),
        patch("services.api.main.httpx.AsyncClient", FakeAsyncClient),
    ):
        response = client.post(
            "/pay",
            headers={"X-Tenant": "tenant-a"},
            json={"amount": 10.0, "currency": "USD", "tenant_id": "tenant-a"},
        )

    assert response.status_code == 201
    assert response.json()["payment_id"] == "payment-123"


@pytest.mark.unit
def test_pay_rejects_non_positive_amount_before_calling_payments():
    mock_pipeline = Mock()
    mock_pipeline.execute.return_value = [0, 0, True, True]
    with patch.object(redis_client, "pipeline", return_value=mock_pipeline):
        response = client.post("/pay", json={"amount": 0, "currency": "USD"})
    assert response.status_code == 422
