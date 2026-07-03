from typing import Dict

books_db: Dict[str, dict] = {}


def seed_data() -> None:
    import uuid

    samples = [
        {
            "title": "The Pragmatic Programmer",
            "author": "David Thomas & Andrew Hunt",
            "isbn": "978-0135957059",
            "publishedYear": 2019,
        },
        {
            "title": "Clean Code",
            "author": "Robert C. Martin",
            "isbn": "978-0132350884",
            "publishedYear": 2008,
        },
        {
            "title": "Designing Data-Intensive Applications",
            "author": "Martin Kleppmann",
            "isbn": "978-1449373320",
            "publishedYear": 2017,
        },
        {
            "title": "The Art of Computer Programming",
            "author": "Donald Knuth",
            "isbn": "978-0201896831",
            "publishedYear": 1997,
        },
        {
            "title": "Structure and Interpretation of Computer Programs",
            "author": "Harold Abelson & Gerald Jay Sussman",
            "isbn": "978-0262510875",
            "publishedYear": 1996,
        },
    ]

    for book in samples:
        book_id = str(uuid.uuid4())
        books_db[book_id] = {"id": book_id, **book}


seed_data()
