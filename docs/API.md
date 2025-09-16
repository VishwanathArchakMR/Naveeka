Note:

All endpoints are prefixed by API_BASE_URL from .env (e.g., https://api.soultrail.com).

All requests and responses are JSON.

Authenticated endpoints expect a Bearer token in the Authorization header:
Authorization: Bearer <JWT>

Standard response envelope (recommended):
{
"success": true,
"data": ...,
"message": "optional"
}
On error:
{
"success": false,
"message": "Human readable error",
"code": "OPTIONAL_ERROR_CODE"
}

Dates should be ISO8601: 2025-08-14T10:22:00.000Z

Place object schema used across endpoints:
{
"_id": "string",
"name": "string",
"description": "string",
"category": "string",
"emotion": "peaceful", // normalized to EmotionKind names (lowercase, underscores/spaces allowed)
"coverImage": "https://cdn.../image.jpg",
"gallery": ["https://cdn.../1.jpg","https://cdn.../2.jpg"],
"isApproved": true,
"isWishlisted": true, // computed per current user where relevant
"ambientAudio": "https://cdn.../ambient.mp3",
"latitude": 28.6139,
"longitude": 77.2090,
"createdAt": "2025-05-01T12:00:00.000Z",
"updatedAt": "2025-05-10T15:30:00.000Z"
}

Supported emotion values (for emotion_theme.dart mapping):

peaceful, adventurous, romantic, spiritual, energetic, nostalgic, joyful, calm, vibrant, heritage
Backend may send snake_case or spaced values; frontend normalizes.

Auth

1.1 POST /auth/login

Description: Login with email and password; returns JWT.

Body:
{
"email": "user@example.com",
"password": "secret"
}

Response:
{
"success": true,
"data": {
"token": "jwt_token_string",
"user": {
"_id": "user_id",
"name": "User Name",
"email": "user@example.com",
"avatar": "https://cdn.../avatar.png"
}
}
}

1.2 POST /auth/register

Description: Register a new user account.

Body:
{
"name": "User Name",
"email": "user@example.com",
"password": "secret"
}

Response:
{
"success": true,
"data": {
"token": "jwt_token_string",
"user": { ...same as login.user }
}
}

1.3 GET /auth/profile

Description: Get current user profile (auth required).

Headers: Authorization: Bearer <JWT>

Response:
{
"success": true,
"data": {
"_id": "user_id",
"name": "User Name",
"email": "user@example.com",
"avatar": "https://cdn.../avatar.png"
}
}

Places

2.1 GET /places

Description: List places with optional filters. Public endpoint; if authenticated, backend may include isWishlisted per user.

Query params (all optional):

page: number (default 1)

limit: number (default 20)

emotion: string (e.g., peaceful)

category: string

approved: boolean (true/false)

search: string (free text)

Response:
{
"success": true,
"data": [
{ Place }, { Place }, ...
],
"pagination": {
"page": 1,
"limit": 20,
"total": 125
}
}

2.2 GET /places/:id

Description: Get a single place by ID.

Route: /places/PLACE_ID

Response:
{
"success": true,
"data": { Place }
}

Note: If the user is authenticated, the backend should set isWishlisted for that user.

Wishlist

Base path used by frontend: AppConstants.apiWishlist → /wishlist

All wishlist endpoints require auth.

3.1 GET /wishlist

Description: Get current user’s wishlisted places.

Headers: Authorization: Bearer <JWT>

Response:
{
"success": true,
"data": [ { Place }, { Place } ]
}

Note: Each Place in the list should have isWishlisted=true.

3.2 POST /wishlist/:placeId

Description: Add a place to the current user’s wishlist.

Headers: Authorization: Bearer <JWT>

Route: /wishlist/PLACE_ID

Body (optional):
{
"notes": "optional user notes"
}

Response:
{
"success": true,
"message": "Added to wishlist"
}

3.3 DELETE /wishlist/:placeId

Description: Remove a place from the user’s wishlist.

Headers: Authorization: Bearer <JWT>

Route: /wishlist/PLACE_ID

Response:
{
"success": true,
"message": "Removed from wishlist"
}

Admin

All admin endpoints require admin authorization. Shape may vary; below is what the admin module expects minimally.

4.1 GET /admin/places

Description: List places for moderation (pending/approved).

Query params:

status: pending|approved|rejected (optional)

page, limit (optional)

Response:
{
"success": true,
"data": [ { Place }, ... ],
"pagination": { ... }
}

4.2 PATCH /admin/places/:id/approve

Description: Approve a place.

Response:
{
"success": true,
"message": "Place approved",
"data": { Place }
}

4.3 PATCH /admin/places/:id/reject

Description: Reject a place.

Response:
{
"success": true,
"message": "Place rejected",
"data": { Place }
}

Error Handling Conventions

Frontend expects human-readable errors via a consistent envelope. Examples:

401 Unauthorized
{
"success": false,
"message": "Unauthorized"
}

404 Not Found
{
"success": false,
"message": "Resource not found"
}

422 Validation error
{
"success": false,
"message": "Invalid input",
"errors": {
"email": ["Email already taken"],
"password": ["Password must be at least 8 characters"]
}
}

500 Server error
{
"success": false,
"message": "Something went wrong"
}

Frontend’s ApiResult and ErrorMapper will surface message to users; avoid leaking stack traces.

Authentication & Headers

Authenticated calls must include:
Authorization: Bearer <JWT>

Content-Type for JSON:
Content-Type: application/json

CORS: allow mobile app origins (for local device testing, typical mobile CORS issues are minimal, but ensure server CORS is permissive enough for dev tools if needed).

Media and URLs

All media URLs (coverImage, gallery, ambientAudio) should be absolute HTTPS URLs (recommended for iOS ATS).

CDN recommended for performance.

If you must support local/dev HTTP:

Android: configure network_security_config.xml

iOS: add Info.plist ATS domain exceptions (dev only)

Search & Filters (Places)

Common filters the frontend supports:

emotion: peaceful|adventurous|romantic|spiritual|energetic|nostalgic|joyful|calm|vibrant|heritage

category: freeform text (e.g., Beach, Forest, Temple)

approved: true/false

search: free text search on name/description/category

pagination: page, limit

Backend should return total count for pagination if possible.

Security & Performance Recommendations

Use HTTPS everywhere (production).

Implement rate limiting on auth and write endpoints.

Validate placeId on wishlist endpoints (404 if not found).

Return only fields required by frontend to keep payloads lean.

Send cache headers for places list/details where appropriate.

Support ETags/If-None-Match or last-modified for places list (optional optimization).

Sanitize/normalize emotion to accepted set on write; normalize to frontend’s set on read.

Example Workflows

10.1 Load Explore places

GET /places?approved=true&limit=20&page=1

Response: list of Place objects; if user logged in, isWishlisted should reflect current user.

10.2 View Place details

GET /places/:id

Response: Place with full fields; if logged in, isWishlisted accurate for that user.

10.3 Toggle Wishlist

If isWishlisted=false → POST /wishlist/:placeId

If isWishlisted=true → DELETE /wishlist/:placeId

10.4 Wishlist screen

GET /wishlist

Response: array of Place; each should include isWishlisted=true.

Environment Variables (Frontend)

The frontend reads these keys from .env:

API_BASE_URL: base API URL, e.g., https://api.soultrail.com

APP_NAME: used in UI

GOOGLE_MAPS_API_KEY: optional for future maps features

ASSETS_BASE_URL: optional for CDN paths if needed

Ensure API_BASE_URL is reachable from devices and uses HTTPS in production.

Status Codes

Use standard HTTP status codes:

200 OK for successful reads

201 Created for successful resource creation (optional)

204 No Content for successful deletes (optional; we also accept 200)

400/422 for validation errors

401 for unauthorized

403 for forbidden

404 for not found

409 for conflicts (e.g., already wishlisted)

500 for server errors

The frontend primarily reads the JSON envelope’s message; status codes should still match semantics.

Appendix A — Minimal Place Validation (server-side suggestion)

name: required, 2–120 chars

description: optional, up to 5,000 chars

category: optional, up to 60 chars

emotion: optional, must be in allowed set (normalize input)

coverImage: optional, URL

gallery: optional array of URL strings

ambientAudio: optional, URL

latitude/longitude: optional doubles

isApproved: boolean (admin-controlled)

timestamps set by server

Appendix B — Example Seed Data

Place example:
{
"_id": "plc_abc123",
"name": "Whispering Pines",
"description": "A tranquil forest escape with soft wind chimes and birdsong.",
"category": "Forest",
"emotion": "peaceful",
"coverImage": "https://cdn.soultrail.com/images/whispering_pines.jpg",
"gallery": [
"https://cdn.soultrail.com/images/wp_1.jpg",
"https://cdn.soultrail.com/images/wp_2.jpg"
],
"isApproved": true,
"isWishlisted": false,
"ambientAudio": "https://cdn.soultrail.com/audio/forest_breeze.mp3",
"latitude": 34.0522,
"longitude": -118.2437,
"createdAt": "2025-05-01T12:00:00.000Z",
"updatedAt": "2025-05-10T15:30:00.000Z"
}