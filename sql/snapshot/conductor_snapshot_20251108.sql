--
-- PostgreSQL database dump
--

\restrict LRhKujPVTgEERgigavxgMLuOnUVkGQJXKY158GFE0eS8IR9HfTLAnSwa4fHlBO1

-- Dumped from database version 14.19 (Homebrew)
-- Dumped by pg_dump version 14.19 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE IF EXISTS conductor;
--
-- Name: conductor; Type: DATABASE; Schema: -; Owner: -
--

CREATE DATABASE conductor WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.UTF-8';


\unrestrict LRhKujPVTgEERgigavxgMLuOnUVkGQJXKY158GFE0eS8IR9HfTLAnSwa4fHlBO1
\connect conductor
\restrict LRhKujPVTgEERgigavxgMLuOnUVkGQJXKY158GFE0eS8IR9HfTLAnSwa4fHlBO1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: attendances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    user_id uuid NOT NULL,
    attended_on date NOT NULL,
    marked_at timestamp with time zone DEFAULT now() NOT NULL,
    source text DEFAULT 'self'::text
);


--
-- Name: course_info; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.course_info (
    course_id uuid NOT NULL,
    description text DEFAULT ''::text,
    links jsonb DEFAULT '[]'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: course_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.course_memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    user_id uuid NOT NULL,
    section_id uuid,
    status text DEFAULT 'active'::text NOT NULL,
    roster_source text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: course_rubric_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.course_rubric_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    item_key text NOT NULL,
    label text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    weight numeric(5,2) DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT course_rubric_items_weight_check CHECK ((weight >= (0)::numeric))
);


--
-- Name: courses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    term_id uuid NOT NULL,
    code text NOT NULL,
    title text NOT NULL,
    sectioning_mode text DEFAULT 'single'::text NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: eval_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.eval_notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    author_id uuid NOT NULL,
    subject_type text NOT NULL,
    subject_id uuid NOT NULL,
    visibility text DEFAULT 'private'::text NOT NULL,
    sentiment smallint,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT eval_notes_subject_type_check CHECK ((subject_type = ANY (ARRAY['user'::text, 'team'::text]))),
    CONSTRAINT eval_notes_visibility_check CHECK ((visibility = ANY (ARRAY['private'::text, 'shared'::text])))
);


--
-- Name: journal_replies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_replies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    journal_id uuid NOT NULL,
    author_id uuid NOT NULL,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: role_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    scope_type text NOT NULL,
    scope_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT role_assignments_scope_type_check CHECK ((scope_type = ANY (ARRAY['global'::text, 'course'::text, 'section'::text, 'team'::text])))
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    label text NOT NULL
);


--
-- Name: schedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schedules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    created_by uuid,
    title text NOT NULL,
    link text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deadline_at timestamp with time zone
);


--
-- Name: team_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_id uuid NOT NULL,
    user_id uuid NOT NULL,
    is_leader boolean DEFAULT false NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: team_ta_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_ta_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_id uuid NOT NULL,
    ta_user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.terms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    starts_on date,
    ends_on date
);


--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profiles (
    user_id uuid NOT NULL,
    name_pronunciation text,
    photo_url text,
    phone text,
    socials jsonb DEFAULT '{}'::jsonb,
    availability_notes text,
    custom jsonb DEFAULT '{}'::jsonb,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    email_verified_at timestamp with time zone,
    given_name text,
    family_name text,
    display_name text,
    pronouns text,
    locale text DEFAULT 'en'::text,
    time_zone text DEFAULT 'America/Los_Angeles'::text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: work_journals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_journals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    user_id uuid NOT NULL,
    content text NOT NULL,
    sentiment_self smallint NOT NULL,
    sentiment_team smallint NOT NULL,
    sentiment_course smallint NOT NULL,
    reach_out_to text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT work_journals_reach_out_to_check CHECK ((reach_out_to = ANY (ARRAY['none'::text, 'team_leader'::text, 'ta'::text, 'professor'::text]))),
    CONSTRAINT work_journals_sentiment_course_check CHECK (((sentiment_course >= '-2'::integer) AND (sentiment_course <= 2))),
    CONSTRAINT work_journals_sentiment_self_check CHECK (((sentiment_self >= '-2'::integer) AND (sentiment_self <= 2))),
    CONSTRAINT work_journals_sentiment_team_check CHECK (((sentiment_team >= '-2'::integer) AND (sentiment_team <= 2)))
);


--
-- Data for Name: attendances; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.attendances (id, course_id, user_id, attended_on, marked_at, source) FROM stdin;
79acce7d-fa4b-4dae-93de-b463f67e75dc	8be3dcbe-c607-4903-af38-5e0608bc967d	b041d90c-594d-44da-825f-5e8944f54e46	2025-11-05	2025-11-05 17:18:06.070029-08	self
5fce76ca-a4e3-45f2-85b8-65ee10bd12a0	8be3dcbe-c607-4903-af38-5e0608bc967d	beff22c0-8f70-44ce-b777-577841338ce8	2025-11-05	2025-11-05 18:54:04.516743-08	self
57f93b3d-8c0c-4e2d-8a3f-ffad2adb75c4	8be3dcbe-c607-4903-af38-5e0608bc967d	f789e04f-1cca-49b9-bf39-f2c770193e50	2025-11-05	2025-11-05 19:37:18.89765-08	self
eeffd007-4e3b-49b5-9404-89854783d3d2	8be3dcbe-c607-4903-af38-5e0608bc967d	f789e04f-1cca-49b9-bf39-f2c770193e50	2025-11-08	2025-11-08 09:29:30.365796-08	self
\.


--
-- Data for Name: course_info; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.course_info (course_id, description, links, updated_at) FROM stdin;
8be3dcbe-c607-4903-af38-5e0608bc967d	new course description 	[]	2025-11-08 22:58:17.354498-08
\.


