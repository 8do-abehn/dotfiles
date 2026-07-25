---
name: linkedin-recommendation
description: Draft, edit, or polish LinkedIn recommendations and professional endorsements for colleagues. Use this whenever the user mentions writing a recommendation, endorsement, or reference for a coworker, shares a draft recommendation to review, or pastes notes/AI summaries about a former colleague they want turned into a recommendation, even if they don't say "LinkedIn" explicitly.
---

# LinkedIn Recommendation Writer

Help the user write recommendations that sound like a real colleague wrote them: credible, specific, and scaled to how well the writer actually knew the person. These are public and signed with the user's name, so their credibility is on the line, not just the subject's.

## Gather before drafting

1. **How the user actually knew the person.** Manager? Peer? Adjacent teams who shared meetings? This drives everything else.
2. **The person's real LinkedIn headline/title.** Notes and memory are often wrong about titles. Ask for the actual headline if not provided; recruiters cross-reference, and the recommendation should echo how the person positions themselves. Spell out the company name in full on first mention (searchability), even if the user writes an abbreviation.
3. **Source material.** The user may provide a rough draft, or notes summarized by another AI tool. AI-summarized notes often contain citation-number artifacts stuck to words ("Studio GameOps (SGO) and Services 12"). Strip these silently; they'd look broken if pasted.

## Core rules

**Claim only what the user directly observed.** This is the rule users correct most. Source notes tend to describe everyone in glowing manager-level detail, but if the user only knew someone through meetings and contracts, the recommendation should only cover meetings and contracts. Cut anything the user didn't witness firsthand, and flag to the user anything you cut so they can confirm. If their headline mentions a skill area the user never saw (e.g., data center ops), leave it out and tell the user why rather than vouching blind.

**Keep confidential work vague or absent.** Salary bands, internal personnel decisions, named third parties. Gesture at the category ("staffing transitions", "team structure decisions") without specifics. Only name partner companies if the relationship is publicly known; offer a generic fallback ("external development partners") if unsure.

**Scale length and warmth to the relationship.**
- Knew them well (manager, mentor, close collaborator): 3-4 short paragraphs, warm is fine.
- Worked adjacent (shared meetings, vendor coordination): 2 short paragraphs, modest. A short honest recommendation reads better than a long glowing one from someone who wasn't close.

**Open by establishing the relationship.** "I worked with X at [Company], where she was [role]..." Watch for ambiguous phrasing like "working with X as the Product Owner", which leaves unclear who held the role.

**Cut intensifiers and stacked clichés.** "Absolute privilege" → "privilege". "Incredibly lucky" → "lucky". One closer, not three ("in a heartbeat" + "makes teams better" + "integrity and competence" is two too many). The content should carry the praise; if it can't, the draft needs specifics, not adjectives.

**Prefer one concrete detail over three superlatives.** A real quote, a named initiative, a specific behavior ("protected his engineers from emergent work so they could focus on sprint goals") is what makes a recommendation believable.

**Fix idioms and typos.** "Take the reins", not "grab the reigns". Watch for words with unintended dismissive tones ("without fuss") and offer alternatives.

**No em-dashes.** Use commas, colons, periods, or parentheses instead.

## Output format

Always end the response with a plain copy/paste version of the full recommendation: no blockquote markers, no markdown decoration inside it, just paragraphs the user can select and paste into LinkedIn.

After the copy/paste block (or before it, but never inside it), briefly note:
- What you changed or cut and why (one line each, only the load-bearing ones)
- Anything the user should verify (title accuracy, whether a partnership is public)

## Iterating

Users refine these over several rounds ("tone it down", "he didn't really do X", "simpler, I didn't know her that well"). On each revision, change only what the correction targets and re-output the full copy/paste version every time, since the user pastes the latest one. When a correction removes a claim, check whether an adjacent sentence was leaning on it and adjust so nothing reads as redundant or orphaned.
