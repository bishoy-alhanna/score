--
-- PostgreSQL database dump
--

\restrict n6vbdaF77prBaqeTYqgZPj8CFBljrMV3WnN8OskLpaJ8DgXbyDVb37dN9H74eFI

-- Dumped from database version 15.15
-- Dumped by pg_dump version 15.15

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
-- Name: cleanup_duplicate_pending_requests(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cleanup_duplicate_pending_requests() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Remove any existing pending requests for the same user-organization pair
    DELETE FROM organization_join_requests 
    WHERE user_id = NEW.user_id 
      AND organization_id = NEW.organization_id 
      AND status = 'PENDING'
      AND id != NEW.id;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.cleanup_duplicate_pending_requests() OWNER TO postgres;

--
-- Name: update_score_aggregate(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_score_aggregate() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Handle user score aggregates
    IF NEW.user_id IS NOT NULL THEN
        INSERT INTO score_aggregates (user_id, category, organization_id, total_score, score_count, average_score)
        SELECT 
            NEW.user_id,
            NEW.category,
            NEW.organization_id,
            COALESCE(SUM(score_value), 0),
            COUNT(*),
            COALESCE(AVG(score_value), 0)
        FROM scores 
        WHERE user_id = NEW.user_id 
          AND category = NEW.category 
          AND organization_id = NEW.organization_id
        ON CONFLICT (user_id, category, organization_id) 
        DO UPDATE SET
            total_score = EXCLUDED.total_score,
            score_count = EXCLUDED.score_count,
            average_score = EXCLUDED.average_score,
            last_updated = CURRENT_TIMESTAMP;
    END IF;
    
    -- Handle group score aggregates
    IF NEW.group_id IS NOT NULL THEN
        INSERT INTO score_aggregates (group_id, category, organization_id, total_score, score_count, average_score)
        SELECT 
            NEW.group_id,
            NEW.category,
            NEW.organization_id,
            COALESCE(SUM(score_value), 0),
            COUNT(*),
            COALESCE(AVG(score_value), 0)
        FROM scores 
        WHERE group_id = NEW.group_id 
          AND category = NEW.category 
          AND organization_id = NEW.organization_id
        ON CONFLICT (group_id, category, organization_id) 
        DO UPDATE SET
            total_score = EXCLUDED.total_score,
            score_count = EXCLUDED.score_count,
            average_score = EXCLUDED.average_score,
            last_updated = CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_score_aggregate() OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    organization_id uuid NOT NULL,
    created_by uuid NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.groups OWNER TO postgres;

--
-- Name: organizations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.organizations OWNER TO postgres;

--
-- Name: score_aggregates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.score_aggregates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    group_id uuid,
    category character varying(255) DEFAULT 'general'::character varying,
    total_score integer DEFAULT 0,
    score_count integer DEFAULT 0,
    average_score numeric(10,2) DEFAULT 0.0,
    organization_id uuid NOT NULL,
    last_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_aggregate_user_or_group CHECK ((((user_id IS NOT NULL) AND (group_id IS NULL)) OR ((user_id IS NULL) AND (group_id IS NOT NULL))))
);


ALTER TABLE public.score_aggregates OWNER TO postgres;

--
-- Name: group_leaderboard; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.group_leaderboard AS
 SELECT g.id AS group_id,
    g.name AS group_name,
    g.organization_id,
    o.name AS organization_name,
    sa.category,
    sa.total_score,
    sa.score_count,
    sa.average_score,
    rank() OVER (PARTITION BY g.organization_id, sa.category ORDER BY sa.total_score DESC) AS rank
   FROM ((public.groups g
     JOIN public.organizations o ON ((g.organization_id = o.id)))
     JOIN public.score_aggregates sa ON ((g.id = sa.group_id)))
  WHERE (g.is_active = true)
  ORDER BY g.organization_id, sa.category, sa.total_score DESC;


ALTER TABLE public.group_leaderboard OWNER TO postgres;

--
-- Name: group_members; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.group_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    group_id uuid NOT NULL,
    user_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    role character varying(50) DEFAULT 'MEMBER'::character varying,
    joined_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    is_active boolean DEFAULT true
);


ALTER TABLE public.group_members OWNER TO postgres;

--
-- Name: organization_invitations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization_invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    invited_by uuid NOT NULL,
    email character varying(255) NOT NULL,
    role character varying(50) DEFAULT 'USER'::character varying,
    message text,
    token character varying(255) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    status character varying(50) DEFAULT 'PENDING'::character varying,
    accepted_by uuid,
    accepted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.organization_invitations OWNER TO postgres;

--
-- Name: organization_join_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization_join_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    requested_role character varying(50) DEFAULT 'USER'::character varying,
    message text,
    status character varying(50) DEFAULT 'PENDING'::character varying,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    review_message text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.organization_join_requests OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    first_name character varying(255),
    last_name character varying(255),
    profile_picture_url character varying(500),
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    birthdate date,
    phone_number character varying(50),
    bio text,
    gender character varying(50),
    school_year character varying(50),
    student_id character varying(100),
    major character varying(255),
    gpa numeric(3,2),
    graduation_year integer,
    university_name character varying(255),
    faculty_name character varying(255),
    address_line1 character varying(500),
    address_line2 character varying(500),
    city character varying(255),
    state character varying(255),
    postal_code character varying(50),
    country character varying(100),
    emergency_contact_name character varying(255),
    emergency_contact_phone character varying(50),
    emergency_contact_relationship character varying(100),
    linkedin_url character varying(500),
    github_url character varying(500),
    personal_website character varying(500),
    timezone character varying(100) DEFAULT 'UTC'::character varying,
    language character varying(10) DEFAULT 'en'::character varying,
    notification_preferences jsonb DEFAULT '{"push": false, "email": true}'::jsonb,
    is_verified boolean DEFAULT false,
    email_verified_at timestamp with time zone,
    last_login_at timestamp with time zone,
    qr_code_token character varying(255),
    qr_code_generated_at timestamp with time zone,
    qr_code_expires_at timestamp with time zone,
    is_super_admin boolean DEFAULT false
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: pending_organization_requests; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.pending_organization_requests AS
 SELECT ojr.id AS request_id,
    ojr.user_id,
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    ojr.organization_id,
    o.name AS organization_name,
    ojr.requested_role,
    ojr.message,
    ojr.created_at AS requested_at
   FROM ((public.organization_join_requests ojr
     JOIN public.users u ON ((ojr.user_id = u.id)))
     JOIN public.organizations o ON ((ojr.organization_id = o.id)))
  WHERE ((ojr.status)::text = 'PENDING'::text)
  ORDER BY ojr.created_at;


ALTER TABLE public.pending_organization_requests OWNER TO postgres;

--
-- Name: qr_scan_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.qr_scan_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    scanned_user_id uuid NOT NULL,
    scanner_user_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    qr_token character varying(255) NOT NULL,
    scan_result character varying(50) NOT NULL,
    score_assigned numeric(10,2),
    score_type character varying(50),
    scan_ip inet,
    user_agent text,
    scanned_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.qr_scan_logs OWNER TO postgres;

--
-- Name: score_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.score_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    max_score integer DEFAULT 100,
    organization_id uuid NOT NULL,
    created_by uuid,
    is_active boolean DEFAULT true,
    is_predefined boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.score_categories OWNER TO postgres;

--
-- Name: scores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    group_id uuid,
    score_value integer NOT NULL,
    category character varying(255) DEFAULT 'general'::character varying,
    description text,
    organization_id uuid NOT NULL,
    assigned_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    category_id uuid,
    CONSTRAINT check_user_or_group CHECK ((((user_id IS NOT NULL) AND (group_id IS NULL)) OR ((user_id IS NULL) AND (group_id IS NOT NULL))))
);


ALTER TABLE public.scores OWNER TO postgres;

--
-- Name: super_admin_config; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.super_admin_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.super_admin_config OWNER TO postgres;

--
-- Name: user_organizations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    role character varying(50) DEFAULT 'USER'::character varying NOT NULL,
    department character varying(255),
    title character varying(255),
    is_active boolean DEFAULT true,
    joined_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    left_at timestamp with time zone
);


ALTER TABLE public.user_organizations OWNER TO postgres;

--
-- Name: user_organization_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.user_organization_details AS
 SELECT u.id AS user_id,
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    uo.organization_id,
    o.name AS organization_name,
    uo.role,
    uo.department,
    uo.title,
    uo.is_active AS membership_active,
    uo.joined_at
   FROM ((public.users u
     JOIN public.user_organizations uo ON ((u.id = uo.user_id)))
     JOIN public.organizations o ON ((uo.organization_id = o.id)))
  WHERE ((u.is_active = true) AND (uo.is_active = true));


ALTER TABLE public.user_organization_details OWNER TO postgres;

--
-- Name: user_leaderboard; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.user_leaderboard AS
 SELECT uod.user_id,
    uod.username,
    uod.first_name,
    uod.last_name,
    uod.organization_id,
    uod.organization_name,
    sa.category,
    sa.total_score,
    sa.score_count,
    sa.average_score,
    rank() OVER (PARTITION BY uod.organization_id, sa.category ORDER BY sa.total_score DESC) AS rank
   FROM (public.user_organization_details uod
     JOIN public.score_aggregates sa ON (((uod.user_id = sa.user_id) AND (uod.organization_id = sa.organization_id))))
  ORDER BY uod.organization_id, sa.category, sa.total_score DESC;


ALTER TABLE public.user_leaderboard OWNER TO postgres;

