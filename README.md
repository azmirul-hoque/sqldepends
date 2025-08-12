# SQL Dependency Analyzer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![CI/CD](https://github.com/your-org/sqldepends/workflows/CI/badge.svg)](https://github.com/your-org/sqldepends/actions)

A comprehensive tool for analyzing SQL dependencies in .NET applications. Automatically discovers database object references, Entity Framework usage patterns, and ADO.NET code across your codebase with detailed reporting and CI/CD integration.

## Features

- **Multi-Language Analysis**: C#, VB.NET, SQL, JavaScript, TypeScript
- **Comprehensive Reporting**: Excel, JSON, SQL, and SARIF output formats  
- **Database Integration**: Live database object validation
- **High Performance**: Parallel processing and smart filtering
- **CI/CD Ready**: GitHub Actions and Azure DevOps integration
- **Quality Gates**: Configurable thresholds and automated checks
- **Container Support**: Docker and Kubernetes deployment options

## Quick Start

### Installation

#### Option 1: PyPI Package (Recommended)
```bash
pip install sqldepends
```

#### Option 2: From Source
```bash
git clone https://github.com/your-org/sqldepends.git
cd sqldepends
pip install -r requirements.txt
```

#### Option 3: PowerShell Script (Windows)
```powershell
# Download and run directly
.\Run-MBoxAnalysisComplete.ps1 -MBoxPath "C:\Your\Project" -GenerateExcel -OpenResults
```

### Basic Usage

#### Command Line Interface
```bash
# Basic analysis
sqldepends --directory ./src --output analysis.json

# With database validation
sqldepends --directory ./src \
  --database-url "mssql://user:pass@server/database" \
  --validate \
  --format excel

# Advanced options
sqldepends --directory ./MyProject \
  --config config.json \
  --parallel \
  --output-dir ./reports \
  --format both
```

#### PowerShell Integration
```powershell
# Comprehensive analysis with Excel output
.\Run-MBoxAnalysisComplete.ps1 `
  -MBoxPath "C:\Projects\MyApp" `
  -GenerateExcel `
  -OpenResults `
  -Verbose
```

## CI/CD Integration

### GitHub Actions

Add to `.github/workflows/sql-analysis.yml`:

```yaml
name: SQL Dependency Analysis
on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    
    - name: Install SQL Dependency Analyzer
      run: pip install sqldepends
    
    - name: Run Analysis
      env:
        SQL_CONNECTION_STRING: ${{ secrets.SQL_CONNECTION_STRING }}
      run: |
        sqldepends --directory . \
          --output analysis.json \
          --database-url "$SQL_CONNECTION_STRING" \
          --validate \
          --format excel
    
    - name: Upload Results
      uses: actions/upload-artifact@v3
      with:
        name: sql-analysis-results
        path: analysis.*
```

### Azure DevOps

Add `azure-pipelines.yml`:

```yaml
trigger: [main]

pool:
  vmImage: 'ubuntu-latest'

variables:
- group: sql-analysis-secrets

steps:
- task: UsePythonVersion@0
  inputs:
    versionSpec: '3.9'

- script: pip install sqldepends
  displayName: 'Install Analyzer'

- script: |
    sqldepends --directory $(Build.SourcesDirectory) \
      --output analysis.json \
      --database-url "$(sql-connection-string)" \
      --validate
  displayName: 'Run Analysis'

- task: PublishBuildArtifacts@1
  inputs:
    pathtoPublish: 'analysis.json'
    artifactName: 'sql-analysis-results'
```

## Documentation

- **[CI/CD Integration Guide](docs/CI-CD-INTEGRATION.md)** - Comprehensive setup instructions
- **[Deployment Guide](docs/DEPLOYMENT-GUIDE.md)** - PyPI, Docker, and enterprise deployment

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup
```bash
# Clone repository
git clone https://github.com/your-org/sqldepends.git
cd sqldepends

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install development dependencies
pip install -e ".[dev]"

# Run tests
pytest
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: [https://sqldepends.readthedocs.io](https://sqldepends.readthedocs.io)
- **Issues**: [GitHub Issues](https://github.com/your-org/sqldepends/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/sqldepends/discussions)

---

**Made with ❤️ for the .NET community**
