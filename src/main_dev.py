"""
* This file is for active development of the package and hence,  it is a living file.

* At any time, you can consult this file for the usage of package components.
* However, the contents of this file may change  abruptly, at any time.
* For permanent usage examples, please see the <tests> folder
"""

import datetime
import os
import rich
import time
from uuid import uuid4

from ai_common import get_llm

from src.config import get_settings
from src.llm_config import get_llm_config
from src.clause_and_effect.agents import ComplianceAgent


def main():

    settings = get_settings()
    llm_config = get_llm_config()

    os.environ['LANGSMITH_API_KEY'] = settings.LANGSMITH_API_KEY.get_secret_value()
    os.environ['LANGSMITH_TRACING'] = settings.LANGSMITH_TRACING
    os.environ['LANGSMITH_PROJECT'] = settings.APPLICATION_NAME.lower()

    model_params = get_llm_config()["sufficiency_judge"][0]
    llm = get_llm(
        model_name=model_params["model"],
        model_provider=model_params["model_provider"],
        api_key=model_params["api_key"],
        model_args=model_params["model_args"],
    )

    output = llm.invoke("Give me information about Ankara.")


    query = "What types of processing of personal data does this Regulation apply to?"
    # query = "Does GDPR apply to a person's personal or household data processing activities?"

    compliance_agent = ComplianceAgent(
        llm_config = llm_config,
        vector_db_url = settings.QDRANT_URL,
        vector_db_port = settings.QDRANT_PORT,
        vector_db_api_key = settings.QDRANT_API_KEY,
        collection_name = settings.VECTOR_DB_COLLECTION_NAME,
        embedding_model = settings.EMBEDDING_MODEL,
        embedding_model_api_key = settings.OPENAI_API_KEY
    )

    response = compliance_agent.ask(query=query)




    dummy = -32


if __name__ == '__main__':
    time_now = datetime.datetime.now().replace(microsecond=0).astimezone(
        tz=datetime.timezone(offset=datetime.timedelta(hours=3), name='UTC+3'))

    config_settings = get_settings()
    print(f'{config_settings.APPLICATION_NAME} started at {time_now}')
    time1 = time.time()
    main()
    time2 = time.time()

    time_now = datetime.datetime.now().replace(microsecond=0).astimezone(
        tz=datetime.timezone(offset=datetime.timedelta(hours=3), name='UTC+3'))
    print(f'{config_settings.APPLICATION_NAME} finished at {time_now}')
    print(f'{config_settings.APPLICATION_NAME} took {(time2 - time1):.2f} seconds')
