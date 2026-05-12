"""
Analyze historical data to extract simulation parameters
- Hourly arrival distributions by product
- Service time distributions for S1, S2, S4
- Fill amount distributions validation
"""

import pandas as pd
import numpy as np
from datetime import datetime
import os

INPUT_DIR = "TAS_data"

# Load all data files
print("="*70)
print("LOADING HISTORICAL DATA")
print("="*70)

s1 = pd.read_csv(os.path.join(INPUT_DIR, "s1_sales_office.csv"))
s2 = pd.read_csv(os.path.join(INPUT_DIR, "s2_inbound_wb.csv"))
s3a = pd.read_csv(os.path.join(INPUT_DIR, "s3a_diesel_bay.csv"))
s3b = pd.read_csv(os.path.join(INPUT_DIR, "s3b_gasohol95_bay.csv"))
s4 = pd.read_csv(os.path.join(INPUT_DIR, "s4_outbound_wb.csv"))

print(f"S1 records: {len(s1)}")
print(f"S2 records: {len(s2)}")
print(f"S3A (Diesel) records: {len(s3a)}")
print(f"S3B (Gasohol95) records: {len(s3b)}")
print(f"S4 records: {len(s4)}")

# ============================================================
# 1) TRUCK ARRIVAL ANALYSIS
# ============================================================
print("\n" + "="*70)
print("1) TRUCK ARRIVAL PATTERNS (HOURLY DISTRIBUTION)")
print("="*70)

def extract_hour(time_str):
    """Extract hour from time string"""
    try:
        if isinstance(time_str, str) and ' ' in time_str:
            time_part = time_str.split(' ')[1]
            hour = int(time_part.split(':')[0])
            return hour
        return None
    except:
        return None

# S3A analysis (Diesel)
s3a['arrival_hour'] = s3a['arrival time'].apply(extract_hour)
diesel_by_hour = s3a['arrival_hour'].value_counts().sort_index()

print("\nDIESEL ARRIVALS BY HOUR:")
print("Hour | Count | Percentage")
print("-" * 30)
total_diesel = len(s3a)
for hour in range(24):
    count = diesel_by_hour.get(hour, 0)
    pct = (count / total_diesel * 100) if total_diesel > 0 else 0
    if count > 0 or hour in [0, 1, 6, 12, 18, 23]:  # Show key hours
        print(f" {hour:2d}  | {count:5d} | {pct:6.2f}%")

# S3B analysis (Gasohol95)
s3b['arrival_hour'] = s3b['arrival time'].apply(extract_hour)
gasohol_by_hour = s3b['arrival_hour'].value_counts().sort_index()

print("\nGASOHOL95 ARRIVALS BY HOUR:")
print("Hour | Count | Percentage")
print("-" * 30)
total_gasohol = len(s3b)
for hour in range(24):
    count = gasohol_by_hour.get(hour, 0)
    pct = (count / total_gasohol * 100) if total_gasohol > 0 else 0
    if count > 0 or hour in [0, 1, 6, 12, 18, 23]:
        print(f" {hour:2d}  | {count:5d} | {pct:6.2f}%")

# Calculate daily totals
print(f"\nTotal Diesel trucks: {total_diesel}")
print(f"Total Gasohol95 trucks: {total_gasohol}")
diesel_pct = (total_diesel / (total_diesel + total_gasohol)) * 100
gasohol_pct = (total_gasohol / (total_diesel + total_gasohol)) * 100
print(f"Diesel percentage: {diesel_pct:.1f}%")
print(f"Gasohol95 percentage: {gasohol_pct:.1f}%")

# ============================================================
# 2) SERVICE TIME DISTRIBUTIONS
# ============================================================
print("\n" + "="*70)
print("2) SERVICE TIME DISTRIBUTIONS")
print("="*70)

