#!/usr/bin/env python3
"""Builds Resources/phrases.txt from Vietnamese text: the compounds and phrases people really write.

    ngrams.py count <cache.npz> <holdout.txt> <corpus.txt[.gz]>...
    ngrams.py emit  <cache.npz> <dictionary.txt> <out.txt> [--min-typed N] [--dom-word X] [--dom-phrase X]

Corpora (object.pouta.csc.fi/OPUS-OpenSubtitles/v2018/mono/vi.txt.gz, and the first three million lines of
OPUS-CCMatrix/v1/mono/vi.txt.gz), the dictionary (github.com/duyetdev/vietnamese-wordlist, Viet74K.txt) and numpy are
not in the repository.

`count` tallies every n-gram of valid syllables (Core/Syllables.swift) in the corpus, one line in fifty going to
`holdout.txt` instead, to measure precision. `emit` turns the counts into phrases. From each prefix of
`min-typed` syllables or more that occurs often enough, the phrase continues along the syllable that follows it
in at least a share of its occurrences, and goes on for as long as the whole stretch stays in that share. The share is `dom-word` when the syllable
completes a word of the dictionary (one entry per line, Viet74K), where a compound is likely, and `dom-phrase`
otherwise. Where no syllable reaches it, the prefix is left without a suggestion: the phrases written there
split, which is how `PhraseIndex` reads them.
"""

import gzip
import re
import sys
import unicodedata
from array import array
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
TONES = {0x0300, 0x0301, 0x0309, 0x0303, 0x0323}

MIN_TYPED = 1
DOM_WORD = 0.95
DOM_PHRASE = 0.99
# The least occurrences of a prefix of n syllables, by n.
MIN_COUNT = {2: 60, 3: 40, 4: 30, 5: 25, 6: 20}
MAX_LENGTH = max(MIN_COUNT)
# Subtitles are full of swearing, and an input method should not offer it.
EXCLUDED = {"địt", "đụ", "lồn", "cặc", "buồi", "đéo", "đĩ"}
# The last word of a phrase that only splits a prefix; no typed text matches it.
BLOCK = -1
BLOCK_TEXT = "\u2026"
HOLDOUT_EVERY = 50


def key(syllable: str) -> str:
    """The same comparison as `Suggest.key`: no tone placement, tone mark last."""
    letters, tone = [], ""
    for ch in unicodedata.normalize("NFD", syllable.lower()):
        if ord(ch) in TONES:
            tone = ch
        else:
            letters.append(ch)
    return "".join(letters) + tone


def vocabulary() -> dict[str, int]:
    source = (ROOT / "Core/Syllables.swift").read_text(encoding="utf8")
    block = re.search(r'private let source = """\n(.*?)"""', source, re.S).group(1)
    keys = sorted({key(word) for word in block.split()})
    return {k: i for i, k in enumerate(keys)}


SEGMENT = re.compile(r"[^\w\s]|[\d_]")


def tokenize(paths, ids, surfaces, holdout):
    tokens = array("i")
    cache: dict[str, int] = {}
    lines = 0
    for path in paths:
        opener = gzip.open if str(path).endswith(".gz") else open
        try:
            with opener(path, "rt", encoding="utf8", errors="ignore") as handle:
                for line in handle:
                    lines += 1
                    line = unicodedata.normalize("NFC", line.lower())
                    if lines % HOLDOUT_EVERY == 0:
                        holdout.write(line if line.endswith("\n") else line + "\n")
                        continue
                    for segment in SEGMENT.split(line):
                        for word in segment.split():
                            number = cache.get(word)
                            if number is None:
                                number = ids.get(key(word), -1)
                                cache[word] = number
                            if number >= 0:
                                surfaces[number][word] += 1
                            tokens.append(number)
                        tokens.append(-1)
        except EOFError:
            pass  # a download cut short ends mid-stream
    return np.frombuffer(tokens, dtype=np.int32), lines


