"""
S3 Bay Data Enhancement Script
Adds Safety & Grounding Compliance columns to S3 data

New columns added:
- grounding time: Triangular(min=3, mode=4, max=6) minutes
- fill start: start time + grounding time
- fill amount: (end time - start time) × 200 L
- average flow rate: fill amount / (end time - fill start)
"""

import pandas as pd
import numpy as np
from datetime import timedelta
import os

# Configuration
INPUT_DIR = "TAS_data"
OUTPUT_DIR = "TAS_data"
S3A_FILE = "s3a_diesel_bay.csv"
S3B_FILE = "s3b_gasohol95_bay.csv"

# Constants
CONSTANT_FLOW_RATE = 200  # L/min
GROUNDING_TIME_MIN = 3
GROUNDING_TIME_MODE = 4
GROUNDING_TIME_MAX = 6

def triangular_distribution(size=1):
    """
    Generate triangular distribution for grounding time
    min=3, mode=4, max=6 minutes
    """
    return np.random.triangular(
        left=GROUNDING_TIME_MIN,
        mode=GROUNDING_TIME_MODE,
        right=GROUNDING_TIME_MAX,
        size=size
    )

def time_to_minutes(time_str):
    """Convert time string (YYYY-MM-DD HH:MM:SS) to minutes since midnight"""
    if pd.isna(time_str):
        return np.nan
    try:
        # Parse datetime string and extract time portion
        time_part = str(time_str).split(' ')[1]  # Get HH:MM:SS
        parts = time_part.split(':')
        hours = int(parts[0])
        minutes = int(parts[1])
        seconds = int(parts[2]) if len(parts) > 2 else 0
        return hours * 60 + minutes + seconds / 60
    except:
        return np.nan

def minutes_to_time(minutes):
    """Convert minutes since midnight back to HH:MM:SS format"""
    if pd.isna(minutes):
        return np.nan
    total_seconds = int(minutes * 60)
    hours = total_seconds // 3600
    mins = (total_seconds % 3600) // 60
    secs = total_seconds % 60
    return f"{hours:02d}:{mins:02d}:{secs:02d}"

def calculate_fill_start_datetime(start_time_str, grounding_minutes):
    """Add grounding time to start time to get fill start time"""
    if pd.isna(start_time_str) or pd.isna(grounding_minutes):
        return np.nan
    try:
        start_dt = pd.to_datetime(start_time_str)
        fill_start_dt = start_dt + pd.Timedelta(minutes=float(grounding_minutes))
        return fill_start_dt.strftime('%Y-%m-%d %H:%M:%S')
    except:
        return np.nan

