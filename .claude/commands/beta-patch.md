Before running the fastlane lane, generate a user-facing changelog for TestFlight:

1. Run `git log $(git describe --tags --abbrev=0)..HEAD --oneline` to see all commits since the last tag.
2. From those commits, write a changelog aimed at end users (not developers). Focus on user-visible changes only — new features, improvements, and bug fixes that affect the user experience. Ignore internal changes (refactor, docs, tests, chore, CI, wip). Write concise, benefit-oriented bullet points — never paste raw commit messages.
3. Write the changelog in two languages with this exact format:
   ```
   [FR]
   Nouveautés :
   - ...

   Corrections :
   - ...

   [EN]
   What's new:
   - ...

   Fixes:
   - ...
   ```
   Omit a section if there are no items for it.
4. Present the changelog to the user and ask for validation before proceeding.
5. Once validated, write the changelog to `fastlane/changelog.txt`.
6. Run `bundle exec fastlane beta bump:patch` and wait for the command to complete.
7. Delete `fastlane/changelog.txt` after the lane finishes (whether it succeeded or failed).
8. Report the result to the user.
