# llama.cpp Daily Summary Generator

This repository contains a system for automatically fetching and summarizing daily activity from the [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) repository using the GitHub API and OpenAI API.

## Features

- **Daily Automated Execution**: GitHub Actions workflow runs daily at 08:00 UTC
- **Comprehensive Data Collection**: Fetches releases, merged pull requests, and commits from the last 2 days
- **AI-Powered Summarization**: Uses OpenAI API to create organized markdown summaries
- **Automatic Updates**: Results are automatically committed to `docs/summary.md`

## Setup

### 1. Environment Variables

The system requires the following secrets to be configured in your GitHub repository:

- `OPENAI_API_BASE`: The base URL for OpenAI API (e.g., `https://api.openai.com/v1`)
- `OPENAI_API_KEY`: Your OpenAI API key
- `OPENAI_MODEL`: The OpenAI model to use (e.g., `gpt-3.5-turbo` or `gpt-4`)

### 2. Configure GitHub Secrets

1. Go to your repository's Settings → Secrets and variables → Actions
2. Add the three required secrets mentioned above

### 3. Manual Execution

You can also run the summarization manually:

```bash
# Set environment variables
export OPENAI_API_BASE="https://api.openai.com/v1"
export OPENAI_API_KEY="your-api-key"
export OPENAI_MODEL="gpt-3.5-turbo"

# Run the script
./scripts/fetch-and-summarize.sh
```

## How It Works

1. **Data Collection**: The script fetches data from the ggml-org/llama.cpp repository:
   - Releases published in the last 2 days
   - Pull requests merged in the last 2 days
   - Non-merge commits from the last 2 days

2. **Content Processing**: Raw data is formatted into structured markdown

3. **AI Summarization**: OpenAI API processes the content to create a concise, organized summary

4. **Output Generation**: The final summary is saved to `docs/summary.md`

## Files

- `scripts/fetch-and-summarize.sh`: Main script that handles data fetching and summarization
- `.github/workflows/daily-summary.yml`: GitHub Actions workflow for daily execution
- `docs/summary.md`: Generated summary file (auto-updated)
- `scripts/fetch-yesterday.sh`: Original script for fetching yesterday's data
- `scripts/fetch-latest.sh`: Original script for fetching latest release

## Error Handling

The system is designed to handle various failure scenarios gracefully:

- **GitHub API failures**: Continues with available data and notes any issues
- **OpenAI API failures**: Falls back to raw formatted content
- **Network issues**: Generates informative error messages
- **Missing credentials**: Skips AI summarization but still processes raw data

## Output Format

The generated summary includes:

- Generation timestamp and date range
- Recent releases with descriptions
- Recently merged pull requests with author and description
- Recent commits (excluding merge commits)
- AI-generated executive summary (when OpenAI API is available)

## Customization

You can customize the behavior by modifying:

- **Date range**: Change the `TWO_DAYS_AGO_ISO` calculation in the script
- **Content filtering**: Adjust the `jq` filters for different data selection
- **Summarization prompt**: Modify the OpenAI prompt for different summary styles
- **Schedule**: Update the cron expression in the GitHub Actions workflow