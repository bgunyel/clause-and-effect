import asyncio
import json
import logging
from pathlib import Path

from ai_common import calculate_token_cost, get_llm
from src.config import get_settings, get_llm_config


TIER_ONE_INSTRUCTIONS = """
You are generating evaluation test cases for a compliance RAG system that answers questions about GDPR.

Given the following GDPR article, generate 3 factual question-answer pairs.

REQUIREMENTS:

1. Questions must be answerable ONLY from this article text
2. Questions should sound like real user queries from engineers or compliance teams
3. Do NOT reference article numbers, paragraph numbers, or document structure in questions
4. Each question should be a different type. Choose 3 from:
   - TIMELINE: Response deadlines, notification periods, retention limits, age thresholds
   - DEFINITION: What counts as X, what does Y mean, who qualifies as Z
   - CONDITIONAL: Under what circumstances, when does X apply, what triggers Y
   - SCOPE: Does X apply to Y, is Z covered, what are the exceptions
5. If the article contains no meaningful timelines or deadlines, skip TIMELINE and use another type

AVOID:
- Meta-questions about article structure ("How many paragraphs...", "List the conditions in subsection 2...")
- Questions that test counting or memorization ("How many exceptions are listed...")
- Yes/no questions that don't require understanding the substance
- Questions answerable by general knowledge without reading the article
- Compound questions that ask two things at once
- Legal jargon that a non-lawyer wouldn't use

GOOD QUESTION PATTERNS:
- "Does GDPR apply to [specific scenario]?"
- "What must a company do when [specific event]?"
- "How long does [entity] have to [action]?"
- "Who is responsible for [obligation]?"
- "What conditions must be met before [action]?"
- "Can [entity] do [action] under GDPR?"

OUTPUT FORMAT (JSON):
{{
  "article_number": "<N>",
  "article_title": "<title>",
  "test_cases": [
    {{
      "question": "<question text>",
      "answer": "<complete answer in 1-3 sentences>",
      "answer_type": "timeline|definition|conditional|scope",
      "supporting_quote": "<exact quote from article that supports this answer>",
      "key_phrases": ["<phrase1>", "<phrase2>", "<phrase3>"]
    }}
  ]
}}

EXAMPLE OUTPUT (for Article 33 - Breach Notification):
{{
  "article_number": "33",
  "article_title": "Notification of a personal data breach to the supervisory authority",
  "test_cases": [
    {{
      "question": "How quickly must a company report a data breach to the regulator?",
      "answer": "The controller must notify the supervisory authority within 72 hours of becoming aware of the breach. If notification is delayed beyond 72 hours, it must include reasons for the delay.",
      "answer_type": "timeline",
      "supporting_quote": "not later than 72 hours after having become aware of it, notify the personal data breach to the supervisory authority",
      "key_phrases": ["72 hours", "without undue delay", "supervisory authority"]
    }},
    {{
      "question": "Does every data breach need to be reported to the supervisory authority?",
      "answer": "No. A breach only needs to be reported if it is likely to result in a risk to the rights and freedoms of natural persons. If the breach is unlikely to pose such a risk, notification is not required.",
      "answer_type": "conditional",
      "supporting_quote": "unless the personal data breach is unlikely to result in a risk to the rights and freedoms of natural persons",
      "key_phrases": ["unlikely to result in a risk", "rights and freedoms"]
    }},
    {{
      "question": "If a data processor discovers a breach, who must they notify?",
      "answer": "The processor must notify the controller without undue delay after becoming aware of the breach. It is then the controller's responsibility to notify the supervisory authority.",
      "answer_type": "scope",
      "supporting_quote": "The processor shall notify the controller without undue delay after becoming aware of a personal data breach",
      "key_phrases": ["processor", "notify the controller", "without undue delay"]
    }}
  ]
}}

ARTICLE TEXT:
Article {article_number}
{article_title}
{article_content}
"""


MAX_CONCURRENT_REQUESTS = 7
BATCH_SIZE = 3


async def process_article(article, llm_list, data_dir: Path, semaphore: asyncio.Semaphore):
    output_file = data_dir / f'article_{int(article["number"]):02d}.txt'
    if output_file.exists():
        print(f"article - {int(article['number']):02d} -- Skipped (already exists)")
        return

    print(f"article - {int(article['number']):02d}")

    instructions = TIER_ONE_INSTRUCTIONS.format(
        article_number=article['number'],
        article_title=article['title'],
        article_content=article['content'],
    )

    answer_str = """
        Please analyze and merge the following in order to obtain full coverage.
        Generate new samples for full coverage, if necessary:
        """

    async def invoke_with_semaphore(llm):
        max_retries = 5
        for attempt in range(max_retries):
            try:
                async with semaphore:
                    return await llm.ainvoke(instructions)
            except Exception as e:
                if attempt == max_retries - 1:
                    raise
                wait = 2 ** attempt
                logging.warning(f"LLM call failed (attempt {attempt + 1}/{max_retries}): {e}. Retrying in {wait}s...")
                await asyncio.sleep(wait)

    responses = await asyncio.gather(*[invoke_with_semaphore(llm) for llm in llm_list])
    for response in responses:
        text = response.content_blocks[-1]['text'] if response.content_blocks else response.content
        answer_str += '\n\n' + text

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(answer_str)

    print(f"article - {int(article['number']):02d} -- Finished")


async def generate_tier_one_dataset():
    settings = get_settings()
    llm_config = get_llm_config()

    articles_file = Path(settings.REGULATIONS_DIR) / 'gdpr_articles.json'
    with open(articles_file, 'r', encoding='utf-8') as f:
        articles = json.load(f)

    model_params = llm_config['orchestrator_model']
    llm_list = [
        get_llm(
            model_name=x['model'],
            model_provider=x['model_provider'],
            api_key=x['api_key'],
            model_args=x['model_args']
        )
        for x in model_params
    ]

    semaphore = asyncio.Semaphore(MAX_CONCURRENT_REQUESTS)
    data_dir = Path(settings.DATA_DIR)
    for i in range(0, len(articles), BATCH_SIZE):
        batch = articles[i:i + BATCH_SIZE]
        await asyncio.gather(*[process_article(article, llm_list, data_dir, semaphore) for article in batch])


def main():
    asyncio.run(generate_tier_one_dataset())

if __name__ == '__main__':
    main()