def calc_duration_minutes(start_time, end_time):
    """Calculate duration in minutes between two datetime strings"""
    try:
        start = pd.to_datetime(start_time)
        end = pd.to_datetime(end_time)
        duration = (end - start).total_seconds() / 60
        return max(duration, 0)  # Avoid negative
    except:
        return np.nan

# S1 Service Time (arrival to start)
s1['service_time'] = s1.apply(
    lambda row: calc_duration_minutes(row['arrival time'], row['start time']),
    axis=1
)
s1['service_time'] = s1['service_time'].dropna()

print("\n--- S1 (SALES OFFICE) SERVICE TIME ---")
print(f"Count: {len(s1['service_time'])}")
print(f"Mean: {s1['service_time'].mean():.2f} min")
print(f"Median: {s1['service_time'].median():.2f} min")
print(f"Std: {s1['service_time'].std():.2f} min")
print(f"Min: {s1['service_time'].min():.2f} min")
print(f"Max: {s1['service_time'].max():.2f} min")
print(f"Percentiles:")
print(f"  5th: {s1['service_time'].quantile(0.05):.2f} min")
print(f"  25th: {s1['service_time'].quantile(0.25):.2f} min")
print(f"  50th: {s1['service_time'].quantile(0.50):.2f} min")
print(f"  75th: {s1['service_time'].quantile(0.75):.2f} min")
print(f"  95th: {s1['service_time'].quantile(0.95):.2f} min")

# S2 Service Time
s2['service_time'] = s2.apply(
    lambda row: calc_duration_minutes(row['arrival time'], row['start time']),
    axis=1
)
s2['service_time'] = s2['service_time'].dropna()

print("\n--- S2 (INBOUND WEIGHBRIDGE) SERVICE TIME ---")
print(f"Count: {len(s2['service_time'])}")
print(f"Mean: {s2['service_time'].mean():.2f} min")
print(f"Median: {s2['service_time'].median():.2f} min")
print(f"Std: {s2['service_time'].std():.2f} min")
print(f"Min: {s2['service_time'].min():.2f} min")
print(f"Max: {s2['service_time'].max():.2f} min")
print(f"Percentiles:")
print(f"  5th: {s2['service_time'].quantile(0.05):.2f} min")
print(f"  25th: {s2['service_time'].quantile(0.25):.2f} min")
print(f"  50th: {s2['service_time'].quantile(0.50):.2f} min")
print(f"  75th: {s2['service_time'].quantile(0.75):.2f} min")
print(f"  95th: {s2['service_time'].quantile(0.95):.2f} min")

# S4 Service Time
s4['service_time'] = s4.apply(
    lambda row: calc_duration_minutes(row['arrival time'], row['start time']),
    axis=1
)
s4['service_time'] = s4['service_time'].dropna()

print("\n--- S4 (OUTBOUND WEIGHBRIDGE) SERVICE TIME ---")
print(f"Count: {len(s4['service_time'])}")
print(f"Mean: {s4['service_time'].mean():.2f} min")
print(f"Median: {s4['service_time'].median():.2f} min")
print(f"Std: {s4['service_time'].std():.2f} min")
print(f"Min: {s4['service_time'].min():.2f} min")
print(f"Max: {s4['service_time'].max():.2f} min")
print(f"Percentiles:")
print(f"  5th: {s4['service_time'].quantile(0.05):.2f} min")
print(f"  25th: {s4['service_time'].quantile(0.25):.2f} min")
print(f"  50th: {s4['service_time'].quantile(0.50):.2f} min")
print(f"  75th: {s4['service_time'].quantile(0.75):.2f} min")
print(f"  95th: {s4['service_time'].quantile(0.95):.2f} min")

# ============================================================
# 3) FILL AMOUNT VALIDATION
# ============================================================
print("\n" + "="*70)
print("3) FILL AMOUNT DISTRIBUTIONS (VALIDATION)")
print("="*70)

