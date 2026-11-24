# Terraform Workspaces -- Practical Notes

## 1. What is a Terraform workspace?

A Terraform workspace lets you use the same Terraform configuration with
multiple independent state instances.

For example, one project can have three workspaces:

-   `dev`
-   `staging`
-   `prod`

Each workspace has its own Terraform state. This lets Terraform track
the resources associated with each workspace separately.

**Important:** Workspaces separate state; they do not automatically
create environments or provide complete security isolation.

## 2. Why use workspaces?

Imagine the GreenDot project needs different EC2 instance sizes for
different environments:

  Workspace   EC2 instance type
  ----------- -------------------
  `dev`       `t3.micro`
  `staging`   `t3.small`
  `prod`      `t3.medium`

You can keep one shared Terraform configuration and select the workspace
to determine which configuration values Terraform uses.

When you run `terraform apply` in each workspace, Terraform manages
resources using that workspace's state.

Switching workspaces alone does **not** create or change infrastructure.
You must run `terraform plan` and `terraform apply`.

## 3. Example project structure

With the local backend, a project may look like this:

``` text
GreenDot/
├── main.tf
├── variables.tf
├── outputs.tf
├── provider.tf
└── terraform.tfstate.d/
    ├── dev/
    │   └── terraform.tfstate
    ├── staging/
    │   └── terraform.tfstate
    └── prod/
        └── terraform.tfstate
```

The `default` workspace uses the root `terraform.tfstate` file.
Non-default local workspaces have state files under
`terraform.tfstate.d`.

Do not commit state files to Git. They can contain sensitive
information.

## 4. Workspace commands

Run these commands from the directory containing your Terraform
configuration.

  -----------------------------------------------------------------------
  Command                             What it does
  ----------------------------------- -----------------------------------
  `terraform workspace list`          Lists available workspaces

  `terraform workspace show`          Shows the currently selected
                                      workspace

  `terraform workspace new dev`       Creates `dev` and selects it

  `terraform workspace select dev`    Switches to `dev`

  `terraform workspace delete dev`    Deletes an eligible non-current
                                      workspace
  -----------------------------------------------------------------------

Example workflow:

``` powershell
terraform init

terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

terraform workspace list
terraform workspace show

terraform workspace select dev
terraform workspace show
```

When you create a workspace with `terraform workspace new`, Terraform
automatically selects it.

You cannot delete the `default` workspace or the currently selected
workspace. Terraform also requires a workspace to have no managed
resources before it can be deleted.

## 5. Your Terraform configuration

Your starting configuration used variables for the AMI and instance
type:

``` hcl
provider "aws" {
  region = "ap-southeast-1"
}

variable "ami" {
  description = "The AMI to use for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "The type of instance to use"
  type        = string
}

resource "aws_instance" "example" {
  ami           = var.ami
  instance_type = var.instance_type
}
```

Because `ami` and `instance_type` have no default values, Terraform
needs values for them from a `.tfvars` file, command-line arguments,
environment variables, or interactive input.

For workspace-based instance sizing, you can select the instance type
using `terraform.workspace`.

### Option A: Conditional expression

``` hcl
resource "aws_instance" "example" {
  ami = var.ami

  instance_type = (
    terraform.workspace == "dev"     ? "t3.micro" :
    terraform.workspace == "staging" ? "t3.small" :
    terraform.workspace == "prod"    ? "t3.medium" :
    null
  )

  tags = {
    Name = "GreenDot-${terraform.workspace}"
  }
}
```

This illustrates the idea, but returning `null` for an unknown workspace
may cause a validation or planning problem because `instance_type` is
required. A map with a clear lookup is easier to maintain.

### Option B: Local map (recommended for this exercise)

Add a `locals` block:

``` hcl
locals {
  instance_types = {
    dev     = "t3.micro"
    staging = "t3.small"
    prod    = "t3.medium"
  }
}
```

Then use it in the resource:

``` hcl
resource "aws_instance" "example" {
  ami           = var.ami
  instance_type = lookup(local.instance_types, terraform.workspace, null)

  tags = {
    Name = "GreenDot-${terraform.workspace}"
  }
}
```

The `lookup` expression returns `null` for an unknown workspace. Since
an EC2 instance requires an instance type, use only the defined
workspace names, or add an explicit validation/precondition to reject
unsupported names.

## 6. How Terraform chooses the instance type

Terraform evaluates `terraform.workspace`, which returns the currently
selected workspace name.

  Selected workspace   `terraform.workspace`   Instance type
  -------------------- ----------------------- ---------------
  `dev`                `dev`                   `t3.micro`
  `staging`            `staging`               `t3.small`
  `prod`               `prod`                  `t3.medium`

Example:

``` powershell
terraform workspace select staging
terraform workspace show
terraform plan
```

The configuration selects `t3.small` because `staging` is active.

## 7. Important: Workspaces and state

Each workspace has its own state. For example, if you apply the EC2
resource in `dev`, that resource is tracked in the `dev` state.

If you then switch to `staging`, Terraform reads the `staging` state
instead. It does not automatically manage the `dev` resource through the
`staging` state.

If you apply in all three workspaces, Terraform can create three
separately managed EC2 instances, assuming the configuration and AWS
permissions allow it.

## 8. Workspaces are not the same as separate projects

Workspaces are useful when environments can share the same general
configuration and differ mainly in values.

For strongly isolated production environments, separate configurations
and/or separate backends and AWS accounts may be more appropriate.
Workspaces alone do not provide access-control or security isolation.

## 9. Safe practice workflow

You can practise workspace commands without creating AWS resources:

``` powershell
terraform init
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
terraform workspace list
terraform workspace select dev
terraform workspace show
terraform plan
```

A plan may ask for the required `ami` variable if you have not supplied
it. You can provide a valid AMI ID for the configured AWS region through
a variable file or command-line input. AMI IDs are region-specific.

**Cost reminder:** `terraform plan` does not create EC2 instances.
`terraform apply` does. If you create practice resources, review the
destroy plan and clean them up when finished.

## 10. Quick recap

-   One Terraform configuration can be used by multiple workspaces.
-   Each workspace has its own state.
-   `terraform.workspace` returns the active workspace name.
-   Workspace selection does not create infrastructure;
    `terraform apply` does.
-   Workspaces are not a substitute for strong environment or account
    isolation.
-   Never commit Terraform state files or secrets to Git.
