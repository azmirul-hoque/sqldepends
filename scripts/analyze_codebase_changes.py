#!/usr/bin/env python3
"""
Codebase Change Analyzer for CLAUDE.md Updates
Analyzes code changes to determine if CLAUDE.md documentation needs updating.
"""

import os
import sys
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Tuple, Set
from datetime import datetime

class CodebaseAnalyzer:
    """Analyzes codebase changes to identify documentation update needs."""
    
    def __init__(self, repo_path: str = "."):
        self.repo_path = Path(repo_path)
        self.important_files = {
            'sql_analyzer.py': 'high',
            'Analyze-SqlCode.ps1': 'high', 
            'config.json': 'medium',
            'requirements.txt': 'medium',
            'README.md': 'medium',
            'sql/database_schema.sql': 'high',
            'sql/analysis_views.sql': 'medium',
            'examples/usage_examples.md': 'low',
            'examples/sample_queries.sql': 'low'
        }
        
    def get_git_changes(self) -> Dict[str, List[str]]:
        """Get recent git changes that might affect documentation."""
        try:
            # Get changed files in last commit
            result = subprocess.run(
                ['git', 'diff', '--name-only', 'HEAD~1', 'HEAD'],
                capture_output=True, text=True, cwd=self.repo_path
            )
            
            if result.returncode != 0:
                # Fallback to staged changes
                result = subprocess.run(
                    ['git', 'diff', '--cached', '--name-only'],
                    capture_output=True, text=True, cwd=self.repo_path
                )
                
            changed_files = result.stdout.strip().split('\n') if result.stdout.strip() else []
            
            # Get commit message for context
            commit_msg_result = subprocess.run(
                ['git', 'log', '-1', '--pretty=format:%s'],
                capture_output=True, text=True, cwd=self.repo_path
            )
            
            return {
                'changed_files': changed_files,
                'commit_message': commit_msg_result.stdout.strip() if commit_msg_result.returncode == 0 else ""
            }
            
        except Exception as e:
            print(f"Warning: Could not analyze git changes: {e}", file=sys.stderr)
            return {'changed_files': [], 'commit_message': ""}
    
    def analyze_file_content_changes(self, filepath: str) -> Dict[str, any]:
        """Analyze specific changes in important files."""
        full_path = self.repo_path / filepath
        if not full_path.exists():
            return {}
            
        changes = {}
        
        try:
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            if filepath.endswith('.py'):
                changes.update(self._analyze_python_changes(content))
            elif filepath.endswith('.ps1'):
                changes.update(self._analyze_powershell_changes(content))
            elif filepath.endswith('.json'):
                changes.update(self._analyze_json_changes(content))
            elif filepath.endswith('.md'):
                changes.update(self._analyze_markdown_changes(content))
                
        except Exception as e:
            print(f"Warning: Could not analyze {filepath}: {e}", file=sys.stderr)
            
        return changes
    
    def _analyze_python_changes(self, content: str) -> Dict[str, any]:
        """Analyze Python file for significant changes."""
        changes = {}
        
        # Look for new imports
        imports = re.findall(r'^(?:from\s+\S+\s+)?import\s+(.+)', content, re.MULTILINE)
        changes['imports'] = [imp.strip() for imp in imports]
        
        # Look for command line arguments
        argparse_patterns = re.findall(r'add_argument\([\'"]([^\'\"]+)[\'"]', content)
        changes['cli_arguments'] = argparse_patterns
        
        # Look for configuration keys
        config_patterns = re.findall(r'[\'"]([A-Z][a-zA-Z]+)[\'"]', content)
        changes['config_keys'] = list(set(config_patterns))
        
        # Look for class definitions
        classes = re.findall(r'^class\s+(\w+)', content, re.MULTILINE)
        changes['classes'] = classes
        
        # Look for function definitions
        functions = re.findall(r'^def\s+(\w+)', content, re.MULTILINE)
        changes['functions'] = functions
        
        return changes
    
    def _analyze_powershell_changes(self, content: str) -> Dict[str, any]:
        """Analyze PowerShell file for significant changes."""
        changes = {}
        
        # Look for parameters
        params = re.findall(r'\[Parameter[^\]]*\]\s*\[[\w\[\]]+\]\s*\$(\w+)', content)
        changes['parameters'] = params
        
        # Look for functions
        functions = re.findall(r'^function\s+(\w+)', content, re.MULTILINE | re.IGNORECASE)
        changes['functions'] = functions
        
        # Look for cmdlet bindings
        cmdlet_patterns = re.findall(r'\[CmdletBinding\([^\]]*\)\]', content)
        changes['cmdlet_features'] = len(cmdlet_patterns) > 0
        
        return changes
    
    def _analyze_json_changes(self, content: str) -> Dict[str, any]:
        """Analyze JSON configuration for changes."""
        try:
            data = json.loads(content)
            return {
                'config_sections': list(data.keys()) if isinstance(data, dict) else [],
                'has_nested_config': any(isinstance(v, dict) for v in data.values()) if isinstance(data, dict) else False
            }
        except:
            return {}
    
    def _analyze_markdown_changes(self, content: str) -> Dict[str, any]:
        """Analyze Markdown files for structural changes."""
        changes = {}
        
        # Count headers
        headers = re.findall(r'^#+\s+(.+)', content, re.MULTILINE)
        changes['sections'] = headers
        
        # Look for code blocks
        code_blocks = re.findall(r'```(\w+)', content)
        changes['code_languages'] = list(set(code_blocks))
        
        return changes
    
    def calculate_impact_score(self, changed_files: List[str]) -> int:
        """Calculate impact score based on changed files."""
        score = 0
        
        for file in changed_files:
            if file in self.important_files:
                if self.important_files[file] == 'high':
                    score += 10
                elif self.important_files[file] == 'medium':
                    score += 5
                elif self.important_files[file] == 'low':
                    score += 2
                    
        return score
    
    def generate_change_summary(self) -> Dict[str, any]:
        """Generate comprehensive change summary."""
        git_changes = self.get_git_changes()
        changed_files = git_changes['changed_files']
        
        # Filter for files we care about
        relevant_changes = [f for f in changed_files if any(f.startswith(key.split('/')[0]) for key in self.important_files.keys())]
        
        summary = {
            'timestamp': datetime.utcnow().isoformat(),
            'changed_files': relevant_changes,
            'commit_message': git_changes['commit_message'],
            'impact_score': self.calculate_impact_score(relevant_changes),
            'file_analyses': {}
        }
        
        # Analyze each relevant file
        for file in relevant_changes:
            if any(file.endswith(ext) for ext in ['.py', '.ps1', '.json', '.md']):
                summary['file_analyses'][file] = self.analyze_file_content_changes(file)
        
        return summary
    
    def should_update_claude_md(self, summary: Dict[str, any]) -> bool:
        """Determine if CLAUDE.md should be updated based on changes."""
        # Update if impact score is above threshold
        if summary['impact_score'] >= 5:
            return True
            
        # Update if specific critical files changed
        critical_files = ['sql_analyzer.py', 'Analyze-SqlCode.ps1', 'config.json']
        if any(f in summary['changed_files'] for f in critical_files):
            return True
            
        # Update if new CLI arguments or major functions added
        for file_analysis in summary['file_analyses'].values():
            if 'cli_arguments' in file_analysis and len(file_analysis['cli_arguments']) > 0:
                return True
            if 'classes' in file_analysis and len(file_analysis['classes']) > 2:
                return True
                
        return False

def main():
    """Main execution function."""
    analyzer = CodebaseAnalyzer()
    summary = analyzer.generate_change_summary()
    
    if analyzer.should_update_claude_md(summary):
        # Output change details for the workflow
        print("=== CLAUDE.md Update Required ===")
        print(f"Impact Score: {summary['impact_score']}")
        print(f"Changed Files: {', '.join(summary['changed_files'])}")
        
        if summary['commit_message']:
            print(f"Commit Message: {summary['commit_message']}")
            
        # Output file-specific changes
        for file, analysis in summary['file_analyses'].items():
            if analysis:
                print(f"\n{file} changes:")
                for key, value in analysis.items():
                    if value:
                        print(f"  - {key}: {value}")
    else:
        print("No significant changes detected that require CLAUDE.md update")
        
    # Always output summary as JSON for workflow processing
    print(f"\n=== JSON Summary ===")
    print(json.dumps(summary, indent=2))

if __name__ == "__main__":
    main()