def count_levels(tokens, size):
    """Per length n: parent group, syllable and count of every kept n-gram, grouped by prefix."""
    group = np.where(tokens >= 0, tokens, -1).astype(np.int64)
    unigrams = np.bincount(tokens[tokens >= 0], minlength=size)
    levels = {1: (None, np.arange(size), unigrams)}
    for n in range(2, MAX_LENGTH + 1):
        prefix = group[: len(tokens) - n + 1]
        following = tokens[n - 1 :]
        valid = (prefix >= 0) & (following >= 0)
        keys = prefix[valid] * size + following[valid]
        unique, inverse, counts = np.unique(
            keys, return_inverse=True, return_counts=True
        )
        kept = counts >= MIN_COUNT[n]
        renumber = np.full(len(unique), -1, dtype=np.int64)
        renumber[kept] = np.arange(kept.sum())
        group = np.full(len(prefix), -1, dtype=np.int64)
        group[np.nonzero(valid)[0]] = renumber[inverse]
        levels[n] = (unique[kept] // size, unique[kept] % size, counts[kept])
        print(f"  {n}-grams kept: {int(kept.sum())}", file=sys.stderr)
    return levels


def dictionary_words(path, ids):
    """Dictionary entries of two syllables or more as tuples of syllable numbers, those made of known syllables."""
    words = set()
    for line in open(path, encoding="utf8"):
        parts = [ids.get(key(part), -1) for part in unicodedata.normalize("NFC", line.strip()).split()]
        if len(parts) >= 2 and all(number >= 0 for number in parts):
            words.add(tuple(parts))
    return words


def phrases(levels, size, words, min_typed, dom_word, dom_phrase):
    children = defaultdict(list)  # (length, group) -> [(count, syllable, group of the child)]
    for n in range(2, MAX_LENGTH + 1):
        parent, syllable, count = levels[n]
        for gid in range(len(count)):
            children[(n - 1, int(parent[gid]))].append((int(count[gid]), int(syllable[gid]), gid))
    for kids in children.values():
        kids.sort(reverse=True)

    def needed(sequence):
        """The share the next syllable must reach: lower when it completes a dictionary word."""
        for length in range(2, 5):
            if tuple(sequence[-length:]) in words:
                return dom_word
        return dom_phrase

    def walk(n, gid, sequence):
        total = int(levels[n][2][gid])
        kids = children.get((n, gid), [])
        if n >= min_typed and kids and kids[0][0] / total >= needed(sequence + [kids[0][1]]):
            chain, node, depth = [kids[0][1]], kids[0], n + 1
            while True:
                following = children.get((depth, node[2]), [])
                if following and following[0][0] / total >= needed(sequence + chain + [following[0][1]]):
                    chain.append(following[0][1])
                    node, depth = following[0], depth + 1
                else:
                    break
            return [sequence + chain]
        found, with_phrases = [], []
        for kid in kids:
            sub = walk(n + 1, kid[2], sequence + [kid[1]])
            if sub:
                found.extend(sub)
                with_phrases.append(kid)
        if n >= min_typed and len(with_phrases) == 1:
            # Below a prefix with no dominant syllable only one child kept phrases (the rest were too rare to
            # count, or have none). A phrase that goes nowhere keeps the words from suggesting that child.
            found.append(sequence + [BLOCK])
        return found

    out = []
    for token in range(size):
        out.extend(walk(1, token, [token]))
    return out


def count(cache_path, holdout_path, corpora):
    ids = vocabulary()
    names = {i: k for k, i in ids.items()}
    surfaces = defaultdict(Counter)
    with open(holdout_path, "w", encoding="utf8") as holdout:
        tokens, lines = tokenize(corpora, ids, surfaces, holdout)
    print(f"{lines} lines, {len(tokens)} tokens", file=sys.stderr)
    levels = count_levels(tokens, len(ids))
    shown = [surfaces[i].most_common(1)[0][0] if surfaces[i] else names[i] for i in range(len(ids))]
    arrays = {"shown": np.array(shown)}
    for n, (parent, syllable, counts) in levels.items():
        arrays[f"parent{n}"] = parent if parent is not None else np.zeros(0, dtype=np.int64)
        arrays[f"syllable{n}"] = syllable
        arrays[f"count{n}"] = counts
    np.savez(cache_path, **arrays)


def emit(cache_path, dictionary_path, out_path, min_typed, dom_word, dom_phrase):
    ids = vocabulary()
    cached = np.load(cache_path)
    levels = {n: (cached[f"parent{n}"], cached[f"syllable{n}"], cached[f"count{n}"]) for n in range(1, MAX_LENGTH + 1)}
    shown = [str(word) for word in cached["shown"]]
    words = dictionary_words(dictionary_path, ids)
    found = phrases(levels, len(ids), words, min_typed, dom_word, dom_phrase)
    excluded = {ids[key(word)] for word in EXCLUDED if key(word) in ids}
    found = [phrase for phrase in found if not excluded.intersection(phrase)]
    lines = sorted({" ".join(shown[t] if t >= 0 else BLOCK_TEXT for t in phrase) for phrase in found})
    header = (
        "# Phrases Suggest completes, from the n-grams of Vietnamese text (see tools/phrases/ngrams.py).\n"
        "# Text: OpenSubtitles (opus.nlpl.eu) and the first three million lines of CCMatrix Vietnamese.\n"
        f"# From {min_typed} typed syllable(s) on, a phrase goes on along the syllable that follows in at least\n"
        f"# {int(dom_word * 100)}% of the occurrences when it completes a dictionary word, {int(dom_phrase * 100)}% otherwise.\n"
        "# The last word of a line that ends in an ellipsis is a stop: the phrases written there split.\n"
    )
    Path(out_path).write_text(header + "\n".join(lines) + "\n", encoding="utf8")
    print(f"{len(lines)} phrases", file=sys.stderr)


def main():
    command, *rest = sys.argv[1:]
    if command == "count":
        cache_path, holdout_path, *corpora = rest
        count(cache_path, holdout_path, corpora)
        return
    flags = {"--min-typed": MIN_TYPED, "--dom-word": DOM_WORD, "--dom-phrase": DOM_PHRASE}
    positional = []
    i = 0
    while i < len(rest):
        if rest[i] in flags:
            flags[rest[i]] = type(flags[rest[i]])(rest[i + 1])
            i += 2
        else:
            positional.append(rest[i])
            i += 1
    cache_path, dictionary_path, out_path = positional
    emit(cache_path, dictionary_path, out_path, flags["--min-typed"], flags["--dom-word"], flags["--dom-phrase"])


if __name__ == "__main__":
    main()