--
-- Data for Name: course_memberships; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.course_memberships (id, course_id, user_id, section_id, status, roster_source, created_at) FROM stdin;
9e6e7630-d7bc-4a83-b220-b697a9939f6c	8be3dcbe-c607-4903-af38-5e0608bc967d	fa8e289c-476a-4d59-9d20-ad25043d5670	\N	active	seed	2025-11-05 15:42:56.345475-08
4b815a90-3185-4148-9e75-b45fdff0bc3a	8be3dcbe-c607-4903-af38-5e0608bc967d	b041d90c-594d-44da-825f-5e8944f54e46	\N	active	seed	2025-11-05 16:04:40.040513-08
803e3688-e98f-4a32-8e07-f724ad924d28	8be3dcbe-c607-4903-af38-5e0608bc967d	f789e04f-1cca-49b9-bf39-f2c770193e50	\N	active	seed	2025-11-05 16:04:40.040513-08
dcad54b2-4be5-423e-9e0d-58438aafebd3	8be3dcbe-c607-4903-af38-5e0608bc967d	ba33dd11-2e99-4fa2-8195-ee7cbf3b2727	\N	active	seed	2025-11-05 16:04:40.040513-08
84100057-998c-42d6-bb75-4a846f8bfca7	8be3dcbe-c607-4903-af38-5e0608bc967d	c41ce7d7-cf0f-450e-b2ec-a3c40cc1448b	\N	active	seed	2025-11-05 16:04:40.040513-08
03b39c4e-31bd-4353-8104-8c4ee8006f3e	8be3dcbe-c607-4903-af38-5e0608bc967d	34de1197-f5f0-4fdc-adb2-5a519df90f6c	\N	active	seed	2025-11-05 16:04:40.040513-08
152922bb-cdf3-4937-9b5d-b49405bacaf0	8be3dcbe-c607-4903-af38-5e0608bc967d	1901ae31-036c-4ff3-a3fb-01ba4724a550	\N	active	seed	2025-11-05 16:04:40.040513-08
11c83e00-2892-432e-98c0-5fecd91d4ec2	8be3dcbe-c607-4903-af38-5e0608bc967d	dbb2aaf1-779e-4ada-80f2-48b7790e16ec	\N	active	seed	2025-11-05 16:04:40.040513-08
eae1aba6-0e50-45bd-9c9a-1c15248018df	8be3dcbe-c607-4903-af38-5e0608bc967d	4a94dfc9-3848-415c-977d-fce4ad82ad57	\N	active	seed	2025-11-05 16:04:40.040513-08
d03cc270-acb0-4f63-8ab2-33bce115fdc6	8be3dcbe-c607-4903-af38-5e0608bc967d	0e5d5302-d5df-4bdc-8890-5b750d8f3fbf	\N	active	seed	2025-11-05 16:04:40.040513-08
65c2fffb-7aba-484e-a367-40fa5b0e2ae0	8be3dcbe-c607-4903-af38-5e0608bc967d	6ce5da82-0ee9-4e89-a08d-18e25f01d97f	\N	active	seed	2025-11-05 16:04:40.040513-08
36277f7e-9b46-4a16-a039-d33985f8ed5f	8be3dcbe-c607-4903-af38-5e0608bc967d	b7731e34-c96d-4c4f-beeb-0e4b3d66b4b5	\N	active	\N	2025-11-05 17:31:02.28043-08
c400a635-489a-4ca8-b1ea-0701be8520d9	8be3dcbe-c607-4903-af38-5e0608bc967d	b8300f2c-ac86-4a19-b443-167933584cfc	\N	active	\N	2025-11-05 17:31:02.28043-08
e4895f74-9c95-4f2f-bcae-5226878eff76	8be3dcbe-c607-4903-af38-5e0608bc967d	69692eb7-cdc7-45fa-84ba-af0a1f469c2a	\N	active	\N	2025-11-05 17:31:02.28043-08
06c2d523-4488-4a81-96c4-a2efd839485e	8be3dcbe-c607-4903-af38-5e0608bc967d	beff22c0-8f70-44ce-b777-577841338ce8	\N	active	\N	2025-11-05 18:44:34.118223-08
dfc95329-3e27-4d5a-9b4d-e1019e2af16f	8be3dcbe-c607-4903-af38-5e0608bc967d	1b06383f-fd15-4bbd-b8f1-0968f6993ed1	\N	active	\N	2025-11-05 18:44:34.118223-08
3e3226d6-e215-435d-b4e4-5ad0323844d6	8be3dcbe-c607-4903-af38-5e0608bc967d	a774f7fc-6885-420b-a5ae-d5f882295303	\N	active	\N	2025-11-05 18:44:34.118223-08
0172f4d4-ca9d-4156-9717-019d5500f68c	8be3dcbe-c607-4903-af38-5e0608bc967d	daf5dc82-0255-4150-bfe1-e3edb4535ef9	\N	active	\N	2025-11-05 18:58:45.730003-08
c70c8efe-8e98-4d1a-8d23-f658a6354ac0	8be3dcbe-c607-4903-af38-5e0608bc967d	7c10cb0d-4922-4e6e-b998-e5a3b01dc2d9	\N	active	\N	2025-11-05 18:58:45.730003-08
a40d4515-36fb-433b-a5eb-1a6ed57e385c	8be3dcbe-c607-4903-af38-5e0608bc967d	328aa03c-ae86-49de-a989-bd82c57b2e9d	\N	active	\N	2025-11-05 18:58:45.730003-08
6870b4eb-9ce9-417d-bff4-1cba95e37555	8be3dcbe-c607-4903-af38-5e0608bc967d	76c9d00e-4da1-4882-9d99-46d3e6d18d83	\N	active	\N	2025-11-05 18:58:45.730003-08
c9dbdc76-f156-4c06-8030-222b3e6730f8	8be3dcbe-c607-4903-af38-5e0608bc967d	d7e008f8-7a76-4032-8f5f-77fd0bb95542	\N	active	\N	2025-11-05 18:58:45.730003-08
f2a74cd6-f946-4f40-b6ce-6081af9a01c8	8be3dcbe-c607-4903-af38-5e0608bc967d	01bff051-8516-467d-82b3-eb626c9451b9	\N	active	\N	2025-11-05 18:58:45.730003-08
\.


