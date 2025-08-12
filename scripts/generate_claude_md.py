#!/usr/bin/env python3
"""
CLAUDE.md Generator Script
Automatically generates updated CLAUDE.md documentation based on current codebase state.
"""

import os
import sys
import json
import argparse
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime

class ClaudeMDGenerator:
    """Generates CLAUDE.md documentation from codebase analysis."""
    
    def __init__(self, input_dir: str = ".", include_git_info: bool = False):
        self.input_dir = Path(input_dir)
        self.include_git_info = include_git_info
        self.git_info = self._get_git_info() if include_git_info else {}
        
    def _get_git_info(self) -> Dict[str, str]:
        """Extract git repository information."""
        git_info = {}
        
        try:
            # Get current commit hash
            result = subprocess.run(['git', 'rev-parse', 'HEAD'], 
                                  capture_output=True, text=True, cwd=self.input_dir)
            if result.returncode == 0:
                git_info['commit_hash'] = result.stdout.strip()[:8]
                
            # Get current branch
            result = subprocess.run(['git', 'rev-parse', '--abbrev-ref', 'HEAD'], 
                                  capture_output=True, text=True, cwd=self.input_dir)
            if result.returncode == 0:
                git_info['branch'] = result.stdout.strip()
                
            # Get last commit message
            result = subprocess.run(['git', 'log', '-1', '--pretty=format:%s'], 
                                  capture_output=True, text=True, cwd=self.input_dir)
            if result.returncode == 0:
                git_info['last_commit'] = result.stdout.strip()
                
        except Exception as e:
            print(f"Warning: Could not extract git info: {e}", file=sys.stderr)
            
        return git_info
    
    def analyze_python_file(self) -> Dict[str, Any]:
        """Analyze the main Python analyzer file."""
        python_file = self.input_dir / "sql_analyzer.py"
        if not python_file.exists():
            return {}
            
        try:
            with open(python_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
            analysis = {
                'imports': self._extract_imports(content),
                'classes': self._extract_classes(content),
                'functions': self._extract_functions(content),
                'cli_args': self._extract_cli_arguments(content),
                'dependencies': self._extract_dependencies(content)
            }
            
            return analysis
            
        except Exception as e:
            print(f"Error analyzing Python file: {e}", file=sys.stderr)
            return {}
    
    def analyze_powershell_file(self) -> Dict[str, Any]:
        """Analyze the PowerShell analyzer file."""
        ps_file = self.input_dir / "Analyze-SqlCode.ps1"
        if not ps_file.exists():
            return {}
            
        try:
            with open(ps_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
            analysis = {
                'parameters': self._extract_ps_parameters(content),
                'functions': self._extract_ps_functions(content),
                'cmdlet_features': self._extract_ps_features(content)
            }
            
            return analysis
            
        except Exception as e:
            print(f"Error analyzing PowerShell file: {e}", file=sys.stderr)
            return {}
    
    def analyze_config_file(self) -> Dict[str, Any]:
        """Analyze the configuration file."""
        config_file = self.input_dir / "config.json"
        if not config_file.exists():
            return {}
            
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                config_data = json.load(f)
                
            return {
                'sections': list(config_data.keys()),
                'analysis_settings': config_data.get('AnalysisSettings', {}),
                'output_settings': config_data.get('OutputSettings', {}),
                'sql_analysis': config_data.get('SqlAnalysis', {}),
                'logging': config_data.get('Logging', {})
            }
            
        except Exception as e:
            print(f"Error analyzing config file: {e}", file=sys.stderr)
            return {}
    
    def analyze_requirements(self) -> List[str]:
        """Analyze Python requirements."""
        req_file = self.input_dir / "requirements.txt"
        if not req_file.exists():
            return []
            
        try:
            with open(req_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
            return [line.strip() for line in lines if line.strip() and not line.startswith('#')]
            
        except Exception as e:
            print(f"Error analyzing requirements: {e}", file=sys.stderr)
            return []
    
    def analyze_sql_files(self) -> Dict[str, Any]:
        """Analyze SQL schema and view files."""
        sql_dir = self.input_dir / "sql"
        sql_files = {}
        
        if sql_dir.exists():
            for sql_file in sql_dir.glob("*.sql"):
                try:
                    with open(sql_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                        
                    sql_files[sql_file.name] = {
                        'tables': re.findall(r'CREATE TABLE\s+(\S+)', content, re.IGNORECASE),
                        'views': re.findall(r'CREATE VIEW\s+(\S+)', content, re.IGNORECASE),
                        'procedures': re.findall(r'CREATE PROCEDURE\s+(\S+)', content, re.IGNORECASE),
                        'size_lines': len(content.split('\n'))
                    }
                    
                except Exception as e:
                    print(f"Error analyzing {sql_file}: {e}", file=sys.stderr)
                    
        return sql_files
    
    def _extract_imports(self, content: str) -> List[str]:
        """Extract Python imports."""
        imports = re.findall(r'^(?:from\s+(\S+)\s+)?import\s+(.+)', content, re.MULTILINE)
        return [f"{imp[0]}.{imp[1]}" if imp[0] else imp[1] for imp in imports]
    
    def _extract_classes(self, content: str) -> List[str]:
        """Extract Python class definitions."""
        return re.findall(r'^class\s+(\w+)', content, re.MULTILINE)
    
    def _extract_functions(self, content: str) -> List[str]:
        """Extract Python function definitions."""
        return re.findall(r'^def\s+(\w+)', content, re.MULTILINE)
    
    def _extract_cli_arguments(self, content: str) -> List[str]:
        """Extract command line arguments."""
        args = re.findall(r'add_argument\([\'"]([^\'\"]+)[\'"]', content)
        return [arg for arg in args if arg.startswith('-')]
    
    def _extract_dependencies(self, content: str) -> List[str]:
        """Extract key dependencies."""
        deps = []
        if 'pyodbc' in content:
            deps.append('pyodbc')
        if 'argparse' in content:
            deps.append('argparse')
        if 'threading' in content:
            deps.append('threading')
        return deps
    
    def _extract_ps_parameters(self, content: str) -> List[str]:
        """Extract PowerShell parameters."""
        params = re.findall(r'\[Parameter[^\]]*\]\s*(?:\[[\w\[\]]+\]\s*)?\$(\w+)', content, re.IGNORECASE)
        return params
    
    def _extract_ps_functions(self, content: str) -> List[str]:
        """Extract PowerShell functions."""
        return re.findall(r'^function\s+(\w+)', content, re.MULTILINE | re.IGNORECASE)
    
    def _extract_ps_features(self, content: str) -> List[str]:
        """Extract PowerShell advanced features."""
        features = []
        if '[CmdletBinding()]' in content:
            features.append('CmdletBinding')
        if 'ValidateSet' in content:
            features.append('Parameter Validation')
        if 'Begin {' in content:
            features.append('Advanced Function Structure')
        return features
    
    def generate_claude_md(self, changes_summary: Optional[str] = None, 
                          build_id: Optional[str] = None, 
                          build_url: Optional[str] = None) -> str:
        """Generate the complete CLAUDE.md content."""
        
        # Analyze all components
        python_analysis = self.analyze_python_file()
        ps_analysis = self.analyze_powershell_file()
        config_analysis = self.analyze_config_file()
        requirements = self.analyze_requirements()
        sql_analysis = self.analyze_sql_files()
        
        # Generate timestamp info
        timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
        
        # Build header with generation info
        header = f"""# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

<!-- Auto-generated on {timestamp} -->"""
        
        if self.include_git_info and self.git_info:
            header += f"""
<!-- Git Info: {self.git_info.get('branch', 'unknown')} @ {self.git_info.get('commit_hash', 'unknown')} -->"""
            
        if build_id:
            header += f"""
<!-- Build: {build_id} -->"""
            
        if build_url:
            header += f"""
<!-- Build URL: {build_url} -->"""
        
        # Generate main content sections
        content = f"""{header}

## Project Overview

This is a SQL Server Code Analysis Tool that analyzes source code files to identify SQL Server database object references, ADO.NET usage patterns, and Entity Framework mappings. The tool stores analysis results in SQL Server with historical tracking capabilities.

## Development Commands

### Python Environment Setup
```bash
# Install dependencies
pip install -r requirements.txt

# Run the main analyzer
python sql_analyzer.py --directory "C:\\MyProject" --output "analysis_results.sql"

# Run with database integration
python sql_analyzer.py --directory "C:\\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth

# Run with configuration file
python sql_analyzer.py --config config.json --directory "C:\\MyProject"
```

### PowerShell Commands
```powershell
# Basic analysis
.\\Analyze-SqlCode.ps1 -Directory "C:\\MyProject" -OutputPath "analysis_results.sql"

# With database integration
.\\Analyze-SqlCode.ps1 -Directory "C:\\MyProject" -Server "localhost" -Database "CodeAnalysis" -UseWindowsAuth

# Generate report with verbose output
.\\Analyze-SqlCode.ps1 -Directory "C:\\MyProject" -OutputPath "analysis.sql" -GenerateReport -Verbose
```

### Database Schema Setup
```bash
# Create database schema automatically
python sql_analyzer.py --directory "C:\\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth --create-schema --schema-file "sql\\database_schema.sql" --views-file "sql\\analysis_views.sql"

# Or execute manually in SSMS:
# 1. Execute sql/database_schema.sql
# 2. Execute sql/analysis_views.sql
```"""

        # Add CLI arguments section if available
        if python_analysis.get('cli_args'):
            content += f"""

### Available Command Line Arguments
```bash
# Python analyzer supports:
{chr(10).join(f"# {arg}" for arg in python_analysis['cli_args'])}
```"""

        # Add PowerShell parameters if available
        if ps_analysis.get('parameters'):
            content += f"""

### PowerShell Parameters
```powershell
# Available parameters:
{chr(10).join(f"# -{param}" for param in ps_analysis['parameters'])}
```"""

        # Architecture section
        content += f"""

## Architecture Overview

### Core Components

1. **sql_analyzer.py**: Main Python implementation with database connectivity via pyodbc
2. **Analyze-SqlCode.ps1**: PowerShell equivalent with SqlServer module integration
3. **config.json**: Configuration file for analysis settings, patterns, and database options"""

        # Add SQL files info
        if sql_analysis:
            for sql_file, info in sql_analysis.items():
                content += f"""
4. **sql/{sql_file}**: {info.get('size_lines', 0)} lines"""
                if info.get('tables'):
                    content += f" - {len(info['tables'])} tables"
                if info.get('views'):
                    content += f" - {len(info['views'])} views"

        # Add classes and functions info
        if python_analysis.get('classes'):
            content += f"""

### Key Classes and Functions

**Python Classes:**
{chr(10).join(f"- **{cls}**: Core analysis component" for cls in python_analysis['classes'])}"""

        if python_analysis.get('functions'):
            main_functions = [f for f in python_analysis['functions'] if not f.startswith('_')][:5]
            if main_functions:
                content += f"""

**Main Functions:**
{chr(10).join(f"- `{func}()`: Primary processing function" for func in main_functions)}"""

        # Database integration section
        content += """

### Database Integration

The tool supports both file export and direct database storage:
- **Live Database Mode**: Direct SQL Server connection with auto-schema creation
- **File Export Mode**: Generates SQL scripts for manual deployment
- **Hybrid Mode**: Both database storage and file export simultaneously

### Analysis Patterns

The tool detects:
- **ADO.NET patterns**: SqlCommand, SqlDataAdapter, SqlConnection, SqlParameter
- **Entity Framework**: DbContext, DbSet, FromSqlRaw, ExecuteSqlRaw
- **Dynamic SQL**: String concatenation, StringBuilder patterns
- **Configuration**: Connection strings in app.config, web.config, appsettings.json
- **Multi-language**: C#, VB.NET, JavaScript, TypeScript, Python, SQL files"""

        # Configuration section
        if config_analysis:
            content += f"""

## Critical Configuration

### Analysis Settings
```json
{{"""
            for section in config_analysis.get('sections', []):
                content += f"""
  "{section}": {{ /* Configuration options */ }}"""
            content += """
}
```"""

        # Add WSL configuration
        content += """

### WSL SQL Server Connection
When running from WSL, use the WSL host IP instead of localhost:
```bash
# Use WSL host IP for SQL Server connections
python sql_analyzer.py --server "172.31.208.1,14333" --database "CodeAnalysis" --username "sv" --password "YourPassword"
```

### Database Connection Examples
```json
{
  "connectionString": "Server=172.31.208.1,14333;Database=CodeAnalysis;User Id=sv;Password=YourPassword;TrustServerCertificate=true;"
}
```"""

        # File structure section
        content += """

## File Structure

```
sqldepends/
├── sql_analyzer.py           # Main Python analyzer
├── Analyze-SqlCode.ps1       # PowerShell implementation
├── config.json               # Configuration settings
├── requirements.txt          # Python dependencies
├── sql/
│   ├── database_schema.sql   # Database table definitions
│   └── analysis_views.sql    # Analysis views and queries
├── examples/
│   ├── sample_queries.sql    # Example analysis queries
│   └── usage_examples.md     # Command-line examples
└── docs/
    ├── README.md             # Main documentation
    ├── REQUIREMENTS.md       # Detailed requirements
    ├── PROJECT_STATUS.md     # Implementation status
    └── TODO.md               # Development roadmap
```"""

        # Common scenarios section
        content += """

## Common Analysis Scenarios

### Basic Code Analysis
```bash
# Analyze .NET application
python sql_analyzer.py --directory "C:\\MyWebApp" --include-extensions ".cs,.cshtml,.js" --exclude-dirs "bin,obj,wwwroot\\lib"

# Analyze legacy VB.NET
python sql_analyzer.py --directory "C:\\Legacy\\VBApp" --include-extensions ".vb,.aspx,.ascx" --output "legacy_analysis.json" --format "json"
```

### Database Integration Analysis
```bash
# With object validation against live database
python sql_analyzer.py --directory "C:\\Enterprise\\Solutions" --server "prod-sql" --database "Enterprise" --validate-objects --parallel-processing
```

### Historical Analysis
```sql
-- View latest analysis results
SELECT * FROM CodeAnalysis.vw_LatestCodeAnalysis

-- See SQL object usage summary  
SELECT * FROM CodeAnalysis.vw_SqlObjectUsage

-- Check for changes between runs
SELECT * FROM CodeAnalysis.vw_CodeAnalysisChanges
```"""

        # Dependencies section
        if requirements:
            content += f"""

## Dependencies

### Python Requirements
```
{chr(10).join(requirements)}
```"""

        # Testing and troubleshooting
        content += """

## Development Guidelines

### Adding New Patterns
1. Update regex patterns in the `SqlPatternAnalyzer` class
2. Add corresponding test cases
3. Update configuration options in `config.json`
4. Document new patterns in the requirements

### Database Schema Changes
1. Update `sql/database_schema.sql` with new table structures
2. Update `sql/analysis_views.sql` with new view definitions
3. Test schema changes against existing data
4. Update migration procedures if needed

### Performance Considerations
- Use `--parallel-processing` for large codebases
- Configure `MaxDegreeOfParallelism` in config.json
- Exclude unnecessary directories (bin, obj, node_modules)
- Use incremental analysis for repeated runs on same codebase

## Testing

### Manual Testing
```bash
# Test with sample project
python sql_analyzer.py --directory "./examples" --output "test_results.sql" --dry-run

# Validate database connectivity
python sql_analyzer.py --server "localhost" --database "TestDB" --windows-auth --validate-connection
```

### Performance Testing
```bash
# Benchmark large codebase
python sql_analyzer.py --directory "C:\\LargeProject" --parallel-processing --generate-statistics --log-level DEBUG
```

## Troubleshooting

### Common Issues
1. **Connection failures**: Verify SQL Server instance, authentication, and firewall settings
2. **Permission errors**: Ensure database create/write permissions
3. **Large file processing**: Increase memory allocation or use streaming mode
4. **Encoding issues**: Specify file encoding explicitly for non-UTF8 files

### Debug Mode
```bash
# Enable verbose logging
python sql_analyzer.py --directory "C:\\MyProject" --log-level DEBUG --log-file "analysis.log"
```"""

        # Add generation footer
        if changes_summary:
            content += f"""

---
**Documentation automatically updated based on:**
```
{changes_summary}
```"""

        content += f"""

*Generated: {timestamp}*"""
        if self.git_info.get('commit_hash'):
            content += f" | *Commit: {self.git_info['commit_hash']}*"
        if build_id:
            content += f" | *Build: {build_id}*"

        return content

def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(description='Generate CLAUDE.md documentation')
    parser.add_argument('--input-dir', default='.', help='Input directory to analyze')
    parser.add_argument('--output', default='CLAUDE.md', help='Output file path')
    parser.add_argument('--changes-summary', help='File containing changes summary')
    parser.add_argument('--include-git-info', action='store_true', help='Include git information')
    parser.add_argument('--build-id', help='Build ID for CI/CD integration')
    parser.add_argument('--build-url', help='Build URL for CI/CD integration')
    
    args = parser.parse_args()
    
    # Read changes summary if provided
    changes_summary = None
    if args.changes_summary and Path(args.changes_summary).exists():
        try:
            with open(args.changes_summary, 'r') as f:
                changes_summary = f.read().strip()
        except Exception as e:
            print(f"Warning: Could not read changes summary: {e}", file=sys.stderr)
    
    # Generate documentation
    generator = ClaudeMDGenerator(args.input_dir, args.include_git_info)
    content = generator.generate_claude_md(changes_summary, args.build_id, args.build_url)
    
    # Write output
    try:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Generated {args.output} successfully")
    except Exception as e:
        print(f"Error writing output file: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()