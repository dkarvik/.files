#!/usr/bin/env -S uv run --quiet --script
# /// script
# dependencies = ["python-frontmatter"]
# ///
"""Parse a reviewed draft (YAML front matter, title line, body) into JSON, and
maintain the alias tables that turn free-text field values into API values.

  parse-draft.py <draft> [aliases.json...]
    -> {"title", "body", "fields", "unresolved"}
  parse-draft.py learn <aliases.json> <field> <raw> <value>
    -> records raw -> value (value read as JSON when it parses, else a string);
       creates the file when missing

aliases.json: {"lists": [field...], "aliases": {field: {raw: value}}}
Alias files merge in order, later entries winning; missing files are skipped.
A list field takes a YAML list or a comma-separated string. A field with an
alias table, even an empty one, is strict: a value that is neither an alias nor
already one of the table's values lands in "unresolved" with its raw text.
"""
import json
import os
import sys

import frontmatter


def load_aliases(files):
    lists, aliases = set(), {}
    for f in files:
        if os.path.exists(f):
            cfg = json.load(open(f))
            lists |= set(cfg.get("lists", []))
            for k, table in cfg.get("aliases", {}).items():
                aliases.setdefault(k, {}).update(table)
    return lists, aliases


def resolve(table, v):
    if table is None:
        return v, None
    key = str(v).strip().lower()
    if key in table:
        return table[key], None
    for known in table.values():
        if str(known) == str(v).strip():
            return known, None
    return None, str(v)


def parse(draft, *aliases_files):
    lists, aliases = load_aliases(aliases_files)
    post = frontmatter.load(draft)
    title, _, body = post.content.strip().partition("\n")
    fields, unresolved = {}, []
    for k, v in post.metadata.items():
        if v is None or v == "":
            continue
        if k in lists:
            vs = v if isinstance(v, list) else [s.strip() for s in str(v).split(",") if s.strip()]
        else:
            vs = [v]
        ok = []
        for x in vs:
            r, raw = resolve(aliases.get(k), x)
            if raw is None:
                ok.append(r)
            else:
                unresolved.append({"field": k, "value": raw})
        if ok:
            fields[k] = ok if k in lists else ok[0]
    return {"title": title.strip(), "body": body.strip(), "fields": fields, "unresolved": unresolved}


def learn(aliases_file, field, raw, value):
    data = json.load(open(aliases_file)) if os.path.exists(aliases_file) else {}
    try:
        value = json.loads(value)
    except json.JSONDecodeError:
        pass
    data.setdefault("aliases", {}).setdefault(field, {})[raw.strip().lower()] = value
    with open(aliases_file, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit("usage: parse-draft.py <draft> [aliases.json...] | learn <aliases.json> <field> <raw> <value>")
    if args[0] == "learn":
        learn(*args[1:])
    else:
        print(json.dumps(parse(*args), indent=2, default=str))
