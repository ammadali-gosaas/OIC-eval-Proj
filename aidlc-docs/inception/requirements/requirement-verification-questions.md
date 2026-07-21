# Requirements Verification Questions

Please answer the following questions based on the customer discovery transcript.

## Question 1
What should the prototype use as its BOM data source for phase one?

A) Live Oracle Fusion PLM data only

B) Mock or sample payloads only

C) Both live Fusion PLM and mock payloads, depending on access

X) Other (please describe after [Answer]: tag below)

[Answer]: C

## Question 2
Which validation capabilities are mandatory in version 1?

A) Missing or blank field checks only

B) Missing/blank fields plus duplicate component detection

C) Missing/blank fields, duplicate detection, and UOM validation

D) Missing/blank fields, duplicate detection, UOM validation, and quantity anomaly detection

X) Other (please describe after [Answer]: tag below)

[Answer]: X
Missing/blank fields, duplicate detection, UOM validation, quantity anomaly detection, circular references/BOM loops, obsolete components in active
BOMs, and effectivity date issues.

## Question 3
How should validation results be treated in the phase-one prototype?

A) Advisory only, with no formal issue status tracking

B) Tracked as issues for review, but no automatic PLM updates

C) Tracked as issues with severity levels and reviewer resolution workflow

X) Other (please describe after [Answer]: tag below)

[Answer]: C

## Question 4
What user roles should the prototype support?

A) Engineers only

B) Engineers and reviewers/approvers

C) Engineers, reviewers/approvers, and IT support/admin users

X) Other (please describe after [Answer]: tag below)

[Answer]: C

## Question 5
What should the AI component do in phase one?

A) Explain issues only

B) Explain issues and suggest corrective actions

C) Explain issues, suggest corrective actions, and summarize BOM risk for users

X) Other (please describe after [Answer]: tag below)

[Answer]: C

## Question 6
What should the main dashboard experience emphasize?

A) Health score overview only

B) List of risky BOMs only

C) Both a health score overview and a list of risky BOMs

D) Dashboard plus a detailed BOM drill-down view with issue explanations

X) Other (please describe after [Answer]: tag below)

[Answer]: D

## Question 7
What logging and troubleshooting detail is required for OIC and integration flows?

A) Basic success/failure status only

B) Status plus timestamps and error messages

C) Status, timestamps, error messages, and correlation/tracking IDs

D) Full request/response trace for support analysis

X) Other (please describe after [Answer]: tag below)

[Answer]: C

## Question 8
How should validation runs be triggered?

A) Manual only

B) Scheduled only

C) Both manual and scheduled

X) Other (please describe after [Answer]: tag below)

[Answer]: C
