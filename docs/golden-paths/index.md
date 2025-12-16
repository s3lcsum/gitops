# Golden Paths

Golden paths are the recommended way to accomplish common tasks in this repository. They're opinionated guides that help you do things "the right way" — following established patterns and conventions.

Think of these as the "happy path" for getting work done. If you follow a golden path, your changes will be consistent with the rest of the codebase and easier for others (including future-you) to understand.

## Available Golden Paths

| Guide | When to Use |
|-------|-------------|
| [Add a Docker Stack](add-docker-stack.md) | Deploying a new service via Docker Compose |
| [Add a Terraform Module](add-terraform-module.md) | Managing new infrastructure with Terraform |
| [Add a Service Behind Traefik](add-service-behind-traefik.md) | Exposing a service through the reverse proxy |

## When to Deviate

Golden paths aren't rules — they're defaults. It's okay to deviate when:

- The service has unusual requirements that don't fit the pattern
- You're experimenting and will clean up later
- A better approach exists (in which case, update the golden path!)

If you find yourself deviating often, that's a signal the golden path might need updating. Consider writing an [ADR](../adr/index.md) if the deviation becomes the new standard.

