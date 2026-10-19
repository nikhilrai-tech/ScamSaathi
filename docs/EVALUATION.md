# How well does it work? (and how we measure it)

**Short answer.** On a fresh test set written after the rules and the model were fixed, ScamSaathi flagged **27 of 36 scams (75%)**
and wrongly flagged **1 of 36 normal messages (2.8%)**. That is a small, made-up sample, so the honest range for the scam
catch rate is **59% to 86%**. It has **not** been tested on real WhatsApp or SMS traffic. Use every result as a strong hint, never as proof.

## What is measured

A message is *flagged* when the verdict is *suspicious* or *dangerous*.

- **Recall**: the share of scam messages that get flagged.
- **False alarms**: the share of normal messages that get flagged. We care about this as much as recall: an app that cries wolf gets uninstalled.
- Intervals are 95% Wilson intervals. With 36 messages they are wide, and that is the real uncertainty.

## The data, and why you should be careful with it

Every message in `packs/core/*.jsonl` is **made up**: written for this project, never copied from a real person's phone, with fake
numbers (`9XXXXXXXXX`) and fake links. That protects people's privacy, and it also means the sets reflect how *we* imagine scams
sound. Real scammers are more varied. Treat the numbers as "how the system behaves on realistic examples", not "how often it works in the wild".

| Set | Scams / normal | How it was used |
|---|---|---|
| `benchmark` | 81 / 60 | Built the rules (tuning set). Not a fair test. |
| `heldout` | 39 / 43 | First look: **51% recall**, 0 false alarms (rules only). Then used for tuning. |
| `heldout2` | 40 / 42 | First look: **57% recall**, 2 false alarms (rules only). Then used for tuning. |
| `heldout3` | 36 / 36 | First look, rules only: **42%** (15/36, interval 27% to 58%), 0 false alarms. With the wording model (trained without this set): **75%** (27/36, interval 59% to 86%), 1 false alarm (2.8%). |
| `everyday` | 0 / 40 | Normal messages with links, added after we saw the model wrongly flag a friend's YouTube link. |

The rule that keeps this honest: **a set's first-look number is recorded once, before anything is changed because of it.**
After that the set joins the training pool and its numbers stop counting as accuracy. The next release needs a new fresh set.

What we learned, in order:

1. **Phrase rules alone catch about half of unseen scams** (51%, 57%, 42% on three fresh sets) but almost never raise a false alarm.
   Their recall on the sets we tuned them on (100%) was overfitting, not skill.
2. **A model that sees wording, not phrases, generalises better.** A character n-gram Naive Bayes, added to the rules, lifted the fresh-set
   catch rate from 42% to 75% at the same low false-alarm rate (reproduce with the commands below).
3. **The model has a real weakness: normal messages with links.** It first flagged a friend's YouTube link. We added the `everyday` set and
   recalibrated. It may still be wrong on normal-message styles we have not thought of. This is the main risk before real-world use.

## Reproduce it

```bash
python tools/evaluate.py                                    # the shipping pack on the tuning set
python tools/evaluate.py --bench packs/core/heldout3.jsonl --markdown

# the honest first-look number for set 3: a model trained WITHOUT it, rules alone vs rules + model
python tools/train_model.py --sets benchmark heldout heldout2 --write --out /tmp/pack_3set.json
python tools/evaluate.py --pack /tmp/pack_3set.json --no-model --bench packs/core/heldout3.jsonl --markdown
python tools/evaluate.py --pack /tmp/pack_3set.json            --bench packs/core/heldout3.jsonl --markdown
```

`tools/train_model.py` chooses the model's alert threshold from *out-of-fold* scores, so that about 3% of normal messages would be flagged.
Over all five sets, leave-one-set-out: rules alone 88% / 0% false alarms, model alone 37% / 2.7%, rules or model 92% / 2.7%.
(The rules' 88% is flattered because they were tuned on some of those sets. Only the fresh-set number above is clean.)

## How the model is kept safe

- It adds a warning (`model.wording`: "The wording is very similar to scam messages seen before") but can **never alone make a message *dangerous***.
- It is a few thousand integer weights inside the signed rule pack, so it is covered by the same signature and the Dart app gives exactly the same answer
  (`packs/core/snapshot.json` records the answer for all ~480 messages, and both engines are tested against it).
- It can be removed from a pack without touching any code.

## What would make the numbers mean more

1. **Real messages, with consent.** A way for users to donate a message they received (after removing names and numbers), reviewed by a person.
2. **More normal messages**, especially from the people we want to serve: family chat, school and cooperative notices, mandi prices, in Hindi, Hinglish and English.
3. **A new fresh set every release**, measured once.
4. **Pilot data** from the 3 institutions in the [roadmap](ARCHITECTURE.md#roadmap).
-