--
-- Data for Name: course_rubric_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.course_rubric_items (id, course_id, item_key, label, enabled, weight, updated_at) FROM stdin;
1bf322a1-5cb8-4bc8-939c-3760cb27639c	8be3dcbe-c607-4903-af38-5e0608bc967d	attendance	Attendance	t	50.00	2025-11-08 22:58:49.744373-08
e28ae98e-c433-4062-9540-f31178b5ae98	8be3dcbe-c607-4903-af38-5e0608bc967d	evaluation_notes	Evaluation Journal	f	0.00	2025-11-08 22:58:49.746773-08
5a0b8c82-39a0-4262-b101-055f7a82d7c7	8be3dcbe-c607-4903-af38-5e0608bc967d	participation	Participation	t	50.00	2025-11-08 22:58:49.747718-08
1b52795a-0caf-4a35-a8d7-65e3bbffa1a6	8be3dcbe-c607-4903-af38-5e0608bc967d	submissions	Submissions/Deadlines	f	0.00	2025-11-08 22:58:49.748424-08
b8ddec56-5e38-4a4a-9175-cc7e954202c3	8be3dcbe-c607-4903-af38-5e0608bc967d	work_journal	Work Journal	f	0.00	2025-11-08 22:58:49.748992-08
\.


--
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.courses (id, term_id, code, title, sectioning_mode, settings, created_at) FROM stdin;
8be3dcbe-c607-4903-af38-5e0608bc967d	5ca1c782-474b-4cb4-b11a-b666974abcc3	CSE110	Software Engineering	single	{}	2025-11-05 15:42:56.333939-08
\.


--
-- Data for Name: eval_notes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.eval_notes (id, course_id, author_id, subject_type, subject_id, visibility, sentiment, body, created_at) FROM stdin;
912149c4-2f61-4acd-8283-3381aaadbff6	8be3dcbe-c607-4903-af38-5e0608bc967d	fa8e289c-476a-4d59-9d20-ad25043d5670	team	e037dc98-b83a-42b1-8608-c330263c8b0f	private	\N	first private comment	2025-11-08 22:41:41.517856-08
35d202e4-fb78-45ed-a767-c5fd0f7103e1	8be3dcbe-c607-4903-af38-5e0608bc967d	fa8e289c-476a-4d59-9d20-ad25043d5670	team	e037dc98-b83a-42b1-8608-c330263c8b0f	shared	2	public evaluation note	2025-11-08 22:43:58.585083-08
fd48ac39-5f6a-4d1b-80e6-9b6e1b1e8c6f	8be3dcbe-c607-4903-af38-5e0608bc967d	fa8e289c-476a-4d59-9d20-ad25043d5670	team	e037dc98-b83a-42b1-8608-c330263c8b0f	private	\N	this is for me	2025-11-08 22:59:41.51033-08
\.


--
-- Data for Name: journal_replies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.journal_replies (id, journal_id, author_id, body, created_at) FROM stdin;
fee2d7e7-27ce-4270-b677-11a9aa2af1aa	f6178b40-b97f-417e-891e-9e093e625070	fa8e289c-476a-4d59-9d20-ad25043d5670	hi	2025-11-08 21:56:55.258001-08
916db99e-a0d6-4c6a-ace8-e4038e44f7ad	f6178b40-b97f-417e-891e-9e093e625070	7c10cb0d-4922-4e6e-b998-e5a3b01dc2d9	hello	2025-11-08 22:00:54.456727-08
9bb513aa-6d9c-47f6-a757-60a5dc9d91cf	f6178b40-b97f-417e-891e-9e093e625070	fa8e289c-476a-4d59-9d20-ad25043d5670	hello back	2025-11-08 22:01:13.239875-08
dc70b588-e09c-4838-90da-e8f44677d799	c16ac4d2-3037-48ab-8ad9-a4556c90bbf4	0e5d5302-d5df-4bdc-8890-5b750d8f3fbf	hi professor	2025-11-08 22:25:52.190285-08
5e656816-51a4-4e39-9aeb-0389a5e7a141	f6178b40-b97f-417e-891e-9e093e625070	fa8e289c-476a-4d59-9d20-ad25043d5670	hello 2	2025-11-08 22:58:02.368417-08
bd2fc118-55d6-48f7-983a-324f01977693	d62438ff-ef9c-4526-ac35-49abc4c5c886	fa8e289c-476a-4d59-9d20-ad25043d5670	yes what' is it	2025-11-08 23:01:47.686418-08
\.


--
-- Data for Name: role_assignments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.role_assignments (id, user_id, role_id, scope_type, scope_id, created_at) FROM stdin;
bbdb90f3-5fc2-4432-9801-3ddf43c86da1	fa8e289c-476a-4d59-9d20-ad25043d5670	66c42637-9efa-4882-ae56-9fb8ab318ed9	course	8be3dcbe-c607-4903-af38-5e0608bc967d	2025-11-05 15:42:56.348749-08
8f6f70ce-8296-44a1-a327-21f86e9228a3	b7731e34-c96d-4c4f-beeb-0e4b3d66b4b5	66c42637-9efa-4882-ae56-9fb8ab318ed9	course	8be3dcbe-c607-4903-af38-5e0608bc967d	2025-11-05 17:31:02.283562-08
90753733-4d67-4711-8801-41ffe4c1c12d	beff22c0-8f70-44ce-b777-577841338ce8	854fd673-f087-47fb-ba0b-193e873d1ce0	course	8be3dcbe-c607-4903-af38-5e0608bc967d	2025-11-05 19:22:23.491978-08
34e939dd-eded-478b-b433-d06ccc561a38	1b06383f-fd15-4bbd-b8f1-0968f6993ed1	854fd673-f087-47fb-ba0b-193e873d1ce0	course	8be3dcbe-c607-4903-af38-5e0608bc967d	2025-11-05 19:22:23.491978-08
e007d92c-0e46-4966-9c28-0d46f9c38c7f	a774f7fc-6885-420b-a5ae-d5f882295303	854fd673-f087-47fb-ba0b-193e873d1ce0	course	8be3dcbe-c607-4903-af38-5e0608bc967d	2025-11-05 19:22:23.491978-08
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.roles (id, key, label) FROM stdin;
66c42637-9efa-4882-ae56-9fb8ab318ed9	professor	Professor
bd754548-89d5-4328-a87b-7669bad84924	student	Student
854fd673-f087-47fb-ba0b-193e873d1ce0	ta	Teaching Assistant
\.


