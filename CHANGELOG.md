# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2025-10-15

### Major Restructure
Complete repository overhaul with structured learning paths.

### Added
- **Beginner Track**: 5 complete modules with 14 hours of content
  - Module 01: Fundamentals (Pods, Deployments, ReplicaSets)
  - Module 02: Networking (Services, Ingress, DNS)
  - Module 03: Configuration (ConfigMaps, Secrets, Storage)
  - Module 04: Workload Management (HPA, Health Checks, Jobs)
  - Module 05: Production Basics (Helm, Monitoring, Security)

- **Expert Track**: 6 advanced modules outlined
  - Module 01: Advanced Networking (CNI, Service Mesh) - Complete
  - Modules 02-06: Security, Operators, Scheduling, Operations, Observability - Planned

- **Supporting Materials**:
  - kubectl command cheat sheet (100+ commands)
  - YAML syntax guide (all resource types)
  - Resource limits and QoS sizing guide
  - Comprehensive troubleshooting guide

- **Examples**:
  - Complete multi-tier application (frontend/backend/database)
  - Production-ready manifests with NetworkPolicies
  - 100+ working YAML examples across all modules

- **Documentation**:
  - PREREQUISITES.md with detailed setup instructions
  - Learning path recommendations
  - Certification mapping (CKA/CKAD/CKS)

### Changed
- Reorganized repository structure for progressive learning
- Updated README with clear navigation and learning tracks
- Moved original docs to archive/ directory

### Features
- Hands-on exercises with validation checklists
- Progressive complexity (beginner → expert)
- Production-focused examples
- Time estimates for each module
- Multiple learning path options

## [1.0.0] - 2025-10-15 (Pre-restructure)

### Initial Content
- Basic Kubernetes setup guide
- Ingress and troubleshooting documentation
- Single-file approach

---

Format based on [Keep a Changelog](https://keepachangelog.com/)
