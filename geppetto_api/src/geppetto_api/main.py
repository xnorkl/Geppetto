from fastapi import FastAPI
from prometheus_client import make_asgi_app

from geppetto_api.api.health import router as health_router

app = FastAPI(
    title="Geppetto API",
    description="Generative AI tool for creating sock puppet accounts",
    version="0.1.0",
)

# Add Prometheus metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# Include routers
app.include_router(health_router, prefix="/api/v1") 