print("\n--- S3A (DIESEL) FILL AMOUNT ---")
diesel_fill = s3a['fill amount'].dropna()
print(f"Count: {len(diesel_fill)}")
print(f"Mean: {diesel_fill.mean():.0f} L")
print(f"Median: {diesel_fill.median():.0f} L")
print(f"Std: {diesel_fill.std():.0f} L")
print(f"Min: {diesel_fill.min():.0f} L")
print(f"Max: {diesel_fill.max():.0f} L")
print(f"Percentiles:")
print(f"  5th: {diesel_fill.quantile(0.05):.0f} L")
print(f"  25th: {diesel_fill.quantile(0.25):.0f} L")
print(f"  50th (median): {diesel_fill.quantile(0.50):.0f} L")
print(f"  75th: {diesel_fill.quantile(0.75):.0f} L")
print(f"  95th: {diesel_fill.quantile(0.95):.0f} L")

print("\n--- S3B (GASOHOL95) FILL AMOUNT ---")
gasohol_fill = s3b['fill amount'].dropna()
print(f"Count: {len(gasohol_fill)}")
print(f"Mean: {gasohol_fill.mean():.0f} L")
print(f"Median: {gasohol_fill.median():.0f} L")
print(f"Std: {gasohol_fill.std():.0f} L")
print(f"Min: {gasohol_fill.min():.0f} L")
print(f"Max: {gasohol_fill.max():.0f} L")
print(f"Percentiles:")
print(f"  5th: {gasohol_fill.quantile(0.05):.0f} L")
print(f"  25th: {gasohol_fill.quantile(0.25):.0f} L")
print(f"  50th (median): {gasohol_fill.quantile(0.50):.0f} L")
print(f"  75th: {gasohol_fill.quantile(0.75):.0f} L")
print(f"  95th: {gasohol_fill.quantile(0.95):.0f} L")

# ============================================================
# 4) PRODUCTIVE FILLING TIME (to validate flow rate logic)
# ============================================================
print("\n" + "="*70)
print("4) PRODUCTIVE FILLING TIME (END TIME - FILL START)")
print("="*70)

# Calculate fill_duration for S3A and S3B
s3a['fill_duration'] = s3a.apply(
    lambda row: calc_duration_minutes(row['fill start'], row['end time']),
    axis=1
)
s3a['fill_duration'] = s3a['fill_duration'].dropna()

s3b['fill_duration'] = s3b.apply(
    lambda row: calc_duration_minutes(row['fill start'], row['end time']),
    axis=1
)
s3b['fill_duration'] = s3b['fill_duration'].dropna()

print("\n--- S3A (DIESEL) PRODUCTIVE FILL TIME ---")
s3a_fill_time = s3a['fill_duration']
s3a_fill_time = s3a_fill_time[s3a_fill_time > 0]
print(f"Count: {len(s3a_fill_time)}")
print(f"Mean: {s3a_fill_time.mean():.2f} min")
print(f"Median: {s3a_fill_time.median():.2f} min")
print(f"Std: {s3a_fill_time.std():.2f} min")
print(f"Min: {s3a_fill_time.min():.2f} min")
print(f"Max: {s3a_fill_time.max():.2f} min")

print("\n--- S3B (GASOHOL95) PRODUCTIVE FILL TIME ---")
s3b_fill_time = s3b['fill_duration']
s3b_fill_time = s3b_fill_time[s3b_fill_time > 0]
print(f"Count: {len(s3b_fill_time)}")
print(f"Mean: {s3b_fill_time.mean():.2f} min")
print(f"Median: {s3b_fill_time.median():.2f} min")
print(f"Std: {s3b_fill_time.std():.2f} min")
print(f"Min: {s3b_fill_time.min():.2f} min")
print(f"Max: {s3b_fill_time.max():.2f} min")

# ============================================================
# 5) DERIVED FLOW RATE (to validate Option A logic)
# ============================================================
print("\n" + "="*70)
print("5) DERIVED FLOW RATE (FILL AMOUNT / PRODUCTIVE FILL TIME)")
print("="*70)