--
-- Data for Name: group_members; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.group_members (id, group_id, user_id, organization_id, role, joined_at, is_active) FROM stdin;
16ff6d48-45ed-438c-8243-93e709bee701	7d800f80-95f3-4398-8c4a-ec410f095447	fd0444af-6d38-469f-8355-cb87f441eafa	2339e8c4-dbe5-4d60-9828-2e129374b15b	MEMBER	2025-11-20 16:19:11.191287+00	t
f485545d-5e5a-4427-a5d2-836119fe7bfb	7d800f80-95f3-4398-8c4a-ec410f095447	43ead350-6b4a-42a8-8fd8-57ae0c09cc38	2339e8c4-dbe5-4d60-9828-2e129374b15b	MEMBER	2025-11-20 16:19:14.806321+00	t
c819af81-f62a-43e4-8207-9e951ee7a870	7d800f80-95f3-4398-8c4a-ec410f095447	4543ec53-772f-48d5-a393-cce7732c5c6a	2339e8c4-dbe5-4d60-9828-2e129374b15b	MEMBER	2025-11-20 16:19:22.275677+00	t
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.groups (id, name, description, organization_id, created_by, is_active, created_at, updated_at) FROM stdin;
7d800f80-95f3-4398-8c4a-ec410f095447	فريق الخدمة	فريق خدمة الكنيسة	2339e8c4-dbe5-4d60-9828-2e129374b15b	4543ec53-772f-48d5-a393-cce7732c5c6a	t	2025-11-17 21:46:01.250915+00	2025-11-17 21:46:01.250915+00
cbc9c7cc-0b24-4761-beb3-964294d8aea3	مجموعة الشباب	مجموعة الشباب الرئيسية	2339e8c4-dbe5-4d60-9828-2e129374b15b	4543ec53-772f-48d5-a393-cce7732c5c6a	f	2025-11-17 21:44:03.66939+00	2025-11-18 00:35:20.780465+00
d5df6338-391a-4eac-8fea-7a79eed73b05	فريق التسبيح	فريق التسبيح والموسيقى	2339e8c4-dbe5-4d60-9828-2e129374b15b	4543ec53-772f-48d5-a393-cce7732c5c6a	f	2025-11-17 21:46:01.250915+00	2025-11-18 00:35:24.180389+00
\.


