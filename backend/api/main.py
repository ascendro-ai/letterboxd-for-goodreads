"""FastAPI application factory and middleware configuration."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from backend.api.config import get_settings
from backend.api.middleware.observability import ObservabilityMiddleware
from backend.services.observability import init_posthog, init_sentry, shutdown_posthog
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    settings = get_settings()
    init_sentry(settings.sentry_dsn, settings.environment)
    init_posthog(settings.posthog_api_key, settings.posthog_host)
    yield
    shutdown_posthog()
    from backend.api.database import engine

    await engine.dispose()


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="Shelf API",
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/api/docs" if settings.environment != "production" else None,
        redoc_url=None,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(ObservabilityMiddleware)

    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        return JSONResponse(
            status_code=500,
            content={
                "error": {"code": "INTERNAL_ERROR", "message": "An unexpected error occurred."}
            },
        )

    # Register routers
    from backend.api.routes import (
        auth,
        books,
        discover,
        export,
        feed,
        import_,
        moderation,
        shelves,
        user_books,
        users,
        waitlist,
    )

    app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
    app.include_router(books.router, prefix="/api/v1/books", tags=["books"])
    app.include_router(users.router, prefix="/api/v1", tags=["users"])
    app.include_router(user_books.router, prefix="/api/v1", tags=["user_books"])
    app.include_router(shelves.router, prefix="/api/v1", tags=["shelves"])
    app.include_router(feed.router, prefix="/api/v1", tags=["feed"])
    app.include_router(import_.router, prefix="/api/v1/me/import", tags=["import"])
    app.include_router(moderation.router, prefix="/api/v1", tags=["moderation"])
    app.include_router(waitlist.router, prefix="/api/v1", tags=["waitlist"])
    app.include_router(export.router, prefix="/api/v1", tags=["export"])
    app.include_router(discover.router, prefix="/api/v1/me/discover", tags=["discover"])

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
