# pdfindex2md

[![selftest](https://github.com/skurtz97/pdfindex2md/actions/workflows/selftest.yml/badge.svg)](https://github.com/skurtz97/pdfindex2md/actions/workflows/selftest.yml)

Turn an Adobe-indexed PDF package into one Markdown file and one plain-text
file per document, plus an index you can grep.

It was written for IBM's *z/OS 3.2 Adobe indexed PDF collection* — 414 PDFs,
2.0 GB, shipped with a Word-generated table of contents as its only index.
Pointed at that package it produces `md/`, `txt/`, `INDEX.md` and `index.txt`
alongside the PDFs in about a minute, and leaves the package itself untouched
so it still opens and bookmarks in a browser exactly as before.

```sh
pdfindex2md ~/docs/mainframe/zOS320-Indexed-PDF-package-\(2026-07-31\)/
```

## What you get

```text
zOS320-Indexed-PDF-package-(2026-07-31)/
├── 1.READ_ME_FIRST_zOS_3.2_TOC.htm        untouched
├── 1.READ_ME_FIRST_zOS_3.2_TOC_files/     untouched
├── *.pdf                                  untouched (414 of them)
├── 1.READ_ME_FIRST_zOS_3.2_TOC.pdx/       untouched
├── md/
│   ├── cascading-flashcopy-izsc200_v3r2.md
│   ├── z-os-openssh-user-s-guide-foto100_v3r2.md
│   └── … 414 files
├── txt/
│   └── … the same 414 documents as plain text
├── INDEX.md                               Markdown table, grouped by category
└── index.txt                              the same index, one line per document
```

Markdown files carry the document title, a page marker per page
(`<!-- page 42 -->`), and headings taken from the PDF's own bookmarks:

```markdown
# z/OS OpenSSH User's Guide

- Order number: SC27-6802-02
- Source: `zos-openssh-users-guide-foto100_v3r2.pdf` (564 pages)

<!-- page 13 -->
## About this document

### Who should use this document?

…body text, one line per line of the printed page…
```

Names keep the document identifier the package uses (`izsc200_v3r2`,
`foto100_v3r2`) so a converted file can be traced back to its PDF, and the
identifier is dropped when the title already spells it out.

## Requirements

| Tool | Why |
|------|-----|
| Python 3.9+ | the script itself, standard library only |
| `pdftotext` from [poppler](https://poppler.freedesktop.org/) | the text of every page |
| `beautifulsoup4` + `lxml` | parsing the package's Word-generated TOC |
| [`pypdfium2`](https://github.com/pypdfium2-team/pypdfium2) (optional) | PDF bookmarks, which become the Markdown headings |

Without `pypdfium2` the Markdown is flat text with page markers. Everything
else still works.

Debian/Ubuntu:

```sh
sudo apt install poppler-utils python3-bs4 python3-lxml python3-pypdfium2
```

Fedora:

```sh
sudo dnf install poppler-utils python3-beautifulsoup4 python3-lxml python3-pypdfium2
```

## Install

It is a single script with no imports outside the standard library, so
installing means putting one file in a directory on your `PATH`. There is
nothing to compile and nothing to configure.

From a release tarball (swap `1.1.0` for whichever release you want):

```sh
curl -LO https://github.com/skurtz97/pdfindex2md/releases/download/v1.1.0/pdfindex2md-1.1.0.tar.gz
tar xzf pdfindex2md-1.1.0.tar.gz
cd pdfindex2md-1.1.0
make install
```

Or from a clone:

```sh
git clone https://github.com/skurtz97/pdfindex2md.git
cd pdfindex2md
make install
```

`make install` copies `pdfindex2md` to `$(PREFIX)/bin` with mode 755, and
`PREFIX` defaults to `$(HOME)/.local`, so it lands in `~/.local/bin` for a
single-user install and in `/usr/local/bin` with `sudo make install
PREFIX=/usr/local`. `DESTDIR` works the usual way for staging.

| command | what it does |
|---------|--------------|
| `make install` | copy the script into `$(DESTDIR)$(PREFIX)/bin` |
| `make uninstall` | remove it again |
| `make check` | run the naming selftest — the same thing CI runs |
| `make clean` | remove `__pycache__` |

Without make, the install is this one line:

```sh
install -m 755 pdfindex2md ~/.local/bin/pdfindex2md
```

Keep the file extensionless: the `#!` line then finds Python and `argv[0]` is
the command name. If you keep it in a clone instead of copying it, a symlink
into your `PATH` works too.

## Usage

```text
usage: pdfindex2md [-h] [-j JOBS] [--limit LIMIT] [--force] [--selftest] [package]
```

| Option | Meaning |
|--------|---------|
| `package` | directory holding the TOC `.htm` and the PDFs; defaults to none, so it is required unless you pass `--selftest` |
| `-j N`, `--jobs N` | conversions run in parallel, default `8` |
| `--limit N` | convert only the first N documents — the cheap way to try it on a big package |
| `--force` | reconvert documents that already have both an `.md` and a `.txt` |
| `--selftest` | check the naming rules and exit 0, no package needed |

A first run on a large package is worth starting with `--limit 5` to confirm
`pdftotext` and the TOC parse cleanly on your system:

```sh
pdfindex2md ~/docs/mainframe/zOS320-Indexed-PDF-package-\(2026-07-31\)/ --limit 5
```

The script picks the first `.htm`/`.html` file in the package as its TOC. If a
package has several, point it at a copy that holds only the one you want.

## How it works

**The TOC is the index.** Adobe's package has no per-document metadata to
read, but its `READ_ME_FIRST…TOC.htm` links every PDF and carries the title and
the order number next to the link. That HTML comes out of Microsoft Word, and
Word nests whole tables inside a single `<td>`, so a naive `<tr>` walk returns
one enormous cell. `parse_toc()` therefore walks `<td>` cells with a recursive
`flatten()` (guarding against cells already seen), and reads the two non-empty
texts before each PDF link as the order number and then the title. A cell whose
text is exactly `Order number` starts a new section, whose name becomes the
category in `INDEX.md`. PDFs the TOC never links are still converted and listed
at the end under *Not in the index*.

**Text comes from `pdftotext -layout`.** Poppler reproduces the printed
line layout, which keeps tables and indentation readable, at roughly a
millisecond per page. Docling and friends produce prettier Markdown, but run
400 documents through an ML layout model and you are waiting hours rather than
a minute; `pdftotext` plus the PDF's own bookmarks gets the structure that
matters for searching and for an LLM's context window.

**Headings come from the PDF bookmarks.** `pypdfium2` exposes the outline as
`(level, title, page)`; the levels are shifted down by two so they nest under
the document's own `#` title. Bookmarks pointing at no page are skipped.

**Running headers, footers and page numbers are dropped.** Any line recurring
in the first or last two lines of a page, in at least `max(3, pages / 3)` pages
(counted per document), is a running head or foot and goes; so does a line that
is nothing but a page number in Arabic or Roman numerals. Only the page edges
are examined, so a sentence that happens to repeat in the body survives. Each
page keeps an `<!-- page N -->` marker, so a quote can be traced to a page.

**Nothing is overwritten by accident.** An existing `.md` and `.txt` pair is
left alone unless `--force` is given, and a document that fails to convert is
reported as `FAILED …` while the rest of the batch continues.

## Naming

`<title-slug>-<document-id>`, for example `cascading-flashcopy-izsc200_v3r2`.

- The title is transliterated to ASCII (NFKD), lowercased, and everything
  outside `[a-z0-9]` becomes a hyphen; runs of hyphens collapse and the ends are
  trimmed. Titles longer than 100 characters are cut.
- The document id is the PDF's own stem, with underscores kept, so
  `izsc200_v3r2.pdf` stays `izsc200_v3r2`.
- The id is dropped when the title already contains it, which is why packages
  whose files are named after their titles (`A-Guide-to-Understaning-AFP-Fonts.pdf`)
  do not get the title twice.
- Titles that are empty, or longer than 120 characters in the TOC, fall back to
  the PDF stem alone — this keeps `[Errno 36] File name too long` out of the run.
- Two documents that slug to the same name get a `-2` suffix.

## Verified on

The z/OS 3.2 Adobe indexed PDF collection (July 2026 edition): 414 documents,
2.0 GB of PDF, converted with `-j 8` in about a minute on a Ryzen 9 desktop —
`md/` 508 MB, `txt/` 514 MB, all 414 with `ok`, none `FAILED`.

Spot checks: headings and page markers are present and in order in the OpenSSH
guide (564 pages, 226 bookmarks), the C++ runtime library reference and the
JES2 documents; Latin text extracts correctly from the Japanese font library
guide, whose CJK glyphs `pdftotext` cannot supply.

## Limitations

- **Scanned PDFs give empty text.** There is no OCR; a page that is an image
  becomes an empty body with its page marker.
- **Tables are layout text, not Markdown tables.** `-layout` preserves the
  columns visually; nothing reconstructs pipe tables.
- **CJK and other non-Latin titles transliterate to nothing,** so those
  documents fall back to their PDF stem for the name. The body text is whatever
  `pdftotext` can extract.
- **`pdftotext` order is the PDF's content-stream order,** which for
  two-column pages can interleave the columns.
- **Title and file name disagreeing duplicates the title.** When the TOC spells
  a title differently from the PDF's own name, both end up in the file name
  (`japanese-font-technical-library-reference-japanese-font-library-technical-reference-s544-5849-01.md`).
- **TOC links to PDFs that are not in the package** are reported and listed in
  the index rather than guessed at; IBM's own TOC has a handful of these
  (`…-LH40-0207-004.pdf` versus the shipped `…-LH40-0207-00.pdf`).

## Troubleshooting

`no TOC .htm in <dir>` — the package directory has no `.htm`/`.html` at its
top level; pass the directory that holds `1.READ_ME_FIRST…TOC.htm`.

`File name too long` — should not happen any more (titles are capped and
over-long TOC titles fall back to the PDF stem), but a package with very long
PDF names can still exceed 255 bytes. Shorten the PDF names or the title cap in
`doc_name()`.

`FAILED …: [Errno 2] No such file or directory: 'pdftotext'` — poppler is not
installed or not in `PATH`.

Markdown with no `##` headings — `pypdfium2` is missing, or that PDF has no
bookmarks.

`AttributeError: 'NoneType' object has no attribute 'loader'` when importing
the script from Python — `importlib.util.spec_from_file_location` cannot load an
extensionless file. Use:

```python
from importlib.machinery import SourceFileLoader
mod = SourceFileLoader("pdfindex2md", "/path/to/pdfindex2md").load_module()
```

## Related

- `pdftotext` alone converts one PDF at a time and gives no structure.
- [Docling](https://github.com/docling-project/docling) and
  [marker](https://github.com/VikParuchuri/marker) produce richer Markdown
  (real tables, figures, OCR) at minutes per document.
- Adobe's own search index (`.pdx`) is fast in a browser and useless to anything
  that reads files.

## License

MIT — see [LICENSE](LICENSE).
