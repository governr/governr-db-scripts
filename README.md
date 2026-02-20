# Governr DB Scripts

Database seeding and management scripts for the Governr application.

## Project Structure

```
governr-db-scripts/
├── .env                    # Database connection credentials
├── requirements.txt        # Python dependencies
├── data/
│   └── assessment_framework.csv   # Seed data for assessment frameworks
├── scripts/
│   ├── run_seed.py         # Main script runner
│   └── csv-from-excel.py   # Convert Excel files to CSV
└── sql/
    └── 001_assessment_framework_seed.sql   # SQL reference file
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

### Running the Assessment Framework Seed

Insert assessment framework data from CSV into the database:

```bash
python scripts/run_seed.py --tenant "defaultorg" --username "admin"
```

**Parameters:**
- `--tenant` (required): Tenant name matching `tenant.tn_tenant_name`
- `--username` (required): Username matching `tenant_user.tu_username`
- `--csv-file` (optional): Path to CSV file (default: `data/assessment_framework.csv`)

**Features:**
- Loads database connection from `.env` file
- Validates tenant and user exist before inserting
- Skips frameworks that already exist (by name + version)
- Provides clear error messages with helpful tips

### Preparing Data

Convert Excel files to CSV format:

```bash
python scripts/csv-from-excel.py
```

## CSV Data Format

The `assessment_framework.csv` file should contain the following columns:

| Column | Description | Example |
|--------|-------------|---------|
| `af_name` | Framework name | `governr Position AI Risk Framework` |
| `af_version` | Version number | `1.0` |
| `af_framework_type` | Type: REGULATORY, INTERNAL, INDUSTRY, ACADEMIC, HYBRID, CUSTOM | `INTERNAL` |
| `af_framework_status` | Status: ACTIVE, DEPRECATED, DRAFT, UNDER_REVIEW, RETIRED | `ACTIVE` |
| `af_is_primary` | Primary flag: Y or N | `N` |

## Dependencies

- `psycopg2-binary` - PostgreSQL database adapter
- `python-dotenv` - Environment variable loader
- `pandas` - Data manipulation (for Excel conversion)
- `openpyxl` - Excel file reading

## Error Handling

The seed script handles common errors:

- **Tenant not found**: Verify `tenant.tn_tenant_name` matches the `--tenant` value
- **User not found**: Verify `tenant_user.tu_username` matches the `--username` value for the specified tenant
- **Duplicate frameworks**: Automatically skipped (based on name + version)