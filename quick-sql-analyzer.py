#!/usr/bin/env python3
"""
Quick SQL Analyzer - Working implementation for MBox analysis
Analyzes C# files for SQL patterns and Entity Framework usage.
"""

import os
import re
import json
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any

class QuickSQLAnalyzer:
    """Quick analyzer for SQL patterns in C# code."""
    
    def __init__(self):
        self.sql_patterns = {
            'SELECT': r'SELECT\s+.*?\s+FROM\s+\w+',
            'INSERT': r'INSERT\s+INTO\s+\w+',
            'UPDATE': r'UPDATE\s+\w+\s+SET',
            'DELETE': r'DELETE\s+FROM\s+\w+',
            'CREATE_TABLE': r'CREATE\s+TABLE\s+\w+',
            'CREATE_VIEW': r'CREATE\s+VIEW\s+\w+',
            'CREATE_PROC': r'CREATE\s+PROCEDURE\s+\w+',
            'STORED_PROC_CALL': r'EXEC\s+\w+|EXECUTE\s+\w+'
        }
        
        self.ef_patterns = {
            'DbContext': r':\s*DbContext|DbContext\s*\{',
            'DbSet': r'DbSet<\w+>',
            'FromSqlRaw': r'FromSqlRaw\s*\(',
            'ExecuteSqlRaw': r'ExecuteSqlRaw\s*\(',
            'FromSqlInterpolated': r'FromSqlInterpolated\s*\(',
            'ExecuteSqlInterpolated': r'ExecuteSqlInterpolated\s*\(',
            'Database.ExecuteSqlRaw': r'Database\.ExecuteSqlRaw'
        }
        
        self.ado_patterns = {
            'SqlConnection': r'SqlConnection\s*\(',
            'SqlCommand': r'SqlCommand\s*\(',
            'SqlDataAdapter': r'SqlDataAdapter\s*\(',
            'CommandText': r'CommandText\s*=',
            'SqlParameter': r'SqlParameter\s*\(',
            'ConnectionString': r'ConnectionString\s*=|connectionString'
        }
        
        self.results = []
        
    def analyze_file(self, file_path: Path) -> List[Dict[str, Any]]:
        """Analyze a single C# file for SQL patterns."""
        findings = []
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                lines = content.split('\n')
                
            # Analyze each line
            for line_num, line in enumerate(lines, 1):
                # Check SQL patterns
                for pattern_name, pattern in self.sql_patterns.items():
                    matches = re.finditer(pattern, line, re.IGNORECASE)
                    for match in matches:
                        findings.append({
                            'file': str(file_path),
                            'line': line_num,
                            'type': 'SQL',
                            'pattern': pattern_name,
                            'text': match.group(),
                            'context': line.strip(),
                            'confidence': 90
                        })
                
                # Check Entity Framework patterns
                for pattern_name, pattern in self.ef_patterns.items():
                    matches = re.finditer(pattern, line, re.IGNORECASE)
                    for match in matches:
                        findings.append({
                            'file': str(file_path),
                            'line': line_num,
                            'type': 'EntityFramework',
                            'pattern': pattern_name,
                            'text': match.group(),
                            'context': line.strip(),
                            'confidence': 95
                        })
                
                # Check ADO.NET patterns
                for pattern_name, pattern in self.ado_patterns.items():
                    matches = re.finditer(pattern, line, re.IGNORECASE)
                    for match in matches:
                        findings.append({
                            'file': str(file_path),
                            'line': line_num,
                            'type': 'ADO.NET',
                            'pattern': pattern_name,
                            'text': match.group(),
                            'context': line.strip(),
                            'confidence': 85
                        })
                        
        except Exception as e:
            print(f"Error analyzing {file_path}: {e}")
            
        return findings
    
    def analyze_directory(self, directory: str) -> List[Dict[str, Any]]:
        """Analyze all C# files in a directory."""
        dir_path = Path(directory)
        all_findings = []
        
        # Find all C# files
        cs_files = list(dir_path.rglob('*.cs'))
        
        print(f"Found {len(cs_files)} C# files to analyze")
        
        for cs_file in cs_files:
            print(f"Analyzing: {cs_file}")
            findings = self.analyze_file(cs_file)
            all_findings.extend(findings)
            
        return all_findings
    
    def generate_sql_output(self, findings: List[Dict[str, Any]], output_file: str):
        """Generate SQL-style output from findings."""
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("-- SQL Server Code Analysis Results\n")
            f.write(f"-- Generated: {datetime.now().isoformat()}\n")
            f.write(f"-- Total findings: {len(findings)}\n\n")
            
            f.write("-- Analysis Results View\n")
            f.write("CREATE VIEW vw_MBoxAnalysisResults AS\n")
            f.write("SELECT \n")
            f.write("    FilePath,\n")
            f.write("    LineNumber,\n") 
            f.write("    PatternType,\n")
            f.write("    PatternName,\n")
            f.write("    MatchedText,\n")
            f.write("    ContextLine,\n")
            f.write("    Confidence\n")
            f.write("FROM (\n")
            f.write("    VALUES \n")
            
            for i, finding in enumerate(findings):
                comma = "," if i < len(findings) - 1 else ""
                f.write(f"        ('{finding['file']}', {finding['line']}, '{finding['type']}', '{finding['pattern']}', '{finding['text'][:50]}...', '{finding['context'][:100]}...', {finding['confidence']}){comma}\n")
            
            f.write(") AS Analysis(FilePath, LineNumber, PatternType, PatternName, MatchedText, ContextLine, Confidence)\n\n")
            
            # Add summary statistics
            f.write("-- Summary Statistics\n")
            sql_count = len([f for f in findings if f['type'] == 'SQL'])
            ef_count = len([f for f in findings if f['type'] == 'EntityFramework'])
            ado_count = len([f for f in findings if f['type'] == 'ADO.NET'])
            
            f.write(f"-- SQL Statements: {sql_count}\n")
            f.write(f"-- Entity Framework: {ef_count}\n")
            f.write(f"-- ADO.NET: {ado_count}\n")
            f.write(f"-- Total: {len(findings)}\n")
            
    def generate_json_output(self, findings: List[Dict[str, Any]], output_file: str):
        """Generate JSON output from findings."""
        output_data = {
            'analysis_timestamp': datetime.now().isoformat(),
            'total_findings': len(findings),
            'summary': {
                'sql_statements': len([f for f in findings if f['type'] == 'SQL']),
                'entity_framework': len([f for f in findings if f['type'] == 'EntityFramework']),
                'ado_net': len([f for f in findings if f['type'] == 'ADO.NET'])
            },
            'findings': findings
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=2)

def main():
    """Main execution function."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Quick SQL Analysis Tool')
    parser.add_argument('--directory', '-d', required=True, help='Directory to analyze')
    parser.add_argument('--output', '-o', required=True, help='Output file path')
    parser.add_argument('--format', choices=['sql', 'json'], default='sql', help='Output format')
    
    args = parser.parse_args()
    
    # Run analysis
    analyzer = QuickSQLAnalyzer()
    findings = analyzer.analyze_directory(args.directory)
    
    print(f"\nAnalysis complete!")
    print(f"Total findings: {len(findings)}")
    print(f"SQL statements: {len([f for f in findings if f['type'] == 'SQL'])}")
    print(f"Entity Framework: {len([f for f in findings if f['type'] == 'EntityFramework'])}")
    print(f"ADO.NET: {len([f for f in findings if f['type'] == 'ADO.NET'])}")
    
    # Generate output
    if args.format == 'json':
        analyzer.generate_json_output(findings, args.output)
    else:
        analyzer.generate_sql_output(findings, args.output)
        
    print(f"Results written to: {args.output}")
    
    return len(findings)

if __name__ == "__main__":
    exit_code = main()
    exit(0 if exit_code >= 0 else 1)