--
-- Data for Name: organization_invitations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.organization_invitations (id, organization_id, invited_by, email, role, message, token, expires_at, status, accepted_by, accepted_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: organization_join_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.organization_join_requests (id, user_id, organization_id, requested_role, message, status, reviewed_by, reviewed_at, review_message, created_at, updated_at) FROM stdin;
9a3c7dc3-3370-46e2-8c1e-4f2465dfb82d	43c97fdd-043d-4025-aadc-ce78071a02fb	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Login join request from test user	APPROVED	4543ec53-772f-48d5-a393-cce7732c5c6a	2025-11-16 18:28:45.914533+00		2025-11-16 18:28:18.202407+00	2025-11-16 18:28:45.911645+00
7cfa3749-e7a8-46cd-8779-78e2955352aa	6115f818-ef2c-49e7-8013-3109dbbc03a8	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Login join request from Test2 Test	APPROVED	4543ec53-772f-48d5-a393-cce7732c5c6a	2025-11-17 05:16:44.499908+00		2025-11-17 05:15:28.281362+00	2025-11-17 05:16:44.497145+00
0d4022fa-3100-4b5a-9bec-b696da9872ca	2a2447ab-6653-483d-bec3-a973f33df80d	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Test3 Test3	APPROVED	4543ec53-772f-48d5-a393-cce7732c5c6a	2025-11-18 00:01:19.0564+00		2025-11-18 00:00:41.172354+00	2025-11-18 00:01:19.053712+00
4662fca8-7dd3-420f-a858-bc42cfc49e84	1fb88c38-2c9a-4fc2-bc32-68a272d2c60f	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Login join request from Test User	REJECTED	4543ec53-772f-48d5-a393-cce7732c5c6a	2025-11-18 00:01:21.766906+00	Request rejected by admin	2025-11-17 21:28:57.870977+00	2025-11-18 00:01:21.764998+00
40ebe89d-e03f-4a09-877c-e315ac5bcc7a	9323eab0-992d-4aed-800b-c71183f0a74d	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Test22 22	APPROVED	4543ec53-772f-48d5-a393-cce7732c5c6a	2025-11-18 01:06:56.503012+00		2025-11-18 01:06:07.290028+00	2025-11-18 01:06:56.500961+00
435c659c-ddec-473c-92f9-596bd93a9f54	2a2447ab-6653-483d-bec3-a973f33df80d	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Login join request from Test3 Test3	REJECTED	4543ec53-772f-48d5-a393-cce7732c5c6a	2025-11-18 01:07:00.222031+00	Request rejected by admin	2025-11-18 01:06:22.511659+00	2025-11-18 01:07:00.219994+00
4bad0456-a1aa-4af4-acc9-3001c8bc044d	fd0444af-6d38-469f-8355-cb87f441eafa	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Bishoy Hanna	APPROVED	\N	2025-11-18 01:37:44.506131+00	Approved by Super Admin: superadmin	2025-11-18 01:36:39.876429+00	2025-11-18 01:37:44.501778+00
70deed47-48d2-4865-894a-d37f152910ec	9323eab0-992d-4aed-800b-c71183f0a74d	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Login join request from Test22 22	REJECTED	\N	2025-11-18 14:41:28.581986+00	Rejected by Super Admin: superadmin	2025-11-18 01:33:48.799445+00	2025-11-18 14:41:28.579118+00
b0463a43-1f2a-4246-8fd7-241a5684a62c	43ead350-6b4a-42a8-8fd8-57ae0c09cc38	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Amir Heshmat 	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-18 16:22:52.600561+00		2025-11-18 16:19:30.535957+00	2025-11-18 16:22:52.597604+00
3d1f57a6-8151-4c76-888d-bea0a1c2a962	fade3837-e9cb-4ac0-8a5f-3f2a6e17b1eb	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Samar Mina	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-21 12:06:06.076017+00		2025-11-20 15:57:12.737+00	2025-11-21 12:06:06.065986+00
4d8f0056-a568-459b-a99e-7165b4ed656c	b0bfdd30-d4de-45fe-9003-f3a83c621c6d	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from andrew youssef	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-21 18:25:34.131958+00		2025-11-21 18:24:51.000189+00	2025-11-21 18:25:34.129642+00
35373a78-7361-44bc-9da4-41e4af35b2d9	60674dc5-8ace-4706-9a0f-db1ce65b0864	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Bishoy Fawzy	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-21 21:08:48.235819+00		2025-11-21 21:07:45.902407+00	2025-11-21 21:08:48.232779+00
e37ef7d8-bb8f-4d67-885e-4b36109b8af2	0d03aab8-e0a5-45c4-98ba-e98adbb997cd	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Samy Maher	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 18:02:52.865269+00		2025-11-22 17:57:31.134566+00	2025-11-22 18:02:52.86304+00
ae8d7d0b-cb5e-4e6f-94d7-b4d7dc3fbe1f	d1447871-4f85-423e-a9c4-6c6f1cf36955	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Aboelwafa Mariam	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 18:02:54.911858+00		2025-11-22 18:02:02.016325+00	2025-11-22 18:02:54.909661+00
a0f26bca-4f49-4bf6-9e06-26d901cd6e34	556d06bd-50ed-4570-bcc1-e77ccac2f384	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Naiema  Dmyean 	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 18:02:56.993105+00		2025-11-22 18:02:25.99332+00	2025-11-22 18:02:56.9909+00
54d0f929-1a31-4436-8344-e0fb38aa5be1	a4e51f81-0b83-41cd-9a19-dd35e7e4d11d	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Kerolos Aboelwafa	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 18:17:04.510988+00		2025-11-22 18:17:01.287685+00	2025-11-22 18:17:04.507742+00
e9b49c27-aa81-456a-aa22-2178e5bfd9ac	316b6878-d2c3-4f75-a013-89b958e4192f	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Mina Rafat	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 18:28:35.395648+00		2025-11-22 18:27:16.608605+00	2025-11-22 18:28:35.393476+00
379cb426-d400-4076-a2dc-33bcc12988f5	7cc5d386-cc60-42c0-8db5-79ca9338d848	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Keros Victor	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 20:16:51.316599+00		2025-11-22 20:16:15.312345+00	2025-11-22 20:16:51.313995+00
1f47d946-9aae-4961-8b36-37ad4c85eeed	df663559-0b78-43e3-b5fe-93bec5e831ef	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Youstina Yousre	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 20:26:09.991859+00		2025-11-22 20:25:59.913606+00	2025-11-22 20:26:09.988618+00
66ef96ce-87d5-4d45-9901-8ae3972795f1	7ed13f74-8c28-4868-8fae-dedc6e667636	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Verena  Eshak	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 20:39:05.490451+00		2025-11-22 20:28:21.176556+00	2025-11-22 20:39:05.487368+00
833242f0-5878-434d-8385-4c96ff4ebf83	d08a65b6-f945-4cc4-88bc-4295271aa2ec	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Kerolos Romany	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 20:43:08.07625+00		2025-11-22 20:42:56.236999+00	2025-11-22 20:43:08.072712+00
4e8e3b28-5c1a-4e5c-9dce-f27c089f0c5f	0402b7ad-6089-44e1-9b69-49e0bd102563	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Maged Samy	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 20:44:46.255746+00		2025-11-22 20:44:39.902772+00	2025-11-22 20:44:46.253351+00
857ab9f0-2a6b-4ec6-9c95-fdd98ff97a59	33cb94c2-6699-4922-aba3-f151ac2c40e7	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Ebram Badee	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 20:55:26.216426+00		2025-11-22 20:55:24.845078+00	2025-11-22 20:55:26.212329+00
1dd2e5df-5f86-4ca3-b164-ca9a3a2d3970	cba93851-be6d-4af1-840b-5cafd00cc4e0	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from بيشوي  صبحي 	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-22 21:05:39.604518+00		2025-11-22 20:57:46.549059+00	2025-11-22 21:05:39.60229+00
6e08f7eb-69cf-46ba-9dd3-d4e47816545c	858c44e0-9944-4e4f-aef8-616d89912869	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Mariam  Ezzat	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-23 07:21:46.008654+00		2025-11-23 06:13:47.539289+00	2025-11-23 07:21:46.006551+00
e76ea351-e5e6-4645-bdbb-082573762c89	11a9ac9c-95d0-42bd-924d-dc7265f48715	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Abanoub Aiad	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-23 08:30:51.137269+00		2025-11-23 08:19:11.518742+00	2025-11-23 08:30:51.135147+00
a8ca57f7-f360-4705-8498-c2760bc990a6	96e31174-7f00-407e-ba79-823206dc9356	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Eriny  Shaker	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-23 08:50:14.810234+00		2025-11-23 08:38:40.454295+00	2025-11-23 08:50:14.808116+00
aa832f53-bf0d-4dc3-87c0-b7461fe569c2	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Dmyan  Marize	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-24 10:00:59.192269+00		2025-11-23 21:28:27.597357+00	2025-11-24 10:00:59.189141+00
eceded41-7962-4e41-bf39-72a55a01b97a	e35c2abd-e271-431a-a932-40ac3c101b09	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from حنان  لبيب 	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-24 15:39:53.497104+00		2025-11-24 13:50:21.166791+00	2025-11-24 15:39:53.494093+00
32f8e0e9-c79b-4cf6-a767-c9e9fc7581ab	2b12e74b-d757-40ea-ab66-1151d1635600	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from ماري جرجس جودة	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-25 19:24:50.313585+00		2025-11-25 18:01:53.945287+00	2025-11-25 19:24:50.3115+00
7218f68b-f2c8-4cf3-b890-37b0756acdb1	f23021af-2b94-4e77-b17e-6b34586a8776	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Mariam Maurice	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-26 15:57:35.503856+00		2025-11-26 15:29:15.761137+00	2025-11-26 15:57:35.501674+00
ea69daca-1d01-4004-9caa-c025cf8488b1	f25820a2-6501-4d29-a4f8-98f900eacdf2	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Abanob Badee	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-26 19:03:41.21743+00		2025-11-26 19:03:05.277523+00	2025-11-26 19:03:41.214289+00
aa3d75d6-eb28-44dc-95f4-7bbc4daa9921	ba3772f8-0764-4336-b89f-f5a2d7d7ad12	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Osama Tharwat	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-27 08:13:44.865187+00		2025-11-27 07:48:06.68992+00	2025-11-27 08:13:44.862162+00
5d688ff2-0aec-4e98-883d-b32eb2ae8feb	c8077b5c-555a-4e25-a018-85a708635c68	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Engy Thabet	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-29 18:22:01.823161+00		2025-11-28 18:11:46.318334+00	2025-11-29 18:22:01.820209+00
7dde832e-a124-403e-985e-686bdd9d57ec	e419d08a-a0ca-4f5b-93ac-a9cd8dd2f7bd	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Fady Rafaat	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-29 18:22:02.885334+00		2025-11-28 13:27:55.756504+00	2025-11-29 18:22:02.883219+00
83741e2f-4c5a-4960-bb39-a9776582a25f	f8f486d1-b24d-4e79-abbe-0d8fe113ce03	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	Registration join request from Berbara  Romany 	APPROVED	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-29 18:30:01.958995+00		2025-11-29 18:23:11.353988+00	2025-11-29 18:30:01.956819+00
\.


--
-- Data for Name: organizations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.organizations (id, name, description, is_active, created_at, updated_at) FROM stdin;
2339e8c4-dbe5-4d60-9828-2e129374b15b	شباب ٢٠٢٦	اجتماع شباب رئيس الملائكة ميخائيل لشباب جامعة و خريجين 	t	2025-11-16 16:14:36.208415+00	2025-11-16 16:14:36.209862+00
9ecd28af-7d8b-493a-95a9-2f65d16dee45	test		f	2025-11-17 08:16:58.882988+00	2025-11-20 16:22:10.732236+00
\.


--
-- Data for Name: qr_scan_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.qr_scan_logs (id, scanned_user_id, scanner_user_id, organization_id, qr_token, scan_result, score_assigned, score_type, scan_ip, user_agent, scanned_at) FROM stdin;
\.


--
-- Data for Name: score_aggregates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.score_aggregates (id, user_id, group_id, category, total_score, score_count, average_score, organization_id, last_updated) FROM stdin;
0c80e911-8a53-4409-b68f-de9e4ad0fe67	2a2447ab-6653-483d-bec3-a973f33df80d	\N	القداس	150	2	75.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-18 00:52:23.652631+00
4eaf16e5-6b09-4007-b737-d639e6c80431	4543ec53-772f-48d5-a393-cce7732c5c6a	\N	general	40	1	40.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-18 00:57:31.378989+00
06c9f841-1ae0-4f42-967c-fe628674042a	fd0444af-6d38-469f-8355-cb87f441eafa	\N	القداس	50	1	50.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-18 01:46:43.680598+00
bb72c4f6-8767-4cf7-abc5-61d9573cc13a	\N	7d800f80-95f3-4398-8c4a-ec410f095447	general	50	1	50.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-20 16:23:58.497519+00
5bd92c93-1627-4c59-9059-8722573575eb	fd0444af-6d38-469f-8355-cb87f441eafa	\N	الاعتراف	200	2	100.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-21 15:03:49.415263+00
353c5c7c-5710-4cfe-8a46-f2863b02f92c	b0bfdd30-d4de-45fe-9003-f3a83c621c6d	\N	القداس	50	1	50.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-21 18:30:23.197853+00
932c35ce-cc6b-4bb0-b704-33bfd602b88e	b0bfdd30-d4de-45fe-9003-f3a83c621c6d	\N	الاعتراف	100	1	100.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-21 18:31:15.95732+00
5b9b655f-8f54-4691-8598-cd44b828a148	b0bfdd30-d4de-45fe-9003-f3a83c621c6d	\N	التناول	100	1	100.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-21 18:31:28.704014+00
929ad512-9659-43cf-b9ea-ab7b4b45261d	60674dc5-8ace-4706-9a0f-db1ce65b0864	\N	التناول	100	1	100.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-21 21:09:53.37024+00
07bf54d5-1e74-4315-aa1b-1d483f485104	60674dc5-8ace-4706-9a0f-db1ce65b0864	\N	الاعتراف	100	1	100.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-21 21:09:59.319816+00
5c472073-9622-4324-8412-1f34e9af27c2	60674dc5-8ace-4706-9a0f-db1ce65b0864	\N	القداس	50	1	50.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-21 21:10:02.31524+00
bf2e0520-4704-44dc-9e0e-fb6e3bbd7bc6	d1447871-4f85-423e-a9c4-6c6f1cf36955	\N	التناول	100	1	100.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-22 20:13:26.536675+00
aac7a45e-d200-4c04-93d8-9b115e85df7c	d1447871-4f85-423e-a9c4-6c6f1cf36955	\N	القداس	50	1	50.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-22 20:13:56.428396+00
bacd1da1-b3f0-45f9-a07b-24dc70c791c4	316b6878-d2c3-4f75-a013-89b958e4192f	\N	التناول	100	1	100.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-22 20:16:08.001468+00
9fde5355-f92f-4cae-b00a-795ff355ebcc	556d06bd-50ed-4570-bcc1-e77ccac2f384	\N	القداس	50	1	50.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-22 20:52:00.475009+00
2340bddd-e4a9-41b3-ad04-69cb8aa8a611	316b6878-d2c3-4f75-a013-89b958e4192f	\N	القداس	70	2	35.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-23 15:15:27.475037+00
04afd3cd-debc-4c49-90c3-5b6b1dc1d29c	cba93851-be6d-4af1-840b-5cafd00cc4e0	\N	التناول	20	1	20.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-24 13:52:48.806742+00
ecb5ce73-e933-406b-9677-d8204d9650af	cba93851-be6d-4af1-840b-5cafd00cc4e0	\N	القداس	20	1	20.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-24 13:53:01.723651+00
798dfe8c-7a2a-4725-8679-1a3ac303c91e	cba93851-be6d-4af1-840b-5cafd00cc4e0	\N	الاعتراف	50	1	50.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-24 13:54:45.988325+00
63cecf5e-1f88-4a64-b656-36a6034b2c19	7cc5d386-cc60-42c0-8db5-79ca9338d848	\N	التناول	120	2	60.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-29 09:23:25.664824+00
ade9b27d-3882-40c1-9f9b-f516b68fbb60	7cc5d386-cc60-42c0-8db5-79ca9338d848	\N	القداس	70	2	35.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-29 09:23:36.168789+00
e75f65ec-0648-4ef1-97cb-552698fc7029	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	\N	الاعتراف	50	1	50.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-30 17:45:53.375136+00
9555a148-35c5-4ba4-b44d-4e2b73ccc389	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	\N	التناول	40	2	20.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-30 17:46:49.734725+00
5ad0b41a-2476-4b41-8b12-37473cfdb160	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	\N	القداس	20	1	20.00	2339e8c4-dbe5-4d60-9828-2e129374b15b	2025-11-30 17:46:53.949977+00
\.


--
-- Data for Name: score_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.score_categories (id, name, description, max_score, organization_id, created_by, is_active, is_predefined, created_at, updated_at) FROM stdin;
7fb8a05a-8f43-4de3-ba26-e41390f632de	الخدمة	الخدمة الكنسية	100	2339e8c4-dbe5-4d60-9828-2e129374b15b	43c97fdd-043d-4025-aadc-ce78071a02fb	f	t	2025-11-16 18:37:12.462797+00	2025-11-18 00:50:43.567887+00
c5d6036f-f3e2-4bdd-9480-a46c6e374283	حفظ الكتاب	حفظ آيات من الكتاب المقدس	100	2339e8c4-dbe5-4d60-9828-2e129374b15b	43c97fdd-043d-4025-aadc-ce78071a02fb	f	f	2025-11-16 18:37:12.462797+00	2025-11-20 16:19:43.048918+00
3ff1b1c3-2096-45de-bbfc-fa41b795d9f1	مسابقات في البيت	التفاعل و الشاركة في المسابقات في البيت 	100	2339e8c4-dbe5-4d60-9828-2e129374b15b	fd0444af-6d38-469f-8355-cb87f441eafa	t	f	2025-11-21 14:59:22.918578+00	2025-11-21 14:59:22.91858+00
b4bb5617-7552-452c-9532-533e297789dc	مسابقات	التفاعل و المشاركة في المسابقات داخل الاجتماع 	50	2339e8c4-dbe5-4d60-9828-2e129374b15b	fd0444af-6d38-469f-8355-cb87f441eafa	t	f	2025-11-21 14:58:51.775243+00	2025-11-21 15:00:43.263+00
35d51ed0-55cb-4209-9ff6-fcb1732e11cd	حضور الاجتماع	حضور اجتماع الشباب 	100	2339e8c4-dbe5-4d60-9828-2e129374b15b	fd0444af-6d38-469f-8355-cb87f441eafa	t	f	2025-11-21 14:58:03.140411+00	2025-11-21 15:00:50.074494+00
cce2a119-2c8a-4288-a61a-137a6fa42bfb	التناول	تناول القربان المقدس	20	2339e8c4-dbe5-4d60-9828-2e129374b15b	43c97fdd-043d-4025-aadc-ce78071a02fb	t	t	2025-11-16 18:37:12.462797+00	2025-11-23 13:01:01.304135+00
db63ba99-e46b-482b-8686-25308fd6e4e0	الاعتراف	سر الاعتراف	50	2339e8c4-dbe5-4d60-9828-2e129374b15b	43c97fdd-043d-4025-aadc-ce78071a02fb	t	t	2025-11-16 18:37:12.462797+00	2025-11-23 13:01:19.296666+00
9300b853-35ca-4306-b011-e1baea0167af	القداس	حضور القداس الإلهي	20	2339e8c4-dbe5-4d60-9828-2e129374b15b	43c97fdd-043d-4025-aadc-ce78071a02fb	t	t	2025-11-16 18:37:12.462797+00	2025-11-23 13:01:38.591092+00
\.


--
-- Data for Name: scores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scores (id, user_id, group_id, score_value, category, description, organization_id, assigned_by, created_at, updated_at, category_id) FROM stdin;
f0aeaea0-f991-4217-b04d-ebef1b436d5d	2a2447ab-6653-483d-bec3-a973f33df80d	\N	100	القداس	Self-reported for 2025-11-18	2339e8c4-dbe5-4d60-9828-2e129374b15b	2a2447ab-6653-483d-bec3-a973f33df80d	2025-11-18 00:00:00+00	2025-11-18 00:03:15.820358+00	9300b853-35ca-4306-b011-e1baea0167af
2ef1241b-ff2f-4d88-9b4b-f8543abd5a18	2a2447ab-6653-483d-bec3-a973f33df80d	\N	50	القداس	Self-reported for 2025-11-10	2339e8c4-dbe5-4d60-9828-2e129374b15b	2a2447ab-6653-483d-bec3-a973f33df80d	2025-11-10 00:00:00+00	2025-11-18 00:52:23.656726+00	9300b853-35ca-4306-b011-e1baea0167af
e271a1d2-56f7-4e0d-a41f-a1841aa2727d	4543ec53-772f-48d5-a393-cce7732c5c6a	\N	40	general		2339e8c4-dbe5-4d60-9828-2e129374b15b	4543ec53-772f-48d5-a393-cce7732c5c6a	2025-11-18 00:57:31.38123+00	2025-11-18 00:57:31.381232+00	c5d6036f-f3e2-4bdd-9480-a46c6e374283
408603b9-ede3-4e3f-845c-ebbcd9d5051e	fd0444af-6d38-469f-8355-cb87f441eafa	\N	100	الاعتراف	Self-reported for 2025-11-18	2339e8c4-dbe5-4d60-9828-2e129374b15b	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-18 00:00:00+00	2025-11-18 01:46:22.693511+00	db63ba99-e46b-482b-8686-25308fd6e4e0
260bc3cf-71bd-4382-9156-940849e84f2d	fd0444af-6d38-469f-8355-cb87f441eafa	\N	50	القداس	Self-reported for 2025-11-18	2339e8c4-dbe5-4d60-9828-2e129374b15b	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-18 00:00:00+00	2025-11-18 01:46:43.683462+00	9300b853-35ca-4306-b011-e1baea0167af
123eb825-5d36-4809-9efb-36ac3b45e246	\N	7d800f80-95f3-4398-8c4a-ec410f095447	50	general		2339e8c4-dbe5-4d60-9828-2e129374b15b	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-20 16:23:58.500593+00	2025-11-20 16:23:58.500596+00	9300b853-35ca-4306-b011-e1baea0167af
8df6f681-2276-4e16-86fd-71666e16eea4	fd0444af-6d38-469f-8355-cb87f441eafa	\N	100	الاعتراف	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	fd0444af-6d38-469f-8355-cb87f441eafa	2025-11-21 00:00:00+00	2025-11-21 15:03:49.418662+00	db63ba99-e46b-482b-8686-25308fd6e4e0
0d848117-7ff0-42be-816e-b27cdb68b4d7	b0bfdd30-d4de-45fe-9003-f3a83c621c6d	\N	50	القداس	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	b0bfdd30-d4de-45fe-9003-f3a83c621c6d	2025-11-21 00:00:00+00	2025-11-21 18:30:23.200376+00	9300b853-35ca-4306-b011-e1baea0167af
95e6f1c6-c917-4712-b130-1c73dbfcef59	b0bfdd30-d4de-45fe-9003-f3a83c621c6d	\N	100	الاعتراف	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	b0bfdd30-d4de-45fe-9003-f3a83c621c6d	2025-11-21 00:00:00+00	2025-11-21 18:31:15.960203+00	db63ba99-e46b-482b-8686-25308fd6e4e0
bd204eac-062c-4341-8335-e1ad320ffd49	b0bfdd30-d4de-45fe-9003-f3a83c621c6d	\N	100	التناول	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	b0bfdd30-d4de-45fe-9003-f3a83c621c6d	2025-11-21 00:00:00+00	2025-11-21 18:31:28.706375+00	cce2a119-2c8a-4288-a61a-137a6fa42bfb
2bef92a3-740d-4f64-ad4e-23ff4d9d0702	60674dc5-8ace-4706-9a0f-db1ce65b0864	\N	100	التناول	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	60674dc5-8ace-4706-9a0f-db1ce65b0864	2025-11-21 00:00:00+00	2025-11-21 21:09:53.372698+00	cce2a119-2c8a-4288-a61a-137a6fa42bfb
bc2d402f-4575-4fc2-a505-7790dab09bf6	60674dc5-8ace-4706-9a0f-db1ce65b0864	\N	100	الاعتراف	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	60674dc5-8ace-4706-9a0f-db1ce65b0864	2025-11-21 00:00:00+00	2025-11-21 21:09:59.322447+00	db63ba99-e46b-482b-8686-25308fd6e4e0
778bfe8d-2df9-45c9-8097-f3f413a3c124	60674dc5-8ace-4706-9a0f-db1ce65b0864	\N	50	القداس	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	60674dc5-8ace-4706-9a0f-db1ce65b0864	2025-11-21 00:00:00+00	2025-11-21 21:10:02.317577+00	9300b853-35ca-4306-b011-e1baea0167af
b7589f9c-9674-4831-8b6e-ba89c321f6ae	d1447871-4f85-423e-a9c4-6c6f1cf36955	\N	100	التناول	Self-reported for 2025-11-22	2339e8c4-dbe5-4d60-9828-2e129374b15b	d1447871-4f85-423e-a9c4-6c6f1cf36955	2025-11-22 00:00:00+00	2025-11-22 20:13:26.540007+00	cce2a119-2c8a-4288-a61a-137a6fa42bfb
6999e4f0-e613-443e-bd11-d6403557835c	d1447871-4f85-423e-a9c4-6c6f1cf36955	\N	50	القداس	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	d1447871-4f85-423e-a9c4-6c6f1cf36955	2025-11-21 00:00:00+00	2025-11-22 20:13:56.432091+00	9300b853-35ca-4306-b011-e1baea0167af
046b78bb-290a-42bd-b7b2-b47a725e90b7	316b6878-d2c3-4f75-a013-89b958e4192f	\N	100	التناول	Self-reported for 2025-11-14	2339e8c4-dbe5-4d60-9828-2e129374b15b	316b6878-d2c3-4f75-a013-89b958e4192f	2025-11-14 00:00:00+00	2025-11-22 20:16:08.006168+00	cce2a119-2c8a-4288-a61a-137a6fa42bfb
a42694f8-0418-45fe-bc54-d470899eba93	316b6878-d2c3-4f75-a013-89b958e4192f	\N	50	القداس	Self-reported for 2025-11-14	2339e8c4-dbe5-4d60-9828-2e129374b15b	316b6878-d2c3-4f75-a013-89b958e4192f	2025-11-14 00:00:00+00	2025-11-22 20:16:33.117711+00	9300b853-35ca-4306-b011-e1baea0167af
e46be7c0-6541-4745-931a-45b95fb8ae44	7cc5d386-cc60-42c0-8db5-79ca9338d848	\N	100	التناول	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	7cc5d386-cc60-42c0-8db5-79ca9338d848	2025-11-21 00:00:00+00	2025-11-22 20:30:26.527128+00	cce2a119-2c8a-4288-a61a-137a6fa42bfb
51f19865-e7dd-4390-8a79-be04938662e0	7cc5d386-cc60-42c0-8db5-79ca9338d848	\N	50	القداس	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	7cc5d386-cc60-42c0-8db5-79ca9338d848	2025-11-21 00:00:00+00	2025-11-22 20:30:42.564134+00	9300b853-35ca-4306-b011-e1baea0167af
0427ef69-c215-40f1-b271-9028cd6152ce	556d06bd-50ed-4570-bcc1-e77ccac2f384	\N	50	القداس	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	556d06bd-50ed-4570-bcc1-e77ccac2f384	2025-11-21 00:00:00+00	2025-11-22 20:52:00.478594+00	9300b853-35ca-4306-b011-e1baea0167af
6c5a8118-1cd3-4598-b367-156db0fcf7d4	316b6878-d2c3-4f75-a013-89b958e4192f	\N	20	القداس	Self-reported for 2025-11-23	2339e8c4-dbe5-4d60-9828-2e129374b15b	316b6878-d2c3-4f75-a013-89b958e4192f	2025-11-23 00:00:00+00	2025-11-23 15:15:27.478361+00	9300b853-35ca-4306-b011-e1baea0167af
8a42131d-80a9-4cda-b947-f3b1fd90114f	cba93851-be6d-4af1-840b-5cafd00cc4e0	\N	20	التناول	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	cba93851-be6d-4af1-840b-5cafd00cc4e0	2025-11-21 00:00:00+00	2025-11-24 13:52:48.810799+00	cce2a119-2c8a-4288-a61a-137a6fa42bfb
b5c90751-f0d0-4618-9b5a-6557756e53d0	cba93851-be6d-4af1-840b-5cafd00cc4e0	\N	20	القداس	Self-reported for 2025-11-21	2339e8c4-dbe5-4d60-9828-2e129374b15b	cba93851-be6d-4af1-840b-5cafd00cc4e0	2025-11-21 00:00:00+00	2025-11-24 13:53:01.726356+00	9300b853-35ca-4306-b011-e1baea0167af
3165bc02-ec75-4c5e-a9bc-3cd3da8275be	cba93851-be6d-4af1-840b-5cafd00cc4e0	\N	50	الاعتراف	Self-reported for 2025-11-01	2339e8c4-dbe5-4d60-9828-2e129374b15b	cba93851-be6d-4af1-840b-5cafd00cc4e0	2025-11-01 00:00:00+00	2025-11-24 13:54:45.992994+00	db63ba99-e46b-482b-8686-25308fd6e4e0
7c2c5e99-0a89-492f-8a66-51e8c870c9ce	7cc5d386-cc60-42c0-8db5-79ca9338d848	\N	20	التناول	Self-reported for 2025-11-28	2339e8c4-dbe5-4d60-9828-2e129374b15b	7cc5d386-cc60-42c0-8db5-79ca9338d848	2025-11-28 00:00:00+00	2025-11-29 09:23:25.668101+00	cce2a119-2c8a-4288-a61a-137a6fa42bfb
2dbdadcf-2d80-42e4-a920-f3bad086b887	7cc5d386-cc60-42c0-8db5-79ca9338d848	\N	20	القداس	Self-reported for 2025-11-28	2339e8c4-dbe5-4d60-9828-2e129374b15b	7cc5d386-cc60-42c0-8db5-79ca9338d848	2025-11-28 00:00:00+00	2025-11-29 09:23:36.172267+00	9300b853-35ca-4306-b011-e1baea0167af
6209bfdf-3bc7-4bb6-9bfb-b44f9d29dfa0	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	\N	20	التناول	Self-reported for 2025-11-28	2339e8c4-dbe5-4d60-9828-2e129374b15b	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	2025-11-28 00:00:00+00	2025-11-30 17:45:46.825594+00	cce2a119-2c8a-4288-a61a-137a6fa42bfb
8d311ab4-00cc-4b4d-b0b9-2b664a12d9cd	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	\N	50	الاعتراف	Self-reported for 2025-11-30	2339e8c4-dbe5-4d60-9828-2e129374b15b	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	2025-11-30 00:00:00+00	2025-11-30 17:45:53.377311+00	db63ba99-e46b-482b-8686-25308fd6e4e0
987bb300-2f1f-44b8-8a7e-96775dfa0899	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	\N	20	التناول	Self-reported for 2025-11-30	2339e8c4-dbe5-4d60-9828-2e129374b15b	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	2025-11-30 00:00:00+00	2025-11-30 17:46:49.737101+00	cce2a119-2c8a-4288-a61a-137a6fa42bfb
b8f6bd22-3b56-4f1e-b0af-000bc8d596fa	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	\N	20	القداس	Self-reported for 2025-11-30	2339e8c4-dbe5-4d60-9828-2e129374b15b	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	2025-11-30 00:00:00+00	2025-11-30 17:46:53.952456+00	9300b853-35ca-4306-b011-e1baea0167af
\.


--
-- Data for Name: super_admin_config; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.super_admin_config (id, username, password_hash, is_active, created_at) FROM stdin;
88e2f059-c91a-4170-a2ab-85c9b69e65e2	superadmin	$2b$12$FFMU9YX5enOmZkrrz5vCJOcOklH/507LKgzfHTu4VNiMa7f4AQ6v6	t	2025-11-16 16:07:14.94154+00
\.


--
-- Data for Name: user_organizations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_organizations (id, user_id, organization_id, role, department, title, is_active, joined_at, updated_at, left_at) FROM stdin;
c739fef1-beb4-4051-837a-1031880a4f10	4543ec53-772f-48d5-a393-cce7732c5c6a	2339e8c4-dbe5-4d60-9828-2e129374b15b	ORG_ADMIN	\N	\N	t	2025-11-16 16:14:36.505545+00	2025-11-16 16:14:36.50673+00	\N
ffd8c904-a7ab-46e4-995a-c2bf2935de2b	8733c0a3-2252-47d9-8cbc-bb95195f0ee2	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	f	2025-11-16 17:19:44.185875+00	2025-11-16 18:25:12.792257+00	\N
ec3307b6-a05d-4542-b366-fb624bd88446	489eeb6d-b0c7-4f02-9983-bb65c05e7c80	9ecd28af-7d8b-493a-95a9-2f65d16dee45	ORG_ADMIN	\N	\N	t	2025-11-17 08:16:59.185187+00	2025-11-17 08:16:59.185868+00	\N
5a3ad4a1-c474-4f15-8db2-a507f0b1c47f	fd0444af-6d38-469f-8355-cb87f441eafa	2339e8c4-dbe5-4d60-9828-2e129374b15b	ORG_ADMIN	\N	\N	t	2025-11-18 01:37:44.506145+00	2025-11-18 01:37:56.039162+00	\N
518fdbea-cba8-4a07-b8f5-55ab47e23f4b	b0bfdd30-d4de-45fe-9003-f3a83c621c6d	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-21 18:25:34.133602+00	2025-11-21 18:25:34.133605+00	\N
756e7def-be8c-4bf8-b713-6ec71748e7a9	0d03aab8-e0a5-45c4-98ba-e98adbb997cd	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 18:02:52.866703+00	2025-11-22 18:02:52.866706+00	\N
859c5cbe-c3eb-4fef-95de-ccb55e98e6f7	d1447871-4f85-423e-a9c4-6c6f1cf36955	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 18:02:54.913341+00	2025-11-22 18:02:54.913343+00	\N
51f354ae-65a7-486f-8721-a2cdb75288b9	556d06bd-50ed-4570-bcc1-e77ccac2f384	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 18:02:56.994574+00	2025-11-22 18:02:56.994577+00	\N
44361cf1-7981-4424-a188-6b2211ea94fe	a4e51f81-0b83-41cd-9a19-dd35e7e4d11d	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 18:17:04.514681+00	2025-11-22 18:17:04.514683+00	\N
5a3aaed5-2002-4f5f-9baf-91c1f874c4a1	316b6878-d2c3-4f75-a013-89b958e4192f	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 18:28:35.397307+00	2025-11-22 18:28:35.397309+00	\N
d04ecf59-ef77-4bb3-8043-fc93d8c04fb5	7cc5d386-cc60-42c0-8db5-79ca9338d848	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 20:16:51.322194+00	2025-11-22 20:16:51.322197+00	\N
c49f099a-60e4-4f60-8bab-b5105c3be82e	df663559-0b78-43e3-b5fe-93bec5e831ef	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 20:26:09.99576+00	2025-11-22 20:26:09.995762+00	\N
165f31aa-e5ec-4832-8c82-ebbd46e9f23f	7ed13f74-8c28-4868-8fae-dedc6e667636	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 20:39:05.495964+00	2025-11-22 20:39:05.495966+00	\N
0f9c2496-6cad-472e-819e-6d833f3d3699	d08a65b6-f945-4cc4-88bc-4295271aa2ec	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 20:43:08.082176+00	2025-11-22 20:43:08.082178+00	\N
6b90d9eb-155e-48ae-9bf2-e3c8df9356a7	0402b7ad-6089-44e1-9b69-49e0bd102563	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 20:44:46.25749+00	2025-11-22 20:44:46.257492+00	\N
a6eb5a66-23f9-40d6-9343-0310bcd1a8b5	33cb94c2-6699-4922-aba3-f151ac2c40e7	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 20:55:26.223818+00	2025-11-22 20:55:26.22382+00	\N
58618036-6679-4981-be98-d19a43dc67c6	cba93851-be6d-4af1-840b-5cafd00cc4e0	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-22 21:05:39.606154+00	2025-11-22 21:05:39.606156+00	\N
1a57ca3b-6dde-49a9-a0db-b52e659b45c8	858c44e0-9944-4e4f-aef8-616d89912869	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-23 07:21:46.010246+00	2025-11-23 07:21:46.010249+00	\N
635d78cc-faf2-4f0b-be8e-0bfd67dde1bd	11a9ac9c-95d0-42bd-924d-dc7265f48715	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-23 08:30:51.138743+00	2025-11-23 08:30:51.138745+00	\N
2d9823ef-c0bf-44d3-94a8-1dcecd79bed8	96e31174-7f00-407e-ba79-823206dc9356	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-23 08:50:14.811687+00	2025-11-23 08:50:14.811689+00	\N
727ab4f3-81d5-4bf0-8abb-95c6ef16ca54	60674dc5-8ace-4706-9a0f-db1ce65b0864	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	f	2025-11-21 21:08:48.239416+00	2025-11-23 17:23:01.449476+00	\N
efbfbd2f-1f81-461a-8aa0-dfaf5d68c208	43ead350-6b4a-42a8-8fd8-57ae0c09cc38	2339e8c4-dbe5-4d60-9828-2e129374b15b	ORG_ADMIN	\N	\N	t	2025-11-18 16:22:52.607049+00	2025-11-23 17:26:29.917017+00	\N
f5f6d2bc-c92a-4b63-b64d-e5712a797697	fade3837-e9cb-4ac0-8a5f-3f2a6e17b1eb	2339e8c4-dbe5-4d60-9828-2e129374b15b	ORG_ADMIN	\N	\N	t	2025-11-21 12:06:06.097573+00	2025-11-23 17:26:45.914554+00	\N
82022e14-07b9-4e5d-8a8e-a1950a83439b	f7c627c5-72e8-4c8b-9b7d-cecfb975277d	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-24 10:00:59.19842+00	2025-11-24 10:00:59.198422+00	\N
69cd93cf-58d1-40bd-a029-2f06536eeac9	e35c2abd-e271-431a-a932-40ac3c101b09	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-24 15:39:53.500646+00	2025-11-24 15:39:53.500648+00	\N
1cea1ed7-6fc0-479d-ad91-e0120807c1b1	2b12e74b-d757-40ea-ab66-1151d1635600	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-25 19:24:50.315203+00	2025-11-25 19:24:50.315206+00	\N
f88c4bc8-a4d3-4c58-a548-227ae1bf3179	f23021af-2b94-4e77-b17e-6b34586a8776	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-26 15:57:35.50533+00	2025-11-26 15:57:35.505332+00	\N
f68a10df-cadb-474c-888f-61ca398941d1	46e1d3aa-b84e-4eed-ad97-52bc309bed46	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-26 18:50:15.211614+00	2025-11-26 18:50:15.21327+00	\N
437d0ee9-d881-40e0-8eae-9fa21ad37bb4	f25820a2-6501-4d29-a4f8-98f900eacdf2	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-26 19:03:41.221146+00	2025-11-26 19:03:41.221148+00	\N
d315522c-b481-44c9-a30f-293bd2b4f6b6	ba3772f8-0764-4336-b89f-f5a2d7d7ad12	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-27 08:13:44.86859+00	2025-11-27 08:13:44.868592+00	\N
00fbdfb1-c7df-4bdf-aa80-d720ec470b9c	c8077b5c-555a-4e25-a018-85a708635c68	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-29 18:22:01.826688+00	2025-11-29 18:22:01.826689+00	\N
a58c3e45-da6b-474e-8750-dc53e9c55650	e419d08a-a0ca-4f5b-93ac-a9cd8dd2f7bd	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-29 18:22:02.886834+00	2025-11-29 18:22:02.886837+00	\N
43a462a1-bc20-457a-822f-1672e715ee5d	f8f486d1-b24d-4e79-abbe-0d8fe113ce03	2339e8c4-dbe5-4d60-9828-2e129374b15b	USER	\N	\N	t	2025-11-29 18:30:01.960484+00	2025-11-29 18:30:01.960487+00	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, username, email, password_hash, first_name, last_name, profile_picture_url, is_active, created_at, updated_at, birthdate, phone_number, bio, gender, school_year, student_id, major, gpa, graduation_year, university_name, faculty_name, address_line1, address_line2, city, state, postal_code, country, emergency_contact_name, emergency_contact_phone, emergency_contact_relationship, linkedin_url, github_url, personal_website, timezone, language, notification_preferences, is_verified, email_verified_at, last_login_at, qr_code_token, qr_code_generated_at, qr_code_expires_at, is_super_admin) FROM stdin;
43ead350-6b4a-42a8-8fd8-57ae0c09cc38	Amirhesho	amirh.mj2014@gmail.com	$2b$12$wt2yE087aKaLdIU4l.FZQuRBOjChdvc48aGoZr5pnwt2O6z72nD0u	Amir	Heshmat 	\N	t	2025-11-18 16:19:30.521387+00	2025-11-18 16:19:30.521391+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
2a2447ab-6653-483d-bec3-a973f33df80d	Test3	test@test.com	$2b$12$duo0l642Jdi0.ichkmlRfeSLAcgT20KzH9BKjUEeHGdZeSdijD6r.	Test3	Test3	/uploads/profile_pictures/2a2447ab-6653-483d-bec3-a973f33df80d_3429872b7330430d9a73f58b91c41cfe.jpeg	t	2025-11-18 00:00:41.160079+00	2025-11-18 01:05:40.179582+00	1983-06-02	0554545484845	Vebsbsnsvsvs	Male	\N	\N	\N	\N	6373	Hshsh	Bsbsb	Hehshs	Hsbsbs	Hsbsb	Bsnsh	Bsbsh	Bsbsh	Hahsh	251815	Vebs	bsbsbsh	bsbsbsb	bsbsbsb	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
cba93851-be6d-4af1-840b-5cafd00cc4e0	Besho sobhy 	Beshoysobhy81@gmail.com	$2b$12$20kYPUhjoBiFnDo063HI8elrhpioP9Tv58udpY9DKt3JFW8nhqVgq	بيشوي 	صبحي 	\N	t	2025-11-22 20:57:46.538162+00	2025-11-22 20:57:46.538166+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
7cc5d386-cc60-42c0-8db5-79ca9338d848	Kerosvictor	kerosvictor53@gmail.com	$2b$12$SOXqRB5P8xp2g.J5Pv5oL.bWZ3KZIXUJXZA4TxzUp4k2Y1IKDbjDG	Keros	Victor	\N	t	2025-11-22 20:16:15.297023+00	2025-11-22 20:17:58.071933+00	2006-09-01	01224446192	\N	Male	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
fa73ef39-38af-4deb-8e25-7813382f0e6f	superadmin	admin@escore.al-hanna.com	scrypt:32768:8:1$tGwODYeVSes4WJyW$aaa08cc78707382d344365e4660c39d3cdc7651f61783fcd0f8a714651244ec202d66a36df8bcd95255c269e561b7b30279b03ce0ec1c27762f24e075510373d	Super	Admin	\N	t	2025-11-16 14:18:38.958733+00	2025-11-16 15:56:26.7259+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	t
8733c0a3-2252-47d9-8cbc-bb95195f0ee2	Bihanna	bisho_f@hotmail.com	$2b$12$o2DPPWcYzueKHT4Wr38.XeDXtbatN9fKWR/QFTpL906GdFmsOZEpm	Bishoy	Hanna	\N	t	2025-11-16 17:17:11.203466+00	2025-11-16 18:25:17.304902+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
43c97fdd-043d-4025-aadc-ce78071a02fb	test1	test1@hotmail.com	$2b$12$C..KLhaLgK5xlvyo5vN/WO9gQXNkWVWaUMwueJbM0EQUHCsfSknwO	test	user	\N	t	2025-11-16 18:28:01.575179+00	2025-11-16 18:28:01.575183+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
489eeb6d-b0c7-4f02-9983-bb65c05e7c80	testadmin	testadmin@hotmail.com	$2b$12$V5sjWmvr9cDh/V6tL38gzOFFwx.ePuyLo0o25KoFH10MsLvJG/DWa	testadmin	org	\N	t	2025-11-17 08:16:59.181882+00	2025-11-17 08:16:59.183783+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
6115f818-ef2c-49e7-8013-3109dbbc03a8	Test2	test2@hotmail.test	$2b$12$KQ/eFmOqbNRxJdI4iqd3OuWKHsR0bqgdxHYxArM82JbOEf5kysxqu	Test2	Test	\N	f	2025-11-17 05:14:55.171875+00	2025-11-17 10:59:26.612218+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
1fb88c38-2c9a-4fc2-bc32-68a272d2c60f	testuser123	testuser123@example.com	$2b$12$0XZSmvtivpLefkWRKj1bnO0X7q3pGFCyTRbqlr87Tw6nI0Iltpdum	Test	User	\N	t	2025-11-17 21:28:45.321533+00	2025-11-17 21:28:45.321537+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
d08a65b6-f945-4cc4-88bc-4295271aa2ec	Kerolos Romany	kerolosromanykrm@gmail.com	$2b$12$CX.noK6nVVThSu7ZV18oyO7KD51YeIr5dnl3GfXAgyrNN.GmweEoO	Kerolos	Romany	/uploads/profile_pictures/9a44d35997014641863915f3d1dc1169_19699b05-5aec-4136-b406-2646d895a746.jpeg	t	2025-11-22 20:42:56.224247+00	2025-11-22 20:53:07.213984+00	2003-02-02	01276133902	\N	Male	graduated	\N	\N	\N	2024	Cairo University 	Faculty of Commerce English Section 	١ حاره فهيم حبشي مصنع النسيج الشرابيه	\N	Cairo	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
9323eab0-992d-4aed-800b-c71183f0a74d	test22	test@test22.com	$2b$12$RGR7MQDVqjI65sbHxUbIquPhFXiUJJa7GR49B0/NQcrTIIl/HwCpC	Test22	22	/uploads/profile_pictures/9323eab0-992d-4aed-800b-c71183f0a74d_eccbd9a912fa48d588733886b9bfd684.jpeg	t	2025-11-18 01:06:07.238129+00	2025-11-18 01:35:46.941982+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
556d06bd-50ed-4570-bcc1-e77ccac2f384	Naiema 	dmyeannaiema@gmail.com	$2b$12$0egw2JDsD6Y6DOGZ9C4ugOjze4/iipB/jfkyj3nYuJXttPXnHBwc.	Naiema 	Dmyean 	/uploads/profile_pictures/98d7ade595534e9dbc64c5662b33bb6e_1000174040.jpg	t	2025-11-22 18:02:25.985997+00	2025-11-22 20:53:53.75339+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
d1447871-4f85-423e-a9c4-6c6f1cf36955	Mariam aboelwafa	mariamaboelwafa077@gmail.com	$2b$12$S/4M/UtEycID2shF5qmBLOsf3wkNEyZ8Iz05OUFua93k9Eub3VEoS	Mariam	Aboelwafa	\N	t	2025-11-22 18:02:02.007888+00	2025-11-22 20:18:42.702908+00	1999-12-12	01226593026	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
df663559-0b78-43e3-b5fe-93bec5e831ef	Yous	youstinayousre@icloud.com	$2b$12$5SFxKElNMSVVTv3jUm.UlOO19hejVQUVr8f2kMaU8EU/Rs7q1/uLC	Youstina	Yousre	\N	t	2025-11-22 20:25:59.897297+00	2025-11-22 20:25:59.897301+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
4543ec53-772f-48d5-a393-cce7732c5c6a	Bhanna	bishoy@al-hanna.com	$2b$12$6kmM7Bq.7Q4vz0yfTaahFus3zRrBACDLGL9ivgIdWq75nH/kQtOuy	Bishoy	Hanna	\N	t	2025-11-16 16:14:36.501172+00	2025-11-18 16:28:49.535244+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
fade3837-e9cb-4ac0-8a5f-3f2a6e17b1eb	smina	samar.sarwat@outlook.com	$2b$12$u8v8e./bD6.Vp.TBrtH1Ue4sUVBFrgMBm6NhyGpxjFABk09N9h9lG	Samar	Mina	\N	t	2025-11-20 15:57:12.704783+00	2025-11-20 15:57:12.704788+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
b0bfdd30-d4de-45fe-9003-f3a83c621c6d	zizo	andrewyoussef222@icloud.com	$2b$12$RbJHKsqtGIaCsUUqeHGX.upMln18QoMaIZj5bEQfgjiRemsBlXri.	andrew	youssef	\N	t	2025-11-21 18:24:50.985864+00	2025-11-21 18:24:50.985867+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
60674dc5-8ace-4706-9a0f-db1ce65b0864	Bfawzy	bisho_ff@hotmail.com	$2b$12$iJXiLF6Mv4BAmEAUrp.Q/eKgknbmXW/87wd9OAhpDvP5eM5KfbYb.	Bishoy	Fawzy	/uploads/profile_pictures/22cc64c96cef4b169599a8c1af4e9548_img_8294.jpeg	t	2025-11-21 21:07:45.893905+00	2025-11-21 21:11:55.636469+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
7ed13f74-8c28-4868-8fae-dedc6e667636	Verena eshak 	verenaeshak8@gmail.com	$2b$12$rtR5tEUnVrJQl.sI4YxnoeFnHigmyqCW5IQo8kCbukMWfNrYMUe.O	Verena 	Eshak	\N	t	2025-11-22 20:28:21.168816+00	2025-11-22 20:28:21.16882+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
a4e51f81-0b83-41cd-9a19-dd35e7e4d11d	Kerolos Aboelwafa	kerolosaboelwafa230@gmail.com	$2b$12$BaLBAe/KSbfWZALRwfVPKO/576uh/8MnfeEc7S.As4SJfmQEpSEsy	Kerolos	Aboelwafa	\N	t	2025-11-22 18:17:01.275219+00	2025-11-22 18:17:01.275221+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
316b6878-d2c3-4f75-a013-89b958e4192f	Mina	minaaramzy9@gmail.com	$2b$12$1iPjrH1J.bzEieguVA//r.Bs1fMriN1tQdzFpFoedfclxaJqucOxi	Mina	Rafat	\N	t	2025-11-22 18:27:16.60065+00	2025-11-22 18:27:16.600653+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
a212d929-8c24-4c66-b199-535160023bf7	بيشوي روماني 	bisho.romany16@gmail.com	$2b$12$OJ3xXCkPpAj5wgoxhXwvnOsTLNpzEHtFWTCKBlCcWJvaidqxBkKDK	بيشوي	روماني	\N	t	2025-11-22 19:50:54.568067+00	2025-11-22 19:50:54.568071+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
0402b7ad-6089-44e1-9b69-49e0bd102563	Maged samy	magedsamy060@gmail.com	$2b$12$OY8rfS8oLvq.Hh37wHftb.9epuLkAKr7GevfASwnfH15xa4Hqcoiy	Maged	Samy	/uploads/profile_pictures/cd79a0c666a140a2b1a2e8d84451b846_img-20250427-wa0039.jpg	t	2025-11-22 20:44:39.894558+00	2025-11-22 21:02:02.032404+00	1995-05-05	01287243232	\N	Male	graduated	\N	\N	\N	\N	جامعة حلوان	كلية تجارة	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
33cb94c2-6699-4922-aba3-f151ac2c40e7	BeRo	bero.badee@gmail.com	$2b$12$6LZUohYLbuGdNgFmcc6LnuzQ0pAnt4wrBnDfdhSZV9CPC3ZHVKvZa	Ebram	Badee	/uploads/profile_pictures/946f1f35b00540beb2234e023515a178_1000164424.jpg	t	2025-11-22 20:55:24.794194+00	2025-11-22 21:09:30.688228+00	2002-07-29	01211652865	\N	Male	graduated	\N	\N	\N	2024	Ain Shams university 	Faculty of commerce 	\N	\N	\N	\N	\N	\N	\N	\N	\N	https://www.linkedin.com/in/ebrambadee/	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
858c44e0-9944-4e4f-aef8-616d89912869	Mariam ezzat	maryamezzat406@gmail.com	$2b$12$NDyPuidr6T8qEEUyIwlGpO07o2R2bgTtsUt2PQrdBAVG1R4egN5Q6	Mariam 	Ezzat	\N	t	2025-11-23 06:13:47.531115+00	2025-11-23 06:13:47.53112+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
0d03aab8-e0a5-45c4-98ba-e98adbb997cd	Samy maher	sameokaa2@icloud.com	$2b$12$FSE9dDj7hWUja3Df6elpAOM5xS7EczcmTVbYo0wXdwXQ6ZygRlEY2	Samy	Maher	/uploads/profile_pictures/43591415bdfb4fbbbbef0f8524340e7e_img_0550.jpeg	t	2025-11-22 17:57:31.124223+00	2025-11-23 00:17:13.485039+00	2001-02-20	01205017533	\N	Male	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
96e31174-7f00-407e-ba79-823206dc9356	Rere	erinyshaker7@gmail.com	$2b$12$H0tfE2kirrNR7oFuyMPYRuN3p/Dp6V44FgRetU4wY28aZHwq6ugwu	Eriny 	Shaker	\N	t	2025-11-23 08:38:40.445227+00	2025-11-23 08:38:40.445232+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
11a9ac9c-95d0-42bd-924d-dc7265f48715	Abanob aiad	abanobaiad237@gmail.com	$2b$12$xSdPKj10RYavZwzne1DASu6lnjDpH8Rl1M3GxfLJmgJZH6HaAbkju	Abanoub	Aiad	\N	t	2025-11-23 08:19:11.510203+00	2025-11-27 09:48:58.459776+00	1998-07-23	01555923655	\N	Male	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
fd0444af-6d38-469f-8355-cb87f441eafa	bishoy@al-hanna.com	bishoy2@al-hanna.com	$2b$12$36VOcMcryD2651x8uFtOQ.IzacuMA4VDPut2rCjN7k90SK7Hh59ey	Bishoy	Hanna	/uploads/profile_pictures/9cd72b38ca9f4f759dfb67625f2dcdc8_image.jpg	t	2025-11-18 01:36:39.868661+00	2025-11-23 17:02:11.286282+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
f7c627c5-72e8-4c8b-9b7d-cecfb975277d	Marize Dmyan 	marizedmyan@gmail.com	$2b$12$RUt56YlzAfm.L9P9dIuEuemSjJSvaNsj2eSL4GMhGGEo0s7NV3wJq	Dmyan 	Marize	\N	t	2025-11-23 21:28:27.585024+00	2025-11-23 21:28:27.585028+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
e35c2abd-e271-431a-a932-40ac3c101b09	حنان 	Hananlabeb@com	$2b$12$GhiAiYbckEAQiLFmOEto5emooeInh0PAeyocqxE.A.fKf8td4tcgW	حنان 	لبيب 	\N	t	2025-11-24 13:50:21.155381+00	2025-11-24 13:50:21.155386+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
f23021af-2b94-4e77-b17e-6b34586a8776	 Mariam Maurice	mariammaurice000@gmail.com	$2b$12$DJuZW3F4BqHdJ1ZJ2SrIp.bnY0c6oE1xZq8./2AzXYMSmhCCP6pu.	Mariam	Maurice	\N	t	2025-11-26 15:29:15.753401+00	2025-11-26 15:29:15.753404+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
46e1d3aa-b84e-4eed-ad97-52bc309bed46	engythabet	thabetengy39@gmail.com	$2b$12$GYVA9q2.PVtgZkhrbZFWKuTJoBoEjuOeNOeZTubGsZc6vI9mNMVcC	انچي 	ثابت 	\N	t	2025-11-25 21:35:18.388625+00	2025-11-26 19:11:01.245239+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
f25820a2-6501-4d29-a4f8-98f900eacdf2	Bebo Badee	Abanobbadee17@gmail.com	$2b$12$W8W/sUv0sr4NE8yUwqaYYu432H07E3h77JUqlDG3fUFzClz6gxY0S	Abanob	Badee	/uploads/profile_pictures/03e76f7d32c7465f9bfe03f42484b5f2_1000517322.jpg	t	2025-11-26 19:03:05.265738+00	2025-11-26 19:13:38.882961+00	2000-03-17	01211733058	\N	Male	graduated	\N	\N	\N	2021	جامعه حلوان	كليه تجاره وادراه اعمال	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
ba3772f8-0764-4336-b89f-f5a2d7d7ad12	osama tharwat	osama.tharwat.habib@gmail.com	$2b$12$aERbTkK/UV/Coa/Pnt4DY.aQn9sveKja9zulRgy/w3RXjjexHhs8.	Osama	Tharwat	\N	t	2025-11-27 07:48:06.678123+00	2025-11-27 07:48:06.678127+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
2b12e74b-d757-40ea-ab66-1151d1635600	ماري جرجس جودة	mgergis142@gmail.com	$2b$12$VElKYuzNR8h.pe5PGPcaYuArysbFTnH4osP0a.6eMDybROJ31vxC2	ماري	جرجس جودة	\N	t	2025-11-25 18:01:53.936703+00	2025-11-27 08:06:59.244898+00	\N	\N	\N	Female	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
b3f0c47b-4fde-4843-bd8d-cdc31005936d	Remonda	remothabet80@gmail.com	$2b$12$Yf5MpIQKtZ/awSwdhgSiVOC7Prtd7DOqTwMrQjQOIMhWMrTbrLNy2	Remonda 	Thabet	\N	t	2025-11-27 12:20:09.461282+00	2025-11-27 12:20:09.461286+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
e419d08a-a0ca-4f5b-93ac-a9cd8dd2f7bd	Fady Rafaat 	fady37494@gmail.com	$2b$12$Xwnnxb4QAHbYReVa2P9Yf.8I4gUdbiv7Cq6xKv8XW7PXceSMX1I3K	Fady	Rafaat	\N	t	2025-11-28 13:27:55.717857+00	2025-11-28 13:27:55.717861+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
c8077b5c-555a-4e25-a018-85a708635c68	Engy thabet	thabetengy39@gnail.com	$2b$12$awvjF3NkUAC9rofxumRNEOa...IhxyqyMoNJZGMMgM8nNK07USsH6	Engy	Thabet	\N	t	2025-11-28 18:11:46.310417+00	2025-11-28 18:11:46.31042+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
f8f486d1-b24d-4e79-abbe-0d8fe113ce03	Brbora	bromany115@gmail.com	$2b$12$5G9Ob2SIATYXdayrgnkt4ehUriozuKpe.LaElVZd76BQqv.nkL1C2	Berbara 	Romany 	/uploads/profile_pictures/2feb86be606d44c287519cb23708b8de_img-20250929-wa0056.jpg	t	2025-11-29 18:23:11.344453+00	2025-11-29 18:37:32.218531+00	2008-01-29	01204925894	🤍💪تشدد وتشجع	Female	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	UTC	en	{"push": false, "email": true}	f	\N	\N	\N	\N	\N	f
\.


