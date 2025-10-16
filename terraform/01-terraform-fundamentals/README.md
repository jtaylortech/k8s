# Module 01: Terraform Fundamentals

**Duration**: ~3 hours
**Prerequisites**: Docker installed, basic command line knowledge
**Next Module**: [02-Provisioning Clusters](../02-provisioning-clusters/README.md)
**Cost**: $0 (uses local Docker)

## Learning Objectives

By the end of this module, you will:
- ✅ Understand Infrastructure as Code (IaC) concepts
- ✅ Write Terraform configurations in HCL
- ✅ Use Terraform CLI commands (init, plan, apply, destroy)
- ✅ Manage Terraform state
- ✅ Work with variables, outputs, and data sources
- ✅ Understand providers and resources
- ✅ Deploy infrastructure with Terraform

---

## Part 1: What is Infrastructure as Code?

### Traditional Infrastructure Management

```
Manual Process:
1. Log into cloud console
2. Click buttons to create resources
3. Document steps in wiki
4. Hope you remember for next time
5. Repeat for dev, staging, prod (inconsistencies!)
```

**Problems**:
- Not reproducible
- Error-prone
- No version control
- Hard to review changes
- Difficult to collaborate

### Infrastructure as Code (IaC)

```
IaC Process:
1. Write infrastructure as code
2. Version control (Git)
3. Review changes (PR/MR)
4. Apply automatically
5. Identical across environments
```

**Benefits**:
- ✅ Reproducible
- ✅ Version controlled
- ✅ Reviewable
- ✅ Automatable
- ✅ Self-documenting

### Why Terraform?

- **Multi-cloud**: AWS, GCP, Azure, and 1000+ providers
- **Declarative**: Describe desired state, Terraform figures out how
- **Large community**: Extensive modules and examples
- **State management**: Knows current vs desired state
- **Plan before apply**: Preview changes before making them

---

## Part 2: Terraform Basics

### HCL (HashiCorp Configuration Language)

Terraform uses HCL, a declarative language:

```hcl
# This is a comment

# Block type, label(s), and body
resource "docker_container" "nginx" {
  name  = "my-nginx"
  image = "nginx:latest"

  ports {
    internal = 80
    external = 8080
  }
}
```

### Core Concepts

**Providers**: Plugins that interact with APIs (AWS, Docker, Kubernetes)

**Resources**: Things you create (servers, containers, networks)

**Data Sources**: Read-only information from providers

**Variables**: Inputs to your configuration

**Outputs**: Values to display or pass to other systems

---

## Part 3: Your First Terraform Configuration

### Prerequisites

```bash
# Install Terraform
brew install terraform

# Verify Docker is running
docker ps

# Create working directory
mkdir ~/terraform-learn
cd ~/terraform-learn
```

### Example 1: Single Docker Container

**File**: `main.tf`
```hcl
# Configure the Docker provider
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  # Uses local Docker daemon
}

# Pull nginx image
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false  # Delete image on destroy
}

# Create nginx container
resource "docker_container" "nginx" {
  name  = "terraform-nginx"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8080
  }
}
```

### Terraform Workflow

```bash
# 1. Initialize (download providers)
terraform init

# 2. Preview changes
terraform plan

# 3. Apply changes
terraform apply

# 4. Verify
docker ps
curl http://localhost:8080

# 5. Destroy resources
terraform destroy
```

**What happened**:
1. `terraform init`: Downloaded Docker provider
2. `terraform plan`: Showed what would be created
3. `terraform apply`: Created image and container
4. `terraform destroy`: Cleaned up resources

---

## Part 4: Terraform State

After applying, Terraform creates a **state file** (`terraform.tfstate`).

### What is State?

State is Terraform's record of:
- What resources were created
- Their current attributes
- Metadata and dependencies

```bash
# View state
terraform show

# List resources in state
terraform state list

# Get specific resource
terraform state show docker_container.nginx
```

### State Best Practices

