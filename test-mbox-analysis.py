#!/usr/bin/env python3
"""
Quick MBox Platform Analysis Test
Performs a simple, safe analysis of the MBox Platform project structure and files.
"""

import os
import json
import re
from pathlib import Path
from datetime import datetime
from collections import defaultdict

class MBoxAnalyzer:
    """Simple analyzer for MBox Platform project."""
    
    def __init__(self, mbox_path: str):
        self.mbox_path = Path(mbox_path)
        self.results = {
            'analysis_timestamp': datetime.now().isoformat(),
            'project_path': str(self.mbox_path),
            'file_summary': {},
            'sql_references': [],
            'entity_framework_usage': [],
            'configuration_files': [],
            'project_structure': {}
        }
        
    def analyze_project_structure(self):
        """Analyze the overall project structure."""
        structure = {}
        
        if not self.mbox_path.exists():
            print(f"ERROR: Path {self.mbox_path} does not exist")
            return structure
            
        # Analyze main directories
        for item in self.mbox_path.iterdir():
            if item.is_dir() and not item.name.startswith('.'):
                structure[item.name] = self._analyze_directory(item)
                
        return structure
    
    def _analyze_directory(self, directory: Path, max_depth: int = 2, current_depth: int = 0):
        """Analyze a directory structure."""
        if current_depth >= max_depth:
            return {"files": len(list(directory.glob('*'))), "truncated": True}
            
        info = {
            "files": 0,
            "cs_files": 0,
            "sql_files": 0,
            "json_files": 0,
            "subdirectories": {}
        }
        
        try:
            for item in directory.iterdir():
                if item.is_file():
                    info["files"] += 1
                    if item.suffix == '.cs':
                        info["cs_files"] += 1
                    elif item.suffix == '.sql':
                        info["sql_files"] += 1
                    elif item.suffix == '.json':
                        info["json_files"] += 1
                elif item.is_dir() and not item.name.startswith('.') and item.name not in ['bin', 'obj']:
                    info["subdirectories"][item.name] = self._analyze_directory(
                        item, max_depth, current_depth + 1
                    )
        except PermissionError:
            info["error"] = "Permission denied"
            
        return info
    
    def find_cs_files_with_sql(self):
        """Find C# files that likely contain SQL code."""
        sql_patterns = [
            r'SELECT\s+.*\s+FROM\s+\w+',
            r'INSERT\s+INTO\s+\w+',
            r'UPDATE\s+\w+\s+SET',
            r'DELETE\s+FROM\s+\w+',
            r'CREATE\s+(TABLE|VIEW|PROCEDURE)',
            r'SqlCommand',
            r'SqlConnection',
            r'CommandText\s*=',
            r'FromSqlRaw',
            r'ExecuteSqlRaw',
            r'DbContext',
            r'DbSet<'
        ]
        
        cs_files = []
        try:
            cs_files = list(self.mbox_path.rglob('*.cs'))
        except:
            print("Error scanning for C# files")
            return []
            
        sql_files = []
        
        for cs_file in cs_files[:50]:  # Limit to first 50 files for safety
            try:
                with open(cs_file, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    
                matches = []
                for pattern in sql_patterns:
                    if re.search(pattern, content, re.IGNORECASE):
                        matches.append(pattern)
                        
                if matches:
                    relative_path = str(cs_file.relative_to(self.mbox_path))
                    sql_files.append({
                        'file': relative_path,
                        'patterns_found': matches,
                        'file_size': cs_file.stat().st_size if cs_file.exists() else 0
                    })
                    
            except Exception as e:
                print(f"Error analyzing {cs_file}: {e}")
                continue
                
        return sql_files
    
    def find_configuration_files(self):
        """Find configuration files that might contain connection strings."""
        config_files = []
        config_patterns = ['appsettings*.json', '*.config', 'web.config', 'app.config']
        
        for pattern in config_patterns:
            try:
                files = list(self.mbox_path.rglob(pattern))
                for file in files:
                    try:
                        relative_path = str(file.relative_to(self.mbox_path))
                        file_info = {
                            'file': relative_path,
                            'size': file.stat().st_size,
                            'has_connection_strings': False
                        }
                        
                        # Check for connection strings
                        with open(file, 'r', encoding='utf-8', errors='ignore') as f:
                            content = f.read()
                            if re.search(r'connectionstring|server\s*=|database\s*=', content, re.IGNORECASE):
                                file_info['has_connection_strings'] = True
                                
                        config_files.append(file_info)
                    except Exception as e:
                        print(f"Error analyzing config file {file}: {e}")
            except:
                continue
                
        return config_files
    
    def analyze_sql_files(self):
        """Find and analyze SQL files."""
        sql_files = []
        
        try:
            for sql_file in self.mbox_path.rglob('*.sql'):
                try:
                    relative_path = str(sql_file.relative_to(self.mbox_path))
                    
                    with open(sql_file, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        
                    sql_info = {
                        'file': relative_path,
                        'size': sql_file.stat().st_size,
                        'lines': len(content.split('\n')),
                        'has_procedures': bool(re.search(r'CREATE\s+PROCEDURE', content, re.IGNORECASE)),
                        'has_tables': bool(re.search(r'CREATE\s+TABLE', content, re.IGNORECASE)),
                        'has_views': bool(re.search(r'CREATE\s+VIEW', content, re.IGNORECASE))
                    }
                    
                    sql_files.append(sql_info)
                    
                except Exception as e:
                    print(f"Error analyzing SQL file {sql_file}: {e}")
        except:
            print("Error scanning for SQL files")
            
        return sql_files
    
    def run_analysis(self):
        """Run the complete analysis."""
        print("Starting MBox Platform Analysis...")
        print(f"Analyzing: {self.mbox_path}")
        
        # Project structure
        print("Analyzing project structure...")
        self.results['project_structure'] = self.analyze_project_structure()
        
        # SQL usage in C# files
        print("Scanning C# files for SQL usage...")
        self.results['sql_references'] = self.find_cs_files_with_sql()
        
        # Configuration files
        print("Finding configuration files...")
        self.results['configuration_files'] = self.find_configuration_files()
        
        # SQL files
        print("Analyzing SQL files...")
        self.results['sql_files'] = self.analyze_sql_files()
        
        # Summary statistics
        self.results['summary'] = {
            'total_cs_files_with_sql': len(self.results['sql_references']),
            'total_config_files': len(self.results['configuration_files']),
            'total_sql_files': len(self.results['sql_files']),
            'config_files_with_connections': len([f for f in self.results['configuration_files'] if f.get('has_connection_strings')])
        }
        
        print("Analysis complete!")
        return self.results
    
    def save_results(self, output_file: str):
        """Save results to a JSON file."""
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(self.results, f, indent=2)
            print(f"Results saved to: {output_file}")
        except Exception as e:
            print(f"Error saving results: {e}")

def main():
    """Main execution."""
    mbox_path = "/mnt/d/dev2/mbox-platform"
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    # Create output directory
    output_dir = Path("./analysis-output/mbox-platform")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Run analysis
    analyzer = MBoxAnalyzer(mbox_path)
    results = analyzer.run_analysis()
    
    # Save results
    output_file = output_dir / f"mbox-quick-analysis-{timestamp}.json"
    analyzer.save_results(str(output_file))
    
    # Print summary
    print("\n" + "="*50)
    print("ANALYSIS SUMMARY")
    print("="*50)
    print(f"C# files with SQL patterns: {results['summary']['total_cs_files_with_sql']}")
    print(f"Configuration files found: {results['summary']['total_config_files']}")
    print(f"SQL files found: {results['summary']['total_sql_files']}")
    print(f"Config files with connections: {results['summary']['config_files_with_connections']}")
    
    if results['sql_references']:
        print(f"\nTop SQL usage files:")
        for ref in results['sql_references'][:5]:
            print(f"  - {ref['file']} ({len(ref['patterns_found'])} patterns)")
    
    print(f"\nDetailed results: {output_file}")

if __name__ == "__main__":
    main()