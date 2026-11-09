Write a short drift report on Diego's own tool repositories.

The text after "Drift data" lists, for each repo input in this machine's flake locks, the revision this machine has and the revision on the remote default branch. Each line ends with MOVED, same, no-clone or unreadable.

1. List the MOVED lines first: repo name, how the two revisions differ (short hashes), and which flake lock it comes from.
2. Then list no-clone and unreadable lines, each with its reason. Never leave a repo out.
3. If nothing moved, say that in one sentence.

Write the result as one note with `write_note`. The path is in the line "Note path" below. Use only the data given. Do not run anything and do not suggest commands that update anything.
