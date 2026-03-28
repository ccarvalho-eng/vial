# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.5] - 2026-03-28

### Added
- Provider icons displayed in providers index (OpenAI, Anthropic, Ollama)
- CSS filter to improve Ollama icon visibility in dark mode

### Fixed
- Provider icons now served via `/images/*` route through Assets plug

## [0.1.4] - 2026-03-27

### Fixed
- Convert markdown badges to HTML to fix rendering on Hex.pm

## [0.1.3] - 2026-03-27

### Fixed
- Remove fixed dimensions from screenshot to prevent squeezing on Hex.pm

## [0.1.2] - 2026-03-27

### Fixed
- Fix README image and badge URLs to work on Hex.pm by using absolute GitHub URLs

## [0.1.1] - 2026-03-27

### Fixed
- Include entire `priv/` directory in Hex package to ensure migrations are available for `mix aludel.install`

## [0.1.0] - 2026-03-27

### Added
- Initial release
- LLM evaluation workbench for Phoenix applications
- Support for multiple LLM providers
- Prompt management and versioning
- Test suite creation and execution
- Run results tracking and analysis
- Web dashboard for visualization
- Standalone application option