--
-- Name: group_members group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_pkey PRIMARY KEY (id);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: organization_invitations organization_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_pkey PRIMARY KEY (id);


--
-- Name: organization_invitations organization_invitations_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_token_key UNIQUE (token);


--
-- Name: organization_join_requests organization_join_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_join_requests
    ADD CONSTRAINT organization_join_requests_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_name_key UNIQUE (name);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: qr_scan_logs qr_scan_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qr_scan_logs
    ADD CONSTRAINT qr_scan_logs_pkey PRIMARY KEY (id);


--
-- Name: score_aggregates score_aggregates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_aggregates
    ADD CONSTRAINT score_aggregates_pkey PRIMARY KEY (id);


--
-- Name: score_categories score_categories_name_organization_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_categories
    ADD CONSTRAINT score_categories_name_organization_id_key UNIQUE (name, organization_id);


--
-- Name: score_categories score_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_categories
    ADD CONSTRAINT score_categories_pkey PRIMARY KEY (id);


--
-- Name: scores scores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scores
    ADD CONSTRAINT scores_pkey PRIMARY KEY (id);


--
-- Name: super_admin_config super_admin_config_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.super_admin_config
    ADD CONSTRAINT super_admin_config_pkey PRIMARY KEY (id);


--
-- Name: super_admin_config super_admin_config_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.super_admin_config
    ADD CONSTRAINT super_admin_config_username_key UNIQUE (username);


