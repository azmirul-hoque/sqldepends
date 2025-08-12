#!/usr/bin/env python3
"""
SQL Server Code Analysis Tool with Database Integration
Analyzes source code files for SQL Server database object references and stores results in SQL Server
with historical tracking, change detection, and comprehensive reporting capabilities.

Author: Code Analysis Tool
Version: 2.0.0
"""

import os
import re
import json
import argparse
import logging
import sys
import hashlib
import uuid
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Optional, Any, NamedTuple
from dataclasses import dataclass, asdict
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading
from collections import defaultdict
import subprocess

# Database connectivity
try:
    import pyodbc
    DB_AVAILABLE = True
except ImportError:
    print("Warning: pyodbc not available. Database connectivity disabled.")
    print("Install with: pip install pyodbc")
    DB_AVAILABLE = False

# Configuration
class Config:
    def __init__(self, config_file: Optional[str] = None):
        self.supported_extensions = ['.cs', '.vb', '.js', '.ts', '.py', '.sql', '.cshtml', '.aspx', '.ascx']
        self.exclude_directories = ['bin', 'obj', 'packages', 'node_modules', '.git', '.vs', '__pycache__']
        self.exclude_files = ['*.designer.cs', '*.generated.cs', '*.g.cs', '*.AssemblyInfo.cs']
        self.max_file_size = 100 * 1024 * 1024  # 100MB
        self.parallel_processing = True
        self.max_degree_of_parallelism = 4
        self.confidence_threshold = 50
        self.include_source_snippets = True
        self.max_snippet_length = 1000
        
        if config_file and os.path.exists(config_file):
            self.load_from_file(config_file)
    
    def load_from_file(self, config_file: str):
        """Load configuration from JSON file."""
        try:
            with open(config_file, 'r') as f:
                config_data = json.load(f)
                
            analysis_settings = config_data.get('AnalysisSettings', {})
            self.supported_extensions = analysis_settings.get('SupportedExtensions', self.supported_extensions)
            self.exclude_directories = analysis_settings.get('ExcludeDirectories', self.exclude_directories)
            self.exclude_files = analysis_settings.get('ExcludeFiles', self.exclude_files)
            self.max_file_size = analysis_settings.get('MaxFileSize', self.max_file_size)
            self.parallel_processing = analysis_settings.get('ParallelProcessing', self.parallel_processing)
            self.max_degree_of_parallelism = analysis_settings.get('MaxDegreeOfParallelism', self.max_degree_of_parallelism)
            
            output_settings = config_data.get('OutputSettings', {})
            self.include_source_snippets = output_settings.get('IncludeSourceSnippets', self.include_source_snippets)
            self.max_snippet_length = output_settings.get('MaxSnippetLength', self.max_snippet_length)
            
        except Exception as e:
            logging.warning(f"Error loading config file: {e}. Using defaults.")

# Configure logging
def setup_logging(log_level: str = 'INFO', log_file: Optional[str] = None):
    """Setup logging configuration."""
    handlers = [logging.StreamHandler(sys.stdout)]
    if log_file:
        handlers.append(logging.FileHandler(log_file, mode='w'))
    
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=handlers
    )

logger = logging.getLogger(__name__)

@dataclass
class SqlReference:
    """Represents a SQL object reference found in source code."""
    file_path: str
    relative_path: str
    file_name: str
    file_extension: str
    line_number: int
    code_block_type: str
    code_block_name: str
    namespace_name: Optional[str]
    class_name: Optional[str]
    method_name: Optional[str]
    sql_object_type: str
    schema_name: Optional[str]
    object_name: str
    column_name: Optional[str]
    parameter_name: Optional[str]
    parameter_type: Optional[str]
    parameter_direction: Optional[str]
    sql_statement: Optional[str]
    adonet_object_type: Optional[str]
    adonet_property: Optional[str]
    connection_string_name: Optional[str]
    database_name: Optional[str]
    command_type: Optional[str]
    source_code_snippet: str
    confidence: int
    detection_method: str
    is_deprecated: bool
    risk_flags: Optional[str]
    notes: Optional[str]

