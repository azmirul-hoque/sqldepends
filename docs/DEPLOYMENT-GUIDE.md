# SQL Dependency Analyzer - Deployment Guide

This guide covers multiple deployment strategies for the SQL Dependency Analyzer, from simple script usage to enterprise CI/CD integration.

## Table of Contents

- [Quick Start](#quick-start)
- [PyPI Package Deployment](#pypi-package-deployment)
- [Docker Container Deployment](#docker-container-deployment)
- [Enterprise Integration](#enterprise-integration)
- [Configuration Management](#configuration-management)
- [Monitoring and Alerting](#monitoring-and-alerting)

---

## Quick Start

### Local Installation

#### Option 1: Direct Script Usage
```bash
# Clone the repository
git clone https://github.com/your-org/sqldepends.git
cd sqldepends

# Install dependencies
pip install -r requirements.txt

# Run analysis
python sql_analyzer.py --directory "/path/to/your/code" --output "results.sql"
```

#### Option 2: PowerShell Script (Windows)
```powershell
# Download and run the PowerShell analyzer
.\Run-MBoxAnalysisComplete.ps1 -MBoxPath "C:\Your\Project" -GenerateExcel -OpenResults
```

### Minimal CI/CD Integration

#### GitHub Actions (Simple)
```yaml
name: SQL Analysis
on: [push]
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    - run: pip install sqlalchemy pandas openpyxl
    - run: python quick-sql-analyzer.py --directory . --output analysis.json --format json
    - uses: actions/upload-artifact@v3
      with:
        name: sql-analysis
        path: analysis.json
```

#### Azure DevOps (Simple)
```yaml
trigger: [main]
pool:
  vmImage: 'ubuntu-latest'
steps:
- task: UsePythonVersion@0
  inputs:
    versionSpec: '3.9'
- script: |
    pip install sqlalchemy pandas openpyxl
    python quick-sql-analyzer.py --directory $(Build.SourcesDirectory) --output analysis.json
  displayName: 'Run SQL Analysis'
- task: PublishBuildArtifacts@1
  inputs:
    pathtoPublish: 'analysis.json'
    artifactName: 'sql-analysis-results'
```

---

## PyPI Package Deployment

### Package Structure

```
sqldepends/
├── setup.py
├── pyproject.toml
├── README.md
├── LICENSE
├── src/
│   └── sqldepends/
│       ├── __init__.py
│       ├── analyzer.py
│       ├── patterns.py
│       ├── database.py
│       ├── reporting.py
│       └── cli.py
├── tests/
│   ├── test_analyzer.py
│   ├── test_patterns.py
│   └── test_database.py
└── docs/
    ├── README.md
    └── CHANGELOG.md
```

### Setup Configuration

#### pyproject.toml
```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "sqldepends"
version = "2.0.0"
description = "SQL Dependency Analysis Tool for .NET Applications"
authors = [
    {name = "Your Name", email = "your.email@company.com"}
]
readme = "README.md"
license = {text = "MIT"}
requires-python = ">=3.8"
keywords = ["sql", "dependency", "analysis", "dotnet", "entity-framework"]
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.8",
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Topic :: Software Development :: Code Generators",
    "Topic :: Database",
]

dependencies = [
    "sqlalchemy>=1.4.0",
    "pandas>=1.3.0",
    "openpyxl>=3.0.0",
    "pyodbc>=4.0.30",
    "click>=8.0.0",
    "rich>=12.0.0",
    "pydantic>=1.10.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-cov>=3.0.0",
    "black>=22.0.0",
    "flake8>=4.0.0",
    "mypy>=0.950",
]

[project.urls]
Homepage = "https://github.com/your-org/sqldepends"
Repository = "https://github.com/your-org/sqldepends.git"
Documentation = "https://sqldepends.readthedocs.io"
Changelog = "https://github.com/your-org/sqldepends/blob/main/CHANGELOG.md"

[project.scripts]
sqldepends = "sqldepends.cli:main"
sql-analyzer = "sqldepends.cli:main"

[tool.setuptools.packages.find]
where = ["src"]

[tool.setuptools.package-data]
sqldepends = ["templates/*.sql", "config/*.json"]
```

#### setup.py (Alternative)
```python
from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="sqldepends",
    version="2.0.0",
    author="Your Name",
    author_email="your.email@company.com",
    description="SQL Dependency Analysis Tool for .NET Applications",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/your-org/sqldepends",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    python_requires=">=3.8",
    install_requires=[
        "sqlalchemy>=1.4.0",
        "pandas>=1.3.0",
        "openpyxl>=3.0.0",
        "pyodbc>=4.0.30",
        "click>=8.0.0",
        "rich>=12.0.0",
        "pydantic>=1.10.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-cov>=3.0.0",
            "black>=22.0.0",
            "flake8>=4.0.0",
            "mypy>=0.950",
        ],
    },
    entry_points={
        "console_scripts": [
            "sqldepends=sqldepends.cli:main",
            "sql-analyzer=sqldepends.cli:main",
        ],
    },
    include_package_data=True,
    package_data={
        "sqldepends": ["templates/*.sql", "config/*.json"],
    },
)
```

### CLI Interface

#### src/sqldepends/cli.py
```python
import click
import json
from pathlib import Path
from rich.console import Console
from rich.progress import Progress
from .analyzer import SqlDependencyAnalyzer
from .reporting import ReportGenerator

console = Console()

@click.command()
@click.option('--directory', '-d', required=True, 
              help='Directory to analyze for SQL dependencies')
@click.option('--output', '-o', 
              help='Output file path (default: sql_dependencies.json)')
@click.option('--format', '-f', type=click.Choice(['json', 'sql', 'excel']), 
              default='json', help='Output format')
@click.option('--config', '-c', 
              help='Configuration file path')
@click.option('--database-url', 
              help='Database URL for validation (optional)')
@click.option('--validate', is_flag=True, 
              help='Validate found objects against database')
@click.option('--parallel', is_flag=True, default=True,
              help='Use parallel processing')
@click.option('--verbose', '-v', is_flag=True, 
              help='Verbose output')
def main(directory, output, format, config, database_url, validate, parallel, verbose):
    """SQL Dependency Analyzer - Analyze .NET code for SQL dependencies."""
    
    if verbose:
        console.print(f"[green]Starting SQL dependency analysis...[/green]")
        console.print(f"Directory: {directory}")
        console.print(f"Format: {format}")
    
    try:
        # Initialize analyzer
        analyzer = SqlDependencyAnalyzer(
            config_file=config,
            parallel_processing=parallel,
            verbose=verbose
        )
        
        # Run analysis
        with Progress() as progress:
            task = progress.add_task("Analyzing...", total=100)
            results = analyzer.analyze_directory(
                directory, 
                progress_callback=lambda p: progress.update(task, completed=p)
            )
        
        # Generate output
        if not output:
            output = f"sql_dependencies.{format}"
        
        report_gen = ReportGenerator(results)
        
        if format == 'json':
            report_gen.generate_json_report(output)
        elif format == 'sql':
            report_gen.generate_sql_report(output)
        elif format == 'excel':
            report_gen.generate_excel_report(output)
        
        console.print(f"[green]Analysis complete! Results saved to: {output}[/green]")
        console.print(f"Found {results.total_findings} SQL dependencies across {len(results.files)} files")
        
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise click.ClickException(str(e))

if __name__ == '__main__':
    main()
```

### Publishing to PyPI

#### 1. Prepare Package
```bash
# Install build tools
pip install build twine

# Build package
python -m build

# Check distribution
twine check dist/*
```

#### 2. Test on TestPyPI
```bash
# Upload to TestPyPI
twine upload --repository testpypi dist/*

# Test installation
pip install --index-url https://test.pypi.org/simple/ sqldepends
```

#### 3. Publish to PyPI
```bash
# Upload to PyPI
twine upload dist/*

# Verify installation
pip install sqldepends
```

### GitHub Actions for PyPI

#### .github/workflows/publish-pypi.yml
```yaml
name: Publish to PyPI

on:
  release:
    types: [published]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install build twine
    - name: Build package
      run: python -m build
    - name: Publish to PyPI
      uses: pypa/gh-action-pypi-publish@release/v1
      with:
        password: ${{ secrets.PYPI_API_TOKEN }}
```

---

## Docker Container Deployment

### Dockerfile
```dockerfile
FROM python:3.9-slim

LABEL maintainer="your.email@company.com"
LABEL description="SQL Dependency Analyzer"
LABEL version="2.0.0"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Microsoft ODBC Driver for SQL Server
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql17

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY *.py ./
COPY config/ ./config/

# Create output directory
RUN mkdir -p /app/output

# Set environment variables
ENV PYTHONPATH="/app/src:$PYTHONPATH"
ENV PYTHONUNBUFFERED=1

# Create non-root user
RUN useradd --create-home --shell /bin/bash analyzer
RUN chown -R analyzer:analyzer /app
USER analyzer

# Set entrypoint
ENTRYPOINT ["python", "quick-sql-analyzer.py"]
CMD ["--help"]
```

### Docker Compose for Development
```yaml
version: '3.8'

services:
  sql-analyzer:
    build: .
    volumes:
      - ./code-to-analyze:/app/input:ro
      - ./analysis-output:/app/output
    environment:
      - SQL_SERVER=${SQL_SERVER}
      - SQL_DATABASE=${SQL_DATABASE}
      - SQL_USERNAME=${SQL_USERNAME}
      - SQL_PASSWORD=${SQL_PASSWORD}
    command: [
      "--directory", "/app/input",
      "--output", "/app/output/analysis.json",
      "--format", "json",
      "--parallel"
    ]

  sql-server:
    image: mcr.microsoft.com/mssql/server:2019-latest
    environment:
      - ACCEPT_EULA=Y
      - SA_PASSWORD=YourStrong@Passw0rd
      - MSSQL_PID=Developer
    ports:
      - "1433:1433"
    volumes:
      - sql-data:/var/opt/mssql

volumes:
  sql-data:
```

### Container Usage
```bash
# Build container
docker build -t sqldepends:latest .

# Run analysis
docker run --rm \
  -v /path/to/code:/app/input:ro \
  -v /path/to/output:/app/output \
  sqldepends:latest \
  --directory /app/input \
  --output /app/output/analysis.json \
  --format json

# Run with database validation
docker run --rm \
  -v /path/to/code:/app/input:ro \
  -v /path/to/output:/app/output \
  -e SQL_SERVER=host.docker.internal \
  -e SQL_DATABASE=MyDatabase \
  -e SQL_USERNAME=sa \
  -e SQL_PASSWORD=MyPassword \
  sqldepends:latest \
  --directory /app/input \
  --output /app/output/analysis.json \
  --validate \
  --database-url "mssql://sa:MyPassword@host.docker.internal/MyDatabase"
```

---

## Enterprise Integration

### Kubernetes Deployment

#### Deployment Manifest
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sql-dependency-analyzer
  namespace: devtools
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sql-dependency-analyzer
  template:
    metadata:
      labels:
        app: sql-dependency-analyzer
    spec:
      containers:
      - name: analyzer
        image: your-registry/sqldepends:2.0.0
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        env:
        - name: SQL_SERVER
          valueFrom:
            secretKeyRef:
              name: sql-secrets
              key: server
        - name: SQL_USERNAME
          valueFrom:
            secretKeyRef:
              name: sql-secrets
              key: username
        - name: SQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: sql-secrets
              key: password
        volumeMounts:
        - name: analysis-output
          mountPath: /app/output
        - name: config
          mountPath: /app/config
      volumes:
      - name: analysis-output
        persistentVolumeClaim:
          claimName: analysis-pvc
      - name: config
        configMap:
          name: analyzer-config
```

#### CronJob for Scheduled Analysis
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: sql-analysis-job
  namespace: devtools
spec:
  schedule: "0 2 * * 0"  # Weekly on Sunday at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: analyzer
            image: your-registry/sqldepends:2.0.0
            command:
            - /bin/bash
            - -c
            - |
              git clone https://github.com/your-org/your-repo.git /tmp/repo
              python quick-sql-analyzer.py \
                --directory /tmp/repo \
                --output /app/output/analysis-$(date +%Y%m%d).json \
                --format json \
                --parallel
          restartPolicy: OnFailure
```

### Jenkins Pipeline Integration

#### Jenkinsfile
```groovy
pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_DIRECTORY', defaultValue: '.', description: 'Directory to analyze')
        booleanParam(name: 'VALIDATE_DATABASE', defaultValue: false, description: 'Validate against database')
        choice(name: 'OUTPUT_FORMAT', choices: ['json', 'excel', 'sql'], description: 'Output format')
    }
    
    environment {
        SQL_CONNECTION = credentials('sql-connection-string')
        ANALYSIS_VERSION = '2.0.0'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup') {
            steps {
                script {
                    if (isUnix()) {
                        sh '''
                            python3 -m venv venv
                            . venv/bin/activate
                            pip install sqldepends
                        '''
                    } else {
                        bat '''
                            python -m venv venv
                            venv\\Scripts\\activate.bat
                            pip install sqldepends
                        '''
                    }
                }
            }
        }
        
        stage('Analysis') {
            steps {
                script {
                    def analysisCmd = "sqldepends --directory ${params.TARGET_DIRECTORY} --format ${params.OUTPUT_FORMAT}"
                    
                    if (params.VALIDATE_DATABASE) {
                        analysisCmd += " --database-url ${SQL_CONNECTION} --validate"
                    }
                    
                    if (isUnix()) {
                        sh ". venv/bin/activate && ${analysisCmd} --output analysis.${params.OUTPUT_FORMAT}"
                    } else {
                        bat "venv\\Scripts\\activate.bat && ${analysisCmd} --output analysis.${params.OUTPUT_FORMAT}"
                    }
                }
            }
        }
        
        stage('Archive') {
            steps {
                archiveArtifacts artifacts: "analysis.${params.OUTPUT_FORMAT}", fingerprint: true
                
                script {
                    if (params.OUTPUT_FORMAT == 'json') {
                        // Parse and display summary
                        def analysis = readJSON file: 'analysis.json'
                        echo "Analysis Results:"
                        echo "- Total Findings: ${analysis.total_findings}"
                        echo "- Files Analyzed: ${analysis.files.size()}"
                    }
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            emailext (
                subject: "SQL Analysis Complete - Build #${BUILD_NUMBER}",
                body: "SQL dependency analysis completed successfully. Check the build artifacts for results.",
                to: "${env.BUILD_USER_EMAIL}"
            )
        }
        failure {
            emailext (
                subject: "SQL Analysis Failed - Build #${BUILD_NUMBER}",
                body: "SQL dependency analysis failed. Check the build logs for details.",
                to: "${env.BUILD_USER_EMAIL}"
            )
        }
    }
}
```

---

## Configuration Management

### Environment-Specific Configurations

#### Development (dev-config.json)
```json
{
  "analysis": {
    "include_extensions": [".cs", ".vb", ".sql"],
    "exclude_directories": ["bin", "obj", "packages"],
    "parallel_processing": true,
    "max_file_size_mb": 50,
    "timeout_seconds": 300
  },
  "database": {
    "validate_objects": true,
    "connection_timeout": 30,
    "query_timeout": 60,
    "retry_attempts": 3
  },
  "reporting": {
    "generate_excel": true,
    "generate_sarif": false,
    "include_metrics": true,
    "output_directory": "./reports"
  },
  "quality_gates": {
    "max_sql_statements": 100,
    "max_total_findings": 200,
    "fail_on_security": false
  },
  "logging": {
    "level": "DEBUG",
    "file": "analysis-dev.log"
  }
}
```

#### Production (prod-config.json)
```json
{
  "analysis": {
    "include_extensions": [".cs", ".vb", ".sql", ".config", ".json"],
    "exclude_directories": ["bin", "obj", "packages", "node_modules", ".git"],
    "parallel_processing": true,
    "max_file_size_mb": 10,
    "timeout_seconds": 600
  },
  "database": {
    "validate_objects": true,
    "connection_timeout": 15,
    "query_timeout": 30,
    "retry_attempts": 2
  },
  "reporting": {
    "generate_excel": true,
    "generate_sarif": true,
    "include_metrics": true,
    "output_directory": "./reports",
    "archive_reports": true,
    "retention_days": 90
  },
  "quality_gates": {
    "max_sql_statements": 50,
    "max_total_findings": 100,
    "fail_on_security": true
  },
  "logging": {
    "level": "INFO",
    "file": "analysis-prod.log",
    "max_size_mb": 10,
    "backup_count": 5
  },
  "notifications": {
    "teams_webhook": "${TEAMS_WEBHOOK_URL}",
    "slack_webhook": "${SLACK_WEBHOOK_URL}",
    "email_recipients": ["dev-team@company.com"]
  }
}
```

---

## Monitoring and Alerting

### Metrics Collection

#### Prometheus Metrics
```python
from prometheus_client import Counter, Histogram, Gauge, start_http_server

# Define metrics
analysis_runs_total = Counter('sql_analysis_runs_total', 'Total number of analysis runs')
analysis_duration = Histogram('sql_analysis_duration_seconds', 'Time spent on analysis')
sql_findings_gauge = Gauge('sql_findings_current', 'Current number of SQL findings')

# In your analyzer code
@analysis_duration.time()
def run_analysis():
    analysis_runs_total.inc()
    results = analyzer.analyze()
    sql_findings_gauge.set(results.total_findings)
    return results
```

#### Health Check Endpoint
```python
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/health')
def health_check():
    return jsonify({
        'status': 'healthy',
        'version': '2.0.0',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/metrics')
def metrics():
    # Return analysis metrics
    return jsonify({
        'last_analysis': get_last_analysis_time(),
        'total_findings': get_current_findings_count(),
        'files_analyzed': get_files_count()
    })
```

### Alerting Rules

#### Grafana Dashboard
```json
{
  "dashboard": {
    "title": "SQL Dependency Analysis",
    "panels": [
      {
        "title": "Total SQL Findings",
        "type": "singlestat",
        "targets": [
          {
            "expr": "sql_findings_current",
            "legendFormat": "Current Findings"
          }
        ]
      },
      {
        "title": "Analysis Duration",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(sql_analysis_duration_seconds_sum[5m])",
            "legendFormat": "Analysis Rate"
          }
        ]
      }
    ]
  }
}
```

#### Alert Rules
```yaml
# prometheus-alerts.yml
groups:
- name: sql-analysis
  rules:
  - alert: HighSQLFindings
    expr: sql_findings_current > 100
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High number of SQL dependencies detected"
      description: "{{ $value }} SQL findings detected, threshold is 100"

  - alert: AnalysisFailure
    expr: increase(sql_analysis_failures_total[1h]) > 3
    for: 0m
    labels:
      severity: critical
    annotations:
      summary: "Multiple SQL analysis failures"
      description: "Analysis has failed {{ $value }} times in the last hour"
```

### Log Management

#### Structured Logging
```python
import structlog

logger = structlog.get_logger(__name__)

def analyze_file(file_path):
    logger.info(
        "Starting file analysis",
        file=file_path,
        size=os.path.getsize(file_path),
        modified=datetime.fromtimestamp(os.path.getmtime(file_path))
    )
    
    try:
        results = perform_analysis(file_path)
        logger.info(
            "Analysis completed",
            file=file_path,
            findings=len(results),
            duration=results.duration
        )
    except Exception as e:
        logger.error(
            "Analysis failed",
            file=file_path,
            error=str(e),
            exception=e
        )
```

#### Log Aggregation (ELK Stack)
```yaml
# filebeat.yml
filebeat.inputs:
- type: log
  paths:
    - /var/log/sql-analyzer/*.log
  fields:
    service: sql-dependency-analyzer
    environment: production

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  index: "sql-analyzer-logs-%{+yyyy.MM.dd}"

setup.template.name: "sql-analyzer"
setup.template.pattern: "sql-analyzer-*"
```

---

*Last updated: $(date)*  
*Version: 2.0.0*