--
-- Name: score_aggregates unique_group_category_org; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_aggregates
    ADD CONSTRAINT unique_group_category_org UNIQUE (group_id, category, organization_id);


--
-- Name: groups unique_group_name_per_org; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT unique_group_name_per_org UNIQUE (name, organization_id);


--
-- Name: organization_join_requests unique_pending_request; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_join_requests
    ADD CONSTRAINT unique_pending_request UNIQUE (user_id, organization_id, status) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: score_aggregates unique_user_category_org; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_aggregates
    ADD CONSTRAINT unique_user_category_org UNIQUE (user_id, category, organization_id);


--
-- Name: user_organizations unique_user_organization; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_organizations
    ADD CONSTRAINT unique_user_organization UNIQUE (user_id, organization_id);


--
-- Name: group_members unique_user_per_group; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT unique_user_per_group UNIQUE (group_id, user_id);


--
-- Name: user_organizations user_organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_organizations
    ADD CONSTRAINT user_organizations_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_qr_code_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_qr_code_token_key UNIQUE (qr_code_token);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_category_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_category_name ON public.score_categories USING btree (name);


--
-- Name: idx_category_org; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_category_org ON public.score_categories USING btree (organization_id);


--
-- Name: idx_group_members_group_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_group_members_group_id ON public.group_members USING btree (group_id);