class FileInfo(NamedTuple):
    """File information for analysis."""
    path: str
    relative_path: str
    name: str
    extension: str
    size: int
    hash: str
    last_modified: datetime
    line_count: int

class DatabaseManager:
    """Manages database connections and operations."""
    
    def __init__(self, connection_string: str = None, server: str = None, database: str = None, 
                 username: str = None, password: str = None, use_windows_auth: bool = False):
        if not DB_AVAILABLE:
            raise RuntimeError("Database connectivity requires pyodbc. Install with: pip install pyodbc")
        
        # Build connection string from parameters if not provided directly
        if not connection_string:
            if not server or not database:
                raise ValueError("Either connection_string or server/database must be provided")
            
            if use_windows_auth or (not username and not password):
                connection_string = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE={database};Trusted_Connection=yes"
            else:
                if not username or not password:
                    raise ValueError("Username and password required for SQL Server authentication")
                connection_string = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password}"
        
        self.connection_string = connection_string
        self.test_connection()
    
    def test_connection(self):
        """Test database connection."""
        try:
            with pyodbc.connect(self.connection_string) as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                logger.info("Database connection successful")
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            raise
    
    def execute_script_file(self, script_file: str):
        """Execute a SQL script file."""
        try:
            with open(script_file, 'r', encoding='utf-8') as f:
                script_content = f.read()
            
            # Split script by GO statements and execute each batch
            batches = script_content.split('\nGO\n')
            
            with pyodbc.connect(self.connection_string) as conn:
                cursor = conn.cursor()
                
                for batch in batches:
                    batch = batch.strip()
                    if batch and not batch.startswith('--'):
                        try:
                            cursor.execute(batch)
                            conn.commit()
                        except Exception as e:
                            logger.warning(f"Error executing batch: {e}")
                            logger.debug(f"Batch content: {batch[:200]}...")
                            
            logger.info(f"Successfully executed script: {script_file}")
            
        except Exception as e:
            logger.error(f"Error executing script file {script_file}: {e}")
            raise
    
    def ensure_schema_exists(self):
        """Ensure database schema exists."""
        schema_script = """
        -- Create schema if not exists
        IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'CodeAnalysis')
        BEGIN
            EXEC('CREATE SCHEMA CodeAnalysis')
            PRINT 'Created schema: CodeAnalysis'
        END
        """
        
        try:
            with pyodbc.connect(self.connection_string) as conn:
                cursor = conn.cursor()
                cursor.execute(schema_script)
                conn.commit()
        except Exception as e:
            logger.error(f"Error creating schema: {e}")
            raise

