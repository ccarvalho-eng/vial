# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.9] - 2026-03-30

### Added
- Dashboard trend indicators showing 7-day comparison for total runs
- Cost per run metric on dashboard
- Latency percentiles (P50, P95) alongside average latency
- Activity chart showing last 30 days of run history with interactive tooltips
- Cost breakdown by provider and by prompt with toggle view
- Latency breakdown by provider
- Provider icons for Gemini, Grok, Perplexity, Google AI Studio, and OpenAI

### Changed
- Dashboard breakdowns are now collapsible/expandable
- Improved stat card tooltip clarity

### Performance
- Optimized dashboard metrics calculation to reduce database queries

## [0.1.8] - 2026-03-29

### Added
- Visual/JSON toggle for assertion editors on suite pages
- Dynamic field switching for json_field assertion type
- Side-by-side layout for run configuration page with template preview

### Fixed
- Phoenix.PubSub supervisor now properly started in application tree

## [0.1.7] - 2026-03-28

### Added
- Visual test case editor with inline editing of variables and assertions
- File attachment support for test cases (PDF, PNG, JPEG, JSON, CSV, TXT)
- Document support for evaluation suites across OpenAI, Anthropic, and Ollama
- JSON field assertion type for validating structured LLM outputs
- Inline editing for suite name and prompt on suite show page
- OpenAI GPT-4o and Anthropic Claude 4.5 providers in seed data

### Changed
- Improved suite index with more prominent edit actions

### Fixed
- Claude 4.x model support for vision/document capabilities

## [0.1.6] - 2026-03-28

### Changed
- Updated library logo

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