--
-- Data for Name: schedules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schedules (id, course_id, created_by, title, link, notes, created_at, deadline_at) FROM stdin;
2c1525fa-7e06-4388-91b8-cf132a2e076c	8be3dcbe-c607-4903-af38-5e0608bc967d	fa8e289c-476a-4d59-9d20-ad25043d5670	first task	\N	this is first task	2025-11-05 16:48:42.602985-08	\N
f97bc386-2a54-4da2-8d99-e3bc6700d284	8be3dcbe-c607-4903-af38-5e0608bc967d	fa8e289c-476a-4d59-9d20-ad25043d5670	reading	\N	reading 5	2025-11-05 19:36:18.267352-08	\N
ea5d36ef-01b2-47c5-9cdd-baacc12f3a05	8be3dcbe-c607-4903-af38-5e0608bc967d	fa8e289c-476a-4d59-9d20-ad25043d5670	home work 2	\N	\N	2025-11-08 22:03:24.573912-08	2025-11-19 22:03:00-08
057c7758-3a46-4345-b83c-b826c370f7fe	8be3dcbe-c607-4903-af38-5e0608bc967d	fa8e289c-476a-4d59-9d20-ad25043d5670	new item	\N	\N	2025-11-08 22:56:50.770666-08	\N
\.


--
-- Data for Name: team_members; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.team_members (id, team_id, user_id, is_leader, joined_at) FROM stdin;
95a26bed-c080-4ba0-8e2b-acf5b2f2c232	48b4c2f2-f533-4db6-b22c-56393cecddfe	7c10cb0d-4922-4e6e-b998-e5a3b01dc2d9	f	2025-11-05 19:22:23.513687-08
11e57204-7a7c-4163-a808-6b2709754105	48b4c2f2-f533-4db6-b22c-56393cecddfe	ba33dd11-2e99-4fa2-8195-ee7cbf3b2727	f	2025-11-05 19:22:23.513687-08
d1767b47-ba29-452c-9200-b0a5978384a0	48b4c2f2-f533-4db6-b22c-56393cecddfe	f789e04f-1cca-49b9-bf39-f2c770193e50	f	2025-11-05 19:22:23.513687-08
d67f85f1-71d5-4e60-b341-b4491a86e72b	48b4c2f2-f533-4db6-b22c-56393cecddfe	b8300f2c-ac86-4a19-b443-167933584cfc	f	2025-11-05 19:22:23.513687-08
8ec59226-47f8-4200-8cf0-476bc547d684	48b4c2f2-f533-4db6-b22c-56393cecddfe	b041d90c-594d-44da-825f-5e8944f54e46	t	2025-11-05 19:22:23.513687-08
30f00e24-abf5-4d75-a1f3-c4edd1c3a379	e037dc98-b83a-42b1-8608-c330263c8b0f	dbb2aaf1-779e-4ada-80f2-48b7790e16ec	f	2025-11-05 19:22:23.513687-08
1f910016-e3e0-4c33-8d7f-72e18012b7a0	e037dc98-b83a-42b1-8608-c330263c8b0f	1901ae31-036c-4ff3-a3fb-01ba4724a550	f	2025-11-05 19:22:23.513687-08
efc1ec97-6a00-49cd-8a22-16a61513adfe	e037dc98-b83a-42b1-8608-c330263c8b0f	34de1197-f5f0-4fdc-adb2-5a519df90f6c	f	2025-11-05 19:22:23.513687-08
a4ff9d89-637b-43c9-b016-2dea85e63ea0	e037dc98-b83a-42b1-8608-c330263c8b0f	d7e008f8-7a76-4032-8f5f-77fd0bb95542	f	2025-11-05 19:22:23.513687-08
443ac82c-264d-4e28-af5a-7202bcf791c9	e037dc98-b83a-42b1-8608-c330263c8b0f	c41ce7d7-cf0f-450e-b2ec-a3c40cc1448b	t	2025-11-05 19:22:23.513687-08
a8d7c8c6-3744-4e0c-940b-2df004dbe145	1ea493cc-2597-470a-9d18-68791da120ff	6ce5da82-0ee9-4e89-a08d-18e25f01d97f	f	2025-11-05 19:22:23.513687-08
3f128400-9acd-440f-93a8-3d9ade965986	1ea493cc-2597-470a-9d18-68791da120ff	69692eb7-cdc7-45fa-84ba-af0a1f469c2a	f	2025-11-05 19:22:23.513687-08
4cd2f5ee-8816-4a22-bb48-d85e93c95bff	1ea493cc-2597-470a-9d18-68791da120ff	01bff051-8516-467d-82b3-eb626c9451b9	f	2025-11-05 19:22:23.513687-08
584d6a4f-f5da-41d0-996e-e588d6ec3403	1ea493cc-2597-470a-9d18-68791da120ff	0e5d5302-d5df-4bdc-8890-5b750d8f3fbf	f	2025-11-05 19:22:23.513687-08
0e8ee02c-4fd3-4f77-a41c-59584c293464	1ea493cc-2597-470a-9d18-68791da120ff	4a94dfc9-3848-415c-977d-fce4ad82ad57	t	2025-11-05 19:22:23.513687-08
08d66572-23ed-480f-a649-4e0165d70900	81a84a1a-e75e-4d24-b65e-54dda092b3a9	daf5dc82-0255-4150-bfe1-e3edb4535ef9	f	2025-11-05 19:22:23.513687-08
a2de2c17-8a3c-4fb1-941d-93bb36025a2e	81a84a1a-e75e-4d24-b65e-54dda092b3a9	328aa03c-ae86-49de-a989-bd82c57b2e9d	f	2025-11-05 19:22:23.513687-08
1ed75a06-2931-471b-bdcb-8b161993ee52	81a84a1a-e75e-4d24-b65e-54dda092b3a9	76c9d00e-4da1-4882-9d99-46d3e6d18d83	t	2025-11-05 19:22:23.513687-08
\.


