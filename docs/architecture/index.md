# A001: Architecture

This section contains high-level system diagrams using [C4 model](https://c4model.com/) conventions. These diagrams help you understand how the pieces fit together before diving into the code.

## Contents

| Document | Description |
|----------|-------------|
| [C4 Container View](c4-container.md) | Shows the major "containers" (applications/services) and how they interact |
| [Coding Conventions](conventions.md) | Standards for Docker stacks and Terraform code |

## C4 Model Levels

The C4 model has four levels of abstraction:

1. **System Context** (Level 1): How the system fits into the world
2. **Container** (Level 2): The high-level technology choices and how containers communicate
3. **Component** (Level 3): Components within a container
4. **Code** (Level 4): Class/function level (usually too detailed for this repo)

For this home lab, we primarily use **Level 2 (Container)** diagrams — they provide enough detail to understand the architecture without getting lost in implementation details.

## How to Read These Diagrams

- **Boxes** = Applications, services, or data stores
- **Arrows** = Communication/data flow (labeled with protocol/purpose)
- **Groupings** = Logical boundaries (network segments, hosts, etc.)

## Keeping Diagrams Updated

When making significant architectural changes:

1. Update the relevant diagram
2. Write an [ADR](../adr/index.md) explaining the change
3. Update the [README](https://github.com/s3lcsum/gitops#readme) if the change affects the public overview

