# Contributing

1. Create a feature branch.
2. Do not commit customer-specific data or secrets.
3. Edit the engine in `src/common` only, then run `build/Build-Scripts.ps1`.
4. Run PSScriptAnalyzer and `tests/Invoke-Tests.ps1`.
5. Test the changes on at least one lab device.
6. Create a pull request with risk assessment, test cases, and rollback plan.