--
-- Data for Name: team_ta_assignments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.team_ta_assignments (id, team_id, ta_user_id, created_at) FROM stdin;
7db6c6f1-69b3-471c-8a9b-3edaf0f4b82a	48b4c2f2-f533-4db6-b22c-56393cecddfe	beff22c0-8f70-44ce-b777-577841338ce8	2025-11-05 19:22:23.524668-08
24686b2c-8ef0-48ad-9ae1-de145819d004	e037dc98-b83a-42b1-8608-c330263c8b0f	a774f7fc-6885-420b-a5ae-d5f882295303	2025-11-05 19:22:23.524668-08
546b6e26-156d-43a6-94ce-310d275aa692	1ea493cc-2597-470a-9d18-68791da120ff	1b06383f-fd15-4bbd-b8f1-0968f6993ed1	2025-11-05 19:22:23.524668-08
1aa3544a-c662-4cde-80f1-4dd3f777b3e1	81a84a1a-e75e-4d24-b65e-54dda092b3a9	beff22c0-8f70-44ce-b777-577841338ce8	2025-11-05 19:22:23.524668-08
\.


--
-- Data for Name: teams; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.teams (id, course_id, code, name, created_at) FROM stdin;
48b4c2f2-f533-4db6-b22c-56393cecddfe	8be3dcbe-c607-4903-af38-5e0608bc967d	team-1	Team 1	2025-11-05 19:22:23.513687-08
e037dc98-b83a-42b1-8608-c330263c8b0f	8be3dcbe-c607-4903-af38-5e0608bc967d	team-2	Team 2	2025-11-05 19:22:23.513687-08
1ea493cc-2597-470a-9d18-68791da120ff	8be3dcbe-c607-4903-af38-5e0608bc967d	team-3	Team 3	2025-11-05 19:22:23.513687-08
81a84a1a-e75e-4d24-b65e-54dda092b3a9	8be3dcbe-c607-4903-af38-5e0608bc967d	team-4	Team 4	2025-11-05 19:22:23.513687-08
\.


--
-- Data for Name: terms; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.terms (id, code, name, starts_on, ends_on) FROM stdin;
5ca1c782-474b-4cb4-b11a-b666974abcc3	FA25	Fall 2025	2025-09-22	2025-12-12
\.


