import datetime
import os
import rich
import time
from uuid import uuid4

from config import get_settings
from src.clause_and_effect import GDPRParser


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

    # Count by type
    article_chunks = [c for c in chunks if c.metadata.get("chunk_type") == "article"]
    paragraph_chunks = [c for c in chunks if c.metadata.get("chunk_type") == "paragraph"]

    print(f"   Article-level: {len(article_chunks)}")
    print(f"   Paragraph-level: {len(paragraph_chunks)}")

    # Count by chapter
    chapters = {}
    for chunk in chunks:
        chapter = chunk.metadata.get("chapter", "unknown")
        chapters[chapter] = chapters.get(chapter, 0) + 1

    print(f"\n📚 Chunks by chapter:")
    for chapter in sorted(chapters.keys()):
        chapter_title = GDPRParser.CHAPTER_TITLES.get(chapter, "Unknown")
        print(f"   Chapter {chapter} ({chapter_title}): {chapters[chapter]} chunks")

    # Sample chunks
    print(f"\n📄 Sample chunks:")
    print("=" * 80)

    for i, chunk in enumerate(chunks[:3], 1):
        print(f"\nChunk {i}: {chunk.id}")
        print(f"Article: {chunk.metadata['article_number']} - {chunk.metadata['article_title']}")
        print(f"Topics: {', '.join(chunk.metadata['topics'])}")
        print(f"\nText preview:")
        print(chunk.text[:300] + "...\n")
        print("-" * 80)

    print("\n✅ Demo complete! Your parser is working.")


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
