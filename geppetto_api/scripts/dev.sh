#!/bin/bash

# Exit on error
set -e

echo "🔨 Building Geppetto API for local development..."

# Install the package in editable mode with dev dependencies
echo "📦 Installing dependencies..."
uv pip install -e ".[dev]"

# Run formatters
echo "✨ Running formatters..."
black .
isort .

# Run linters
echo "🔍 Running linters..."
ruff check .
mypy .

# Run tests
echo "🧪 Running tests..."
pytest

echo "✅ Build complete!" 