--
-- Data for Name: user_profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_profiles (user_id, name_pronunciation, photo_url, phone, socials, availability_notes, custom, updated_at) FROM stdin;
fa8e289c-476a-4d59-9d20-ad25043d5670	MARE-ee-uh	https://picsum.photos/seed/prof-marya/200	+1-858-555-0101	{"slack": "@marya", "github": "marya-conductor"}	Office hours Tue/Thu 2–4pm, CSE Basement.	{}	2025-11-05 15:42:56.333939-08
b041d90c-594d-44da-825f-5e8944f54e46	\N	https://picsum.photos/seed/alex-stu1/160	\N	{"github": "alex.stu1"}	Available most afternoons.	{}	2025-11-05 16:04:40.040513-08
f789e04f-1cca-49b9-bf39-f2c770193e50	\N	https://picsum.photos/seed/brenda-stu2/160	\N	{"github": "brenda.stu2"}	Available most afternoons.	{}	2025-11-05 16:04:40.040513-08
ba33dd11-2e99-4fa2-8195-ee7cbf3b2727	\N	https://picsum.photos/seed/carlos-stu3/160	\N	{"github": "carlos.stu3"}	Available most afternoons.	{}	2025-11-05 16:04:40.040513-08
c41ce7d7-cf0f-450e-b2ec-a3c40cc1448b	\N	https://picsum.photos/seed/dina-stu4/160	\N	{"github": "dina.stu4"}	Available most afternoons.	{}	2025-11-05 16:04:40.040513-08
34de1197-f5f0-4fdc-adb2-5a519df90f6c	\N	https://picsum.photos/seed/eli-stu5/160	\N	{"github": "eli.stu5"}	Available most afternoons.	{}	2025-11-05 16:04:40.040513-08
1901ae31-036c-4ff3-a3fb-01ba4724a550	\N	https://picsum.photos/seed/farah-stu6/160	\N	{"github": "farah.stu6"}	Available most afternoons.	{}	2025-11-05 16:04:40.040513-08
dbb2aaf1-779e-4ada-80f2-48b7790e16ec	\N	https://picsum.photos/seed/gavin-stu7/160	\N	{"github": "gavin.stu7"}	Available most afternoons.	{}	2025-11-05 16:04:40.040513-08
4a94dfc9-3848-415c-977d-fce4ad82ad57	\N	https://picsum.photos/seed/hana-stu8/160	\N	{"github": "hana.stu8"}	Available most afternoons.	{}	2025-11-05 16:04:40.040513-08
0e5d5302-d5df-4bdc-8890-5b750d8f3fbf	\N	https://picsum.photos/seed/ivan-stu9/160	\N	{"github": "ivan.stu9"}	Available most afternoons.	{}	2025-11-05 16:04:40.040513-08
6ce5da82-0ee9-4e89-a08d-18e25f01d97f	\N	https://picsum.photos/seed/jules-stu10/160	\N	{"github": "jules.stu10"}	Available most afternoons.	{}	2025-11-05 16:04:40.040513-08
b7731e34-c96d-4c4f-beeb-0e4b3d66b4b5	\N	https://via.placeholder.com/84?text=Prof	\N	{}	\N	{}	2025-11-05 17:31:02.273906-08
b8300f2c-ac86-4a19-b443-167933584cfc	\N	https://via.placeholder.com/84?text=S	\N	{}	\N	{}	2025-11-05 17:31:02.276914-08
69692eb7-cdc7-45fa-84ba-af0a1f469c2a	\N	https://via.placeholder.com/84?text=S	\N	{}	\N	{}	2025-11-05 17:31:02.276914-08
beff22c0-8f70-44ce-b777-577841338ce8	\N	https://via.placeholder.com/84?text=TA	\N	{}	\N	{}	2025-11-05 18:44:34.116278-08
1b06383f-fd15-4bbd-b8f1-0968f6993ed1	\N	https://via.placeholder.com/84?text=TA	\N	{}	\N	{}	2025-11-05 18:44:34.116278-08
a774f7fc-6885-420b-a5ae-d5f882295303	\N	https://via.placeholder.com/84?text=TA	\N	{}	\N	{}	2025-11-05 18:44:34.116278-08
daf5dc82-0255-4150-bfe1-e3edb4535ef9	\N	https://via.placeholder.com/84?text=S	\N	{}	\N	{}	2025-11-05 18:58:45.730003-08
7c10cb0d-4922-4e6e-b998-e5a3b01dc2d9	\N	https://via.placeholder.com/84?text=S	\N	{}	\N	{}	2025-11-05 18:58:45.730003-08
328aa03c-ae86-49de-a989-bd82c57b2e9d	\N	https://via.placeholder.com/84?text=S	\N	{}	\N	{}	2025-11-05 18:58:45.730003-08
76c9d00e-4da1-4882-9d99-46d3e6d18d83	\N	https://via.placeholder.com/84?text=S	\N	{}	\N	{}	2025-11-05 18:58:45.730003-08
d7e008f8-7a76-4032-8f5f-77fd0bb95542	\N	https://via.placeholder.com/84?text=S	\N	{}	\N	{}	2025-11-05 18:58:45.730003-08
01bff051-8516-467d-82b3-eb626c9451b9	\N	https://via.placeholder.com/84?text=S	\N	{}	\N	{}	2025-11-05 18:58:45.730003-08
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, email, email_verified_at, given_name, family_name, display_name, pronouns, locale, time_zone, is_active, created_at, updated_at) FROM stdin;
fa8e289c-476a-4d59-9d20-ad25043d5670	marya.prof@example.edu	2025-11-05 15:42:56.333939-08	Marya	Conductor	Prof. Marya Conductor	she/her	en	America/Los_Angeles	t	2025-11-05 15:42:56.333939-08	2025-11-05 15:42:56.333939-08
b041d90c-594d-44da-825f-5e8944f54e46	alex.stu1@example.edu	2025-11-05 16:03:17.165399-08	Alex	Lee	Alex Lee	they/them	en	America/Los_Angeles	t	2025-11-05 16:03:17.165399-08	2025-11-05 16:03:17.165399-08
f789e04f-1cca-49b9-bf39-f2c770193e50	brenda.stu2@example.edu	2025-11-05 16:03:17.165399-08	Brenda	Nguyen	Brenda Nguyen	she/her	en	America/Los_Angeles	t	2025-11-05 16:03:17.165399-08	2025-11-05 16:03:17.165399-08
ba33dd11-2e99-4fa2-8195-ee7cbf3b2727	carlos.stu3@example.edu	2025-11-05 16:03:17.165399-08	Carlos	Garcia	Carlos Garcia	he/him	en	America/Los_Angeles	t	2025-11-05 16:03:17.165399-08	2025-11-05 16:03:17.165399-08
c41ce7d7-cf0f-450e-b2ec-a3c40cc1448b	dina.stu4@example.edu	2025-11-05 16:03:17.165399-08	Dina	Khan	Dina Khan	she/her	en	America/Los_Angeles	t	2025-11-05 16:03:17.165399-08	2025-11-05 16:03:17.165399-08
34de1197-f5f0-4fdc-adb2-5a519df90f6c	eli.stu5@example.edu	2025-11-05 16:03:17.165399-08	Eli	Patel	Eli Patel	they/them	en	America/Los_Angeles	t	2025-11-05 16:03:17.165399-08	2025-11-05 16:03:17.165399-08
1901ae31-036c-4ff3-a3fb-01ba4724a550	farah.stu6@example.edu	2025-11-05 16:03:17.165399-08	Farah	Hassan	Farah Hassan	she/her	en	America/Los_Angeles	t	2025-11-05 16:03:17.165399-08	2025-11-05 16:03:17.165399-08
dbb2aaf1-779e-4ada-80f2-48b7790e16ec	gavin.stu7@example.edu	2025-11-05 16:03:17.165399-08	Gavin	Smith	Gavin Smith	he/him	en	America/Los_Angeles	t	2025-11-05 16:03:17.165399-08	2025-11-05 16:03:17.165399-08
4a94dfc9-3848-415c-977d-fce4ad82ad57	hana.stu8@example.edu	2025-11-05 16:03:17.165399-08	Hana	Kim	Hana Kim	she/her	en	America/Los_Angeles	t	2025-11-05 16:03:17.165399-08	2025-11-05 16:03:17.165399-08
0e5d5302-d5df-4bdc-8890-5b750d8f3fbf	ivan.stu9@example.edu	2025-11-05 16:03:17.165399-08	Ivan	Petrov	Ivan Petrov	he/him	en	America/Los_Angeles	t	2025-11-05 16:03:17.165399-08	2025-11-05 16:03:17.165399-08
6ce5da82-0ee9-4e89-a08d-18e25f01d97f	jules.stu10@example.edu	2025-11-05 16:03:17.165399-08	Jules	Martin	Jules Martin	they/them	en	America/Los_Angeles	t	2025-11-05 16:03:17.165399-08	2025-11-05 16:03:17.165399-08
b7731e34-c96d-4c4f-beeb-0e4b3d66b4b5	marya.conductor@example.edu	\N	\N	\N	Prof. Marya Conductor	\N	en	America/Los_Angeles	t	2025-11-05 17:31:02.268043-08	2025-11-05 17:31:02.268043-08
b8300f2c-ac86-4a19-b443-167933584cfc	alex.lee@example.edu	\N	\N	\N	Alex Lee	\N	en	America/Los_Angeles	t	2025-11-05 17:31:02.273074-08	2025-11-05 17:31:02.273074-08
69692eb7-cdc7-45fa-84ba-af0a1f469c2a	jordan.kim@example.edu	\N	\N	\N	Jordan Kim	\N	en	America/Los_Angeles	t	2025-11-05 17:31:02.273575-08	2025-11-05 17:31:02.273575-08
beff22c0-8f70-44ce-b777-577841338ce8	ta.one@example.edu	\N	\N	\N	TA One	\N	en	America/Los_Angeles	t	2025-11-05 18:44:34.113039-08	2025-11-05 18:44:34.113039-08
1b06383f-fd15-4bbd-b8f1-0968f6993ed1	ta.two@example.edu	\N	\N	\N	TA Two	\N	en	America/Los_Angeles	t	2025-11-05 18:44:34.115503-08	2025-11-05 18:44:34.115503-08
a774f7fc-6885-420b-a5ae-d5f882295303	ta.three@example.edu	\N	\N	\N	TA Three	\N	en	America/Los_Angeles	t	2025-11-05 18:44:34.115967-08	2025-11-05 18:44:34.115967-08
daf5dc82-0255-4150-bfe1-e3edb4535ef9	sam.taylor@example.edu	\N	\N	\N	Sam Taylor	\N	en	America/Los_Angeles	t	2025-11-05 18:58:45.730003-08	2025-11-05 18:58:45.730003-08
7c10cb0d-4922-4e6e-b998-e5a3b01dc2d9	casey.ng@example.edu	\N	\N	\N	Casey Ng	\N	en	America/Los_Angeles	t	2025-11-05 18:58:45.730003-08	2025-11-05 18:58:45.730003-08
328aa03c-ae86-49de-a989-bd82c57b2e9d	riley.chen@example.edu	\N	\N	\N	Riley Chen	\N	en	America/Los_Angeles	t	2025-11-05 18:58:45.730003-08	2025-11-05 18:58:45.730003-08
76c9d00e-4da1-4882-9d99-46d3e6d18d83	morgan.patel@example.edu	\N	\N	\N	Morgan Patel	\N	en	America/Los_Angeles	t	2025-11-05 18:58:45.730003-08	2025-11-05 18:58:45.730003-08
d7e008f8-7a76-4032-8f5f-77fd0bb95542	drew.garcia@example.edu	\N	\N	\N	Drew Garcia	\N	en	America/Los_Angeles	t	2025-11-05 18:58:45.730003-08	2025-11-05 18:58:45.730003-08
01bff051-8516-467d-82b3-eb626c9451b9	jamie.khan@example.edu	\N	\N	\N	Jamie Khan	\N	en	America/Los_Angeles	t	2025-11-05 18:58:45.730003-08	2025-11-05 18:58:45.730003-08
\.


