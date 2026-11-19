# Repository test map

Root-level GitHub Actions workflows are the active CI for this merged repository. Nested component workflows remain reference files; GitHub does not execute workflows from subfolders.

## Active checks

- Repository validation runs AI utility tests, ForAI and AI-resource catalog validation, WinDevKit Python tests, and Windows PowerShell suites. Python checks run on Windows and Ubuntu with Python 3.11 and 3.15.
- WinDevKit kits CI runs format, clippy, tests, release builds, and existing per-kit interop/E2E checks for all 36 Rust kits when kit or shared-crate files change. Existing EmbedKit/OCRKit CI fetches are pinned and SHA-256 verified.

## Local checks

From the repository root:

    python -m compileall -q ai_tools
    python -m unittest -v tests.test_ai_tools

    cd forai
    python scripts/validate.py
    python -m unittest discover -s tests -v

    cd ../ai-resources
    python scripts/validate.py

    cd ../windevkit
    python -m py_compile tools/verify.py tools/publish.py tools/scaffold-dll.py tests/test_verify.py
    python -m unittest discover -s tests -v

On Windows 11 x64, run PowerShell suites from the repository root with PowerShell 7. CI installs .NET 10 for compiler-backed fixtures and initializes the x64 Visual C++ environment for the symbol-vault fixture. Most suites accept temporary work/evidence paths; the strict scenario test uses ignored work/.

Checks use synthetic fixtures and mock tools where possible. They do not certify real-device behavior, production deployments, service access, accessibility, or external-resource suitability. Release publishing and the monthly issue-writing link check remain inactive because they publish artifacts or create/update repository issues; enable them only after separate review.
