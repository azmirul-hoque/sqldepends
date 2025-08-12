# CI/CD Integration Guide for SQL Dependency Analyzer

This guide provides comprehensive instructions for integrating the SQL Dependency Analyzer into your CI/CD pipelines.

## Table of Contents

- [GitHub Actions Integration](#github-actions-integration)
- [Azure DevOps Integration](#azure-devops-integration)
- [Secrets Management](#secrets-management)
- [Artifact Storage](#artifact-storage)
- [Quality Gates](#quality-gates)
- [Troubleshooting](#troubleshooting)

---

## GitHub Actions Integration

### Quick Start

1. **Copy the workflow file** to your repository:
   ```bash
   mkdir -p .github/workflows
   cp .github/workflows/sql-dependency-analysis.yml .github/workflows/
   ```

2. **Configure repository secrets** (if using database validation):
   - `SQL_CONNECTION_STRING` - Complete SQL Server connection string, OR
   - `SQL_SERVER` - SQL Server instance name
   - `SQL_DATABASE` - Database name  
   - `SQL_USERNAME` - SQL authentication username
   - `SQL_PASSWORD` - SQL authentication password

3. **Enable workflow permissions**:
   - Go to Settings → Actions → General
   - Set "Workflow permissions" to "Read and write permissions"
   - Check "Allow GitHub Actions to create and approve pull requests"

### Workflow Features

#### Automatic Triggers
- **Push to main/develop branches** - Full analysis
- **Pull requests to main** - Analysis with PR comments
- **Weekly schedule** - Automated dependency audits
- **Manual dispatch** - On-demand analysis with custom parameters

#### Generated Artifacts
- **Excel Reports** - Comprehensive analysis with multiple worksheets
- **JSON Results** - Machine-readable findings for integration
- **SARIF Reports** - Security scanning integration
- **Markdown Summaries** - Human-readable reports

### Configuration Options

#### Manual Workflow Dispatch Parameters

```yaml
workflow_dispatch:
  inputs:
    target_directory:
      description: 'Directory to analyze'
      default: '.'
    include_database_validation:
      description: 'Validate against live database'
      type: boolean
      default: false
    output_format:
      description: 'Output format'
      type: choice
      options: ['both', 'json', 'sql']
      default: 'both'
```

#### Environment Variables

```yaml
env:
  ANALYSIS_VERSION: "2.0.0"
  PYTHON_VERSION: "3.9"
```

### Advanced Configuration

#### Custom Analysis Configuration

Create `.github/sql-analysis-config.json`:

```json
{
  "analysis": {
    "include_extensions": [".cs", ".vb", ".sql", ".json"],
    "exclude_directories": ["bin", "obj", "packages"],
    "parallel_processing": true,
    "max_file_size_mb": 10
  },
  "quality_gates": {
    "max_sql_statements": 50,
    "max_total_findings": 100,
    "fail_on_security_issues": true
  },
  "notifications": {
    "teams_webhook": "${{ secrets.TEAMS_WEBHOOK }}",
    "slack_webhook": "${{ secrets.SLACK_WEBHOOK }}"
  }
}
```

#### Matrix Strategy for Multiple Projects

```yaml
strategy:
  matrix:
    project: ['ProjectA', 'ProjectB', 'ProjectC']
    include:
    - project: 'ProjectA'
      directory: './src/ProjectA'
      database: 'ProjectA_DB'
    - project: 'ProjectB'
      directory: './src/ProjectB'  
      database: 'ProjectB_DB'
```

---

## Azure DevOps Integration

### Quick Start

1. **Copy the pipeline file**:
   ```bash
   cp pipelines/azure-pipelines.yml azure-pipelines.yml
   ```

2. **Create a new pipeline**:
   - Go to Pipelines → New pipeline
   - Select "Azure Repos Git" or "GitHub"
   - Choose "Existing Azure Pipelines YAML file"
   - Select `azure-pipelines.yml`

3. **Configure variable groups**:
   ```bash
   # Create variable group linked to Key Vault
   az pipelines variable-group create \
     --name "sql-analysis-secrets" \
     --variables foo=bar \
     --authorize true
   ```

### Azure Key Vault Integration

#### 1. Create Key Vault and Service Principal

```bash
# Create resource group
az group create --name rg-sql-analysis --location eastus

# Create Key Vault  
az keyvault create --name kv-sql-analysis-prod --resource-group rg-sql-analysis

# Create service principal
az ad sp create-for-rbac --name sp-sql-analysis \
  --role "Key Vault Secrets User" \
  --scopes /subscriptions/{subscription-id}/resourceGroups/rg-sql-analysis/providers/Microsoft.KeyVault/vaults/kv-sql-analysis-prod
```

#### 2. Store SQL Connection Secrets

```bash
# Store connection secrets
az keyvault secret set --vault-name kv-sql-analysis-prod \
  --name "sql-server-connection" --value "your-server.database.windows.net"

az keyvault secret set --vault-name kv-sql-analysis-prod \
  --name "sql-username" --value "sql-user"

az keyvault secret set --vault-name kv-sql-analysis-prod \
  --name "sql-password" --value "your-secure-password"
```

#### 3. Configure Service Connection

1. Go to Project Settings → Service connections
2. Create "Azure Resource Manager" connection
3. Use the service principal credentials from step 1
4. Name it `azure-sql-connection`

### Pipeline Features

#### Parameters

```yaml
parameters:
- name: targetDirectory
  displayName: 'Target Directory to Analyze'
  type: string
  default: '$(Build.SourcesDirectory)'

- name: includeDatabaseValidation
  displayName: 'Validate Against Live Database'
  type: boolean  
  default: false

- name: publishToFeed
  displayName: 'Publish to Artifact Feed'
  type: boolean
  default: true
```

#### Multi-Stage Pipeline

1. **AnalyzeCode** - Run SQL dependency analysis
2. **PublishResults** - Publish to artifact feeds and notify teams  
3. **QualityGate** - Evaluate quality gates and set build status

#### Quality Gates

```yaml
quality_gates:
  high_dependency_threshold: 100
  direct_sql_threshold: 50
  status_levels: ['passed', 'attention', 'warning']
```

### Universal Packages Integration

```yaml
- task: UniversalPackages@0
  inputs:
    command: 'publish'
    publishDirectory: '$(Pipeline.Workspace)/sql-analysis-reports'
    feedsToUsePublish: 'internal'
    vstsFeedPublish: '$(System.TeamProject)/sql-analysis-feed'
    vstsFeedPackagePublish: 'sql-dependency-analysis'
```

---

## Secrets Management

### GitHub Actions Secrets

#### Repository Secrets (Recommended)
```
SQL_CONNECTION_STRING = "Server=myserver;Database=mydb;User Id=myuser;Password=mypass;TrustServerCertificate=true;"
SQL_SERVER = "myserver.database.windows.net"
SQL_DATABASE = "production_db"  
SQL_USERNAME = "sql_service_account"
SQL_PASSWORD = "secure_password_here"
TEAMS_WEBHOOK_URL = "https://outlook.office.com/webhook/..."
SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/..."
```

#### Environment Secrets (For multi-environment)
- `PROD_SQL_CONNECTION_STRING`
- `STAGING_SQL_CONNECTION_STRING` 
- `DEV_SQL_CONNECTION_STRING`

#### Organization Secrets (For shared resources)
- `SHARED_TEAMS_WEBHOOK`
- `SHARED_SONARCLOUD_TOKEN`

### Azure DevOps Secrets

#### Key Vault Secrets
```
sql-server-connection = "prod-sql.database.windows.net"
sql-database = "ProductionDB"
sql-username = "sql-service-user"
sql-password = "ultra-secure-password"
teams-webhook-url = "https://outlook.office.com/webhook/..."
```

#### Variable Groups
1. **sql-analysis-secrets** (linked to Key Vault)
2. **sql-analysis-config** (regular variables)
   - `keyVaultName = "kv-sql-analysis-prod"`
   - `azureServiceConnection = "azure-sql-connection"`
   - `analysisVersion = "2.0.0"`

### Security Best Practices

#### ✅ Do's
- Use Key Vault/GitHub Secrets for sensitive data
- Rotate credentials regularly  
- Use service principals with minimal permissions
- Enable audit logging for secret access
- Use connection strings instead of individual components when possible

#### ❌ Don'ts  
- Never hardcode credentials in YAML files
- Don't use personal accounts for service connections
- Avoid overly broad Key Vault permissions
- Don't log sensitive values in pipeline output

---

## Artifact Storage

### GitHub Actions Artifacts

#### Built-in Artifact Storage
```yaml
- name: Upload Analysis Artifacts
  uses: actions/upload-artifact@v3
  with:
    name: sql-dependency-analysis-${{ env.ANALYSIS_RUN_ID }}
    path: |
      ./analysis-output/
      ./analysis-artifacts/
    retention-days: 30
```

#### GitHub Releases
```yaml
- name: Upload Reports to Release
  if: github.ref == 'refs/heads/main'
  uses: softprops/action-gh-release@v1
  with:
    tag_name: analysis-${{ github.run_number }}
    name: SQL Dependency Analysis - ${{ env.ANALYSIS_TIMESTAMP }}
    files: |
      ./analysis-artifacts/sql-dependency-report.xlsx
      ./analysis-output/sql-dependencies.json
```

### Azure DevOps Artifacts

#### Pipeline Artifacts
```yaml
- task: PublishBuildArtifacts@1
  inputs:
    pathtoPublish: 'analysis-output'
    artifactName: 'sql-analysis-results'
    publishLocation: 'Container'
```

#### Universal Packages Feed
```yaml
- task: UniversalPackages@0
  inputs:
    command: 'publish'  
    publishDirectory: '$(Pipeline.Workspace)/sql-analysis-reports'
    feedsToUsePublish: 'internal'
    vstsFeedPublish: '$(System.TeamProject)/sql-analysis-feed'
```

### External Storage Integration

#### Azure Blob Storage
```yaml
- task: AzureFileCopy@4
  inputs:
    SourcePath: '$(Pipeline.Workspace)/sql-analysis-reports'
    azureSubscription: '$(azureServiceConnection)'
    Destination: 'AzureBlob'
    storage: '$(storageAccountName)'
    ContainerName: 'sql-analysis-reports'
```

#### AWS S3 (via GitHub Actions)
```yaml
- name: Upload to S3
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  run: |
    aws s3 sync ./analysis-artifacts/ s3://my-analysis-bucket/reports/$(date +%Y/%m/%d)/
```

---

## Quality Gates

### Configuration

#### GitHub Actions Quality Gates
```yaml
env:
  MAX_SQL_STATEMENTS: 50
  MAX_TOTAL_FINDINGS: 100
  FAIL_ON_SECURITY: true
```

#### Azure DevOps Quality Gates  
```yaml
variables:
  qualityGate.maxFindings: 100
  qualityGate.maxSqlStatements: 50
  qualityGate.failBuild: false
```

### Implementation

#### Conditional Build Failure
```yaml
# GitHub Actions
- name: Evaluate Quality Gates
  run: |
    TOTAL_FINDINGS=$(jq '.total_findings' ./analysis-artifacts/ci-summary.json)
    if [ "$TOTAL_FINDINGS" -gt "$MAX_TOTAL_FINDINGS" ]; then
      echo "::error::Quality gate failed: Too many findings ($TOTAL_FINDINGS > $MAX_TOTAL_FINDINGS)"
      exit 1
    fi

# Azure DevOps  
- task: PowerShell@2
  inputs:
    script: |
      $findings = (Get-Content summary.json | ConvertFrom-Json).total_findings
      if ($findings -gt $(qualityGate.maxFindings)) {
        Write-Host "##vso[task.logissue type=error]Quality gate failed"
        exit 1
      }
```

#### Branch Protection Rules

**GitHub**: Settings → Branches → Add rule
- Require status checks: `SQL Dependency Analysis / sql-dependency-analysis`
- Require branches to be up to date

**Azure DevOps**: Branch Policies → Build validation
- Add `SQL Dependency Analysis` pipeline
- Set as required

---

## Troubleshooting

### Common Issues

#### 1. Permission Errors

**GitHub Actions**:
```
Error: Resource not accessible by integration
```
**Solution**: Enable "Read and write permissions" in repository settings

**Azure DevOps**:
```  
TF400813: The user does not have permission to access this resource
```
**Solution**: Grant "Build Service" account proper permissions

#### 2. Database Connection Failures

**Error**: `Login failed for user 'username'`

**Solutions**:
- Verify credentials in Key Vault/Secrets
- Check firewall rules allow CI/CD agent IPs
- Ensure SQL authentication is enabled
- Test connection string format

#### 3. Python Package Installation Issues

**Error**: `No module named 'pandas'`

**Solutions**:  
```yaml
# Add explicit package installation
- run: pip install --upgrade pip setuptools wheel
- run: pip install pandas openpyxl sqlalchemy pyodbc
```

#### 4. Artifact Upload Failures

**Error**: `No files were found with the provided path`

**Solutions**:
- Check file paths are correct and relative to workspace
- Ensure analysis actually generated output files
- Verify directory structure in logs

### Debug Mode

#### Enable Debug Logging

**GitHub Actions**:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

**Azure DevOps**:
```yaml
variables:
  system.debug: true
```

#### Analysis Debug Mode
```yaml
# Add debug flags to analysis command
- run: python quick-sql-analyzer.py --log-level DEBUG --verbose --dry-run
```

### Support and Documentation

- **GitHub Repository**: [https://github.com/your-org/sqldepends](https://github.com/your-org/sqldepends)
- **Issue Tracker**: Report bugs and feature requests
- **Wiki**: Additional examples and configurations
- **Discussions**: Community support and best practices

---

*Last updated: $(date)*  
*Version: 2.0.0*