--
-- Data for Name: work_journals; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.work_journals (id, course_id, user_id, content, sentiment_self, sentiment_team, sentiment_course, reach_out_to, created_at) FROM stdin;
f11cf25e-ab74-4c4c-bf3e-cc931a83edfb	8be3dcbe-c607-4903-af38-5e0608bc967d	b041d90c-594d-44da-825f-5e8944f54e46	I feel good	1	0	0	professor	2025-11-05 18:35:14.614611-08
726ecf4b-5074-44a1-94af-73f5e10d43da	8be3dcbe-c607-4903-af38-5e0608bc967d	b041d90c-594d-44da-825f-5e8944f54e46	hey TA	0	0	0	ta	2025-11-05 19:11:50.863735-08
d62438ff-ef9c-4526-ac35-49abc4c5c886	8be3dcbe-c607-4903-af38-5e0608bc967d	f789e04f-1cca-49b9-bf39-f2c770193e50	Hi prof i had a question .....	1	1	1	professor	2025-11-05 19:37:39.626185-08
5d90bb86-a287-44d4-9f0b-b95a0c87ee96	8be3dcbe-c607-4903-af38-5e0608bc967d	7c10cb0d-4922-4e6e-b998-e5a3b01dc2d9	hi prof what's up	0	0	0	\N	2025-11-08 21:35:27.052152-08
f6178b40-b97f-417e-891e-9e093e625070	8be3dcbe-c607-4903-af38-5e0608bc967d	7c10cb0d-4922-4e6e-b998-e5a3b01dc2d9	hi prof what's up	0	0	0	professor	2025-11-08 21:35:45.944111-08
5a514061-2554-4a9d-99c7-0808b42a9974	8be3dcbe-c607-4903-af38-5e0608bc967d	daf5dc82-0255-4150-bfe1-e3edb4535ef9	hey what' sup	0	0	0	professor	2025-11-08 22:04:21.764508-08
25c36ad3-31cd-4da9-b5ca-13ccb3ce7a64	8be3dcbe-c607-4903-af38-5e0608bc967d	c41ce7d7-cf0f-450e-b2ec-a3c40cc1448b	hi Dina Khan	0	0	0	professor	2025-11-08 22:23:55.472219-08
963139bf-728e-4b1f-ab82-d1e03b957ccb	8be3dcbe-c607-4903-af38-5e0608bc967d	4a94dfc9-3848-415c-977d-fce4ad82ad57	hi Hana Kim	0	0	0	professor	2025-11-08 22:24:45.767059-08
c16ac4d2-3037-48ab-8ad9-a4556c90bbf4	8be3dcbe-c607-4903-af38-5e0608bc967d	0e5d5302-d5df-4bdc-8890-5b750d8f3fbf	hi Ivan	0	0	0	professor	2025-11-08 22:25:36.327828-08
69ec40ac-a622-445b-9b83-944a231c7992	8be3dcbe-c607-4903-af38-5e0608bc967d	f789e04f-1cca-49b9-bf39-f2c770193e50	Hi prof I had a question	0	0	0	professor	2025-11-08 23:01:24.953054-08
\.


--
-- Name: attendances attendances_course_id_user_id_attended_on_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendances
    ADD CONSTRAINT attendances_course_id_user_id_attended_on_key UNIQUE (course_id, user_id, attended_on);


