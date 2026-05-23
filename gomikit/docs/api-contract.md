# GomiKit API Contract Draft

Base path: `/api/v1`

## Mobile App

### `GET /areas/resolve`

Resolve the user location to a Japanese waste-rule area.

Query:

- `lat`
- `lng`
- `locale`

Response:

```json
{
  "area": {
    "id": "shibuya",
    "prefecture": "Tokyo",
    "municipality": "Shibuya",
    "town": "Jinnan 1-chome",
    "sourceUpdatedAt": "2026-05-10"
  }
}
```

### `GET /areas/:areaId/today`

Return today's collection rules and reminder metadata.

Response:

```json
{
  "date": "2026-05-23",
  "timezone": "Asia/Tokyo",
  "items": [
    {
      "ruleId": "pet-bottle",
      "displayName": "PET 塑料瓶",
      "category": "recyclable",
      "collectionText": "周三",
      "disposalTime": "当天 8:00 前"
    }
  ]
}
```

### `GET /areas/:areaId/waste-rules/search`

Search waste rules by item name, alias, or category.

Query:

- `q`
- `locale`

### `GET /waste-rules/:ruleId`

Return full disposal instructions, including washing, labels, caps, bag, location, and hazards.

### `POST /feedback`

Submit user correction feedback.

Body:

```json
{
  "areaId": "shibuya",
  "ruleId": "pet-bottle",
  "locale": "zh",
  "message": "The PDF says bottle caps are collected separately."
}
```

## QR Pages

### `POST /qr-pages`

Create a public QR garbage instruction page for a host or shop.

### `GET /qr-pages/:slug`

Return public multilingual QR page data. This endpoint must not require sign-in.

### `POST /qr-pages/:slug/images`

Upload up to three garbage-area photos. Images should be compressed, orientation-corrected, and captioned before publishing.

## AI Ingestion

### `POST /admin/ingestion/jobs`

Create an official-source ingestion job.

Body:

```json
{
  "areaId": "shibuya",
  "seedUrls": ["https://www.city.shibuya.tokyo.jp/..."],
  "locales": ["zh", "ja", "en", "ko"]
}
```

Pipeline:

1. Search official municipal pages.
2. Fetch HTML and PDF content.
3. Extract structured waste rules.
4. Translate locale fields.
5. Persist reusable area rules.
6. Mark sources as verified or stale.