✅ **Do**:
- Use remote state in production (S3, GCS, Azure Blob)
- Enable state locking
- Never commit state files to Git
- Use `.gitignore` for `*.tfstate*`

❌ **Don't**:
- Edit state files manually
- Delete state files (you'll lose track of resources)
- Share state files (use remote backend)

---

## Part 5: Variables and Outputs

### Variables (Inputs)

**File**: `variables.tf`
```hcl
variable "container_name" {
  description = "Name of the Docker container"
  type        = string
  default     = "my-nginx"
}

variable "external_port" {
  description = "External port for nginx"
  type        = number
  default     = 8080
}

variable "nginx_version" {
  description = "Nginx Docker image version"
  type        = string
  default     = "latest"
}
```

**Updated** `main.tf`:
```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:${var.nginx_version}"
  keep_locally = false
}

resource "docker_container" "nginx" {
  name  = var.container_name
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.external_port
  }
}
```

### Using Variables

**Method 1**: Command line
```bash
terraform apply -var="container_name=web" -var="external_port=9090"
```

**Method 2**: Variable file
**File**: `terraform.tfvars`
```hcl
container_name = "production-web"
external_port  = 80
nginx_version  = "1.25"
```

```bash
terraform apply  # Automatically loads terraform.tfvars
```

**Method 3**: Environment variables
```bash
export TF_VAR_container_name="staging-web"
export TF_VAR_external_port=8080
terraform apply
```

### Outputs (Results)

**File**: `outputs.tf`
```hcl
output "container_id" {
  description = "ID of the Docker container"
  value       = docker_container.nginx.id
}

output "container_name" {
  description = "Name of the Docker container"
  value       = docker_container.nginx.name
}

output "image_id" {
  description = "ID of the Docker image"
  value       = docker_image.nginx.image_id
}

output "access_url" {
  description = "URL to access nginx"
  value       = "http://localhost:${var.external_port}"
}
```

```bash
terraform apply

# View outputs
terraform output

# Get specific output
terraform output access_url

# JSON format (for scripts)
terraform output -json
```

---

## Part 6: Multiple Resources

Let's deploy multiple containers:

**File**: `multi-container.tf`
```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Frontend (nginx)
resource "docker_image" "nginx" {
  name = "nginx:1.25"
}

resource "docker_container" "frontend" {
  name  = "frontend"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8080
  }
}

# Backend (simple API)
resource "docker_image" "api" {
  name = "hashicorp/http-echo"
}

resource "docker_container" "backend" {
  name  = "backend"
  image = docker_image.api.image_id

  command = ["-text=Hello from Backend!"]

  ports {
    internal = 5678
    external = 5678
  }
}

# Database (Redis)
resource "docker_image" "redis" {
  name = "redis:7-alpine"
}

resource "docker_container" "database" {
  name  = "database"
  image = docker_image.redis.image_id

  ports {
    internal = 6379
    external = 6379
  }
}
```

```bash
terraform init
terraform apply

# Verify all containers
docker ps

# Test frontend
curl http://localhost:8080

# Test backend
curl http://localhost:5678
```

---

## Part 7: Resource Dependencies

Terraform automatically figures out dependencies:

```hcl
resource "docker_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_container" "web" {
  name  = "web"
  image = docker_image.nginx.image_id  # Depends on image

  # ... other config
}
```

**Dependency graph**:
```
docker_image.nginx  →  docker_container.web
(created first)        (created after image)
```

### Explicit Dependencies

Sometimes you need to force order:

```hcl
resource "docker_container" "app" {
  name  = "app"
  image = "myapp:latest"

  # Wait for database to be ready
  depends_on = [docker_container.database]
}
```

---

## Part 8: Data Sources

Read existing resources:

```hcl
# Get Docker host information
data "docker_registry_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_image" "nginx" {
  name          = data.docker_registry_image.nginx.name
  pull_triggers = [data.docker_registry_image.nginx.sha256_digest]
}

output "nginx_digest" {
  value = data.docker_registry_image.nginx.sha256_digest
}
```

---

## Hands-On Exercises

### Exercise 1: Custom Configuration

Modify the nginx example to:
1. Use variable for nginx version
2. Add health check
3. Mount a custom HTML file
4. Output the container IP

**Solution template**:
```hcl
variable "html_content" {
  default = "<h1>Hello from Terraform!</h1>"
}

resource "local_file" "index" {
  filename = "${path.module}/index.html"
  content  = var.html_content
}

resource "docker_container" "nginx" {
  name  = "custom-nginx"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8080
  }

  volumes {
    host_path      = abspath(local_file.index.filename)
    container_path = "/usr/share/nginx/html/index.html"
  }

  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost"]
    interval = "30s"
    timeout  = "3s"
    retries  = 3
  }
}

output "container_ip" {
  value = docker_container.nginx.network_data[0].ip_address
}
```

### Exercise 2: Multi-Tier Application

Deploy a complete app stack:
- Frontend (nginx)
- Backend (API)
- Database (PostgreSQL)
- Configure environment variables
- Set up networking

### Exercise 3: State Management

1. Apply configuration
2. Make manual change with `docker stop`
3. Run `terraform plan` (drift detection)
4. Run `terraform apply` (reconcile)

---

## Validation Checklist

Before moving to the next module, ensure you can:

- [ ] Write basic Terraform configuration (HCL)
- [ ] Run terraform init, plan, apply, destroy
- [ ] Use variables and outputs
- [ ] Understand Terraform state
- [ ] Deploy multiple resources
- [ ] Read Terraform documentation
- [ ] Debug Terraform errors

**Self-test**:
```bash
# Can you do this without looking?
# 1. Create main.tf with nginx container on port 9090
# 2. Add variable for port number
# 3. Add output for access URL
# 4. Apply and verify
# 5. Destroy
```

---

## Common Issues

### Issue: Provider not found

**Error**: `Provider registry.terraform.io/hashicorp/docker not found`

**Solution**:
```bash
terraform init  # Run init first
```

### Issue: Port already in use

**Error**: `port is already allocated`

**Solution**:
```bash
# Check what's using the port
lsof -i :8080

# Use different port
terraform apply -var="external_port=9090"
```

### Issue: State locked

**Error**: `state file is locked`

**Solution**:
```bash
# If no other terraform is running
terraform force-unlock <LOCK_ID>
```

---

## Key Takeaways

1. **Infrastructure as Code** makes infrastructure reproducible
2. **Terraform** is declarative—describe what you want
3. **State** tracks what Terraform created
4. **Plan before apply** to preview changes
5. **Variables** make configurations reusable
6. **Outputs** expose important information
7. **Resources** depend on each other automatically

---

## Terraform CLI Reference

```bash
# Initialize
terraform init

# Validate syntax
terraform validate

# Format code
terraform fmt

# Plan changes
terraform plan
terraform plan -out=plan.tfplan

# Apply changes
terraform apply
terraform apply plan.tfplan
terraform apply -auto-approve  # Skip confirmation

# Destroy resources
terraform destroy
terraform destroy -target=docker_container.nginx

# State management
terraform state list
terraform state show <resource>
terraform state mv <old> <new>
terraform state rm <resource>

# Outputs
terraform output
terraform output -json

# Other
terraform version
terraform providers
terraform graph  # Dependency graph
```

---

## Additional Resources

- [Terraform Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
- [Terraform Language](https://www.terraform.io/language)
- [HCL Syntax](https://www.terraform.io/language/syntax)
- [Terraform Functions](https://www.terraform.io/language/functions)

---

## Next Steps

**Ready for the cloud?** → [Module 02: Provisioning Kubernetes Clusters](../02-provisioning-clusters/README.md)

**Want more practice?** Try these:
- Deploy a full LAMP stack with Docker
- Create a multi-environment setup (dev/prod)
- Build reusable modules

---

**Clean up**:
```bash
terraform destroy
rm -rf .terraform terraform.tfstate*
```
