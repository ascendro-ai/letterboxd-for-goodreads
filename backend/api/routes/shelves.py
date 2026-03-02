from __future__ import annotations

from uuid import UUID

from backend.api.deps import DB, CurrentUser
from backend.api.schemas.shelves import (
    AddBookToShelfRequest,
    CreateShelfRequest,
    ShelfDetailResponse,
    ShelfResponse,
    UpdateShelfRequest,
)
from backend.services import shelf_service
from fastapi import APIRouter, Query, status

router = APIRouter()


@router.post("/me/shelves", response_model=ShelfResponse, status_code=status.HTTP_201_CREATED)
async def create_shelf(
    request: CreateShelfRequest,
    db: DB,
    current_user: CurrentUser,
) -> ShelfResponse:
    """Create a new custom shelf."""
    return await shelf_service.create_shelf(db, current_user, request)


@router.get("/me/shelves", response_model=list[ShelfResponse])
async def list_my_shelves(
    db: DB,
    current_user: CurrentUser,
) -> list[ShelfResponse]:
    """List all your shelves."""
    return await shelf_service.list_shelves(db, current_user.id)


@router.patch("/me/shelves/{shelf_id}", response_model=ShelfResponse)
async def update_shelf(
    shelf_id: UUID,
    request: UpdateShelfRequest,
    db: DB,
    current_user: CurrentUser,
) -> ShelfResponse:
    """Update a shelf's name, description, or visibility."""
    return await shelf_service.update_shelf(db, current_user.id, shelf_id, request)


@router.delete("/me/shelves/{shelf_id}", status_code=status.HTTP_200_OK)
async def delete_shelf(
    shelf_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Delete a shelf."""
    await shelf_service.delete_shelf(db, current_user.id, shelf_id)
    return {"message": "Shelf deleted"}


@router.post(
    "/me/shelves/{shelf_id}/books",
    status_code=status.HTTP_201_CREATED,
)
async def add_book_to_shelf(
    shelf_id: UUID,
    request: AddBookToShelfRequest,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Add a book to a shelf."""
    await shelf_service.add_book_to_shelf(db, current_user.id, shelf_id, request.user_book_id)
    return {"message": "Book added to shelf"}


@router.delete(
    "/me/shelves/{shelf_id}/books/{user_book_id}",
    status_code=status.HTTP_200_OK,
)
async def remove_book_from_shelf(
    shelf_id: UUID,
    user_book_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Remove a book from a shelf."""
    await shelf_service.remove_book_from_shelf(db, current_user.id, shelf_id, user_book_id)
    return {"message": "Book removed from shelf"}


@router.get("/users/{user_id}/shelves", response_model=list[ShelfResponse])
async def list_user_shelves(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> list[ShelfResponse]:
    """List another user's public shelves."""
    return await shelf_service.list_user_shelves(db, current_user.id, user_id)


@router.get("/users/{user_id}/shelves/{shelf_id}", response_model=ShelfDetailResponse)
async def get_user_shelf(
    user_id: UUID,
    shelf_id: UUID,
    db: DB,
    current_user: CurrentUser,
    cursor: str | None = None,
    limit: int = Query(20, ge=1, le=100),
) -> ShelfDetailResponse:
    """View a specific shelf from another user."""
    return await shelf_service.get_shelf_detail(
        db, current_user.id, user_id, shelf_id, cursor, limit
    )
