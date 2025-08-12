#!/usr/bin/env python3
"""
Quick MBox Platform Scan - Fast and Safe Analysis
"""

import os
from pathlib import Path
from datetime import datetime
import json

def quick_scan():
    """Perform a quick, safe scan of the MBox platform."""
    mbox_path = Path("/mnt/d/dev2/mbox-platform")
    
    if not mbox_path.exists():
        print(f"ERROR: {mbox_path} not found")
        return
    
    results = {
        'timestamp': datetime.now().isoformat(),
        'project_path': str(mbox_path),
        'src_directories': {},
        'key_files': [],
        'file_counts': {}
    }
    
    print("Quick MBox Platform Scan")
    print("=" * 30)
    
    # Scan src directory structure
    src_path = mbox_path / "src"
    if src_path.exists():
        print(f"Scanning src directory...")
        for item in src_path.iterdir():
            if item.is_dir():
                file_count = len(list(item.glob("*.cs")))
                results['src_directories'][item.name] = {
                    'cs_files': file_count,
                    'path': str(item.relative_to(mbox_path))
                }
                print(f"  {item.name}: {file_count} C# files")
    
    # Look for key configuration files
    key_patterns = [
        "appsettings*.json",
        "*.sln",
        "*.csproj"
    ]
    
    print(f"\nScanning for key files...")
    for pattern in key_patterns:
        files = list(mbox_path.glob(f"**/{pattern}"))[:10]  # Limit results
        for file in files:
            rel_path = str(file.relative_to(mbox_path))
            results['key_files'].append({
                'file': rel_path,
                'type': pattern,
                'size': file.stat().st_size
            })
            print(f"  Found: {rel_path}")
    
    # File type counts (top level only for speed)
    extensions = ['.cs', '.sql', '.json', '.cshtml']
    for ext in extensions:
        count = len(list(mbox_path.glob(f"**/*{ext}")))
        results['file_counts'][ext] = count
        print(f"  {ext} files: {count}")
    
    # Save results
    output_dir = Path("./analysis-output/mbox-platform")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = output_dir / f"quick-scan-{timestamp}.json"
    
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nResults saved to: {output_file}")
    
    # Generate simple report
    report_file = output_dir / f"quick-scan-report-{timestamp}.md"
    with open(report_file, 'w') as f:
        f.write(f"""# MBox Platform Quick Scan Report

**Scan Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
**Project Path:** {mbox_path}

## Source Directory Structure

""")
        for dir_name, info in results['src_directories'].items():
            f.write(f"- **{dir_name}**: {info['cs_files']} C# files\n")
        
        f.write(f"""

## File Counts

""")
        for ext, count in results['file_counts'].items():
            f.write(f"- {ext} files: {count}\n")
        
        f.write(f"""

## Key Files Found

""")
        for file_info in results['key_files']:
            f.write(f"- {file_info['file']} ({file_info['size']} bytes)\n")
        
        f.write(f"""

## Analysis Notes

This was a quick, read-only scan of the MBox Platform project performed from the sqldepends directory.

**Safety measures:**
- No files were modified
- No database connections attempted  
- Limited to basic file system scanning
- Results isolated to analysis-output directory

**Next Steps:**
1. Review the source directory structure
2. Identify key areas for SQL dependency analysis
3. Run targeted analysis on specific components
4. Generate detailed reports for architecture review

""")
    
    print(f"Report saved to: {report_file}")
    print("\nQuick scan complete - no changes made to source project!")

if __name__ == "__main__":
    quick_scan()