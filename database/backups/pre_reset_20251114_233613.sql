--
-- PostgreSQL database dump
--

\restrict dRbwxhmQSWgwVN2ErFm1rbhGv0fKYIV3KhQdW4NQ8cukgFfhFk0nwzL34FBMRJ9

-- Dumped from database version 15.14
-- Dumped by pg_dump version 15.14

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
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


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
-- Name: group_members; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.group_members (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    group_id uuid NOT NULL,
    user_id uuid NOT NULL,
    joined_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    is_active boolean DEFAULT true
);


ALTER TABLE public.group_members OWNER TO postgres;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.groups (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    organization_id uuid NOT NULL,
    created_by uuid,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.groups OWNER TO postgres;

--
-- Name: organization_invitations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization_invitations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    organization_id uuid NOT NULL,
    inviter_id uuid NOT NULL,
    email character varying(255) NOT NULL,
    role character varying(50) DEFAULT 'USER'::character varying NOT NULL,
    token character varying(255) NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying,
    accepted_by uuid,
    accepted_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.organization_invitations OWNER TO postgres;

--
-- Name: organization_join_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization_join_requests (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    requested_role character varying(50) DEFAULT 'USER'::character varying NOT NULL,
    message text,
    status character varying(20) DEFAULT 'PENDING'::character varying,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    review_message text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.organization_join_requests OWNER TO postgres;

--
-- Name: organizations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organizations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.organizations OWNER TO postgres;

--
-- Name: qr_scan_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.qr_scan_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    scanned_by uuid,
    scan_type character varying(50),
    success boolean DEFAULT true,
    error_message text,
    scanned_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.qr_scan_logs OWNER TO postgres;

--
-- Name: score_aggregates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.score_aggregates (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    group_id uuid,
    organization_id uuid NOT NULL,
    category character varying(255) DEFAULT 'general'::character varying,
    total_score integer DEFAULT 0,
    score_count integer DEFAULT 0,
    average_score numeric(10,2) DEFAULT 0.0,
    last_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT score_aggregates_check CHECK ((((user_id IS NOT NULL) AND (group_id IS NULL)) OR ((user_id IS NULL) AND (group_id IS NOT NULL))))
);


ALTER TABLE public.score_aggregates OWNER TO postgres;

--
-- Name: score_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.score_categories (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
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
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    group_id uuid,
    organization_id uuid NOT NULL,
    category_id uuid,
    category character varying(255) DEFAULT 'general'::character varying,
    score_value integer DEFAULT 0 NOT NULL,
    description text,
    assigned_by uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT scores_check CHECK ((((user_id IS NOT NULL) AND (group_id IS NULL)) OR ((user_id IS NULL) AND (group_id IS NOT NULL))))
);


ALTER TABLE public.scores OWNER TO postgres;

--
-- Name: super_admin_config; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.super_admin_config (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    is_super_admin boolean DEFAULT true,
    granted_by uuid,
    granted_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.super_admin_config OWNER TO postgres;

--
-- Name: user_organizations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_organizations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    role character varying(50) DEFAULT 'USER'::character varying NOT NULL,
    department character varying(100),
    title character varying(100),
    is_active boolean DEFAULT true,
    joined_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    left_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_organizations OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    first_name character varying(255),
    last_name character varying(255),
    profile_picture_url character varying(500),
    birthdate date,
    phone_number character varying(20),
    bio text,
    gender character varying(20),
    school_year character varying(50),
    student_id character varying(50),
    major character varying(100),
    gpa double precision,
    graduation_year integer,
    university_name character varying(255),
    faculty_name character varying(255),
    address_line1 character varying(255),
    address_line2 character varying(255),
    city character varying(100),
    state character varying(50),
    postal_code character varying(20),
    country character varying(100),
    emergency_contact_name character varying(255),
    emergency_contact_phone character varying(20),
    emergency_contact_relationship character varying(50),
    linkedin_url character varying(500),
    github_url character varying(500),
    personal_website character varying(500),
    timezone character varying(50) DEFAULT 'UTC'::character varying,
    language character varying(10) DEFAULT 'en'::character varying,
    notification_preferences json,
    is_active boolean DEFAULT true,
    is_verified boolean DEFAULT false,
    email_verified_at timestamp with time zone,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    qr_code_token character varying(255),
    qr_code_generated_at timestamp with time zone,
    qr_code_expires_at timestamp with time zone
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Data for Name: group_members; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.group_members (id, group_id, user_id, joined_at, is_active) FROM stdin;
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.groups (id, name, description, organization_id, created_by, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: organization_invitations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.organization_invitations (id, organization_id, inviter_id, email, role, token, status, accepted_by, accepted_at, expires_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: organization_join_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.organization_join_requests (id, user_id, organization_id, requested_role, message, status, reviewed_by, reviewed_at, review_message, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: organizations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.organizations (id, name, description, is_active, created_at, updated_at) FROM stdin;
11111111-1111-1111-1111-111111111111	Tech University	Technology and Engineering University	t	2025-11-14 21:33:57.465078+00	2025-11-14 21:33:57.465078+00
22222222-2222-2222-2222-222222222222	Business School	School of Business and Management	t	2025-11-14 21:33:57.465078+00	2025-11-14 21:33:57.465078+00
33333333-3333-3333-3333-333333333333	Arts Academy	Academy of Arts and Design	t	2025-11-14 21:33:57.465078+00	2025-11-14 21:33:57.465078+00
\.


--
-- Data for Name: qr_scan_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.qr_scan_logs (id, user_id, organization_id, scanned_by, scan_type, success, error_message, scanned_at) FROM stdin;
\.


--
-- Data for Name: score_aggregates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.score_aggregates (id, user_id, group_id, organization_id, category, total_score, score_count, average_score, last_updated) FROM stdin;
\.


--
-- Data for Name: score_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.score_categories (id, name, description, max_score, organization_id, created_by, is_active, is_predefined, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: scores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scores (id, user_id, group_id, organization_id, category_id, category, score_value, description, assigned_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: super_admin_config; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.super_admin_config (id, user_id, is_super_admin, granted_by, granted_at, created_at) FROM stdin;
\.


--
-- Data for Name: user_organizations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_organizations (id, user_id, organization_id, role, department, title, is_active, joined_at, left_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, username, email, password_hash, first_name, last_name, profile_picture_url, birthdate, phone_number, bio, gender, school_year, student_id, major, gpa, graduation_year, university_name, faculty_name, address_line1, address_line2, city, state, postal_code, country, emergency_contact_name, emergency_contact_phone, emergency_contact_relationship, linkedin_url, github_url, personal_website, timezone, language, notification_preferences, is_active, is_verified, email_verified_at, last_login_at, created_at, updated_at, qr_code_token, qr_code_generated_at, qr_code_expires_at) FROM stdin;
\.


--
-- Name: group_members group_members_group_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_group_id_user_id_key UNIQUE (group_id, user_id);


--
-- Name: group_members group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_pkey PRIMARY KEY (id);


--
-- Name: groups groups_name_organization_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_name_organization_id_key UNIQUE (name, organization_id);


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
-- Name: organization_join_requests organization_join_requests_user_id_organization_id_status_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_join_requests
    ADD CONSTRAINT organization_join_requests_user_id_organization_id_status_key UNIQUE (user_id, organization_id, status);


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
-- Name: score_aggregates score_aggregates_group_id_organization_id_category_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_aggregates
    ADD CONSTRAINT score_aggregates_group_id_organization_id_category_key UNIQUE (group_id, organization_id, category);


--
-- Name: score_aggregates score_aggregates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_aggregates
    ADD CONSTRAINT score_aggregates_pkey PRIMARY KEY (id);


--
-- Name: score_aggregates score_aggregates_user_id_organization_id_category_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.score_aggregates
    ADD CONSTRAINT score_aggregates_user_id_organization_id_category_key UNIQUE (user_id, organization_id, category);


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
-- Name: super_admin_config super_admin_config_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.super_admin_config
    ADD CONSTRAINT super_admin_config_user_id_key UNIQUE (user_id);


--
-- Name: user_organizations user_organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_organizations
    ADD CONSTRAINT user_organizations_pkey PRIMARY KEY (id);


--
-- Name: user_organizations user_organizations_user_id_organization_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_organizations
    ADD CONSTRAINT user_organizations_user_id_organization_id_key UNIQUE (user_id, organization_id);


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
-- Name: idx_aggregate_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aggregate_category ON public.score_aggregates USING btree (category);


--
-- Name: idx_aggregate_group; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aggregate_group ON public.score_aggregates USING btree (group_id);


--
-- Name: idx_aggregate_org; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aggregate_org ON public.score_aggregates USING btree (organization_id);


--
-- Name: idx_aggregate_points; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aggregate_points ON public.score_aggregates USING btree (total_score DESC);


--
-- Name: idx_aggregate_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aggregate_user ON public.score_aggregates USING btree (user_id);


--
-- Name: idx_category_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_category_name ON public.score_categories USING btree (name);


--
-- Name: idx_category_org; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_category_org ON public.score_categories USING btree (organization_id);


--
-- Name: idx_group_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_group_active ON public.groups USING btree (is_active);


--
-- Name: idx_group_member_group; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_group_member_group ON public.group_members USING btree (group_id);


--
-- Name: idx_group_member_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_group_member_user ON public.group_members USING btree (user_id);


--
-- Name: idx_group_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_group_name ON public.groups USING btree (name);


--
-- Name: idx_group_org; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_group_org ON public.groups USING btree (organization_id);


--
-- Name: idx_invitation_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invitation_email ON public.organization_invitations USING btree (email);


--
-- Name: idx_invitation_org; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invitation_org ON public.organization_invitations USING btree (organization_id);


--
-- Name: idx_invitation_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invitation_status ON public.organization_invitations USING btree (status);


--
-- Name: idx_invitation_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invitation_token ON public.organization_invitations USING btree (token);


--
-- Name: idx_join_req_org; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_join_req_org ON public.organization_join_requests USING btree (organization_id);


--
-- Name: idx_join_req_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_join_req_status ON public.organization_join_requests USING btree (status);


--
-- Name: idx_join_req_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_join_req_user ON public.organization_join_requests USING btree (user_id);


--
-- Name: idx_org_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_org_active ON public.organizations USING btree (is_active);


--
-- Name: idx_org_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_org_name ON public.organizations USING btree (name);


--
-- Name: idx_qr_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_qr_token ON public.users USING btree (qr_code_token);


--
-- Name: idx_scan_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scan_date ON public.qr_scan_logs USING btree (scanned_at);


--
-- Name: idx_scan_org; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scan_org ON public.qr_scan_logs USING btree (organization_id);


--
-- Name: idx_scan_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scan_user ON public.qr_scan_logs USING btree (user_id);


--
-- Name: idx_score_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_category ON public.scores USING btree (category_id);


--
-- Name: idx_score_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_date ON public.scores USING btree (created_at);


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
-- Name: idx_super_admin_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_super_admin_user ON public.super_admin_config USING btree (user_id);


--
-- Name: idx_user_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_active ON public.users USING btree (is_active);


--
-- Name: idx_user_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_email ON public.users USING btree (email);


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
-- Name: idx_user_school_year; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_school_year ON public.users USING btree (school_year);


--
-- Name: idx_user_student_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_student_id ON public.users USING btree (student_id);


--
-- Name: idx_user_username; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_username ON public.users USING btree (username);


--
-- Name: groups update_groups_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON public.groups FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


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
-- Name: organization_invitations organization_invitations_inviter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization_invitations
    ADD CONSTRAINT organization_invitations_inviter_id_fkey FOREIGN KEY (inviter_id) REFERENCES public.users(id) ON DELETE CASCADE;


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
-- Name: qr_scan_logs qr_scan_logs_scanned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qr_scan_logs
    ADD CONSTRAINT qr_scan_logs_scanned_by_fkey FOREIGN KEY (scanned_by) REFERENCES public.users(id);


--
-- Name: qr_scan_logs qr_scan_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qr_scan_logs
    ADD CONSTRAINT qr_scan_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


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
-- Name: super_admin_config super_admin_config_granted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.super_admin_config
    ADD CONSTRAINT super_admin_config_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES public.users(id);


--
-- Name: super_admin_config super_admin_config_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.super_admin_config
    ADD CONSTRAINT super_admin_config_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


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

\unrestrict dRbwxhmQSWgwVN2ErFm1rbhGv0fKYIV3KhQdW4NQ8cukgFfhFk0nwzL34FBMRJ9

