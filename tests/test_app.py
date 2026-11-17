import sqlite3

import pytest

from app import create_app


@pytest.fixture()
def application(tmp_path):
    return create_app({"TESTING": True, "DATABASE": str(tmp_path / "requests.db")})


@pytest.fixture()
def client(application):
    return application.test_client()


def test_home_and_headers(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"Request Tracker" in response.data
    assert response.headers["X-Content-Type-Options"] == "nosniff"


def test_health_and_readiness(client):
    assert client.get("/healthz").json == {"status": "ok"}
    assert client.get("/readyz").status_code == 200


@pytest.mark.parametrize("payload", [{}, [], None, {"title": ""}, {"title": "   "},
                                    {"title": 4}, {"title": "x" * 121}])
def test_reject_invalid_title(client, payload):
    assert client.post("/api/requests", json=payload).status_code == 400
    assert client.get("/api/requests").json == []


def test_reject_malformed_json(client):
    assert client.post("/api/requests", data="{", content_type="application/json").status_code == 400


@pytest.mark.parametrize("size", [1, 120])
def test_accept_boundary_lengths(client, size):
    assert client.post("/api/requests", json={"title": "x" * size}).status_code == 201


def test_create_list_and_persist(application, client):
    response = client.post("/api/requests", json={"title": "  Sample request  "})
    assert response.status_code == 201
    assert response.json == {"id": 1, "title": "Sample request", "status": "Open"}
    fresh_client = create_app(application.config).test_client()
    assert fresh_client.get("/api/requests").json == [response.json]
    with sqlite3.connect(application.config["DATABASE"]) as db:
        assert db.execute("SELECT title FROM requests").fetchone()[0] == "Sample request"


def test_parameterised_sql(client):
    title = "Robert'); DROP TABLE requests;--"
    assert client.post("/api/requests", json={"title": title}).status_code == 201
    assert client.get("/api/requests").json[0]["title"] == title


def test_not_ready_when_database_missing(application, client):
    with sqlite3.connect(application.config["DATABASE"]) as db:
        db.execute("DROP TABLE requests")
    assert client.get("/readyz").status_code == 503
    assert client.get("/healthz").status_code == 200


def test_metrics_use_bounded_route_labels(client):
    client.get("/healthz")
    client.get("/missing-personal-data")
    metrics = client.get("/metrics").text
    assert 'route="/healthz"' in metrics
    assert 'route="unmatched"' in metrics
    assert "/missing-personal-data" not in metrics
    assert "tracker_http_request_duration_seconds_bucket" in metrics


def test_body_size_limit(client):
    assert client.post("/api/requests", json={"title": "x" * 17000}).status_code == 413
