from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# This file is  <repo>/backend/api/app/config/settings.py
# parents[0]=config  [1]=app  [2]=api  [3]=backend  [4]=<repo root>
ENV_FILE = Path(__file__).resolve().parents[4] / "env" / "dev.env"


class Settings(BaseSettings):
    database_url: str
    redis_url: str
    jwt_secret: str

    model_config = SettingsConfigDict(env_file=ENV_FILE, extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()