"""Predefined content warning and mood tag lists.

Only tags from these lists are accepted. This prevents abuse and keeps
the taxonomy clean. Add new tags here as the community requests them.
"""

CONTENT_WARNING_TAGS = [
    "graphic_violence",
    "sexual_content",
    "substance_abuse",
    "self_harm",
    "eating_disorders",
    "child_abuse",
    "domestic_violence",
    "sexual_assault",
    "animal_cruelty",
    "racism",
    "homophobia",
    "transphobia",
    "ableism",
    "war",
    "torture",
    "death_of_a_loved_one",
    "suicide",
    "gore",
    "kidnapping",
    "stalking",
]

MOOD_TAGS = [
    "slow_burn",
    "page_turner",
    "emotional",
    "dark",
    "lighthearted",
    "funny",
    "atmospheric",
    "tense",
    "hopeful",
    "melancholic",
    "thought_provoking",
    "romantic",
    "adventurous",
    "cozy",
    "unsettling",
    "inspirational",
    "nostalgic",
    "suspenseful",
    "bittersweet",
    "whimsical",
]

ALL_TAGS = {
    **{tag: "content_warning" for tag in CONTENT_WARNING_TAGS},
    **{tag: "mood" for tag in MOOD_TAGS},
}

# Number of votes required before a tag is considered confirmed
VOTE_THRESHOLD = 3


def is_valid_tag(tag_name: str) -> bool:
    return tag_name in ALL_TAGS


def get_tag_type(tag_name: str) -> str | None:
    return ALL_TAGS.get(tag_name)
