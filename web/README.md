# Web Frontend

Simple single-page UI for the dylib compiler.

## How to use

1. Open `index.html` locally or host it (GitHub Pages, Vercel, Netlify, etc.)
2. Create a fine-grained GitHub PAT with access only to the `compiler` repo:
   - Contents: Read
   - Actions: Read and Write
   - Metadata: Read
3. Paste the PAT into the page
4. Paste your Objective-C source
5. Click **Compile dylib**

The page will:
- Trigger the GitHub Actions workflow
- Poll until the build finishes
- Give you a download link for the `.dylib`

## Security note

This is intended for **personal use**. Do not deploy this page publicly with a real token. For a public service you need a backend that holds the PAT.
