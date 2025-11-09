// server.js — Conductor (clean, consolidated)
// @ts-check
require('dotenv').config();

const express = require('express');
const cookieParser = require('cookie-parser');
const { Pool } = require('pg');
const path = require('path');
const crypto = require('crypto');

const app = express();
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// ---------- Middleware ----------
app.use(express.json());
app.use(cookieParser());

// Serve static files in /public (images, html, css, js)
app.use(express.static(path.join(__dirname, 'public')));

// ---------- Demo sessions (cookie -> userId) ----------
const sessions = new Map(); // sid -> user_id

function setSession(res, userId) {
  const sid = crypto.randomUUID();
  sessions.set(sid, userId);
  res.cookie('sid', sid, {
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 1000 * 60 * 60 * 8, // 8 hours
    // secure: true, // enable under HTTPS
  });
}

function getUserIdFromCookie(req) {
  const sid = req.cookies.sid;
  if (!sid) return null;
  if (!sessions.has(sid)) return null;
  return sessions.get(sid);
}

// ---------- Auth middlewares ----------
function authAny(req, res, next) {
  const uid = getUserIdFromCookie(req);
  if (!uid) return res.status(401).json({ error: 'Unauthenticated' });
  req.userId = uid;
  next();
}

async function authProfessor(req, res, next) {
  const uid = getUserIdFromCookie(req);
  if (!uid) return res.status(401).json({ error: 'Unauthenticated' });

  const { rows } = await pool.query(
    `
    SELECT c.id AS course_id
    FROM role_assignments ra
    JOIN roles r ON r.id = ra.role_id AND r.key='professor'
    JOIN courses c ON c.id = ra.scope_id AND ra.scope_type='course'
    JOIN terms t   ON t.id = c.term_id
    WHERE ra.user_id = $1
    ORDER BY t.starts_on DESC NULLS LAST
    LIMIT 1;
    `,
    [uid]
  );
  if (!rows.length) return res.status(403).json({ error: 'Not a professor' });

  req.userId = uid;
  req.profCourseId = rows[0].course_id;
  next();
}

async function authTA(req, res, next) {
  const uid = getUserIdFromCookie(req);
  if (!uid) return res.status(401).json({ error: 'Unauthenticated' });

  const { rows } = await pool.query(
    `
    SELECT c.id AS course_id
    FROM role_assignments ra
    JOIN roles r ON r.id = ra.role_id AND r.key='ta'
    JOIN courses c ON c.id = ra.scope_id AND ra.scope_type='course'
    JOIN terms t   ON t.id = c.term_id
    WHERE ra.user_id = $1
    ORDER BY t.starts_on DESC NULLS LAST
    LIMIT 1;
    `,
    [uid]
  );
  if (!rows.length) return res.status(403).json({ error: 'Not a TA' });

  req.userId = uid;
  req.taCourseId = rows[0].course_id;
  next();
}

async function authTeamLeader(req, res, next) {
  const uid = getUserIdFromCookie(req);
  if (!uid) return res.status(401).json({ error: 'Unauthenticated' });

  const { rows } = await pool.query(
    `
    SELECT tm.team_id, t.course_id
    FROM team_members tm
    JOIN teams t ON t.id = tm.team_id
    JOIN courses c ON c.id = t.course_id
    JOIN terms te ON te.id = c.term_id
    WHERE tm.user_id = $1 AND tm.is_leader = TRUE
    ORDER BY te.starts_on DESC NULLS LAST, tm.joined_at DESC
    LIMIT 1;
    `,
    [uid]
  );
  if (!rows.length) return res.status(403).json({ error: 'Not a team leader' });

  req.userId = uid;
  req.teamId = rows[0].team_id;
  req.tlCourseId = rows[0].course_id;
  next();
}

// ---------- Helpers ----------
async function getRoleFlags(userId) {
  const { rows } = await pool.query(
    `
    SELECT
      EXISTS (
        SELECT 1 FROM role_assignments ra
        JOIN roles r ON r.id = ra.role_id
        WHERE ra.user_id = $1 AND r.key = 'professor'
      ) AS is_professor,
      EXISTS (
        SELECT 1 FROM role_assignments ra
        JOIN roles r ON r.id = ra.role_id
        WHERE ra.user_id = $1 AND r.key = 'ta'
      ) AS is_ta,
      EXISTS (
        SELECT 1 FROM team_members tm
        WHERE tm.user_id = $1 AND tm.is_leader = TRUE
      ) AS is_team_leader
    `,
    [userId]
  );
  return {
    is_professor: !!rows[0]?.is_professor,
    is_ta: !!rows[0]?.is_ta,
    is_team_leader: !!rows[0]?.is_team_leader,
  };
}

async function getUserTimeZone(userId) {
  const { rows } = await pool.query(
    `SELECT COALESCE(time_zone, 'America/Los_Angeles') AS tz FROM users WHERE id=$1`,
    [userId]
  );
  return rows[0]?.tz || 'America/Los_Angeles';
}

// ---------- Journal reply helpers (generic across roles) ----------
async function getJournalContext(journalId) {
  const { rows } = await pool.query(`
    WITH j AS (
      SELECT j.id, j.course_id, j.user_id AS student_id, COALESCE(j.reach_out_to,'none') AS reach_out_to
      FROM work_journals j
      WHERE j.id = $1
      LIMIT 1
    ),
    st AS (
      SELECT tm.team_id
      FROM j
      LEFT JOIN team_members tm
        ON tm.user_id = (SELECT student_id FROM j)
      LEFT JOIN teams t ON t.id = tm.team_id
      WHERE t.course_id = (SELECT course_id FROM j)
      ORDER BY tm.joined_at DESC NULLS LAST
      LIMIT 1
    )
    SELECT
      (SELECT id         FROM j)                  AS journal_id,
      (SELECT course_id  FROM j)                  AS course_id,
      (SELECT student_id FROM j)                  AS student_id,
      (SELECT reach_out_to FROM j)                AS reach_out_to,
      (SELECT team_id    FROM st)                 AS team_id
  `, [journalId]);
  return rows[0] || null;
}

