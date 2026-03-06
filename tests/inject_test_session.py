#!/usr/bin/env python3
"""
Inject a realistic long workout session into the iPhone simulator's App Group.

This writes directly to sessions.json in the shared container, simulating what
WatchConnectivity would deliver after a real workout. The iPhone app picks up
new sessions from App Group on foreground via DataManager.loadSessionsFromAppGroup().

Usage:
    python3 tests/inject_test_session.py --duration-min 110 --distance-km 13
    python3 tests/inject_test_session.py  # defaults: 110 min, 13 km
"""

import argparse
import json
import math
import os
import random
import subprocess
import sys
import uuid
from datetime import datetime, timedelta, timezone

# Apple reference date: Jan 1, 2001 00:00:00 UTC
APPLE_REF = datetime(2001, 1, 1, tzinfo=timezone.utc)

# iPhone simulator App Group path
APP_GROUP_PATH = (
    "/Users/sergeymuzyukin/Library/Developer/CoreSimulator/Devices/"
    "532CEF41-FFB9-44D3-9A92-3723EAC93A82/data/Containers/Shared/AppGroup/"
    "790B74BE-4237-49DB-9BF4-6D2B614A17E9"
)
SESSIONS_FILE = os.path.join(APP_GROUP_PATH, "sessions.json")
BUNDLE_ID = "com.shuttlx.ShuttlX"


def to_apple_timestamp(dt: datetime) -> float:
    """Convert datetime to Apple's timeIntervalSinceReferenceDate."""
    return (dt - APPLE_REF).total_seconds()


def gen_uuid() -> str:
    """Generate an uppercase UUID string matching Swift's UUID encoding."""
    return str(uuid.uuid4()).upper()


def generate_segments(start: datetime, duration_min: float, distance_km: float):
    """Generate alternating run/walk segments totaling the given duration."""
    segments = []
    elapsed = 0.0
    total_seconds = duration_min * 60
    total_distance_m = distance_km * 1000
    segment_count = 0

    while elapsed < total_seconds:
        # Alternate run/walk, starting with running
        is_run = segment_count % 2 == 0
        activity = "running" if is_run else "walking"

        # Segment duration: 2-8 min for runs, 1-4 min for walks
        if is_run:
            seg_dur = random.uniform(3 * 60, 8 * 60)
        else:
            seg_dur = random.uniform(1 * 60, 4 * 60)

        # Clamp to remaining time
        seg_dur = min(seg_dur, total_seconds - elapsed)
        if seg_dur < 10:
            break

        seg_start = start + timedelta(seconds=elapsed)
        seg_end = start + timedelta(seconds=elapsed + seg_dur)

        # Distribute distance proportionally, with runs getting more per second
        run_speed_factor = 2.5 if is_run else 1.0
        seg_distance = None  # Will be set after all segments generated

        seg = {
            "id": gen_uuid(),
            "activityType": activity,
            "startDate": to_apple_timestamp(seg_start),
            "endDate": to_apple_timestamp(seg_end),
            "_duration": seg_dur,
            "_is_run": is_run,
        }
        segments.append(seg)

        elapsed += seg_dur
        segment_count += 1

    # Distribute distance across segments weighted by speed
    total_weight = sum(
        s["_duration"] * (2.5 if s["_is_run"] else 1.0) for s in segments
    )
    for seg in segments:
        weight = seg["_duration"] * (2.5 if seg["_is_run"] else 1.0)
        seg_dist = (weight / total_weight) * total_distance_m
        seg["distance"] = round(seg_dist, 1)
        seg["steps"] = int(seg_dist / (0.85 if seg["_is_run"] else 0.65))
        # Clean up internal keys
        del seg["_duration"]
        del seg["_is_run"]

    return segments


def generate_route_points(start: datetime, duration_min: float, distance_km: float):
    """Generate GPS route points along a loop path (one point every ~30s)."""
    points = []
    total_seconds = duration_min * 60
    interval = 30  # seconds between points
    n_points = int(total_seconds / interval)

    # Start near San Francisco's Golden Gate Park
    base_lat = 37.7694
    base_lon = -122.4862

    # Create a roughly elliptical loop
    # Total circumference ~ distance_km, so radius ~ distance / (2*pi)
    radius_lat = distance_km / (2 * math.pi * 111.0)  # 111 km per degree lat
    radius_lon = radius_lat * 1.3  # stretch horizontally

    for i in range(n_points):
        t = i / max(n_points - 1, 1)
        angle = 2 * math.pi * t

        # Add some noise to make it realistic
        noise_lat = random.gauss(0, 0.00003)
        noise_lon = random.gauss(0, 0.00003)

        lat = base_lat + radius_lat * math.sin(angle) + noise_lat
        lon = base_lon + radius_lon * math.cos(angle) + noise_lon

        # Altitude varies 10-60m with gentle hills
        alt = 25 + 20 * math.sin(angle * 3) + random.uniform(-2, 2)

        ts = start + timedelta(seconds=i * interval)

        # Speed: ~2.5-4 m/s running, ~1.2-1.8 m/s walking
        # Approximate based on position in workout
        speed = random.uniform(1.5, 3.5)

        point = {
            "latitude": round(lat, 6),
            "longitude": round(lon, 6),
            "altitude": round(alt, 1),
            "timestamp": to_apple_timestamp(ts),
            "speed": round(speed, 2),
            "horizontalAccuracy": round(random.uniform(3, 12), 1),
        }
        points.append(point)

    return points


