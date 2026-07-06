"""Unit tests for the Books API CRUD endpoints."""

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


# ─── GET /api/books ──────────────────────────────────────────────

class TestListBooks:
    def test_list_books_empty(self, client):
        """Returns an empty list when no books exist."""
        response = client.get("/api/books")
        assert response.status_code == 200
        assert response.json() == []

    def test_list_books_returns_all(self, client, created_book):
        """Returns all books after creation."""
        response = client.get("/api/books")
        assert response.status_code == 200
        books = response.json()
        assert len(books) == 1
        assert books[0]["id"] == created_book["id"]

    def test_list_books_multiple(self, client, sample_book):
        """Returns multiple books."""
        client.post("/api/books", json=sample_book)
        client.post("/api/books", json={**sample_book, "title": "Another Book"})
        response = client.get("/api/books")
        assert response.status_code == 200
        assert len(response.json()) == 2


# ─── GET /api/books/{id} ─────────────────────────────────────────

class TestGetBook:
    def test_get_book_by_id(self, client, created_book):
        """Returns a specific book by its ID."""
        response = client.get(f"/api/books/{created_book['id']}")
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Test Book"
        assert data["author"] == "Test Author"

    def test_get_book_not_found(self, client):
        """Returns 404 for a non-existent book ID."""
        response = client.get("/api/books/nonexistent-id")
        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()


# ─── POST /api/books ─────────────────────────────────────────────

class TestCreateBook:
    def test_create_book_success(self, client, sample_book):
        """Creates a book and returns it with an auto-generated ID."""
        response = client.post("/api/books", json=sample_book)
        assert response.status_code == 201
        data = response.json()
        assert "id" in data
        assert data["title"] == sample_book["title"]
        assert data["author"] == sample_book["author"]
        assert data["isbn"] == sample_book["isbn"]
        assert data["publishedYear"] == sample_book["publishedYear"]

    def test_create_book_minimal(self, client):
        """Creates a book with only required fields."""
        response = client.post(
            "/api/books",
            json={"title": "Minimal Book", "author": "Minimal Author"},
        )
        assert response.status_code == 201
        data = response.json()
        assert data["isbn"] is None
        assert data["publishedYear"] is None

    def test_create_book_missing_title(self, client):
        """Returns 422 when required 'title' is missing."""
        response = client.post(
            "/api/books",
            json={"author": "Author Only"},
        )
        assert response.status_code == 422

    def test_create_book_missing_author(self, client):
        """Returns 422 when required 'author' is missing."""
        response = client.post(
            "/api/books",
            json={"title": "Title Only"},
        )
        assert response.status_code == 422

    def test_create_book_empty_title(self, client):
        """Returns 422 when title is empty string."""
        response = client.post(
            "/api/books",
            json={"title": "", "author": "Author"},
        )
        assert response.status_code == 422

    def test_create_book_invalid_year(self, client):
        """Returns 422 when publishedYear is out of range."""
        response = client.post(
            "/api/books",
            json={"title": "Book", "author": "Author", "publishedYear": 999},
        )
        assert response.status_code == 422

    def test_create_book_persists(self, client, sample_book):
        """Confirms the created book is retrievable via GET."""
        create_resp = client.post("/api/books", json=sample_book)
        book_id = create_resp.json()["id"]

        get_resp = client.get(f"/api/books/{book_id}")
        assert get_resp.status_code == 200
        assert get_resp.json()["title"] == sample_book["title"]


# ─── PATCH /api/books/{id} ───────────────────────────────────────

class TestUpdateBook:
    def test_update_book_title(self, client, created_book):
        """Partially updates only the title."""
        response = client.patch(
            f"/api/books/{created_book['id']}",
            json={"title": "Updated Title"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Updated Title"
        assert data["author"] == created_book["author"]  # unchanged

    def test_update_book_multiple_fields(self, client, created_book):
        """Updates multiple fields at once."""
        response = client.patch(
            f"/api/books/{created_book['id']}",
            json={"title": "New Title", "publishedYear": 2025},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "New Title"
        assert data["publishedYear"] == 2025

    def test_update_book_not_found(self, client):
        """Returns 404 when updating a non-existent book."""
        response = client.patch(
            "/api/books/nonexistent-id",
            json={"title": "Won't Work"},
        )
        assert response.status_code == 404

    def test_update_book_no_fields(self, client, created_book):
        """Returns 400 when no fields are provided."""
        response = client.patch(
            f"/api/books/{created_book['id']}",
            json={},
        )
        assert response.status_code == 400


# ─── DELETE /api/books/{id} ──────────────────────────────────────

class TestDeleteBook:
    def test_delete_book_success(self, client, created_book):
        """Deletes a book and returns 204."""
        response = client.delete(f"/api/books/{created_book['id']}")
        assert response.status_code == 204

        # Confirm it's gone
        get_resp = client.get(f"/api/books/{created_book['id']}")
        assert get_resp.status_code == 404

    def test_delete_book_not_found(self, client):
        """Returns 404 when deleting a non-existent book."""
        response = client.delete("/api/books/nonexistent-id")
        assert response.status_code == 404

    def test_delete_book_removes_from_list(self, client, sample_book):
        """Confirms deleted book no longer appears in list."""
        create_resp = client.post("/api/books", json=sample_book)
        book_id = create_resp.json()["id"]

        client.delete(f"/api/books/{book_id}")

        list_resp = client.get("/api/books")
        assert all(b["id"] != book_id for b in list_resp.json())


# ─── GET /health ─────────────────────────────────────────────────

class TestHealthCheck:
    def test_health_check(self, client):
        """Health endpoint returns 200 with status 'healthy'."""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data