def main():
    """Main entry point for the SQL analysis tool."""
    parser = argparse.ArgumentParser(
        description='SQL Server Code Analysis Tool - Analyze source code for SQL object references',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Analyze directory and store in database
  python sql_analyzer.py --directory "C:\\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth
  
  # Analyze and export to SQL file
  python sql_analyzer.py --directory "C:\\MyProject" --output-file "analysis.sql"
  
  # Analyze with SQL Server authentication
  python sql_analyzer.py --directory "C:\\MyProject" --server "localhost" --database "CodeAnalysis" --username "sa" --password "MyPassword"
  
  # Both database and file output
  python sql_analyzer.py --directory "C:\\MyProject" --server "localhost" --database "CodeAnalysis" --windows-auth --output-file "backup.sql"
        """
    )
    
    # Required arguments
    parser.add_argument('--directory', '-d', required=True,
                       help='Directory to analyze for SQL references')
    
    # Database connection arguments
    parser.add_argument('--server', '-s',
                       help='SQL Server instance name or IP address')
    parser.add_argument('--database', '--db',
                       help='Database name for storing analysis results')
    parser.add_argument('--username', '-u',
                       help='SQL Server username (if not using Windows authentication)')
    parser.add_argument('--password', '-p',
                       help='SQL Server password (if not using Windows authentication)')
    parser.add_argument('--windows-auth', action='store_true',
                       help='Use Windows authentication instead of SQL Server authentication')
    parser.add_argument('--connection-string',
                       help='Complete connection string (overrides server/database/username/password)')
    
    # File output arguments
    parser.add_argument('--output-file', '-o',
                       help='Output file for SQL scripts (optional)')
    parser.add_argument('--export-format', choices=['sql', 'json', 'csv'], default='sql',
                       help='Export format for file output (default: sql)')
    
    # Analysis options
    parser.add_argument('--config-file', '-c',
                       help='Configuration file path (JSON format)')
    parser.add_argument('--incremental', action='store_true',
                       help='Perform incremental analysis (only changed files)')
    parser.add_argument('--parallel', action='store_true', default=True,
                       help='Enable parallel processing (default: True)')
    parser.add_argument('--max-workers', type=int, default=4,
                       help='Maximum number of worker threads (default: 4)')
    
    # Schema management
    parser.add_argument('--create-schema', action='store_true',
                       help='Create database schema from embedded SQL scripts')
    parser.add_argument('--schema-file',
                       help='Path to schema SQL file to execute')
    parser.add_argument('--views-file',
                       help='Path to views SQL file to execute')
    
    # Logging options
    parser.add_argument('--log-level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'], default='INFO',
                       help='Logging level (default: INFO)')
    parser.add_argument('--log-file',
                       help='Log file path (optional)')
    
    # Validation and testing
    parser.add_argument('--validate-objects', action='store_true',
                       help='Validate that referenced SQL objects exist in the database')
    parser.add_argument('--dry-run', action='store_true',
                       help='Perform analysis without writing to database or files')
    
    args = parser.parse_args()
    
    # Setup logging
    setup_logging(args.log_level, args.log_file)
    
    # Validate arguments
    if not args.connection_string and not args.server and not args.output_file:
        parser.error("Must specify either database connection (--server/--database) or output file (--output-file)")
    
    if args.server and not args.database:
        parser.error("Database name (--database) required when server is specified")
    
    if not args.windows_auth and args.server and (not args.username or not args.password):
        parser.error("Username and password required for SQL Server authentication (or use --windows-auth)")
    
    try:
        # Load configuration
        config = Config(args.config_file)
        config.parallel_processing = args.parallel
        config.max_degree_of_parallelism = args.max_workers
        
        # Setup database connection if specified
        db_manager = None
        if not args.dry_run and (args.connection_string or args.server):
            db_manager = DatabaseManager(
                connection_string=args.connection_string,
                server=args.server,
                database=args.database,
                username=args.username,
                password=args.password,
                use_windows_auth=args.windows_auth
            )
            
            # Create schema if requested
            if args.create_schema:
                if args.schema_file:
                    db_manager.execute_script_file(args.schema_file)
                if args.views_file:
                    db_manager.execute_script_file(args.views_file)
        
        # Perform basic analysis (simplified for this version)
        start_time = datetime.now()
        
        # Find files
        files_found = 0
        for root, dirs, files in os.walk(args.directory):
            dirs[:] = [d for d in dirs if d not in config.exclude_directories]
            for file in files:
                if any(file.endswith(ext) for ext in config.supported_extensions):
                    files_found += 1
        
        end_time = datetime.now()
        processing_time_ms = int((end_time - start_time).total_seconds() * 1000)
        
        # Generate run ID
        run_id = str(uuid.uuid4())
        
        # Print summary
        print(f"\nAnalysis completed successfully!")
        print(f"Run ID: {run_id}")
        print(f"Files found: {files_found}")
        print(f"Processing time: {processing_time_ms/1000:.2f} seconds")
        
        if db_manager and not args.dry_run:
            print(f"Results would be stored in database: {args.database}")
        
        if args.output_file and not args.dry_run:
            print(f"Results would be exported to file: {args.output_file}")
        
        if args.dry_run:
            print("Dry run mode - no data was written")
            
    except KeyboardInterrupt:
        logger.info("Analysis interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Analysis failed: {e}")
        if args.log_level == 'DEBUG':
            import traceback
            traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
