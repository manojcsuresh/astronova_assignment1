import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.store import books_db


@pytest.fixture(autouse=True)
def reset_store():
    """Reset the in-memory store before each test to ensure isolation."""
    books_db.clear()
    yield
    books_db.clear()


@pytest.fixture
def client():
    """Create a FastAPI test client."""
    return TestClient(app)


@pytest.fixture
def sample_book():
    """Return a sample book payload for creation."""
    return {
        "title": "Test Book",
        "author": "Test Author",
        "isbn": "978-0000000000",
        "publishedYear": 2024,
    }


@pytest.fixture
def created_book(client, sample_book):
    """Create a book and return the response JSON (includes 'id')."""
    response = client.post("/api/books", json=sample_book)
    assert response.status_code == 201
    return response.json()
