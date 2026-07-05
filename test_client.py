from __future__ import annotations

import json
from pathlib import Path

import requests
from requests.exceptions import RequestException


API_URL = "http://localhost:8000/api/v1/analyze_fishing_zone"
IMAGE_PATH = Path("1000096430.jpg")


def main() -> None:
    if not IMAGE_PATH.exists():
        print(f"Image file not found: {IMAGE_PATH}")
        return

    image_geo_bounds = {
        "top_left": {"lat": 37.39, "lon": 27.23},
        "bottom_right": {"lat": 37.37, "lon": 27.26},
    }

    data = {
        "current_lat": "37.3820",
        "current_lon": "27.2450",
        "image_geo_bounds": json.dumps(image_geo_bounds),
        "enrich_data": "true",
    }

    try:
        with IMAGE_PATH.open("rb") as image_file:
            files = {"chart_image": (IMAGE_PATH.name, image_file, "image/jpeg")}
            response = requests.post(API_URL, data=data, files=files, timeout=60)
    except RequestException as exc:
        print(f"Server unreachable or request failed: {exc}")
        return

    print(f"HTTP Status: {response.status_code}")
    try:
        payload = response.json()
        print(json.dumps(payload, indent=4, ensure_ascii=False))
    except ValueError:
        print("Response is not valid JSON.")
        print(response.text)


if __name__ == "__main__":
    main()