--
-- Name: attendances attendances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendances
    ADD CONSTRAINT attendances_pkey PRIMARY KEY (id);


--
-- Name: course_info course_info_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_info
    ADD CONSTRAINT course_info_pkey PRIMARY KEY (course_id);


--
-- Name: course_memberships course_memberships_course_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_memberships
    ADD CONSTRAINT course_memberships_course_id_user_id_key UNIQUE (course_id, user_id);


--
-- Name: course_memberships course_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_memberships
    ADD CONSTRAINT course_memberships_pkey PRIMARY KEY (id);


--
-- Name: course_rubric_items course_rubric_items_course_id_item_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_rubric_items
    ADD CONSTRAINT course_rubric_items_course_id_item_key_key UNIQUE (course_id, item_key);


--
-- Name: course_rubric_items course_rubric_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_rubric_items
    ADD CONSTRAINT course_rubric_items_pkey PRIMARY KEY (id);


--
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (id);


--
-- Name: courses courses_term_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_term_id_code_key UNIQUE (term_id, code);


--
-- Name: eval_notes eval_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.eval_notes
    ADD CONSTRAINT eval_notes_pkey PRIMARY KEY (id);


--
-- Name: journal_replies journal_replies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_replies
    ADD CONSTRAINT journal_replies_pkey PRIMARY KEY (id);


--
-- Name: role_assignments role_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_pkey PRIMARY KEY (id);


--
-- Name: role_assignments role_assignments_user_id_role_id_scope_type_scope_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_user_id_role_id_scope_type_scope_id_key UNIQUE (user_id, role_id, scope_type, scope_id);


--
-- Name: roles roles_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_key_key UNIQUE (key);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (id);


--
-- Name: team_members team_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_pkey PRIMARY KEY (id);


--
-- Name: team_members team_members_team_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_team_id_user_id_key UNIQUE (team_id, user_id);


--
-- Name: team_ta_assignments team_ta_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_ta_assignments
    ADD CONSTRAINT team_ta_assignments_pkey PRIMARY KEY (id);


--
-- Name: team_ta_assignments team_ta_assignments_team_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_ta_assignments
    ADD CONSTRAINT team_ta_assignments_team_id_key UNIQUE (team_id);


--
-- Name: teams teams_course_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_course_id_code_key UNIQUE (course_id, code);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: terms terms_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.terms
    ADD CONSTRAINT terms_code_key UNIQUE (code);


--
-- Name: terms terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.terms
    ADD CONSTRAINT terms_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: work_journals work_journals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_journals
    ADD CONSTRAINT work_journals_pkey PRIMARY KEY (id);


--
-- Name: eval_notes_author_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX eval_notes_author_idx ON public.eval_notes USING btree (author_id, created_at DESC);


--
-- Name: eval_notes_course_subject_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX eval_notes_course_subject_idx ON public.eval_notes USING btree (course_id, subject_type, subject_id);


--
-- Name: idx_attend_course_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attend_course_date ON public.attendances USING btree (course_id, attended_on);


--
-- Name: idx_attend_course_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attend_course_user ON public.attendances USING btree (course_id, user_id);


--
-- Name: idx_course_membership_course; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_course_membership_course ON public.course_memberships USING btree (course_id);


--
-- Name: idx_course_membership_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_course_membership_user ON public.course_memberships USING btree (user_id);


--
-- Name: idx_journal_replies_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_journal_replies_created_at ON public.journal_replies USING btree (created_at DESC);


--
-- Name: idx_journal_replies_journal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_journal_replies_journal_id ON public.journal_replies USING btree (journal_id);


--
-- Name: idx_role_assign_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_role_assign_scope ON public.role_assignments USING btree (scope_type, scope_id);


--
-- Name: idx_schedules_course_deadline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_schedules_course_deadline ON public.schedules USING btree (course_id, deadline_at, created_at DESC);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: idx_work_journals_course_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_journals_course_created ON public.work_journals USING btree (course_id, created_at DESC);


--
-- Name: idx_work_journals_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_journals_user_created ON public.work_journals USING btree (user_id, created_at DESC);


--
-- Name: attendances attendances_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendances
    ADD CONSTRAINT attendances_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: attendances attendances_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendances
    ADD CONSTRAINT attendances_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: course_info course_info_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_info
    ADD CONSTRAINT course_info_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: course_memberships course_memberships_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_memberships
    ADD CONSTRAINT course_memberships_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: course_memberships course_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_memberships
    ADD CONSTRAINT course_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: course_rubric_items course_rubric_items_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_rubric_items
    ADD CONSTRAINT course_rubric_items_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: courses courses_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_term_id_fkey FOREIGN KEY (term_id) REFERENCES public.terms(id) ON DELETE CASCADE;


--
-- Name: eval_notes eval_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.eval_notes
    ADD CONSTRAINT eval_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: eval_notes eval_notes_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.eval_notes
    ADD CONSTRAINT eval_notes_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: journal_replies journal_replies_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_replies
    ADD CONSTRAINT journal_replies_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: journal_replies journal_replies_journal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_replies
    ADD CONSTRAINT journal_replies_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES public.work_journals(id) ON DELETE CASCADE;


--
-- Name: role_assignments role_assignments_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: role_assignments role_assignments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: schedules schedules_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: schedules schedules_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: team_members team_members_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: team_members team_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: team_ta_assignments team_ta_assignments_ta_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_ta_assignments
    ADD CONSTRAINT team_ta_assignments_ta_user_id_fkey FOREIGN KEY (ta_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: team_ta_assignments team_ta_assignments_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_ta_assignments
    ADD CONSTRAINT team_ta_assignments_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: teams teams_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: user_profiles user_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: work_journals work_journals_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_journals
    ADD CONSTRAINT work_journals_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: work_journals work_journals_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_journals
    ADD CONSTRAINT work_journals_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict LRhKujPVTgEERgigavxgMLuOnUVkGQJXKY158GFE0eS8IR9HfTLAnSwa4fHlBO1