--
-- Name: idx_group_members_org_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_group_members_org_id ON public.group_members USING btree (organization_id);


--
-- Name: idx_group_members_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_group_members_user_id ON public.group_members USING btree (user_id);


--
-- Name: idx_groups_created_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_groups_created_by ON public.groups USING btree (created_by);


--
-- Name: idx_groups_name_org; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_groups_name_org ON public.groups USING btree (name, organization_id);


--
-- Name: idx_groups_organization_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_groups_organization_id ON public.groups USING btree (organization_id);


--
-- Name: idx_invitations_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invitations_email ON public.organization_invitations USING btree (email);


--
-- Name: idx_invitations_expires_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invitations_expires_at ON public.organization_invitations USING btree (expires_at);


--
-- Name: idx_invitations_org_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invitations_org_id ON public.organization_invitations USING btree (organization_id);


--
-- Name: idx_invitations_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invitations_status ON public.organization_invitations USING btree (status);


--
-- Name: idx_invitations_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invitations_token ON public.organization_invitations USING btree (token);


--
-- Name: idx_join_requests_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_join_requests_created_at ON public.organization_join_requests USING btree (created_at);


--
-- Name: idx_join_requests_org_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_join_requests_org_id ON public.organization_join_requests USING btree (organization_id);


--
-- Name: idx_join_requests_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_join_requests_status ON public.organization_join_requests USING btree (status);