def process_s3_file(input_file, output_file, bay_type):
    """
    Process S3 bay file and add grounding compliance columns
    
    Parameters:
    - input_file: path to input CSV
    - output_file: path to output CSV
    - bay_type: 's3a' or 's3b' for logging
    """
    
    print(f"\n{'='*60}")
    print(f"Processing {bay_type}: {input_file}")
    print(f"{'='*60}")
    
    # Read CSV
    df = pd.read_csv(input_file)
    print(f"Loaded {len(df)} records")
    
    # Convert time columns to minutes
    print("Converting time columns to minutes...")
    df['start_time_min'] = df['start time'].apply(time_to_minutes)
    df['end_time_min'] = df['end time'].apply(time_to_minutes)
    df['arrival_time_min'] = df['arrival time'].apply(time_to_minutes)
    df['departure_time_min'] = df['departure time'].apply(time_to_minutes)
    
    # Generate grounding times (triangular distribution)
    print("Generating grounding times (Triangular distribution)...")
    grounding_times = triangular_distribution(size=len(df))
    df['grounding time'] = grounding_times
    
    # Calculate fill start time using datetime (to preserve date)
    print("Calculating fill start times...")
    df['fill start'] = df.apply(
        lambda row: calculate_fill_start_datetime(row['start time'], row['grounding time']),
        axis=1
    )
    
    # Calculate process duration and fill duration
    print("Calculating durations...")
    df['process_duration'] = df['end_time_min'] - df['start_time_min']
    
    # Calculate fill_duration: need to parse both end time and fill start time
    def calc_fill_duration(end_time_str, fill_start_str):
        if pd.isna(end_time_str) or pd.isna(fill_start_str):
            return np.nan
        try:
            end_dt = pd.to_datetime(end_time_str)
            fill_start_dt = pd.to_datetime(fill_start_str)
            duration_minutes = (end_dt - fill_start_dt).total_seconds() / 60
            return duration_minutes
        except:
            return np.nan
    
    df['fill_duration'] = df.apply(
        lambda row: calc_fill_duration(row['end time'], row['fill start']),
        axis=1
    )
    
    # Calculate fill amount (preserves original historical logic)
    print("Calculating fill amounts...")
    df['fill amount'] = df['process_duration'] * CONSTANT_FLOW_RATE
    
    # Calculate average flow rate (more realistic, varies by truck)
    print("Calculating average flow rates...")
    # Avoid division by zero
    df['average flow rate'] = df['fill amount'] / df['fill_duration'].replace(0, np.nan)
    
    # Data quality validation
    print("\nPerforming data quality checks...")
    invalid_records = df[df['fill_duration'] <= 0].copy()
    if len(invalid_records) > 0:
        print(f"⚠️  WARNING: {len(invalid_records)} records have invalid fill duration")
        print("   (grounding time >= process duration)")
        print("\nInvalid records:")
        print(invalid_records[['po number', 'vehicle number', 'start time', 'end time', 'grounding time']])
    else:
        print("✓ All records passed validation (fill_duration > 0)")
    
    # Calculate validation metrics
    total_records = len(df)
    valid_fill_amount = len(df[df['fill amount'].notna()])
    valid_flow_rate = len(df[df['average flow rate'].notna()])
    print(f"✓ Records with valid fill amount: {valid_fill_amount}/{total_records}")
    print(f"✓ Records with valid flow rate: {valid_flow_rate}/{total_records}")
    
    # Statistics
    print("\n" + "="*60)
    print("GROUNDING TIME STATISTICS")
    print("="*60)
    print(f"Mean:   {df['grounding time'].mean():.2f} min")
    print(f"Median: {df['grounding time'].median():.2f} min")
    print(f"Min:    {df['grounding time'].min():.2f} min")
    print(f"Max:    {df['grounding time'].max():.2f} min")
    print(f"Std:    {df['grounding time'].std():.2f} min")
    
    # Count within expected range
    within_range = len(df[(df['grounding time'] >= GROUNDING_TIME_MIN) & 
                          (df['grounding time'] <= GROUNDING_TIME_MAX)])
    pct_within = (within_range / len(df)) * 100
    print(f"\nRecords within 3-6 min range: {within_range} ({pct_within:.1f}%)")
    
    print("\n" + "="*60)
    print("FLOW RATE STATISTICS")
    print("="*60)
    print(f"Mean:   {df['average flow rate'].mean():.2f} L/min")
    print(f"Median: {df['average flow rate'].median():.2f} L/min")
    print(f"Min:    {df['average flow rate'].min():.2f} L/min")
    print(f"Max:    {df['average flow rate'].max():.2f} L/min")
    print(f"Std:    {df['average flow rate'].std():.2f} L/min")
    
    print("\n" + "="*60)
    print("FILL AMOUNT STATISTICS")
    print("="*60)
    print(f"Mean:   {df['fill amount'].mean():.0f} L")
    print(f"Median: {df['fill amount'].median():.0f} L")
    print(f"Min:    {df['fill amount'].min():.0f} L")
    print(f"Max:    {df['fill amount'].max():.0f} L")
    print(f"Total:  {df['fill amount'].sum():.0f} L")
    
    # Prepare final output with proper column order
    final_columns = [
        'po number',
        'vehicle number',
        'arrival time',
        'start time',
        'grounding time',
        'fill start',
        'end time',
        'departure time',
        'fill amount',
        'average flow rate'
    ]
    
    # Select only the columns we want
    df_output = df[final_columns].copy()
    
    # Round numeric columns for clean output
    df_output['grounding time'] = df_output['grounding time'].round(2)
    df_output['fill amount'] = df_output['fill amount'].round(0)
    df_output['average flow rate'] = df_output['average flow rate'].round(2)
    
    # Save to CSV
    print(f"\nSaving to {output_file}...")
    df_output.to_csv(output_file, index=False)
    print(f"✓ Successfully saved {len(df_output)} records")
    
    return df_output

def main():
    """Main execution"""
    print("\n" + "="*60)
    print("S3 BAY DATA ENHANCEMENT - GROUNDING COMPLIANCE")
    print("="*60)
    
    # Process both S3 files
    try:
        # Process S3A (Diesel)
        s3a_input = os.path.join(INPUT_DIR, S3A_FILE)
        s3a_output = os.path.join(OUTPUT_DIR, S3A_FILE)
        df_s3a = process_s3_file(s3a_input, s3a_output, "S3A (Diesel Bay)")
        
        # Process S3B (Gasohol 95)
        s3b_input = os.path.join(INPUT_DIR, S3B_FILE)
        s3b_output = os.path.join(OUTPUT_DIR, S3B_FILE)
        df_s3b = process_s3_file(s3b_input, s3b_output, "S3B (Gasohol95 Bay)")
        
        print("\n" + "="*60)
        print("PROCESSING COMPLETE ✓")
        print("="*60)
        print(f"\nS3A records processed: {len(df_s3a)}")
        print(f"S3B records processed: {len(df_s3b)}")
        print(f"\nOutput files:")
        print(f"  - {s3a_output}")
        print(f"  - {s3b_output}")
        
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        import traceback
        traceback.print_exc()
        return False
    
    return True

if __name__ == "__main__":
    main()
