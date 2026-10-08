# monorepo root-dir Dockerfile repro

Minimal repo to check which Dockerfile and which build context the PaaS uses
when an app's **root dir** is set to a subfolder (`app/`).

```
/Dockerfile            ROOT image, expects repo root as context
/root.html             ROOT page ("ROOT Dockerfile was built")
/.dockerignore         excludes ignored-by-root.txt (and .git)
/ROOT_CONTEXT_MARKER
/ignored-by-root.txt
/app/Dockerfile        APP image, expects app/ as context
/app/index.html        APP page ("APP Dockerfile was built")
/app/.dockerignore     excludes ignored-by-app.txt
/app/APP_CONTEXT_MARKER
/app/ignored-by-app.txt
/app/package.json      Vite-like shape for framework detection, no deps
```

Both images are `busybox` `httpd` on `$PORT` (default 8080). Each page links to
`/context.txt`, which is `find /ctx -maxdepth 2 | sort` of `COPY . /ctx`, the
build context as the builder saw it.

`/app/Dockerfile` only uses paths relative to `app/` (`COPY index.html APP_CONTEXT_MARKER /www/`).
Neither file exists at the repo root, so building it with the repo root as
context **fails** instead of quietly working.

## Branches

- `main`: both Dockerfiles.
- `no-root-dockerfile`: the same, minus `/Dockerfile`.

## Reading `/context.txt`

| Listing contains | Meaning |
|---|---|
| `/ctx/APP_CONTEXT_MARKER`, `/ctx/index.html`, `/ctx/package.json`; no `ignored-by-app.txt` | context = `app/`, app `.dockerignore` applied (correct for root dir `app/`) |
| `/ctx/ROOT_CONTEXT_MARKER`, `/ctx/app`, `/ctx/README.md`, `/ctx/.dockerignore`, `/ctx/app/APP_CONTEXT_MARKER`; no `/ctx/ignored-by-root.txt` | context = repo root, root `.dockerignore` applied |
| `/ctx/ignored-by-root.txt` or `/ctx/ignored-by-app.txt` present | that place's `.dockerignore` was **not** applied |

## Test matrix

| branch | root dir setting | expected page | expected context listing | actual |
|---|---|---|---|---|
| `main` | `app/` | APP Dockerfile was built | app only (`APP_CONTEXT_MARKER`, `index.html`, `package.json`, `.dockerignore`; no `ignored-by-app.txt`) | |
| `main` | repo root | ROOT Dockerfile was built | repo root (`ROOT_CONTEXT_MARKER`, `app/…`, `README.md`, `.dockerignore`; no `ignored-by-root.txt`) | |
| `no-root-dockerfile` | `app/` | APP Dockerfile was built | app only (same as row 1) | |
| `no-root-dockerfile` | repo root | none defined: there is no root Dockerfile and nothing detectable at the root. Note what the platform does (error, auto-detect fallback, or it finds `app/Dockerfile`) | n/a | |

## Which outcome means which bug

- **Root dir `app/` shows the ROOT page** (main, row 1): Dockerfile lookup
  ignores the root dir and uses `/Dockerfile`. The listing will also show the
  repo-root context.
- **Root dir `app/` fails with `"/index.html": not found` /
  `"/APP_CONTEXT_MARKER": not found`**: the builder found `app/Dockerfile` but
  used the **repo root as build context**. The Dockerfile path honors the root
  dir; the context doesn't.
- **APP page, but `ignored-by-app.txt` is in the listing**: context is right,
  but the `app/.dockerignore` was not applied.
- **`no-root-dockerfile` + `app/` errors with "no Dockerfile found"** (or falls
  back to a Node/Vite buildpack): the lookup only checks the repo root, so
  `app/Dockerfile` is never considered. A Vite/Node fallback here means framework
  detection honors the root dir while Dockerfile detection doesn't.
- **`no-root-dockerfile` + repo root builds the APP page**: the platform
  searches subfolders for a Dockerfile. Note the context it used (it will most
  likely fail on `COPY index.html` if the context is the repo root).

## Local check

```sh
docker build -t repro-root .            && docker run --rm -p 8080:8080 repro-root
docker build -t repro-app  app          && docker run --rm -p 8081:8080 repro-app
# reproduce the context bug locally (expected to FAIL):
docker build -f app/Dockerfile .
```
