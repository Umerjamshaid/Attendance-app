Here you go — clean, professional, and ready to send or drop into your repo as `api.md` 📄✨

---

```md
# 📡 Attendance App API Documentation

## 🎯 Overview
This document defines the required API endpoints for the Flutter Attendance App.

The mobile app will:
- Authenticate employees
- Mark attendance with device + location data
- Handle offline scenarios with sync support

---

# 🔐 1. Authentication

## ➤ Login

**Endpoint:**
```

POST /api/auth/login

````

**Description:**
Authenticates employee and returns access + refresh tokens.

**Request:**
```json
{
  "employee_id": "EMP001",
  "password": "123456"
}
````

**Response:**

```json
{
  "access_token": "jwt_access_token",
  "refresh_token": "jwt_refresh_token",
  "employee_id": "EMP001",
  "name": "John Doe",
  "expires_in_minutes": 30
}
```

---

## ➤ Refresh Token

**Endpoint:**

```
POST /api/auth/refresh
```

**Description:**
Generates a new access token when the old one expires.

**Request:**

```json
{
  "refresh_token": "jwt_refresh_token"
}
```

**Response:**

```json
{
  "access_token": "new_access_token",
  "expires_in_minutes": 30
}
```

---

# ✅ 2. Attendance

## ➤ Mark Attendance

**Endpoint:**

```
POST /api/attendance/mark
```

**Headers:**

```
Authorization: Bearer {access_token}
```

**Description:**
Marks employee attendance with device, location, and timestamp.

**Request:**

```json
{
  "employee_id": "EMP001",
  "device_id": "android_abc123",
  "latitude": 24.8607,
  "longitude": 67.0011,
  "accuracy_meters": 15.5,
  "timestamp": "2026-04-05T09:00:00",
  "request_id": "uuid-12345"
}
```

**Response (Success):**

```json
{
  "success": true,
  "marked_at": "2026-04-05T09:00:03",
  "message": "Attendance marked successfully"
}
```

**Response (Duplicate):**

```json
{
  "error": "Attendance already marked today"
}
```

---

## ➤ Sync Offline Records

**Endpoint:**

```
POST /api/attendance/sync
```

**Headers:**

```
Authorization: Bearer {access_token}
```

**Description:**
Uploads locally stored attendance records when device was offline.

**Request:**

```json
{
  "records": [
    {
      "id": "uuid-123",
      "employee_id": "EMP001",
      "device_id": "android_abc123",
      "latitude": 24.8607,
      "longitude": 67.0011,
      "timestamp": "2026-04-05T09:00:00"
    }
  ]
}
```

**Response:**

```json
{
  "synced": [
    {
      "id": "uuid-123",
      "success": true
    }
  ],
  "failed": []
}
```

---

# 📊 3. Optional Endpoints

## ➤ Attendance History

**Endpoint:**

```
GET /api/attendance/history
```

**Headers:**

```
Authorization: Bearer {access_token}
```

**Description:**
Returns employee attendance history.

**Response:**

```json
[
  {
    "date": "2026-04-05",
    "check_in": "09:00",
    "location": "Office"
  }
]
```

---

## ➤ Logout (Optional)

**Endpoint:**

```
POST /api/auth/logout
```

**Description:**
Invalidates session (optional, depends on backend).

---

# ⚠️ Important Backend Requirements

## 🔐 Security

* Use JWT authentication (access + refresh tokens)
* All endpoints must require HTTPS
* Do not trust client data blindly

## 📍 Validation

* Validate:

  * device_id
  * location (latitude/longitude)
  * timestamp
* Implement geofencing (restrict attendance to allowed areas)

## 🔁 Idempotency

* Use `request_id` to prevent duplicate attendance submissions

## 📶 Offline Support

* Support batch syncing of attendance records
* Handle duplicate sync requests safely

## 🚫 Rate Limiting

* Prevent spam (e.g., max 5 attendance requests per minute)

---

# 🎯 Summary

| Feature            | Endpoint                    |
| ------------------ | --------------------------- |
| Login              | POST /api/auth/login        |
| Refresh Token      | POST /api/auth/refresh      |
| Mark Attendance    | POST /api/attendance/mark   |
| Sync Offline Data  | POST /api/attendance/sync   |
| Attendance History | GET /api/attendance/history |

---

# 🚀 Notes

* Backend is responsible for **final validation**
* Mobile app only **collects and sends data**
* System should be designed for **1000+ employees scale**

---

```

---

If you want next:
- I can turn this into a **Postman collection**
- Or simulate this API so you can start coding without waiting

Just say the word 😏
```

---

## Endpoints List

- POST /api/auth/login
- POST /api/auth/refresh
- POST /api/attendance/mark
- POST /api/attendance/sync
- GET /api/attendance/history
- POST /api/auth/logout
