from typing import Optional
from pydantic import BaseModel, Field


class BookCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=300, description="Book title")
    author: str = Field(..., min_length=1, max_length=200, description="Book author")
    isbn: Optional[str] = Field(None, max_length=20, description="ISBN identifier")
    publishedYear: Optional[int] = Field(
        None,
        ge=1000,
        le=2100,
        description="Year the book was published",
    )


class BookUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=300)
    author: Optional[str] = Field(None, min_length=1, max_length=200)
    isbn: Optional[str] = Field(None, max_length=20)
    publishedYear: Optional[int] = Field(None, ge=1000, le=2100)


class BookResponse(BaseModel):
    id: str
    title: str
    author: str
    isbn: Optional[str] = None
    publishedYear: Optional[int] = None
