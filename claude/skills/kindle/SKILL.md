---
name: kindle
description: Extract text from Kindle books for use as context in Claude projects
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Glob, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer, mcp__claude-in-chrome__javascript_tool, mcp__claude-in-chrome__find, mcp__claude-in-chrome__get_page_text, mcp__claude-in-chrome__shortcuts_execute, mcp__claude-in-chrome__gif_creator
argument-hint: [file-path or "browser" or "playwright"]
---

# Kindle Book Text Extraction

Extract full text from Kindle books using one of three methods.

## Determine Method

Parse the argument provided after `/kindle`:

- **File path** (ends in `.azw3`, `.mobi`, `.epub`, `.azw`, `.kfx`): Use **Method 1 (Calibre)**
- **`browser`**: Use **Method 2 (Chrome Browser Automation via MCP)**
- **`playwright`**: Use **Method 3 (Playwright + Claude Vision API)**
- **No argument**: Ask the user which method they want:
  1. **File conversion** - provide a path to a DRM-free ebook file
  2. **Browser reading (MCP)** - read via Chrome extension (slower, no API key needed)
  3. **Playwright extraction (recommended)** - autonomous browser automation, fastest, free local OCR

---

## Method 1: Calibre File Conversion (preferred)

Use this when the user provides an ebook file path.

### Steps

1. Verify the file exists at the given path
2. Run the extract script:
   ```bash
   bash ~/8do/kindle_reader_skil/extract.sh "INPUT_FILE_PATH"
   ```
3. The script outputs a `.txt` file in the same directory as the input
4. Read the output file to verify it has content
5. Report to user:
   - Output file path
   - Word count (`wc -w`)
   - First few lines as a preview

### Troubleshooting
- If `ebook-convert` fails with DRM errors, tell the user they need to remove DRM first (Calibre + DeDRM plugin)
- If the file format isn't supported, list supported formats: azw3, mobi, epub, azw, kfx

---

## Method 2: Chrome Browser Automation (fallback)

Use this to read from Kindle Cloud Reader page by page via screenshots.

### Steps

1. Call `mcp__claude-in-chrome__tabs_context_mcp` to check current tabs
2. Look for a tab with Kindle Cloud Reader (`read.amazon.com`)
   - If found, use that tab
   - If not found, create a new tab and navigate to `https://read.amazon.com`
3. Wait for the page to load. If the user needs to sign in, tell them and wait.
4. Once a book is open, begin the extraction loop:

#### Extraction Loop

```
page_number = 1
accumulated_text = ""

repeat:
   a. Use mcp__claude-in-chrome__computer to take a screenshot of the current page
   b. Read the visible text from the screenshot using your vision capabilities
   c. Append the extracted text to accumulated_text with a page separator
   d. Click the right side of the reader area OR press the right arrow key to advance
   e. Wait briefly for the page to render (use mcp__claude-in-chrome__javascript_tool to sleep 1s)
   f. Take another screenshot - compare with previous to detect if page changed
   g. If page didn't change (end of book or chapter), stop the loop
   h. Increment page_number
   i. Every 10 pages, report progress to the user
   j. If page_number > 500, pause and ask user if they want to continue
```

5. Save accumulated text to a file:
   - Default filename: `kindle_extract_YYYY-MM-DD_HHMMSS.txt` in the current working directory
6. Report final results:
   - Output file path
   - Number of pages extracted
   - Word count
   - First few lines as preview

### Navigation Tips
- The Kindle Cloud Reader page turn area is the right ~30% of the reading area
- Right arrow key also advances pages
- If stuck on library view, tell user to open a book first
- Some books render text as images - vision reading is required for these

### Stopping
- The user can say "stop" at any time to end extraction with what's been collected so far
- Auto-stop when the same page appears twice in a row (end of book/chapter)

---

## Output Format

The extracted text file should contain:
```
# [Book title if detectable]
# Extracted via /kindle on YYYY-MM-DD

[page text]

--- Page 2 ---

[page text]

...
```

For Calibre conversions, use the raw output from ebook-convert (it handles formatting well).

---

## Method 3: Playwright + Local OCR (recommended)

Autonomous extraction using a standalone Playwright script. Fastest method — runs independently in the terminal. Uses macOS Vision Framework for free, fast, local OCR by default.

### Prerequisites
- Python venv with `playwright`, `ocrmac`, and `Pillow` packages
- macOS (for built-in Apple Vision OCR)
- Chromium installed via `playwright install chromium`
- `ANTHROPIC_API_KEY` environment variable *(only if using `--api` flag)*

### Steps

1. Run the extraction script:
   ```bash
   cd ~/8do/kindle_reader_skil
   source .venv/bin/activate
   python extract_browser.py [-o output.txt] [--api] [-m model-id]
   ```
2. A Chromium browser opens. The user logs into Amazon and opens the book.
3. User presses Enter in the terminal to start extraction.
4. The script runs autonomously: screenshot → ArrowRight → local OCR → repeat (~1s/page).
5. Auto-stops at end of book (duplicate screenshot detection).
6. Ctrl+C saves progress at any time; auto-saves every 50 pages.

### Options
- `-o FILE` — set output file path (default: `kindle_extract_YYYY-MM-DD_HHMMSS.txt`)
- `--api` — use Claude Vision API instead of local OCR (requires `ANTHROPIC_API_KEY`)
- `-m MODEL` — set Claude model, only with `--api` (default: `claude-haiku-4-5-20251001`)
- `--headless` — run without visible browser (only after first login, cookies are persisted)