--
-- Name: idx_join_requests_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_join_requests_user_id ON public.organization_join_requests USING btree (user_id);


--
-- Name: idx_org_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_org_active ON public.organizations USING btree (is_active);


--
-- Name: idx_org_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_org_name ON public.organizations USING btree (name);


--
-- Name: idx_qr_scan_logs_org_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_qr_scan_logs_org_id ON public.qr_scan_logs USING btree (organization_id);


--
-- Name: idx_qr_scan_logs_scan_result; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_qr_scan_logs_scan_result ON public.qr_scan_logs USING btree (scan_result);


--
-- Name: idx_qr_scan_logs_scanned_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_qr_scan_logs_scanned_at ON public.qr_scan_logs USING btree (scanned_at);


--
-- Name: idx_qr_scan_logs_scanned_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_qr_scan_logs_scanned_user ON public.qr_scan_logs USING btree (scanned_user_id);


--
-- Name: idx_qr_scan_logs_scanner_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_qr_scan_logs_scanner_user ON public.qr_scan_logs USING btree (scanner_user_id);


--
-- Name: idx_qr_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_qr_token ON public.users USING btree (qr_code_token);


--
-- Name: idx_score_aggregates_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_aggregates_category ON public.score_aggregates USING btree (category);


--
-- Name: idx_score_aggregates_group_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_aggregates_group_id ON public.score_aggregates USING btree (group_id);


