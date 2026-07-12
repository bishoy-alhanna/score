--
-- PostgreSQL database dump
--

\restrict qjQy9ZqAoT221terSgikfitZL3putdERE9CtxeOlxxI1kZ7hlIuYecQEdHYJVM6

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
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    filter_start_date date,
    filter_end_date date,
    filter_enabled boolean DEFAULT false
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

\unrestrict qjQy9ZqAoT221terSgikfitZL3putdERE9CtxeOlxxI1kZ7hlIuYecQEdHYJVM6

