# iOS Dylib Compiler

Real arm64 iOS `.dylib` compiler powered by GitHub Actions macOS runners + official Xcode.

**Live frontend:** https://ios-dylib-compiler-alzscriptzs-projects.vercel.app

## What it does

- Accepts Objective-C / C source
- Builds a real **arm64 iOS** dynamic library (not simulator)
- Gives you a downloadable `.dylib`
- Designed for use with tools like LiveContainer / KSign for injection

## Repo structure

| Path | Description |
|------|-------------|
| `.github/workflows/build-dylib.yml` | The actual compiler workflow |
| `examples/hello.m` | Simple example source |
| `web/` | Frontend UI (deployed on Vercel) |

## How to use the website

1. Open the live site: https://ios-dylib-compiler-alzscriptzs-projects.vercel.app
2. Create a **fine-grained GitHub PAT** with access only to this repo:
   - **Contents**: Read and Write
   - **Actions**: Read and Write
   - **Metadata**: Read
3. Paste the PAT into the page
4. Paste your source code
5. Click **Compile dylib**
6. Wait ~1-3 minutes, then download the zip

## Manual trigger (curl)

```bash
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer YOUR_PAT" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/alzscriptz/compiler/dispatches \
  -d '{
    "event_type": "build-dylib",
    "client_payload": {
      "source": "#import <Foundation/Foundation.h>\n\n__attribute__((constructor))\nstatic void init(void) {\n    NSLog(@\"Hello from dylib!\");\n}\n",
      "filename": "libmytweak"
    }
  }'
```

Then go to the Actions tab and download the artifact.

## Notes

- This only **compiles** the dylib. Injection / signing / packaging is handled by your preferred tools (LiveContainer, KSign, etc.).
- GitHub Actions artifacts are cleaned before each build so the compiler keeps working within the available artifact storage quota.
- The frontend stores the PAT only in your browser (never sent to any third-party server except GitHub).

## Security

The current frontend is intended for **personal use**.  
If you ever want a public version, we should move the PAT into a Vercel serverless function.
