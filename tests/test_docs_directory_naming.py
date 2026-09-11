"""Every directory under `docs/` must be named in CLAUDE.md.

CLAUDE.md's documentation section opens by naming its own failure mode — "the
distinction erodes easily" — and then eroded: `docs/research/` was created on
`dev-05`, held one file, and was named by no table, no README and no other file
in the repository (issue #61). The same branch revised the count in that
sentence from four directories to five while adding `docs/adr/`, and did not
count the sixth.

The cost of an unnamed directory is not the directory. It is that the next
document of its kind has no rule saying where it goes, and the one after that
has a precedent instead of a rule.

**Scope limit, stated because it is the interesting half.** These tests catch a
directory that is *unnamed* and a count that is *stale*. They cannot catch a
directory that is named in the wrong place, described wrongly, or given a job
that overlaps its neighbour's — that judgement is what review is for. A green
run here is evidence about the two cases below and about nothing else.
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CLAUDE_MD = PROJECT_ROOT / "CLAUDE.md"
DOCS = PROJECT_ROOT / "docs"

# The heading the documentation table lives under. Written as a literal:
# reading it back out of the file would make the test agree with whatever the
# file happens to say.
SECTION_HEADING = "## Documentation"

# Number words this project would plausibly reach for. A count outside this
# range means the section grew past what the sentence form can carry, which is
# worth a failure rather than a silent skip.
NUMBER_WORDS = {
    "Three": 3,
    "Four": 4,
    "Five": 5,
    "Six": 6,
    "Seven": 7,
    "Eight": 8,
}

# `docs/agents/` carries agent configuration, not a kind of documentation, so
# it is named in CLAUDE.md's prose rather than in the table. The invariant is
# that a directory is named *somewhere*, which is the weakest form of the rule
# that still catches issue #61.
NAMING_FORM = "docs/{name}/"


def _documentation_section() -> list[str]:
    lines = CLAUDE_MD.read_text(encoding="utf-8").splitlines()
    assert SECTION_HEADING in lines, (
        f"CLAUDE.md has no {SECTION_HEADING!r} heading. If the section was "
        "renamed, rename SECTION_HEADING with it — these tests are about that "
        "section and silently measure nothing without it."
    )
    start = lines.index(SECTION_HEADING)
    for offset, line in enumerate(lines[start + 1 :], start=start + 1):
        if line.startswith("## "):
            return lines[start + 1 : offset]
    return lines[start + 1 :]


def test_every_docs_directory_is_named_in_claude_md():
    text = CLAUDE_MD.read_text(encoding="utf-8")
    directories = sorted(p.name for p in DOCS.iterdir() if p.is_dir())
    assert directories, "docs/ has no subdirectories; the glob is wrong"

    unnamed = [
        name for name in directories if NAMING_FORM.format(name=name) not in text
    ]
    assert not unnamed, (
        f"docs/ subdirectories named nowhere in CLAUDE.md: {unnamed}. "
        "Give each one a job in the documentation table, or fold its contents "
        "into a directory that already has one."
    )


def test_the_stated_directory_count_matches_the_table():
    section = _documentation_section()

    counted = [
        line for line in section if line.startswith("| `docs/") and line.endswith("|")
    ]
    assert counted, "no `docs/...` rows found under the documentation heading"

    sentences = [line for line in section if "directories with different jobs" in line]
    assert len(sentences) == 1, (
        f"expected exactly one 'N directories with different jobs' sentence, "
        f"found {len(sentences)}"
    )

    stated_word = sentences[0].split(" ", 1)[0]
    assert stated_word in NUMBER_WORDS, (
        f"'{stated_word}' is not a number word this test knows; "
        f"expected one of {sorted(NUMBER_WORDS)}"
    )

    assert NUMBER_WORDS[stated_word] == len(counted), (
        f"CLAUDE.md says '{stated_word}' directories but the table has "
        f"{len(counted)} rows. The count and the table were revised in the "
        "same window once already and disagreed; see issue #61."
    )


def test_every_table_row_names_a_directory_that_exists():
    # The inverse of the first test, and the reason it is here: the first one
    # asks whether each directory is named *somewhere* in CLAUDE.md, and
    # `docs/research/` is now named in the prose as well as the table. So a
    # typo in the table row alone — `docs/researchX/` — left both other tests
    # green when it was tried. This one reads the rows and asks the filesystem.
    rows = [
        line for line in _documentation_section() if line.startswith("| `docs/")
    ]
    assert rows, "no `docs/...` rows found under the documentation heading"

    named = [line.split("`")[1].removeprefix("docs/").removesuffix("/") for line in rows]
    missing = [name for name in named if not (DOCS / name).is_dir()]
    assert not missing, (
        f"CLAUDE.md's documentation table names directories that do not "
        f"exist: {missing}. A row describing nothing is worse than no row — "
        "it reads as a rule someone is already following."
    )