async function isProfessorForCourse(userId, courseId) {
  const { rows } = await pool.query(`
    SELECT 1
    FROM role_assignments ra
    JOIN roles r ON r.id = ra.role_id AND r.key='professor'
    WHERE ra.user_id=$1 AND ra.scope_type='course' AND ra.scope_id=$2
    LIMIT 1
  `, [userId, courseId]);
  return !!rows.length;
}
async function isAssignedTAForTeam(userId, teamId) {
  if (!teamId) return false;
  const { rows } = await pool.query(`
    SELECT 1 FROM team_ta_assignments WHERE ta_user_id=$1 AND team_id=$2 LIMIT 1
  `, [userId, teamId]);
  return !!rows.length;
}
async function isLeaderOfTeam(userId, teamId) {
  if (!teamId) return false;
  const { rows } = await pool.query(`
    SELECT 1 FROM team_members WHERE user_id=$1 AND team_id=$2 AND is_leader=TRUE LIMIT 1
  `, [userId, teamId]);
  return !!rows.length;
}

async function canReplyToJournal(userId, ctx) {
  if (!ctx) return false;
  if (userId === ctx.student_id) return true;                          // student can continue their thread
  if (await isProfessorForCourse(userId, ctx.course_id)) return true;  // prof can reply to all

  if (ctx.reach_out_to === 'ta') {
    if (await isAssignedTAForTeam(userId, ctx.team_id)) return true;
  }
  if (ctx.reach_out_to === 'team_leader') {
    if (await isLeaderOfTeam(userId, ctx.team_id)) return true;
  }
  // 'professor' covered above; 'none' => only student & profs
  return false;
}

