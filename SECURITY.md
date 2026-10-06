# Security Policy

## Supported Versions

Sqinky is pre-1.0. Security fixes are released only for the latest published version. Please upgrade to the latest release before reporting an issue.

Fixes are tested only against the Ruby and Rails versions that still receive maintenance from their maintainers, see [Supported versions](README.md#supported-versions).

## Reporting a Vulnerability

Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.

Report them privately through [GitHub private vulnerability reporting](https://github.com/david-uhlig/sqinky/security/advisories/new) instead. If you can't use GitHub, email david.uhlig@gmail.com with `[sqinky security]` in the subject.

Please include:

- the affected Sqinky version, and your Ruby, Rails, and Sqids versions,
- a description of the issue and its impact,
- steps or a minimal model definition to reproduce it, and
- a suggested fix, if you have one.

## What to Expect

Sqinky is maintained by one person in their spare time, so these timelines are a best effort:

- You will get an acknowledgement within 7 days.
- You will get an initial assessment within 14 days, including whether the report is accepted.
- If accepted, a fix is developed in a private fork and released as a new gem version. A GitHub security advisory is published at the same time, and a CVE is requested where appropriate.

You will be credited in the advisory unless you prefer to stay anonymous. Please keep the report confidential until the advisory is published.

## Scope

Sqids encodings are not encrypted, and anyone can decode them with the public Sqids library. The following is expected behavior and not a vulnerability:

- decoding an encoding back to its numbers,
- guessing or enumerating valid encodings, and
- accessing a record found through an encoding when the application doesn't authorize that access.

Use encodings to shorten URLs and hide sequential IDs from casual view, not for access control, see the note in [Usage](README.md#usage).

In scope are, for example, a crafted encoding that makes a `find_by_*`, `destroy_by_*`, or `delete_by_*` helper act on a record other than the one it decodes to, or that triggers excessive resource use.

Vulnerabilities in Sqids itself should be reported to the [Sqids Ruby project](https://github.com/sqids/sqids-ruby).
