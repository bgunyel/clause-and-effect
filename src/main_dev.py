import datetime
import os
import rich
import time
from uuid import uuid4

from config import get_settings
from src.clause_and_effect import EmbeddingGenerator, GDPRParser, VectorDatabase


def main():

    settings = get_settings()

    os.environ['LANGSMITH_API_KEY'] = settings.LANGSMITH_API_KEY.get_secret_value()
    os.environ['LANGSMITH_TRACING'] = settings.LANGSMITH_TRACING
    os.environ['LANGSMITH_PROJECT'] = settings.APPLICATION_NAME.lower()

    gdpr_path = settings.REGULATIONS_DIR / "gdpr.pdf"

    if not gdpr_path.exists():
        print("❌ GDPR file not found!")
        print(f"Expected location: {gdpr_path}")
        print("\n💡 Run this command to download:")
        print("   bash scripts/download_regulations.sh")
        return

    print(f"✅ Found GDPR at: {gdpr_path}")
    print()

    # Parse GDPR
    parser = GDPRParser()
    chunks = parser.parse(gdpr_path)

    # Statistics
    print(f"\n📊 Statistics:")
    print(f"   Total chunks: {len(chunks)}")

    # Initialize vector DB
    vector_db = VectorDatabase(
        vector_db_url = settings.QDRANT_URL,
        vector_db_port = settings.QDRANT_PORT,
        vector_db_api_key = settings.QDRANT_API_KEY,
        collection_name = settings.VECTOR_DB_COLLECTION_NAME,
        embedding_model = settings.EMBEDDING_MODEL,
        embedding_model_api_key = settings.OPENAI_API_KEY
    )
    vector_db.create_collection()

    # Index chunks
    vector_db.index_chunks(chunks)

    # Test search
    query = "What is the timeline for data deletion requests?"
    print(f"\n🔍 Searching: {query}")

    results = vector_db.search(query, top_k=3)

    print(f"\n✅ Found {len(results)} results:")
    for i, result in enumerate(results, 1):
        print(f"\n{i}. {result['chunk_id']} (score: {result['score']:.3f})")
        print(f"   Article: {result['metadata']['article_number']} - {result['metadata']['article_title']}")
        print(f"   Text: {result['text'][:150]}...")

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
