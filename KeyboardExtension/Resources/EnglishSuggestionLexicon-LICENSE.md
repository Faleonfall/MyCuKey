# EnglishSuggestionLexicon.tsv

This suggestion lexicon is generated for MyCuKey from:

- `count_1w.txt`, the word-frequency list published by Peter Norvig at
  <https://norvig.com/ngrams/> derived from the Google Web Trillion Word
  Corpus (Thorsten Brants, Alex Franz, Google Inc., distributed by the
  Linguistic Data Consortium). Norvig publishes the list for free use;
  see the "Natural Language Corpus Data" chapter of *Beautiful Data*.

Generation rules applied for MyCuKey:

- Top lowercase alphabetic entries by corpus frequency, kept only when the
  macOS spell checker accepts them (drops corpus-frequent misspellings such
  as "definately"), about 42,000 words.
- Web artifacts (protocol/domain/file-extension tokens), foreign function
  words, single letters other than "a"/"i", unrecognized two-letter tokens,
  and profanity are excluded. Profanity stays typable — the engine never
  rewrites words the system spell checker accepts — it is only never
  suggested or silently committed, matching native keyboard behavior.
- The numeric score column is a MyCuKey-local ranking hint mapped
  monotonically from corpus rank into the 6200-10000 band the engine's
  scoring constants are tuned for. It is not a raw frequency claim.
