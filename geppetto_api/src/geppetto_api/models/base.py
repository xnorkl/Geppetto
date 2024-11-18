from pydantic import BaseModel, ConfigDict

class BaseModelConfig(BaseModel):
    """Base configuration for all models."""
    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={"example": {}}
    ) 