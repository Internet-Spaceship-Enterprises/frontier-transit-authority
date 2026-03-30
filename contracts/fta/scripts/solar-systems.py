#!/usr/bin/env python3

import requests
import math


API_URL = "https://world-api-utopia.uat.pub.evefrontier.com/v2/solarsystems"
OUTPUT_FILE = "solar-systems.move"
PAGE_LIMIT = 1000

def process_item(item: dict) -> str:
    """
    Replace this with your real processing logic.
    Must return a string for each item.
    """
    return f"""        {item['id']} => SolarSystem{{
            id: {item['id']},
            name: b"{item['name']}".to_string(),
            constellationId: {item['constellationId']},
            regionId: {item['regionId']},
            location_x: b"{item['location']['x']}".to_string(),
            location_y: b"{item['location']['y']}".to_string(),
            location_z: b"{item['location']['z']}".to_string(),
        }},"""

def fetch_all_items() -> list[dict]:
    items: list[dict] = []
    offset = 0
    page_idx = 1

    while True:
        response = requests.get(
            API_URL,
            params={
                "limit": PAGE_LIMIT,
                "offset": offset,
            },
            timeout=30,
        )
        response.raise_for_status()
        payload = response.json()

        page_data = payload.get("data", [])
        metadata = payload.get("metadata", {})

        items.extend(page_data)

        total = metadata.get("total", 0)
        limit = metadata.get("limit", PAGE_LIMIT)
        offset = metadata.get("offset", offset) + limit

        pages = math.ceil(total / limit)
        print(f"Fetched page {page_idx} of {pages}")

        if len(items) >= total or not page_data:
            break

        page_idx += 1

    return items


def main() -> None:
    all_items = fetch_all_items()

    output_parts = []
    for item in all_items:
        result = process_item(item)
        output_parts.append(result)

    content = "\n".join(output_parts)

    final_output = f"""module fta::solar_systems;

#[error(code = 1)]
const EUnknownSolarSystem: vector<u8> =
    b"Unknown solar system";

public struct SolarSystem has copy, drop, store {{
    id: u64,
    name: std::string::String,
    constellationId: u64,
    regionId: u64,
    location_x: std::string::String,
    location_y: std::string::String,
    location_z: std::string::String,
}}

public fun name(solar_system: &SolarSystem): std::string::String {{
    solar_system.name
}}

public fun lookup(id: u64): SolarSystem {{
    match (id) {{
{content}
        _0 => abort EUnknownSolarSystem
    }}
}}"""
    

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write(final_output)

    print(f"Wrote {len(all_items)} processed items to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()