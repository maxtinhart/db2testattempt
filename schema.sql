-- ============================================================================
-- SQL SCHEMA DEFINITION: Class Student Profile Dataset
-- PostgreSQL / ANSI SQL Compatible
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. DROP EXISTING TABLES (Enforces clean setup)
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_student_profiles;
DROP TABLE IF EXISTS student_availability CASCADE;
DROP TABLE IF EXISTS availability_slots CASCADE;
DROP TABLE IF EXISTS student_tools CASCADE;
DROP TABLE IF EXISTS tools CASCADE;
DROP TABLE IF EXISTS student_skills CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS raw_class_dataset_staging CASCADE;

-- ----------------------------------------------------------------------------
-- 2. LOOKUP / REFERENCE TABLES
-- ----------------------------------------------------------------------------

-- Software tools and programming languages reference
CREATE TABLE tools (
    tool_id SERIAL PRIMARY KEY,
    tool_name VARCHAR(50) UNIQUE NOT NULL
);

-- Pre-populate standard tool options derived from dataset
INSERT INTO tools (tool_name) VALUES
    ('Python'),
    ('JavaScript'),
    ('SQL'),
    ('Excel'),
    ('R'),
    ('none yet');

-- Time availability slots reference
CREATE TABLE availability_slots (
    slot_id SERIAL PRIMARY KEY,
    slot_name VARCHAR(50) UNIQUE NOT NULL
);

-- Pre-populate standard availability options
INSERT INTO availability_slots (slot_name) VALUES
    ('Weekday mornings'),
    ('Weekday afternoons'),
    ('Weekday evenings'),
    ('Weekend mornings'),
    ('Weekend afternoons'),
    ('Weekend evenings');

-- ----------------------------------------------------------------------------
-- 3. CORE ENTITY TABLES
-- ----------------------------------------------------------------------------

-- Main student profile table
CREATE TABLE students (
    netid VARCHAR(12) PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    school_year VARCHAR(20) NOT NULL CHECK (
        school_year IN ('Freshman', 'Sophomore', 'Junior', 'Senior', 'Graduate', 'Other')
    ),
    intro_programming VARCHAR(20) NOT NULL CHECK (
        intro_programming IN ('took_it', 'equivalent', 'neither')
    ),
    working_style TEXT,
    interests TEXT,
    semester_goal TEXT,
    submitted_at TIMESTAMPTZ NOT NULL
);

-- Student skill rating matrix (1-5 self-assessment)
CREATE TABLE student_skills (
    netid VARCHAR(12) PRIMARY KEY REFERENCES students(netid) ON DELETE CASCADE,
    skill_programming INTEGER NOT NULL CHECK (skill_programming BETWEEN 1 AND 5),
    skill_data_stats INTEGER NOT NULL CHECK (skill_data_stats BETWEEN 1 AND 5),
    skill_frontend_design INTEGER NOT NULL CHECK (skill_frontend_design BETWEEN 1 AND 5),
    skill_business_pitch INTEGER NOT NULL CHECK (skill_business_pitch BETWEEN 1 AND 5)
);

-- ----------------------------------------------------------------------------
-- 4. JUNCTION TABLES (Many-to-Many Relationships)
-- ----------------------------------------------------------------------------

-- Mapping students to known tools
CREATE TABLE student_tools (
    netid VARCHAR(12) NOT NULL REFERENCES students(netid) ON DELETE CASCADE,
    tool_id INTEGER NOT NULL REFERENCES tools(tool_id) ON DELETE RESTRICT,
    PRIMARY KEY (netid, tool_id)
);

-- Mapping students to weekly availability
CREATE TABLE student_availability (
    netid VARCHAR(12) NOT NULL REFERENCES students(netid) ON DELETE CASCADE,
    slot_id INTEGER NOT NULL REFERENCES availability_slots(slot_id) ON DELETE RESTRICT,
    PRIMARY KEY (netid, slot_id)
);

-- ----------------------------------------------------------------------------
-- 5. PERFORMANCE INDEXES
-- ----------------------------------------------------------------------------

CREATE INDEX idx_students_school_year ON students(school_year);
CREATE INDEX idx_students_submitted_at ON students(submitted_at);
CREATE INDEX idx_student_skills_programming ON student_skills(skill_programming);
CREATE INDEX idx_student_skills_frontend ON student_skills(skill_frontend_design);
CREATE INDEX idx_student_tools_tool ON student_tools(tool_id);
CREATE INDEX idx_student_avail_slot ON student_availability(slot_id);

-- ----------------------------------------------------------------------------
-- 6. ANALYTICAL RECONSTRUCTION VIEW
-- ----------------------------------------------------------------------------

CREATE VIEW v_student_profiles AS
SELECT 
    s.netid,
    s.full_name,
    s.school_year,
    s.intro_programming,
    sk.skill_programming,
    sk.skill_data_stats,
    sk.skill_frontend_design,
    sk.skill_business_pitch,
    STRING_AGG(DISTINCT t.tool_name, '; ') AS tools,
    STRING_AGG(DISTINCT a.slot_name, '; ') AS availability,
    s.working_style,
    s.interests,
    s.semester_goal,
    s.submitted_at
FROM students s
JOIN student_skills sk ON s.netid = sk.netid
LEFT JOIN student_tools st ON s.netid = st.netid
LEFT JOIN tools t ON st.tool_id = t.tool_id
LEFT JOIN student_availability sa ON s.netid = sa.netid
LEFT JOIN availability_slots a ON sa.slot_id = a.slot_id
GROUP BY 
    s.netid, s.full_name, s.school_year, s.intro_programming,
    sk.skill_programming, sk.skill_data_stats, sk.skill_frontend_design, sk.skill_business_pitch,
    s.working_style, s.interests, s.semester_goal, s.submitted_at;

-- ----------------------------------------------------------------------------
-- 7. STAGING TABLE & ETL POPULATION SCRIPT
-- ----------------------------------------------------------------------------

CREATE TABLE raw_class_dataset_staging (
    netid VARCHAR(50),
    name VARCHAR(200),
    school_year VARCHAR(50),
    intro_programming VARCHAR(50),
    skill_programming INT,
    skill_data_stats INT,
    skill_frontend_design INT,
    skill_business_pitch INT,
    tools TEXT,
    availability TEXT,
    working_style TEXT,
    interests TEXT,
    semester_goal TEXT,
    submitted_at TIMESTAMPTZ
);

COMMIT;