// ---------- Public-ish demo data ----------
app.get('/api/professor-demo', async (_req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT
        u.id AS user_id,
        u.display_name,
        u.pronouns,
        up.photo_url,
        up.phone,
        up.socials,
        t.code   AS term_code,
        t.name   AS term_name,
        c.id     AS course_id,
        c.code   AS course_code,
        c.title  AS course_title
      FROM courses c
      JOIN terms t ON t.id = c.term_id
      JOIN course_memberships cm ON cm.course_id = c.id
      JOIN users u ON u.id = cm.user_id
      LEFT JOIN user_profiles up ON up.user_id = u.id
      JOIN role_assignments ra
        ON ra.user_id = u.id
       AND ra.scope_type = 'course'
       AND ra.scope_id = c.id
      JOIN roles r ON r.id = ra.role_id AND r.key = 'professor'
      ORDER BY t.starts_on DESC NULLS LAST
      LIMIT 1;
    `);
    if (!rows.length) return res.status(404).json({ error: 'No professor found yet.' });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

app.get('/api/students', async (_req, res) => {
  try {
    const { rows } = await pool.query(`
      WITH latest AS (
        SELECT c.id AS course_id, t.starts_on
        FROM courses c
        JOIN terms t ON t.id = c.term_id
        WHERE c.code = 'CSE110'
        ORDER BY t.starts_on DESC NULLS LAST
        LIMIT 1
      )
      SELECT
        u.id,
        u.display_name,
        u.pronouns,
        COALESCE(up.photo_url, '') AS photo_url
      FROM latest
      JOIN course_memberships cm ON cm.course_id = latest.course_id
      JOIN users u ON u.id = cm.user_id
      LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE NOT EXISTS (
        SELECT 1
        FROM role_assignments ra
        JOIN roles r ON r.id = ra.role_id
        WHERE ra.user_id = u.id
          AND ra.scope_type = 'course'
          AND ra.scope_id = latest.course_id
          AND r.key = 'professor'
      )
      ORDER BY u.display_name ASC;
    `);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ---------- Auth ----------
app.post('/api/login', async (req, res) => {
  try {
    const username = (req.body?.username || '').trim();
    const password = (req.body?.password || '').trim();
    if (!username || !password) return res.status(400).json({ error: 'Username and password required.' });
    if (username !== password) return res.status(401).json({ error: 'Invalid credentials (demo uses name==password).' });

    const { rows } = await pool.query(
      `SELECT id FROM users WHERE LOWER(display_name)=LOWER($1) OR LOWER(email)=LOWER($1) LIMIT 1;`,
      [username]
    );
    if (!rows.length) return res.status(404).json({ error: 'No such user.' });

    const userId = rows[0].id;
    setSession(res, userId);
    const flags = await getRoleFlags(userId);
    res.json({ ok: true, ...flags });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

app.post('/api/logout', (req, res) => {
  const sid = req.cookies.sid;
  if (sid) sessions.delete(sid);
  res.clearCookie('sid');
  res.json({ ok: true });
});

// Anchor-friendly logout
app.get('/logout', (req, res) => {
  const sid = req.cookies.sid;
  if (sid) sessions.delete(sid);
  res.clearCookie('sid');
  res.redirect('/login.html');
});

// Who am I (+ latest course header info)
app.get('/api/session/me', authAny, async (req, res) => {
  try {
    const flags = await getRoleFlags(req.userId);
    const { rows } = await pool.query(`
      SELECT c.code AS course_code, c.title AS course_title, t.code AS term_code, t.name AS term_name
      FROM course_memberships cm
      JOIN courses c ON c.id = cm.course_id
      JOIN terms t ON t.id = c.term_id
      WHERE cm.user_id=$1
      ORDER BY t.starts_on DESC NULLS LAST, cm.created_at DESC
      LIMIT 1
    `, [req.userId]);
    const top = rows[0] || {};
    res.json({ user_id: req.userId, ...flags, ...top });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ---------- Student APIs ----------
app.get('/api/student/me', authAny, async (req, res) => {
  try {
    const userId = req.userId;
    const { is_professor } = await getRoleFlags(userId);

    const { rows } = await pool.query(
      `
      WITH my_latest_course AS (
        SELECT cm.course_id
        FROM course_memberships cm
        JOIN courses c ON c.id = cm.course_id
        JOIN terms t   ON t.id = c.term_id
        WHERE cm.user_id = $1
        ORDER BY t.starts_on DESC NULLS LAST, cm.created_at DESC
        LIMIT 1
      ),
      prof AS (
        SELECT u2.display_name AS professor_name
        FROM my_latest_course lc
        JOIN role_assignments ra
          ON ra.scope_type='course' AND ra.scope_id=lc.course_id
        JOIN roles r ON r.id=ra.role_id AND r.key='professor'
        JOIN users u2 ON u2.id=ra.user_id
        LIMIT 1
      )
      SELECT
        u.id AS user_id,
        u.display_name,
        u.pronouns,
        up.photo_url,
        c.id   AS course_id,
        c.code AS course_code,
        c.title AS course_title,
        t.code AS term_code,
        t.name AS term_name,
        (SELECT professor_name FROM prof) AS professor_name
      FROM users u
      LEFT JOIN user_profiles up ON up.user_id = u.id
      JOIN my_latest_course lc ON TRUE
      JOIN courses c ON c.id = lc.course_id
      JOIN terms t ON t.id = c.term_id
      WHERE u.id = $1
      LIMIT 1;
      `,
      [userId]
    );
    if (!rows.length) return res.status(404).json({ error: 'No course found for this user.' });

    res.json({ ...rows[0], is_professor });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

app.get('/api/student/schedules', authAny, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `
      WITH my_latest_course AS (
        SELECT cm.course_id
        FROM course_memberships cm
        JOIN courses c ON c.id = cm.course_id
        JOIN terms t   ON t.id = c.term_id
        WHERE cm.user_id = $1
        ORDER BY t.starts_on DESC NULLS LAST, cm.created_at DESC
        LIMIT 1
      )
      SELECT id, title, link, notes, created_at, deadline_at
      FROM schedules
      WHERE course_id = (SELECT course_id FROM my_latest_course)
      ORDER BY COALESCE(deadline_at, created_at) ASC, created_at DESC
      LIMIT 200;
      `,
      [req.userId]
    );
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ---------- Professor: schedules ----------
app.post('/api/schedules', authProfessor, async (req, res) => {
  try {
    const { title, deadline_at, link, notes } = req.body || {};
    if (!title || !title.trim()) return res.status(400).json({ error: 'Title required' });

    const { rows } = await pool.query(
      `
      INSERT INTO schedules (course_id, created_by, title, link, notes, deadline_at)
      VALUES ($1, $2, $3, NULLIF($4,''), NULLIF($5,''), $6::timestamptz)
      RETURNING id, title, link, notes, created_at, deadline_at;
      `,
      [req.profCourseId, req.userId, title.trim(), link || null, notes || null, deadline_at || null]
    );
    res.status(201).json(rows[0]);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Public schedules – latest CSE110
app.get('/api/schedules', async (_req, res) => {
  try {
    const { rows } = await pool.query(`
      WITH latest AS (
        SELECT c.id AS course_id
        FROM courses c
        JOIN terms t ON t.id = c.term_id
        WHERE c.code='CSE110'
        ORDER BY t.starts_on DESC NULLS LAST
        LIMIT 1
      )
      SELECT id, title, link, notes, created_at, deadline_at
      FROM schedules
      WHERE course_id = (SELECT course_id FROM latest)
      ORDER BY COALESCE(deadline_at, created_at) ASC, created_at DESC
      LIMIT 200;
    `);
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ---------- Attendance ----------
app.post('/api/student/attendance/today', authAny, async (req, res) => {
  try {
    const userId = req.userId;
    const tz = await getUserTimeZone(userId);

    const { rows: courseRows } = await pool.query(
      `
      SELECT cm.course_id
      FROM course_memberships cm
      JOIN courses c ON c.id = cm.course_id
      JOIN terms   t ON t.id = c.term_id
      WHERE cm.user_id = $1
      ORDER BY t.starts_on DESC NULLS LAST, cm.created_at DESC
      LIMIT 1;
      `,
      [userId]
    );
    if (!courseRows.length) return res.status(404).json({ error: 'No course found' });
    const courseId = courseRows[0].course_id;

    const { rows: todayRows } = await pool.query(
      `SELECT (now() AT TIME ZONE $1)::date AS today;`,
      [tz]
    );
    const attendedOn = todayRows[0].today;

    const { rows } = await pool.query(
      `
      INSERT INTO attendances (course_id, user_id, attended_on, source)
      VALUES ($1, $2, $3, 'self')
      ON CONFLICT (course_id, user_id, attended_on)
      DO UPDATE SET source = EXCLUDED.source
      RETURNING id, attended_on, marked_at;
      `,
      [courseId, userId, attendedOn]
    );

    res.json({ ok: true, record: rows[0] });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

app.get('/api/student/attendance', authAny, async (req, res) => {
  try {
    const userId = req.userId;

    const { rows: courseRows } = await pool.query(
      `
      SELECT cm.course_id
      FROM course_memberships cm
      JOIN courses c ON c.id = cm.course_id
      JOIN terms   t ON t.id = c.term_id
      WHERE cm.user_id = $1
      ORDER BY t.starts_on DESC NULLS LAST, cm.created_at DESC
      LIMIT 1;
      `,
      [userId]
    );
    if (!courseRows.length) return res.json([]);
    const courseId = courseRows[0].course_id;

    const { rows } = await pool.query(
      `
      SELECT attended_on, marked_at, source
      FROM attendances
      WHERE course_id=$1 AND user_id=$2
      ORDER BY attended_on DESC, marked_at DESC
      LIMIT 400;
      `,
      [courseId, userId]
    );

    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ---------- Professor: roster + rubric ----------
app.get('/api/professor/roster', authProfessor, async (req, res) => {
  try {
    const courseId = req.profCourseId;

    const tz = await getUserTimeZone(req.userId);
    const { rows: todayRows } = await pool.query(
      `SELECT (now() AT TIME ZONE $1)::date AS today;`,
      [tz]
    );
    const today = todayRows[0].today;

    // Attendance rubric (if missing, treat enabled=true, weight=100 for demo)
    const { rows: rw } = await pool.query(
      `
      SELECT enabled, COALESCE(weight,0)::numeric AS weight
      FROM course_rubric_items
      WHERE course_id=$1 AND item_key='attendance'
      LIMIT 1
      `,
      [courseId]
    );
    const attendanceEnabled = (rw.length ? !!rw[0].enabled : true);
    const attendanceWeight  = (rw.length ? Number(rw[0].weight || 0) : 100);

    const TOTAL_CLASSES = 10; // demo assumption

    const { rows } = await pool.query(
      `
      WITH students AS (
        SELECT u.id, u.display_name, COALESCE(up.photo_url,'') AS photo_url, u.pronouns
        FROM course_memberships cm
        JOIN users u ON u.id = cm.user_id
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE cm.course_id = $1
          AND NOT EXISTS (
            SELECT 1 FROM role_assignments ra
            JOIN roles r ON r.id = ra.role_id
            WHERE ra.user_id = u.id
              AND ra.scope_type='course' AND ra.scope_id=$1
              AND r.key IN ('professor','ta')
          )
      ),
      agg AS (
        SELECT a.user_id,
               COUNT(*)::int AS total,
               MAX(attended_on) AS last_attended,
               BOOL_OR(attended_on = $2) AS present_today
        FROM attendances a
        WHERE a.course_id = $1
        GROUP BY a.user_id
      )
      SELECT s.id, s.display_name, s.photo_url, s.pronouns,
             COALESCE(agg.total,0) AS attendance_count,
             agg.last_attended,
             COALESCE(agg.present_today,false) AS present_today
      FROM students s
      LEFT JOIN agg ON agg.user_id = s.id
      ORDER BY s.display_name ASC;
      `,
      [courseId, today]
    );

    const withScores = rows.map(r => {
      const count = Number(r.attendance_count || 0);
      const ratio = TOTAL_CLASSES > 0 ? count / TOTAL_CLASSES : 0;
      const attContributionOutOf10 = attendanceEnabled
        ? (ratio * 10) * (attendanceWeight / 100)
        : 0;
      return {
        ...r,
        attendance_ratio: ratio,
        score_out_of_10: Math.round(attContributionOutOf10 * 10) / 10,
        rubric_meta: {
          attendance_enabled: attendanceEnabled,
          attendance_weight: attendanceWeight,
          total_classes: TOTAL_CLASSES
        }
      };
    });

    res.json(withScores);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

app.get('/api/professor/student/:userId/attendance', authProfessor, async (req, res) => {
  try {
    const courseId = req.profCourseId;
    const studentId = req.params.userId;

    const { rows } = await pool.query(
      `
      SELECT attended_on, marked_at, source
      FROM attendances
      WHERE course_id=$1 AND user_id=$2
      ORDER BY attended_on DESC, marked_at DESC
      LIMIT 400;
      `,
      [courseId, studentId]
    );
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ---------- Work Journal / Stand-Up ----------
app.post('/api/student/journal', authAny, async (req, res) => {
  try {
    const userId = req.userId;
    const { content, sentiment_self, sentiment_team, sentiment_course, reach_out_to } = req.body || {};
    if (!content || !String(content).trim()) {
      return res.status(400).json({ error: 'Content required.' });
    }
    const clamp = (x) => {
      const n = Number(x);
      if (!Number.isFinite(n)) return 0;
      return Math.max(-2, Math.min(2, Math.trunc(n)));
    };
    const sSelf = clamp(sentiment_self);
    const sTeam = clamp(sentiment_team);
    const sCourse = clamp(sentiment_course);

    const reach = (reach_out_to || 'none').toLowerCase();
    if (!['none','team_leader','ta','professor'].includes(reach)) {
      return res.status(400).json({ error: 'Invalid reach_out_to.' });
    }

    const { rows: courseRows } = await pool.query(
      `
      SELECT cm.course_id
      FROM course_memberships cm
      JOIN courses c ON c.id = cm.course_id
      JOIN terms   t ON t.id = c.term_id
      WHERE cm.user_id = $1
      ORDER BY t.starts_on DESC NULLS LAST, cm.created_at DESC
      LIMIT 1;
      `,
      [userId]
    );
    if (!courseRows.length) return res.status(404).json({ error: 'No course found.' });
    const courseId = courseRows[0].course_id;

    const { rows } = await pool.query(
      `
      INSERT INTO work_journals
        (course_id, user_id, content,
         sentiment_self, sentiment_team, sentiment_course, reach_out_to)
      VALUES
        ($1,$2,$3,$4,$5,$6,NULLIF($7,'none'))
      RETURNING id, content, sentiment_self, sentiment_team, sentiment_course, reach_out_to, created_at;
      `,
      [courseId, userId, String(content).trim(), sSelf, sTeam, sCourse, reach]
    );

    res.status(201).json(rows[0]);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

app.get('/api/student/journal', authAny, async (req, res) => {
  try {
    const userId = req.userId;
    const { rows } = await pool.query(
      `
      SELECT j.id, j.content, j.sentiment_self, j.sentiment_team, j.sentiment_course,
             COALESCE(j.reach_out_to, 'none') AS reach_out_to, j.created_at
      FROM work_journals j
      WHERE j.user_id = $1
      ORDER BY j.created_at DESC
      LIMIT 100;
      `,
      [userId]
    );
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Professor: reach-outs to professor
app.get('/api/professor/journal', authProfessor, async (req, res) => {
  try {
    const courseId = req.profCourseId;
    const { rows } = await pool.query(
      `
      SELECT j.id, j.content, j.sentiment_self, j.sentiment_team, j.sentiment_course,
             j.reach_out_to, j.created_at,
             u.display_name AS student_name, COALESCE(up.photo_url,'') AS photo_url
      FROM work_journals j
      JOIN users u ON u.id = j.user_id
      LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE j.course_id = $1
        AND j.reach_out_to = 'professor'
      ORDER BY j.created_at DESC
      LIMIT 200;
      `,
      [courseId]
    );
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// TA: my teams + members
app.get('/api/ta/teams', authTA, async (req, res) => {
  try {
    const courseId = req.taCourseId;
    const taId = req.userId;

    const { rows: teams } = await pool.query(
      `
      SELECT t.id AS team_id, t.code, t.name
      FROM team_ta_assignments x
      JOIN teams t ON t.id = x.team_id
      WHERE x.ta_user_id = $1 AND t.course_id = $2
      ORDER BY t.code ASC;
      `,
      [taId, courseId]
    );
    const teamIds = teams.map(t => t.team_id);
    if (!teamIds.length) return res.json([]);

    const { rows: members } = await pool.query(
      `
      SELECT tm.team_id, u.id AS user_id, u.display_name, u.pronouns,
             COALESCE(up.photo_url,'') AS photo_url, tm.is_leader
      FROM team_members tm
      JOIN users u ON u.id = tm.user_id
      LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE tm.team_id = ANY($1::uuid[])
      ORDER BY tm.team_id, tm.is_leader DESC, u.display_name ASC;
      `,
      [teamIds]
    );

    const byTeam = new Map();
    teams.forEach(t => byTeam.set(t.team_id, { team_id: t.team_id, code: t.code, name: t.name, members: [] }));
    members.forEach(m => {
      const bucket = byTeam.get(m.team_id);
      if (bucket) {
        bucket.members.push({
          user_id: m.user_id,
          display_name: m.display_name,
          pronouns: m.pronouns,
          photo_url: m.photo_url,
          is_leader: m.is_leader
        });
      }
    });

    res.json(Array.from(byTeam.values()));
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// TA: reach-outs sent to TA (their assigned teams)
app.get('/api/ta/journal', authTA, async (req, res) => {
  try {
    const taId = req.userId;
    const courseId = req.taCourseId;

    const { rows } = await pool.query(`
      WITH my_teams AS (
        SELECT team_id FROM team_ta_assignments WHERE ta_user_id=$1
      ),
      my_students AS (
        SELECT DISTINCT tm.user_id
        FROM team_members tm
        JOIN teams t ON t.id = tm.team_id
        WHERE tm.team_id IN (SELECT team_id FROM my_teams)
          AND t.course_id = $2
      )
      SELECT j.id, j.content, j.sentiment_self, j.sentiment_team, j.sentiment_course,
             j.reach_out_to, j.created_at,
             u.display_name AS student_name,
             COALESCE(up.photo_url,'') AS photo_url
      FROM work_journals j
      JOIN my_students ms ON ms.user_id = j.user_id
      JOIN users u ON u.id = j.user_id
      LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE j.course_id = $2 AND j.reach_out_to = 'ta'
      ORDER BY j.created_at DESC
      LIMIT 200;
    `, [taId, courseId]);

    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Team Leader: overview + members + assigned TA
app.get('/api/team-leader/overview', authTeamLeader, async (req, res) => {
  try {
    const teamId = req.teamId;

    const { rows: teamRows } = await pool.query(
      `
      SELECT t.id AS team_id, t.code, t.name,
             c.code AS course_code, c.title AS course_title,
             te.code AS term_code, te.name AS term_name
      FROM teams t
      JOIN courses c ON c.id = t.course_id
      JOIN terms te  ON te.id = c.term_id
      WHERE t.id = $1
      LIMIT 1;
      `,
      [teamId]
    );

    const { rows: members } = await pool.query(
      `
      SELECT u.id, u.display_name, u.pronouns, COALESCE(up.photo_url,'') AS photo_url, tm.is_leader
      FROM team_members tm
      JOIN users u ON u.id = tm.user_id
      LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE tm.team_id = $1
      ORDER BY tm.is_leader DESC, u.display_name ASC;
      `,
      [teamId]
    );

    const { rows: taRows } = await pool.query(
      `
      SELECT u.id AS ta_user_id, u.display_name AS ta_name, COALESCE(up.photo_url,'') AS ta_photo
      FROM team_ta_assignments x
      JOIN users u ON u.id = x.ta_user_id
      LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE x.team_id = $1
      LIMIT 1;
      `,
      [teamId]
    );

    res.json({
      team: teamRows[0] || null,
      ta: taRows[0] || null,
      members
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Team Leader: reach-outs to leader (their team)
app.get('/api/team-leader/journal', authTeamLeader, async (req, res) => {
  try {
    const teamId = req.teamId;
    const courseId = req.tlCourseId;

    const { rows } = await pool.query(`
      WITH team_students AS (
        SELECT tm.user_id FROM team_members tm WHERE tm.team_id=$1
      )
      SELECT j.id, j.content, j.sentiment_self, j.sentiment_team, j.sentiment_course,
             j.reach_out_to, j.created_at,
             u.display_name AS student_name,
             COALESCE(up.photo_url,'') AS photo_url
      FROM work_journals j
      JOIN team_students s ON s.user_id = j.user_id
      JOIN users u ON u.id = j.user_id
      LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE j.course_id = $2 AND j.reach_out_to = 'team_leader'
      ORDER BY j.created_at DESC
      LIMIT 200;
    `, [teamId, courseId]);

    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ---------- Teams list for professor (latest course) ----------
app.get('/api/professor/teams', authProfessor, async (req, res) => {
  try {
    const courseId = req.profCourseId;
    const { rows } = await pool.query(`
      WITH leaders AS (
        SELECT tm.team_id, tm.user_id
        FROM team_members tm
        WHERE tm.is_leader = TRUE
      ),
      ta_assign AS (
        SELECT tta.team_id, tta.ta_user_id
        FROM team_ta_assignments tta
      ),
      sizes AS (
        SELECT team_id, COUNT(*)::int AS size
        FROM team_members
        GROUP BY team_id
      )
      SELECT
        t.id AS team_id, t.code, t.name,
        ulead.display_name AS leader_name,
        ulead.id AS leader_id,
        uta.display_name AS ta_name,
        uta.id AS ta_id,
        COALESCE(s.size,0) AS size
      FROM teams t
      LEFT JOIN leaders l ON l.team_id = t.id
      LEFT JOIN users ulead ON ulead.id = l.user_id
      LEFT JOIN ta_assign ta ON ta.team_id = t.id
      LEFT JOIN users uta ON uta.id = ta.ta_user_id
      LEFT JOIN sizes s ON s.team_id = t.id
      WHERE t.course_id = $1
      ORDER BY t.code ASC;
    `, [courseId]);
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'Internal error' });
  }
});

// ---------- Team detail ----------
app.get('/api/professor/team/:teamId', authProfessor, async (req, res) => {
  try {
    const courseId = req.profCourseId;
    const teamId = req.params.teamId;

    // team header
    const { rows: head } = await pool.query(`
      WITH l AS (
        SELECT tm.user_id FROM team_members tm
        WHERE tm.team_id=$1 AND tm.is_leader=TRUE LIMIT 1
      ),
      ta AS (
        SELECT tta.ta_user_id FROM team_ta_assignments tta
        WHERE tta.team_id=$1 LIMIT 1
      )
      SELECT
        t.id, t.code, t.name,
        (SELECT u.display_name FROM l JOIN users u ON u.id=l.user_id) AS leader_name,
        (SELECT u.id FROM l JOIN users u ON u.id=l.user_id) AS leader_id,
        (SELECT u.display_name FROM ta JOIN users u ON u.id=ta.ta_user_id) AS ta_name,
        (SELECT u.id FROM ta JOIN users u ON u.id=ta.ta_user_id) AS ta_id
      FROM teams t
      WHERE t.id=$1 AND t.course_id=$2
      LIMIT 1;
    `, [teamId, courseId]);
    if (!head.length) return res.status(404).json({ error:'No such team' });

    // members
    const { rows: members } = await pool.query(`
      SELECT tm.user_id AS id, u.display_name, u.pronouns,
             COALESCE(up.photo_url,'') AS photo_url,
             tm.is_leader
      FROM team_members tm
      JOIN users u ON u.id=tm.user_id
      LEFT JOIN user_profiles up ON up.user_id=u.id
      WHERE tm.team_id=$1
      ORDER BY tm.is_leader DESC, u.display_name ASC;
    `, [teamId]);

    // emails for quick reach-out
    const { rows: emails } = await pool.query(`
      SELECT u.id, u.email FROM users u
      WHERE u.id = ANY($1::uuid[])
    `, [members.map(m => m.id)]);

    const emailMap = new Map(emails.map(e => [e.id, e.email || '']));
    const data = {
      ...head[0],
      members: members.map(m => ({ ...m, email: emailMap.get(m.id) || '' }))
    };
    res.json(data);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'Internal error' });
  }
});

// ---------- Professor evaluation notes (create) ----------
app.post('/api/professor/eval-notes', authProfessor, async (req, res) => {
  try {
    const { subject_type, subject_id, visibility, sentiment, body } = req.body || {};
    if (!subject_type || !['user','team'].includes(subject_type)) {
      return res.status(400).json({ error:'subject_type must be "user" or "team"' });
    }
    if (!subject_id) return res.status(400).json({ error:'subject_id required' });
    if (!body || !String(body).trim()) return res.status(400).json({ error:'Note body required' });

    const vis = (visibility === 'shared') ? 'shared' : 'private';
    let sent = null;
    if (sentiment !== undefined && sentiment !== null && sentiment !== '') {
      const n = Number(sentiment);
      if (!Number.isFinite(n) || n < -5 || n > 5) return res.status(400).json({ error:'sentiment must be between -5 and 5' });
      sent = Math.trunc(n);
    }

    // sanity: ensure subject belongs to this course
    if (subject_type === 'team') {
      const ok = await pool.query(`SELECT 1 FROM teams WHERE id=$1 AND course_id=$2`, [subject_id, req.profCourseId]);
      if (!ok.rowCount) return res.status(400).json({ error:'Team not in your course' });
    } else {
      // user: must be enrolled in course
      const ok = await pool.query(`
        SELECT 1 FROM course_memberships WHERE course_id=$1 AND user_id=$2
      `, [req.profCourseId, subject_id]);
      if (!ok.rowCount) return res.status(400).json({ error:'User not in your course' });
    }

    const { rows } = await pool.query(`
      INSERT INTO eval_notes (course_id, author_id, subject_type, subject_id, visibility, sentiment, body)
      VALUES ($1,$2,$3,$4,$5,$6,$7)
      RETURNING id, course_id, author_id, subject_type, subject_id, visibility, sentiment, body, created_at;
    `, [req.profCourseId, req.userId, subject_type, subject_id, vis, sent, String(body).trim()]);
    res.status(201).json(rows[0]);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'Internal error' });
  }
});

// ---------- Professor evaluation notes (list by subject; only notes authored by this prof) ----------
app.get('/api/professor/eval-notes', authProfessor, async (req, res) => {
  try {
    const st = String(req.query.subject_type || '');
    const sid = String(req.query.subject_id || '');
    if (!['user','team'].includes(st)) return res.status(400).json({ error:'subject_type must be "user" or "team"' });
    if (!sid) return res.status(400).json({ error:'subject_id required' });

    const { rows } = await pool.query(`
      SELECT id, visibility, sentiment, body, created_at
      FROM eval_notes
      WHERE course_id=$1 AND author_id=$2 AND subject_type=$3 AND subject_id=$4
      ORDER BY created_at DESC
      LIMIT 200;
    `, [req.profCourseId, req.userId, st, sid]);
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'Internal error' });
  }
});


// ---------- Course Info ----------
app.get('/api/professor/course-info', authProfessor, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT course_id, description, links, updated_at
       FROM course_info WHERE course_id=$1`,
      [req.profCourseId]
    );
    if (!rows.length) {
      const ins = await pool.query(
        `INSERT INTO course_info (course_id, description, links)
         VALUES ($1, '', '[]'::jsonb)
         ON CONFLICT (course_id) DO NOTHING
         RETURNING course_id, description, links, updated_at;`,
        [req.profCourseId]
      );
      return res.json(ins.rows[0] || { course_id: req.profCourseId, description: '', links: [], updated_at: new Date().toISOString() });
    }
    res.json(rows[0]);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'Internal error' });
  }
});

