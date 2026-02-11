"""
Index regulation documents into vector database
"""

from src.config import get_settings
from src.clause_and_effect import GDPRParser, VectorDatabase


def main():
    """Index GDPR into vector database"""
    print("""
    ╔═══════════════════════════════════════════╗
    ║                                           ║
    ║        { Clause & Effect }                ║
    ║   Document Indexing                       ║
    ║                                           ║
    ╚═══════════════════════════════════════════╝
    """)

    settings = get_settings()

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
        vector_db_url=settings.QDRANT_URL,
        vector_db_port=settings.QDRANT_PORT,
        vector_db_api_key=settings.QDRANT_API_KEY,
        collection_name=settings.VECTOR_DB_COLLECTION_NAME,
        embedding_model=settings.EMBEDDING_MODEL,
        embedding_model_api_key=settings.OPENAI_API_KEY
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


if __name__ == "__main__":
    main()