# Participant guide

In order. Each page ends with a checkpoint the next page assumes.

| Step | Page | When |
|---|---|---|
| 1 | [Prep](01-prep.md) | before the clinic |
| 2 | [Your issue](02-your-issue.md) | first thing |
| 3 | [Branch](03-branch.md) | clinic, first thing |
| 4 | [Reproduce](04-reproduce.md) | clinic, before touching the fix |
| 5 | [Fix and test](05-fix-and-test.md) | clinic |
| 6 | [Validate](06-validate.md) | clinic, before every commit |
| 7 | [Commit](07-commit.md) | clinic |
| 8 | [Open the pull request](08-open-the-pr.md) | clinic, before the review block |
| 9 | [After the clinic](09-after-the-clinic.md) | the following week |

Also: [Cheat sheet](cheatsheet.md) (one page),
[Testing locally](local-testing.md) (what CI runs and how to run the same
thing, plus how to test your change by hand), and
[Troubleshooting](troubleshooting.md).

Your issue's brief is in [`../groups/`](../groups/README.md).

## The whole thing in one picture

```
 prep                                  clinic                                  week after
 ─────────────────────────────────     ─────────────────────────────────────   ──────────────
 fork, bundle, env check         ──►   branch ──► reproduce ──► fix+test        review,
 read brief and issue                         ◄── validate ◄──┘     │           amend,
                                              commit -s ──► push ──► PR         merge
```

Reproduce before you fix; several of these issues are old and some are
already fixed.
