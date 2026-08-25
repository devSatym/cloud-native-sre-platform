"""
Sanity tests to ensure CI pipeline is working.
Service-specific tests live beside the API and Payments services.
"""


def test_sanity():
    """Basic sanity check - CI should pass."""
    assert 1 + 1 == 2


def test_imports():
    """Verify core dependencies are installed (skip if not available)."""
    import pytest

    # Try to import optional dependencies - skip if not installed locally
    pytest.importorskip("fastapi", reason="fastapi not installed - run: make install")
    pytest.importorskip("redis", reason="redis not installed - run: make install")
    pytest.importorskip(
        "prometheus_fastapi_instrumentator", reason="instrumentator not installed - run: make install"
    )

    assert pytest is not None
