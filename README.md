# iOS Dylib Compiler

Remote compiler that builds real arm64 iOS `.dylib` files using GitHub Actions macOS runners + official Xcode.

## How it works

1. Trigger the workflow via `repository_dispatch` or manual `workflow_dispatch`
2. Runner uses real Xcode + iOS SDK
3. Compiles your Objective-C / C source into an arm64 `.dylib`
4. Uploads the dylib as a workflow artifact (downloadable for 3 days)

## Trigger via API (for the website)

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

## Notes

- Output is a real arm64 iOS dylib (not simulator).
- For injection into games/apps people commonly use tools like LiveContainer or KSign after obtaining the dylib.
- This repo only compiles. Signing / injection / sideloading is left to the user and their preferred tools.
- Free GitHub accounts have limited macOS minutes. Don't spam builds.

## Local test

You can also run the workflow manually from the Actions tab and paste source code.