# Calculate flow rate for S3A and S3B
def calc_flow_rate(fill_amount, fill_duration_min):
    """Calculate flow rate"""
    if fill_duration_min and fill_duration_min > 0:
        return fill_amount / fill_duration_min
    return None

s3a['calculated_flow_rate'] = s3a.apply(
    lambda row: calc_flow_rate(row['fill amount'], row['fill_duration']),
    axis=1
)

s3b['calculated_flow_rate'] = s3b.apply(
    lambda row: calc_flow_rate(row['fill amount'], row['fill_duration']),
    axis=1
)

print("\n--- S3A (DIESEL) AVERAGE FLOW RATE ---")
s3a_flow = s3a['calculated_flow_rate'].dropna()
s3a_flow_valid = s3a_flow[(s3a_flow > 0) & (s3a_flow < 500)]  # Remove outliers
print(f"Count: {len(s3a_flow_valid)}")
print(f"Mean: {s3a_flow_valid.mean():.2f} L/min")
print(f"Median: {s3a_flow_valid.median():.2f} L/min")
print(f"Std: {s3a_flow_valid.std():.2f} L/min")
print(f"Min: {s3a_flow_valid.min():.2f} L/min")
print(f"Max: {s3a_flow_valid.max():.2f} L/min")

print("\n--- S3B (GASOHOL95) AVERAGE FLOW RATE ---")
s3b_flow = s3b['calculated_flow_rate'].dropna()
s3b_flow_valid = s3b_flow[(s3b_flow > 0) & (s3b_flow < 500)]  # Remove outliers
print(f"Count: {len(s3b_flow_valid)}")
print(f"Mean: {s3b_flow_valid.mean():.2f} L/min")
print(f"Median: {s3b_flow_valid.median():.2f} L/min")
print(f"Std: {s3b_flow_valid.std():.2f} L/min")
print(f"Min: {s3b_flow_valid.min():.2f} L/min")
print(f"Max: {s3b_flow_valid.max():.2f} L/min")

# ============================================================
# 6) GROUNDING TIME STATISTICS
# ============================================================
print("\n" + "="*70)
print("6) GROUNDING TIME STATISTICS (NEW COLUMN)")
print("="*70)

print("\n--- S3A (DIESEL) GROUNDING TIME ---")
if 'grounding time' in s3a.columns:
    s3a_grounding = s3a['grounding time'].dropna()
    print(f"Count: {len(s3a_grounding)}")
    print(f"Mean: {s3a_grounding.mean():.2f} min")
    print(f"Median: {s3a_grounding.median():.2f} min")
    print(f"Std: {s3a_grounding.std():.2f} min")
    print(f"Min: {s3a_grounding.min():.2f} min")
    print(f"Max: {s3a_grounding.max():.2f} min")
    print(f"In range [3-6]: {len(s3a_grounding[(s3a_grounding >= 3) & (s3a_grounding <= 6)])} / {len(s3a_grounding)}")
else:
    print("Grounding time column not found")

print("\n--- S3B (GASOHOL95) GROUNDING TIME ---")
if 'grounding time' in s3b.columns:
    s3b_grounding = s3b['grounding time'].dropna()
    print(f"Count: {len(s3b_grounding)}")
    print(f"Mean: {s3b_grounding.mean():.2f} min")
    print(f"Median: {s3b_grounding.median():.2f} min")
    print(f"Std: {s3b_grounding.std():.2f} min")
    print(f"Min: {s3b_grounding.min():.2f} min")
    print(f"Max: {s3b_grounding.max():.2f} min")
    print(f"In range [3-6]: {len(s3b_grounding[(s3b_grounding >= 3) & (s3b_grounding <= 6)])} / {len(s3b_grounding)}")
else:
    print("Grounding time column not found")

print("\n" + "="*70)
print("ANALYSIS COMPLETE")
print("="*70)
