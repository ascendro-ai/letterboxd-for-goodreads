"""Standardized HTTP error response helpers.

All API errors use a consistent JSON shape: {"error": {"code": ..., "message": ...}}.
These helpers centralize status codes so routes stay clean.
"""

from fastapi import HTTPException


class AppError(HTTPException):
    """Structured API error with code + message."""

    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(
            status_code=status_code,
            detail={"error": {"code": code, "message": message}},
        )


def book_not_found() -> AppError:
    return AppError(404, "BOOK_NOT_FOUND", "No book found with the given ID.")


def user_not_found() -> AppError:
    return AppError(404, "USER_NOT_FOUND", "No user found with the given ID.")


def user_book_not_found() -> AppError:
    return AppError(404, "USER_BOOK_NOT_FOUND", "No logged book found with the given ID.")


def shelf_not_found() -> AppError:
    return AppError(404, "SHELF_NOT_FOUND", "No shelf found with the given ID.")


def shelf_limit_reached() -> AppError:
    return AppError(403, "SHELF_LIMIT_REACHED", "Maximum number of shelves reached for free tier.")


def already_logged() -> AppError:
    return AppError(409, "ALREADY_LOGGED", "You have already logged this book.")


def review_required() -> AppError:
    return AppError(422, "REVIEW_REQUIRED", "A review is required when rating a book.")


def blocked_user() -> AppError:
    return AppError(403, "BLOCKED_USER", "You cannot interact with this user.")


def already_following() -> AppError:
    return AppError(409, "ALREADY_FOLLOWING", "You are already following this user.")


def not_following() -> AppError:
    return AppError(409, "NOT_FOLLOWING", "You are not following this user.")


def import_in_progress() -> AppError:
    return AppError(409, "IMPORT_IN_PROGRESS", "An import is already in progress.")


def invalid_rating() -> AppError:
    return AppError(422, "INVALID_RATING", "Rating must be between 0.5 and 5.0 in 0.5 increments.")


def duplicate_username() -> AppError:
    return AppError(409, "DUPLICATE_USERNAME", "This username is already taken.")


def self_action() -> AppError:
    return AppError(400, "SELF_ACTION", "You cannot perform this action on yourself.")


def work_not_found() -> AppError:
    return AppError(404, "WORK_NOT_FOUND", "No work found with the given ID.")


def duplicate_report() -> AppError:
    return AppError(
        409,
        "DUPLICATE_REPORT",
        "You already have an open report for this issue on this book.",
    )


def report_rate_limited() -> AppError:
    return AppError(
        429,
        "REPORT_RATE_LIMITED",
        "You have reached the maximum number of reports per day. Please try again tomorrow.",
    )