def generate_km_splits(duration_min: float, distance_km: float):
    """Generate per-km split times."""
    splits = []
    n_km = int(distance_km)
    avg_pace_sec = (duration_min * 60) / distance_km  # seconds per km

    cumulative = 0.0
    for km in range(1, n_km + 1):
        # Vary pace ±15% to simulate natural variation
        split_time = avg_pace_sec * random.uniform(0.85, 1.15)
        cumulative += split_time

        splits.append({
            "id": gen_uuid(),
            "kmNumber": km,
            "splitTime": round(split_time, 2),
            "cumulativeTime": round(cumulative, 2),
        })

    return splits


def generate_session(duration_min: float, distance_km: float) -> dict:
    """Generate a complete TrainingSession dictionary."""
    # Workout happened "today", ending ~30 minutes ago
    end_time = datetime.now(timezone.utc) - timedelta(minutes=30)
    start_time = end_time - timedelta(minutes=duration_min)

    segments = generate_segments(start_time, duration_min, distance_km)
    route = generate_route_points(start_time, duration_min, distance_km)
    km_splits = generate_km_splits(duration_min, distance_km)

    total_steps = sum(s.get("steps", 0) for s in segments)
    total_distance = sum(s.get("distance", 0) for s in segments)

    # Heart rate: avg ~138, max ~172
    avg_hr = round(random.uniform(132, 144), 1)
    max_hr = round(random.uniform(168, 178), 1)

    # Calories: ~7-9 kcal/min for mixed run/walk
    calories = round(duration_min * random.uniform(7.2, 8.5), 1)

    session = {
        "id": gen_uuid(),
        "startDate": to_apple_timestamp(start_time),
        "endDate": to_apple_timestamp(end_time),
        "duration": duration_min * 60,
        "averageHeartRate": avg_hr,
        "maxHeartRate": max_hr,
        "caloriesBurned": calories,
        "distance": round(total_distance, 1),
        "totalSteps": total_steps,
        "segments": segments,
        "route": route,
        "kmSplits": km_splits,
        "sportType": "running",
        "modifiedDate": to_apple_timestamp(end_time),
    }

    return session


def inject_session(session: dict):
    """Read existing sessions.json, append the new session, write back."""
    existing = []
    if os.path.exists(SESSIONS_FILE):
        try:
            with open(SESSIONS_FILE, "r") as f:
                existing = json.load(f)
            if not isinstance(existing, list):
                existing = []
        except (json.JSONDecodeError, IOError):
            existing = []

    existing.append(session)

    with open(SESSIONS_FILE, "w") as f:
        json.dump(existing, f, indent=2)

    return len(existing)


def foreground_app():
    """Bring the iPhone app to foreground to trigger session reload."""
    try:
        subprocess.run(
            ["xcrun", "simctl", "launch", "booted", BUNDLE_ID],
            capture_output=True,
            text=True,
            timeout=10,
        )
        print("  App launched/foregrounded in simulator")
    except Exception as e:
        print(f"  Warning: could not foreground app: {e}")
        print(f"  Manually tap the app in the simulator to trigger reload")


def print_summary(session: dict, total_count: int):
    """Print a human-readable summary of the injected session."""
    duration_min = session["duration"] / 60
    segments = session["segments"]
    run_segs = [s for s in segments if s["activityType"] == "running"]
    walk_segs = [s for s in segments if s["activityType"] == "walking"]

    run_time = sum(
        s["endDate"] - s["startDate"] for s in run_segs
    )
    walk_time = sum(
        s["endDate"] - s["startDate"] for s in walk_segs
    )

    print("\n" + "=" * 60)
    print("  INJECTED TEST SESSION")
    print("=" * 60)
    print(f"  ID:             {session['id']}")
    print(f"  Duration:       {duration_min:.0f} min")
    print(f"  Distance:       {session['distance']:.1f} m ({session['distance']/1000:.1f} km)")
    print(f"  Total Steps:    {session['totalSteps']}")
    print(f"  Avg HR:         {session['averageHeartRate']:.0f} bpm")
    print(f"  Max HR:         {session['maxHeartRate']:.0f} bpm")
    print(f"  Calories:       {session['caloriesBurned']:.0f} kcal")
    print(f"  Sport:          {session.get('sportType', 'N/A')}")
    print(f"  Segments:       {len(segments)} ({len(run_segs)} run, {len(walk_segs)} walk)")
    print(f"  Run time:       {run_time/60:.1f} min")
    print(f"  Walk time:      {walk_time/60:.1f} min")
    print(f"  Route points:   {len(session.get('route', []))}")
    print(f"  Km splits:      {len(session.get('kmSplits', []))}")
    print(f"  Sessions file:  {total_count} total sessions")
    print("=" * 60)


def main():
    parser = argparse.ArgumentParser(
        description="Inject a test workout session into iPhone simulator App Group"
    )
    parser.add_argument(
        "--duration-min",
        type=float,
        default=110,
        help="Workout duration in minutes (default: 110)",
    )
    parser.add_argument(
        "--distance-km",
        type=float,
        default=13,
        help="Total distance in kilometers (default: 13)",
    )
    parser.add_argument(
        "--no-foreground",
        action="store_true",
        help="Don't try to foreground the app after injection",
    )
    args = parser.parse_args()

    # Verify App Group exists
    if not os.path.isdir(APP_GROUP_PATH):
        print(f"ERROR: App Group directory not found at:\n  {APP_GROUP_PATH}")
        print("Make sure the iPhone simulator has the app installed.")
        sys.exit(1)

    print(f"Generating {args.duration_min:.0f}-min, {args.distance_km:.0f}-km session...")
    session = generate_session(args.duration_min, args.distance_km)

    print(f"Injecting into: {SESSIONS_FILE}")
    total = inject_session(session)

    print_summary(session, total)

    if not args.no_foreground:
        print("\nForegrounding app to trigger reload...")
        foreground_app()

    print("\nDone! Open History tab to verify the session appears.")


if __name__ == "__main__":
    main()
