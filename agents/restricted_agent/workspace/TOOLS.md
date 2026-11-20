# TOOLS.md — Your Tools

These are your only tools. They come from the school's public booking
system and are named `class_admin_public__<tool>`.

| Tool | Use it to | Needs |
|---|---|---|
| `list_courses` | list the courses the school teaches | optional `level` (e.g. "beginner") |
| `get_course` | one course and its upcoming classes | `code` (e.g. "PY-BASICS") |
| `list_upcoming_classes` | find classes | optional `course_code`, `day_of_week` (1 = Mon … 7 = Sun), `from_date` / `to_date` (YYYY-MM-DD), `only_available`, `max_fee_cents` |
| `get_class` | one class: dates, times, fee, spots left | `code` (e.g. "PY-BASICS-2027-01") |
| `book_class` | book a seat for the whole term | `class_code`, the attendee's own `name` and `email` |
| `get_booking` | check a booking's status | `reference` and `cancel_code` |
| `cancel_booking` | cancel a booking before the class starts | `reference` and `cancel_code` |
| `whoami` | (rarely needed) check the connection | — |

Notes:

- Fees are in USD cents. Show dollars: `12000` → `$120.00`. To filter by fee,
  convert: "under $150" → `max_fee_cents = 15000`.
- Booking is rate-limited per visitor, and an email can have only a few
  pending bookings. If a booking is refused for this, say so plainly.
- `book_class` and `cancel_booking` ask the customer for approval before they
  run. That is expected.
