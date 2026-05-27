# HAQMS — Bug Fix Documentation

**Assignment:** Figital Labs Full Stack Internship  
**Stack:** Next.js + Node.js + Express + PostgreSQL + Prisma  
**Total Issues Fixed:** 11

---

## My Approach

I read every file before touching anything. Grouped bugs into 
four categories — security, performance, concurrency, and schema 
— and fixed them in that order. Security first because a slow app 
is a bad experience, but a breached hospital system is a liability.

---

## Issues Found & Fixed

### 1. Broken Admin Authorization
**File:** `backend/src/middleware/auth.js`  
**Problem:** The `authorizeAdminOnlyLegacy` middleware had the role check commented out. Any logged-in user — even a receptionist — could delete patient records.  
**Fix:** Uncommented the role check so only `ADMIN` role can proceed.  
**Why it matters:** In a hospital, patient records getting deleted by unauthorized staff is a serious compliance issue.

---

### 2. Plaintext Password in Logs
**File:** `backend/src/routes/auth.js`  
**Problem:** Every login attempt logged the raw password to the console. Anyone with server log access could see all passwords.  
**Fix:** Removed the `console.log` lines that included `req.body.password`.

---

### 3. Password Hash Returned in API Response
**File:** `backend/src/routes/auth.js`  
**Problem:** The register endpoint returned the full user object including the hashed password. Attackers can run offline brute force attacks against hashes.  
**Fix:** Explicitly selected only `id`, `email`, `name`, `role` in the response.

---

### 4. Hardcoded JWT Secret + Ignored Expiration
**File:** `backend/src/middleware/auth.js`, `backend/src/routes/auth.js`  
**Problem:** JWT secret had a hardcoded fallback. Token expiry was set to 365 days. `ignoreExpiration: true` meant expired tokens still worked.  
**Fix:** Removed the fallback (server throws if `JWT_SECRET` env is missing). Set expiry to `8h` (one hospital shift). Removed `ignoreExpiration`.  
**Why it matters:** A doctor who leaves the hospital should lose access at end of shift, not a year later.

---

### 5. SQL Injection
**File:** `backend/src/routes/doctors.js`  
**Problem:** Search query was directly concatenated into a raw SQL string using `$queryRawUnsafe`. An attacker could dump the entire users table including password hashes.  
**Fix:** Replaced with Prisma's `findMany({ where })` which uses parameterized queries internally. User input never touches the SQL string.

---

### 6. N+1 Query Problem
**File:** `backend/src/routes/appointments.js`  
**Problem:** For every appointment, two separate DB queries ran to fetch the patient and doctor. 100 appointments = 201 DB queries.  
**Fix:** Used Prisma's `include` to fetch patient and doctor in a single JOIN query.

---

### 7. In-Memory Pagination
**File:** `backend/src/routes/patients.js`  
**Problem:** All patients were loaded into Node.js memory, filtered in JavaScript, then paginated. At scale this would crash the server.  
**Fix:** Moved filtering, searching, and pagination to the database using `where`, `skip`, and `take`.

---

### 8. Sequential DB Calls in Reports
**File:** `backend/src/routes/reports.js`  
**Problem:** For each doctor, 4 database queries ran one after another. With an added 80ms artificial sleep per doctor, this scaled terribly.  
**Fix:** Replaced with `Promise.all()` so all 4 queries fire simultaneously. Also removed the redundant `findMany` call — reused the count for revenue calculation instead.

---

### 9. Sequential DB Calls in Doctor Stats
**File:** `backend/src/routes/doctors.js`  
**Problem:** 4 independent aggregate queries ran sequentially with separate `await` calls.  
**Fix:** Replaced with `Promise.all()`.

---

### 10. Memory Leak in Queue Page
**File:** `frontend/src/app/queue/page.js`  
**Problem:** `setInterval` inside `useEffect` had no cleanup function. Every time the user navigated to the queue page, a new interval was created and never cleared — eventually dozens of intervals would poll the server simultaneously.  
**Fix:** Added `return () => clearInterval(intervalId)` as the cleanup function.

---

### 11. Hardcoded API URL
**File:** `frontend/src/context/AuthContext.js`, `frontend/src/app/queue/page.js`  
**Problem:** Backend URL was hardcoded as `http://localhost:5000/api` in two places. Impossible to deploy without editing source code.  
**Fix:** Replaced with `process.env.NEXT_PUBLIC_API_URL` and added it to `.env.local`.

---

### 12. Missing Database Indexes
**File:** `backend/prisma/schema.prisma`  
**Problem:** No indexes on commonly queried columns like `doctorId`, `status`, `createdAt`. At scale these queries do full table scans.  
**Fix:** Added indexes on `Doctor` (specialization, department), `Appointment` (doctorId+status, patientId, appointmentDate), `QueueToken` (doctorId+createdAt, status).

---

### 13. Queue Check-in Race Condition
**File:** `backend/src/routes/queue.js`  
**Problem:** Token number generation was a two-step read-then-insert with a 350ms artificial sleep in between. Two concurrent requests could read the same max token and both insert the same token number.  
**Fix:** Wrapped the read and insert in a `prisma.$transaction()` so they execute atomically. Removed the artificial sleep.

---

## Known Remaining Issues

- **Double booking** — appointment duplicate check is millisecond-exact. A proper fix would add a `@@unique([doctorId, appointmentDate])` constraint with time-slot rounding logic.
- **No rate limiting** — login endpoint has no brute force protection. Should add `express-rate-limit`.
- **No input validation library** — phone numbers accept any string. Should add `zod` or `joi` for schema validation.
- **CORS** — still open to all origins. Should whitelist the frontend domain in production.
- **No debounce on search** — frontend still fires API call on every keystroke. Should add 300ms debounce.

---

## What I Prioritized and Why

Security bugs first — a slow app is a bad experience, a breached hospital system is a legal and ethical disaster. Within security, I fixed authorization before SQL injection because a broken access control affects every single endpoint, while SQL injection requires an attacker to actively exploit it.

Performance second — N+1 and in-memory pagination are the ones that silently kill apps at scale. Most developers don't notice them until production traffic hits.

Concurrency last — the race condition is real but requires simultaneous requests to trigger. Less likely in a small hospital, but still wrong.