app.post('/api/professor/course-info', authProfessor, async (req, res) => {
  try {
    const description = String(req.body?.description || '');
    const links = Array.isArray(req.body?.links) ? req.body.links : [];
    const norm = links
      .filter(x => x && typeof x === 'object')
      .map(x => ({ label: String(x.label||'').trim(), url: String(x.url||'').trim() }))
      .filter(x => x.label && x.url);

    const { rows } = await pool.query(
      `INSERT INTO course_info (course_id, description, links)
       VALUES ($1, $2, $3::jsonb)
       ON CONFLICT (course_id)
       DO UPDATE SET description=EXCLUDED.description, links=EXCLUDED.links, updated_at=now()
       RETURNING course_id, description, links, updated_at;`,
      [req.profCourseId, description, JSON.stringify(norm)]
    );
    res.json(rows[0]);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'Internal error' });
  }
});

// Student: read course info for latest course
app.get('/api/student/course-info', authAny, async (req, res) => {
  try {
    const { rows: c } = await pool.query(`
      SELECT cm.course_id
      FROM course_memberships cm
      JOIN courses c ON c.id = cm.course_id
      JOIN terms   t ON t.id = c.term_id
      WHERE cm.user_id = $1
      ORDER BY t.starts_on DESC NULLS LAST, cm.created_at DESC
      LIMIT 1
    `, [req.userId]);
    if (!c.length) return res.status(404).json({ error: 'No course found.' });
    const courseId = c[0].course_id;

    const { rows } = await pool.query(`
      INSERT INTO course_info (course_id, description, links)
      VALUES ($1, '', '[]'::jsonb)
      ON CONFLICT (course_id) DO NOTHING;
      SELECT ci.course_id, ci.description, ci.links, ci.updated_at,
             courses.code AS course_code, courses.title AS course_title,
             t.code AS term_code, t.name AS term_name
      FROM course_info ci
      JOIN courses ON courses.id = ci.course_id
      JOIN terms t  ON t.id = courses.term_id
      WHERE ci.course_id = $1
      LIMIT 1;
    `, [courseId]);

    res.json(rows[rows.length - 1]);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ---------- Rubric (professor) ----------
app.get('/api/professor/rubric', authProfessor, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, item_key, label, enabled, weight, updated_at
       FROM course_rubric_items
       WHERE course_id=$1
       ORDER BY label ASC;`,
      [req.profCourseId]
    );
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'Internal error' });
  }
});

// Bulk upsert items
app.put('/api/professor/rubric', authProfessor, async (req, res) => {
  try {
    const items = Array.isArray(req.body) ? req.body : [];
    const results = [];
    for (const it of items) {
      const key = String(it.item_key || '').trim();
      if (!key) continue;
      const enabled = !!it.enabled;
      const weight = isFinite(+it.weight) ? Math.max(0, +it.weight) : 0;
      const label = (typeof it.label === 'string' && it.label.trim())
        ? it.label.trim()
        : null;

      const { rows } = await pool.query(
        `INSERT INTO course_rubric_items (course_id, item_key, label, enabled, weight)
         VALUES ($1, $2, COALESCE($3,
           (SELECT label FROM course_rubric_items WHERE course_id=$1 AND item_key=$2 LIMIT 1),
           INITCAP(REPLACE($2,'_',' '))
         ), $4, $5)
         ON CONFLICT (course_id, item_key)
         DO UPDATE SET
           label = COALESCE(EXCLUDED.label, course_rubric_items.label),
           enabled = EXCLUDED.enabled,
           weight = EXCLUDED.weight,
           updated_at = now()
         RETURNING id, item_key, label, enabled, weight, updated_at;`,
        [req.profCourseId, key, label, enabled, weight]
      );
      results.push(rows[0]);
    }
    res.json(results);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'Internal error' });
  }
});

// ---------- Journal replies (threading) ----------
app.get('/api/journal/:id/replies', authAny, async (req, res) => {
  try {
    const jId = String(req.params.id || '').trim();
    if (!/^[0-9a-fA-F-]{32,36}$/.test(jId)) {
      return res.status(400).json({ error: 'Bad journal id' });
    }

    const ctx = await getJournalContext(jId);
    if (!ctx) return res.status(404).json({ error: 'Journal not found' });

    const allowed = await canReplyToJournal(req.userId, ctx);
    if (!allowed) return res.status(403).json({ error: 'Not allowed' });

    const { rows } = await pool.query(`
      SELECT r.id, r.body, r.created_at,
             u.id AS author_id, u.display_name AS author_name,
             COALESCE(up.photo_url,'') AS author_photo
      FROM journal_replies r
      JOIN users u ON u.id = r.author_id
      LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE r.journal_id = $1
      ORDER BY r.created_at ASC
    `, [jId]);

    res.json(rows);
  } catch (e) {
    console.error('GET replies error', e);
    res.status(500).json({ error: 'Internal error' });
  }
});

app.post('/api/journal/:id/replies', authAny, async (req, res) => {
  try {
    const jId = String(req.params.id || '').trim();
    if (!/^[0-9a-fA-F-]{32,36}$/.test(jId)) {
      return res.status(400).json({ error: 'Bad journal id' });
    }
    const body = String(req.body?.body || '').trim();
    if (!body) return res.status(400).json({ error: 'Body required.' });

    const ctx = await getJournalContext(jId);
    if (!ctx) return res.status(404).json({ error: 'Journal not found' });

    const allowed = await canReplyToJournal(req.userId, ctx);
    if (!allowed) return res.status(403).json({ error: 'Not allowed' });

    const { rows } = await pool.query(`
      INSERT INTO journal_replies (journal_id, author_id, body)
      VALUES ($1, $2, $3)
      RETURNING id, journal_id, author_id, body, created_at
    `, [jId, req.userId, body]);

    res.status(201).json(rows[0]);
  } catch (e) {
    console.error('POST reply error', e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ---------- Profile helpers ----------
async function getLatestSharedCourse(viewerId, targetId) {
  const { rows } = await pool.query(`
    SELECT c.id AS course_id
    FROM course_memberships cm1
    JOIN course_memberships cm2 ON cm2.course_id = cm1.course_id
    JOIN courses c ON c.id = cm1.course_id
    JOIN terms   t ON t.id = c.term_id
    WHERE cm1.user_id = $1 AND cm2.user_id = $2
    ORDER BY t.starts_on DESC NULLS LAST, GREATEST(cm1.created_at, cm2.created_at) DESC
    LIMIT 1
  `, [viewerId, targetId]);
  return rows[0]?.course_id || null;
}

async function getStudentTeamInCourse(userId, courseId) {
  const { rows } = await pool.query(`
    SELECT tm.team_id
    FROM team_members tm
    JOIN teams t ON t.id = tm.team_id
    WHERE tm.user_id = $1 AND t.course_id = $2
    ORDER BY tm.joined_at DESC NULLS LAST
    LIMIT 1
  `, [userId, courseId]);
  return rows[0]?.team_id || null;
}

async function isAssignedTAForStudent(viewerId, studentId, courseId) {
  const teamId = await getStudentTeamInCourse(studentId, courseId);
  if (!teamId) return false;
  const { rows } = await pool.query(`
    SELECT 1 FROM team_ta_assignments
    WHERE ta_user_id=$1 AND team_id=$2
    LIMIT 1
  `, [viewerId, teamId]);
  return !!rows.length;
}

async function isLeaderOfStudent(viewerId, studentId, courseId) {
  const teamId = await getStudentTeamInCourse(studentId, courseId);
  if (!teamId) return false;
  const { rows } = await pool.query(`
    SELECT 1 FROM team_members
    WHERE user_id=$1 AND team_id=$2 AND is_leader=TRUE
    LIMIT 1
  `, [viewerId, teamId]);
  return !!rows.length;
}

// ---------- Profile: public data ----------
app.get('/api/profile/:userId', authAny, async (req, res) => {
  try {
    const targetId = req.params.userId;
    const viewerId = req.userId;

    const { rows } = await pool.query(`
      SELECT u.id, u.display_name, u.email, u.pronouns,
             COALESCE(up.photo_url,'') AS photo_url,
             COALESCE(up.phone,'')     AS phone,
             COALESCE(up.socials,'{}') AS socials
      FROM users u
      LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE u.id = $1
      LIMIT 1
    `, [targetId]);
    if (!rows.length) return res.status(404).json({ error: 'User not found' });

    // Find latest shared course (optional but useful context)
    const sharedCourseId = await getLatestSharedCourse(viewerId, targetId);
    let courseCtx = null;
    if (sharedCourseId) {
      const cr = await pool.query(`
        SELECT c.id AS course_id, c.code AS course_code, c.title AS course_title,
               t.code AS term_code, t.name AS term_name
        FROM courses c
        JOIN terms t ON t.id = c.term_id
        WHERE c.id=$1
        LIMIT 1
      `, [sharedCourseId]);
      courseCtx = cr.rows[0] || null;
    }

    res.json({ ...rows[0], course: courseCtx });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'Internal error' });
  }
});

// ---------- Profile journals: list a user's entries (thread starters) ----------
app.get('/api/profile/:userId/journal', authAny, async (req, res) => {
  try {
    const targetId = req.params.userId;
    const viewerId = req.userId;

    const courseId = await getLatestSharedCourse(viewerId, targetId);
    if (!courseId) return res.json([]); // no shared course → no visibility

    // For now show journal entries authored for that user in the shared course.
    const { rows } = await pool.query(`
      SELECT j.id, j.content, j.sentiment_self, j.sentiment_team, j.sentiment_course,
             COALESCE(j.reach_out_to,'none') AS reach_out_to, j.created_at
      FROM work_journals j
      WHERE j.user_id = $1 AND j.course_id = $2
      ORDER BY j.created_at DESC
      LIMIT 200
    `, [targetId, courseId]);

    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'Internal error' });
  }
});

// ---------- Profile message: start a thread with this user ----------
app.post('/api/profile/:userId/message', authAny, async (req, res) => {
  try {
    const targetId = req.params.userId;    // the profile owner (student/ta/prof/etc.)
    const actorId  = req.userId;           // who is sending
    const content  = String(req.body?.content || '').trim();
    if (!content) return res.status(400).json({ error: 'Content required.' });

    // Must share a course
    const courseId = await getLatestSharedCourse(actorId, targetId);
    if (!courseId) return res.status(403).json({ error: 'No shared course with this user.' });

    // Decide reach_out_to so reply permissions behave:
    // - professor → 'professor'
    // - assigned TA for student's team → 'ta'
    // - team leader of student's team → 'team_leader'
    // - otherwise (e.g. peer/student) → 'none' (student + professor can still reply)
    let reach = 'none';
    if (await isProfessorForCourse(actorId, courseId)) reach = 'professor';
    else if (await isAssignedTAForStudent(actorId, targetId, courseId)) reach = 'ta';
    else if (await isLeaderOfStudent(actorId, targetId, courseId)) reach = 'team_leader';

    const { rows } = await pool.query(`
      INSERT INTO work_journals
        (course_id, user_id, content,
         sentiment_self, sentiment_team, sentiment_course, reach_out_to)
      VALUES ($1, $2, $3, 0, 0, 0, NULLIF($4,'none'))
      RETURNING id, content, COALESCE(reach_out_to,'none') AS reach_out_to, created_at
    `, [courseId, targetId, content, reach]);

    res.status(201).json(rows[0]);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'Internal error' });
  }
});


// ---------- Pages (guards for role pages) ----------
app.get('/', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/student', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'student.html'));
});

app.get('/professor', async (req, res) => {
  const uid = getUserIdFromCookie(req);
  if (!uid) return res.redirect('/login.html');
  const flags = await getRoleFlags(uid);
  if (!flags.is_professor) return res.redirect('/login.html');
  res.sendFile(path.join(__dirname, 'public', 'professor.html'));
});

app.get('/ta', async (req, res) => {
  const uid = getUserIdFromCookie(req);
  if (!uid) return res.redirect('/login.html');
  const flags = await getRoleFlags(uid);
  if (!flags.is_ta) return res.redirect('/login.html');
  res.sendFile(path.join(__dirname, 'public', 'ta.html'));
});

app.get('/team-leader', async (req, res) => {
  const uid = getUserIdFromCookie(req);
  if (!uid) return res.redirect('/login.html');
  const flags = await getRoleFlags(uid);
  if (!flags.is_team_leader) return res.redirect('/login.html');
  res.sendFile(path.join(__dirname, 'public', 'team_leader.html'));
});

// Public profile page (auth required to see details)
app.get('/profile/:userId', authAny, (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'profile.html'));
});

app.get('/prof_teams', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'prof_teams.html'));
});
app.get('/prof_team', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'prof_team.html'));
});


// Health
app.get('/api/health', (_req, res) => res.json({ ok: true }));

// ---------- Error Handler (last) ----------
app.use((err, _req, res, _next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal error' });
});

// ---------- Start ----------
const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () =>
  console.log(`Conductor running: http://localhost:${PORT}`)
);

// Graceful shutdown (helps avoid orphaned 3000 listeners)
process.once('SIGINT', () => { server.close(()=>process.exit(0)); });
process.once('SIGTERM', () => { server.close(()=>process.exit(0)); });
