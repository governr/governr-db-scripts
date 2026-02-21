# Governr DB Scripts

Database seeding and management scripts for the Governr application.

## Project Structure

```
governr-db-scripts/
├── .env                    # Database connection credentials
├── requirements.txt        # Python dependencies
├── data/
│   └── governr-ai-risk/    # Assessment set: Governr AI Risk Framework
│       ├── assessment_framework.csv                        # Seed data for assessment frameworks
│       ├── assessment_template.csv                         # Seed data for assessment templates
│       ├── assessment_template_question.csv                # Seed data for template questions
│       └── assessment_template_question_response_option.csv # Seed data for question response options
├── scripts/
│   ├── run_seed.py         # Run individual SQL seed scripts
│   ├── run_all_seeds.py    # Run all seed scripts in order
│   └── csv-from-excel.py   # Convert Excel files to CSV
└── sql/
    ├── 001_assessment_framework_seed.sql               # Framework seed
    ├── 002_assessment_template_seed.sql                # Template seed
    ├── 003_assessment_template_question_seed.sql       # Question seed
    └── 004_assessment_template_question_response_option_seed.sql  # Response option seed
```

### Adding New Assessment Sets

To add a new assessment set (e.g., `iso-42001`):

1. Create a new subfolder in `data/`:
   ```bash
   mkdir data/iso-42001
   ```

2. Add your CSV files with the same filenames:
   ```
   data/iso-42001/
   ├── assessment_framework.csv
   ├── assessment_template.csv
   ├── assessment_template_question.csv
   └── assessment_template_question_response_option.csv
   ```

3. Run the seed with the `--data-dir` option:
   ```bash
   python scripts/run_all_seeds.py --tenant "org" --username "admin" --data-dir "data/iso-42001"
   ```

## Setup

### Prerequisites

- Python 3.12+
- PostgreSQL client (psql)
- Access to the Governr database

### Installation

1. Create a virtual environment:
   ```bash
   python -m venv .venv
   source .venv/Scripts/activate  # Windows Git Bash
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Configure environment variables in `.env`:
   ```
   DB_HOST=your_host
   DB_PORT=5432
   DB_NAME=your_database
   DB_USER=your_user
   DB_PASSWORD=your_password
   ```

## Usage

### Running All Seeds

Run all seed scripts in the correct order (frameworks → templates → questions → response options):

```bash
# Using default data directory (data/governr-ai-risk)
python scripts/run_all_seeds.py --tenant "defaultorg" --username "admin"

# Using a different assessment set
python scripts/run_all_seeds.py --tenant "defaultorg" --username "admin" --data-dir "data/iso-42001"
```

**Parameters:**
- `--tenant` (required): Tenant name matching `tenant.tn_tenant_name`
- `--username` (required): Username matching `tenant_user.tu_username`
- `--sql-dir` (optional): Directory containing SQL files (default: `sql`)
- `--data-dir` (optional): Directory containing CSV data files (default: `data/governr-ai-risk`)

### Running Individual Seeds

Run a specific seed script:

```bash
# Using default data directory
python scripts/run_seed.py --tenant "defaultorg" --username "admin"

# Using a different assessment set
python scripts/run_seed.py --tenant "defaultorg" --username "admin" --data-dir "data/iso-42001"
```

**Parameters:**
- `--tenant` (required): Tenant name matching `tenant.tn_tenant_name`
- `--username` (required): Username matching `tenant_user.tu_username`
- `--sql-file` (optional): Path to SQL file (default: `sql/001_assessment_framework_seed.sql`)
- `--data-dir` (optional): Directory containing CSV data files (default: `data/governr-ai-risk`)

**Examples:**
```bash
# Run assessment framework seed (default)
python scripts/run_seed.py --tenant "defaultorg" --username "admin"

# Run assessment template seed with a different data set
python scripts/run_seed.py --tenant "defaultorg" --username "admin" --sql-file sql/002_assessment_template_seed.sql --data-dir "data/iso-42001"

# Run assessment template question seed
python scripts/run_seed.py --tenant "defaultorg" --username "admin" --sql-file sql/003_assessment_template_question_seed.sql

