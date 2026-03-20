import os
from pydantic_settings import BaseSettings
from pydantic import SecretStr
from functools import lru_cache
from pathlib import Path

from ai_common import LlmServers, ModelNames

FILE_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE_DIR = os.path.abspath(os.path.join(FILE_DIR, os.pardir))


class Settings(BaseSettings):
    APPLICATION_NAME: str = "Clause-And-Effect"
    APPLICATION_OWNER: SecretStr = "Bertan Günyel"
    IDENTITY_EMAIL: SecretStr = "bertan.gunyel@gmail.com"

    # AI related
    EMBEDDING_MODEL: str = "text-embedding-3-small" # OpenAI
    GROQ_API_KEY: SecretStr = ""
    LANGSMITH_API_KEY: SecretStr = ""
    LANGSMITH_TRACING: str = "true"
    OLLAMA_API_KEY: SecretStr = ""
    OPENAI_API_KEY: SecretStr = ""
    TAVILY_API_KEY: SecretStr = ""

    # Vector Database
    QDRANT_API_KEY: SecretStr = ""
    QDRANT_URL: SecretStr = ""
    QDRANT_PORT: int = 6333
    VECTOR_DB_COLLECTION_NAME: str = "compliance_docs"

    # Paths
    INPUT_FOLDER: Path = os.path.join(ENV_FILE_DIR, 'input')
    OUT_FOLDER: Path = os.path.join(ENV_FILE_DIR, 'out')
    DATA_DIR: Path = os.path.join(ENV_FILE_DIR, 'data')
    REGULATIONS_DIR: Path = os.path.join(DATA_DIR, 'regulations')
    CHUNKS_DIR: Path = os.path.join(DATA_DIR, 'chunks')
    TEST_CASES_DIR: Path = os.path.join(DATA_DIR, 'test_cases')

    class Config:
        case_sensitive = True
        env_file_encoding = "utf-8"
        env_file = os.path.join(ENV_FILE_DIR, '.env')

@lru_cache()
def get_settings() -> Settings:
    return Settings()

def get_llm_config():
    settings = get_settings()

    llm_config = {
        'orchestrator_model': [
            {
                'model': ModelNames.MINIMAX_M_2_7,
                'model_provider': LlmServers.OLLAMA,
                'api_key': settings.OLLAMA_API_KEY,
                'max_llm_retries': 3,
                'model_args': {
                    'temperature': 0,
                    # 'reasoning_effort': 'high',  # only for gpt-oss models: ['high', 'medium', 'low']
                    'top_p': 0.95,
                }
            },
            {
                'model': ModelNames.GLM_5,
                'model_provider': LlmServers.OLLAMA,
                'api_key': settings.OLLAMA_API_KEY,
                'max_llm_retries': 3,
                'model_args': {
                    'temperature': 0,
                    # 'reasoning_effort': 'high',  # only for gpt-oss models: ['high', 'medium', 'low']
                    'top_p': 0.95,
                }
            },
            {
                'model': ModelNames.KIMI_K_2_5,
                'model_provider': LlmServers.OLLAMA,
                'api_key': settings.OLLAMA_API_KEY,
                'max_llm_retries': 3,
                'model_args': {
                    'temperature': 0,
                    # 'reasoning_effort': 'high',  # only for gpt-oss models: ['high', 'medium', 'low']
                    'top_p': 0.95,
                }
            },
            {
                'model': ModelNames.QWEN_3_5,
                'model_provider': LlmServers.OLLAMA,
                'api_key': settings.OLLAMA_API_KEY,
                'max_llm_retries': 3,
                'model_args': {
                    'temperature': 0,
                    # 'reasoning_effort': 'high',  # only for gpt-oss models: ['high', 'medium', 'low']
                    'top_p': 0.95,
                }
            },
            {
                'model': ModelNames.MINIMAX_M_2_5,
                'model_provider': LlmServers.OLLAMA,
                'api_key': settings.OLLAMA_API_KEY,
                'max_llm_retries': 3,
                'model_args': {
                    'temperature': 0,
                    # 'reasoning_effort': 'high',  # only for gpt-oss models: ['high', 'medium', 'low']
                    'top_p': 0.95,
                }
            },
            {
                'model': ModelNames.DEEPSEEK_V_3_2,
                'model_provider': LlmServers.OLLAMA,
                'api_key': settings.OLLAMA_API_KEY,
                'max_llm_retries': 3,
                'model_args': {
                    'temperature': 0,
                    # 'reasoning_effort': 'high',  # only for gpt-oss models: ['high', 'medium', 'low']
                    'top_p': 0.95,
                }
            },

        ],
        'writer_model': [
            {
                'model': ModelNames.NEMOTRON_3_SUPER,
                'model_provider': LlmServers.OLLAMA,
                'api_key': settings.OLLAMA_API_KEY,
                'max_llm_retries': 3,
                'model_args': {
                    'temperature': 0,
                    'reasoning_effort': 'high',  # only for gpt-oss models: ['high', 'medium', 'low']
                    'top_p': 0.95,
                }
            },
            {
                'model': ModelNames.GPT_OSS_120B,
                'model_provider': LlmServers.OLLAMA,
                'api_key': settings.OLLAMA_API_KEY,
                'max_llm_retries': 3,
                'model_args': {
                    'temperature': 0,
                    'reasoning_effort': 'high',  # only for gpt-oss models: ['high', 'medium', 'low']
                    'top_p': 0.95,
                }
            },
        ]

    }

    return llm_config