--
-- Name: idx_score_aggregates_org_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_aggregates_org_id ON public.score_aggregates USING btree (organization_id);


--
-- Name: idx_score_aggregates_total_score; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_aggregates_total_score ON public.score_aggregates USING btree (total_score DESC);


--
-- Name: idx_score_aggregates_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_aggregates_user_id ON public.score_aggregates USING btree (user_id);


--
-- Name: idx_score_cat; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_cat ON public.scores USING btree (category_id);


--
-- Name: idx_score_cat_org; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_cat_org ON public.score_categories USING btree (organization_id);


--
-- Name: idx_score_cat_predefined; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_cat_predefined ON public.score_categories USING btree (is_predefined);


--
-- Name: idx_score_categories_predefined; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_categories_predefined ON public.score_categories USING btree (is_predefined);


--
-- Name: idx_score_category_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_category_id ON public.scores USING btree (category_id);


--
-- Name: idx_score_group; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_group ON public.scores USING btree (group_id);


--
-- Name: idx_score_org; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_org ON public.scores USING btree (organization_id);


--
-- Name: idx_score_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_user ON public.scores USING btree (user_id);


--
-- Name: idx_scores_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scores_category ON public.scores USING btree (category);


--
-- Name: idx_scores_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scores_created_at ON public.scores USING btree (created_at);


--
-- Name: idx_scores_group_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scores_group_id ON public.scores USING btree (group_id);


--
-- Name: idx_scores_organization_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scores_organization_id ON public.scores USING btree (organization_id);


--
-- Name: idx_scores_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scores_user_id ON public.scores USING btree (user_id);


--
-- Name: idx_super_admin_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_super_admin_active ON public.super_admin_config USING btree (is_active);


--
-- Name: idx_super_admin_username; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_super_admin_username ON public.super_admin_config USING btree (username);


--
-- Name: idx_user_graduation_year; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_graduation_year ON public.users USING btree (graduation_year);


--
-- Name: idx_user_org_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_org_active ON public.user_organizations USING btree (is_active);


--
-- Name: idx_user_org_org; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_org_org ON public.user_organizations USING btree (organization_id);


--
-- Name: idx_user_org_role; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_org_role ON public.user_organizations USING btree (role);


--
-- Name: idx_user_org_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_org_user ON public.user_organizations USING btree (user_id);


--
-- Name: idx_user_organizations_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_organizations_active ON public.user_organizations USING btree (is_active);


--
-- Name: idx_user_organizations_org_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_organizations_org_id ON public.user_organizations USING btree (organization_id);


--
-- Name: idx_user_organizations_role; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_organizations_role ON public.user_organizations USING btree (role);


--
-- Name: idx_user_organizations_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_organizations_user_id ON public.user_organizations USING btree (user_id);


--
-- Name: idx_user_school_year; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_school_year ON public.users USING btree (school_year);


--
-- Name: idx_user_student_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_student_id ON public.users USING btree (student_id);


--
-- Name: idx_users_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_active ON public.users USING btree (is_active);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: idx_users_is_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_is_active ON public.users USING btree (is_active);


--
-- Name: idx_users_is_super_admin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_is_super_admin ON public.users USING btree (is_super_admin);


--
-- Name: idx_users_qr_code_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_qr_code_token ON public.users USING btree (qr_code_token);


--
-- Name: idx_users_username; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_username ON public.users USING btree (username);


--
-- Name: organization_join_requests trigger_cleanup_duplicate_pending_requests; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_cleanup_duplicate_pending_requests AFTER INSERT ON public.organization_join_requests FOR EACH ROW EXECUTE FUNCTION public.cleanup_duplicate_pending_requests();


--
-- Name: scores trigger_update_score_aggregate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_score_aggregate AFTER INSERT OR UPDATE ON public.scores FOR EACH ROW EXECUTE FUNCTION public.update_score_aggregate();


--
-- Name: groups update_groups_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON public.groups FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: organization_invitations update_invitations_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_invitations_updated_at BEFORE UPDATE ON public.organization_invitations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: organization_join_requests update_join_requests_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_join_requests_updated_at BEFORE UPDATE ON public.organization_join_requests FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: organizations update_organizations_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: score_categories update_score_categories_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_score_categories_updated_at BEFORE UPDATE ON public.score_categories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: scores update_scores_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_scores_updated_at BEFORE UPDATE ON public.scores FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: user_organizations update_user_organizations_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_user_organizations_updated_at BEFORE UPDATE ON public.user_organizations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: group_members group_members_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: group_members group_members_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: group_members group_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: groups groups_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: groups groups_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: organization_invitations organization_invitations_accepted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_accepted_by_fkey FOREIGN KEY (accepted_by) REFERENCES public.users(id);


--
-- Name: organization_invitations organization_invitations_invited_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: organization_invitations organization_invitations_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: organization_join_requests organization_join_requests_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_join_requests
    ADD CONSTRAINT organization_join_requests_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: organization_join_requests organization_join_requests_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_join_requests
    ADD CONSTRAINT organization_join_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id);


--
-- Name: organization_join_requests organization_join_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_join_requests
    ADD CONSTRAINT organization_join_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: qr_scan_logs qr_scan_logs_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qr_scan_logs
    ADD CONSTRAINT qr_scan_logs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: qr_scan_logs qr_scan_logs_scanned_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qr_scan_logs
    ADD CONSTRAINT qr_scan_logs_scanned_user_id_fkey FOREIGN KEY (scanned_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: qr_scan_logs qr_scan_logs_scanner_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qr_scan_logs
    ADD CONSTRAINT qr_scan_logs_scanner_user_id_fkey FOREIGN KEY (scanner_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: score_aggregates score_aggregates_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_aggregates
    ADD CONSTRAINT score_aggregates_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: score_aggregates score_aggregates_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_aggregates
    ADD CONSTRAINT score_aggregates_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: score_aggregates score_aggregates_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_aggregates
    ADD CONSTRAINT score_aggregates_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: score_categories score_categories_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_categories
    ADD CONSTRAINT score_categories_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: score_categories score_categories_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_categories
    ADD CONSTRAINT score_categories_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: scores scores_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scores
    ADD CONSTRAINT scores_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id);


--
-- Name: scores scores_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scores
    ADD CONSTRAINT scores_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.score_categories(id) ON DELETE SET NULL;


--
-- Name: scores scores_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scores
    ADD CONSTRAINT scores_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: scores scores_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scores
    ADD CONSTRAINT scores_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: scores scores_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scores
    ADD CONSTRAINT scores_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_organizations user_organizations_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_organizations
    ADD CONSTRAINT user_organizations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: user_organizations user_organizations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_organizations
    ADD CONSTRAINT user_organizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict n6vbdaF77prBaqeTYqgZPj8CFBljrMV3WnN8OskLpaJ8DgXbyDVb37dN9H74eFI