# Run response option seed
python scripts/run_seed.py --tenant "defaultorg" --username "admin" --sql-file sql/004_assessment_template_question_response_option_seed.sql
```

### Preparing Data

Convert Excel files to CSV format:

```bash
python scripts/csv-from-excel.py
```

## Seed Order

Seeds must be run in order due to foreign key dependencies:

1. **001_assessment_framework_seed.sql** - Creates assessment frameworks
2. **002_assessment_template_seed.sql** - Creates templates (requires frameworks)
3. **003_assessment_template_question_seed.sql** - Creates questions (requires templates)
4. **004_assessment_template_question_response_option_seed.sql** - Creates response options (requires questions)

## Assessment Data

### Governr Position AI Risk Framework

The seed data includes the **governr Position AI Risk Framework** with 6 specialised assessment templates:

| Template | Code | Description |
|----------|------|-------------|
| System Risk Assessment | `GOVR-SYSTEM-RISK` | AI orchestration, monitoring, and infrastructure risks |
| Model Risk Assessment | `GOVR-MODEL-RISK` | Model security, adversarial attacks, and drift |
| Agent Risk Assessment | `GOVR-AGENT-RISK` | AI agent tool access, memory isolation, and human oversight |
| Dataset Risk Assessment | `GOVR-DATASET-RISK` | Data poisoning, PII detection, and lineage |
| API Risk Assessment | `GOVR-API-RISK` | API security, rate limiting, and authentication |
| MCP Server Risk Assessment | `GOVR-MCP-RISK` | MCP server validation, tool chaining, and isolation |

Each template contains 10 questions with 5 maturity-based response options (scored 0-100).

## CSV Data Formats

### assessment_framework.csv

| Column | Description | Example |
|--------|-------------|---------|
| `af_name` | Framework name | `governr Position AI Risk Framework` |
| `af_version` | Version number | `1.0` |
| `af_framework_type` | Type: REGULATORY, INTERNAL, INDUSTRY, ACADEMIC, HYBRID, CUSTOM | `INTERNAL` |
| `af_framework_status` | Status: ACTIVE, DEPRECATED, DRAFT, UNDER_REVIEW, RETIRED | `ACTIVE` |
| `af_is_primary` | Primary flag: Y or N | `N` |

### assessment_template.csv

| Column | Description | Example |
|--------|-------------|---------|
| `af_name` | Parent framework name | `governr Position AI Risk Framework` |
| `atmp_name` | Template name | `governr Position System Risk Assessment` |
| `atmp_code` | Unique template code | `GOVR-SYSTEM-RISK` |
| `atmp_version` | Version number | `1` |
| `atmp_status` | Status: ACTIVE, DEPRECATED, DRAFT, UNDER_REVIEW, RETIRED | `DRAFT` |
| `atmp_is_active` | Active flag: Y or N | `Y` |

### assessment_template_question.csv

| Column | Description | Example |
|--------|-------------|---------|
| `af_name` | Parent framework name | `governr Position AI Risk Framework` |
| `atmp_code` | Parent template code | `GOVR-SYSTEM-RISK` |
| `atq_code` | Unique question code | `SYS-Q01` |
| `atq_text` | Question text | `Do you detect and block malicious signals...?` |
| `atq_response_type` | Response type: SINGLE_CHOICE, MULTIPLE_CHOICE, TEXT, NUMBER | `SINGLE_CHOICE` |
| `atq_question_type` | Question type: MULTIPLE_CHOICE_SINGLE, MULTIPLE_CHOICE_MULTI, FREE_TEXT | `MULTIPLE_CHOICE_SINGLE` |
| `atq_is_mandatory` | Mandatory flag: Y or N | `Y` |
| `atq_is_active` | Active flag: Y or N | `Y` |
| `atq_sequence` | Display order | `1` |

### assessment_template_question_response_option.csv

| Column | Description | Example |
|--------|-------------|---------|
| `atq_code` | Parent question code | `SYS-Q01` |
| `atqro_code` | Unique response option code | `SYS-Q01-R01` |
| `atqro_label` | Response option text | `Malicious signals trigger erroneous workflows...` |
| `atqro_sequence` | Display order | `1` |
| `atqro_is_default` | Default selection: Y or N | `Y` |
| `atqro_is_active` | Active flag: Y or N | `Y` |
| `atqro_score_risk` | Risk score (0-100, higher = better maturity) | `0` |

## Dependencies

- `psycopg2-binary` - PostgreSQL database adapter
- `python-dotenv` - Environment variable loader
- `pandas` - Data manipulation (for Excel conversion)
- `openpyxl` - Excel file reading

## Error Handling

The seed scripts handle common errors:

- **Tenant not found**: Verify `tenant.tn_tenant_name` matches the `--tenant` value
- **User not found**: Verify `tenant_user.tu_username` matches the `--username` value for the specified tenant
- **Duplicate entries**: Automatically skipped (based on unique codes)
- **Missing dependencies**: Clear error messages indicate which parent records are missing (e.g., run framework seed before template seed)