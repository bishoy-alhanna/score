# Multi-Tenant SaaS Scoring & Leaderboard Platform

A secure, scalable multi-tenant SaaS platform for organizations to manage users, groups, scoring systems, and leaderboards.

## Architecture Overview

- **Backend**: Microservices architecture with Flask
- **Frontend**: React applications (Admin & User dashboards)
- **Database**: PostgreSQL with Redis caching
- **Deployment**: Docker containers with Docker Compose

## Services

### Backend Services
- **auth-service**: Authentication, JWT tokens, password management
- **user-service**: User CRUD, role management, org-scoped operations
- **group-service**: Group management, membership, hierarchies
- **scoring-service**: Score assignment, updates, aggregation
- **leaderboard-service**: Real-time leaderboards, caching
- **organization-service**: Organization management, settings
- **api-gateway**: Request routing, authentication, rate limiting
- **config-server**: Centralized configuration management

### Frontend Applications
- **admin-dashboard**: Organization admin interface
- **user-dashboard**: End-user interface

## Multi-Tenancy

- Shared schema with tenant column (organization_id)
- Complete data isolation between organizations
- JWT-based authentication with org context
- Role-based access control (ORG_ADMIN, USER)

## Getting Started

1. Clone the repository
2. Run `docker-compose up` to start all services
3. Access admin dashboard at http://localhost:3000
4. Access user dashboard at http://localhost:3001

## Development

Each service can be developed and deployed independently. See individual service README files for specific setup instructions.

