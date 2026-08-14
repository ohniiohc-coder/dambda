# DAMBDA — ECS edition

This folder is the ECS-only deployment of DAMBDA. The backend runs on Amazon ECS Fargate; it does not create or deploy Amazon EKS resources.

## Repository and layout

- GitHub repository: `kcy9442/github-actions-test`
- `app/` — Flutter client
- `backend/` — Node.js API and Docker image
- `dambda/` — Terraform for AWS infrastructure
- `.github/workflows/` — CI/CD workflows

## Developer quick start

1. Configure AWS credentials for the target account.
2. Copy `dambda/terraform.tfvars.example` to `dambda/terraform.tfvars` and fill in environment-specific values. Never commit this file.
3. Run `terraform init` and `terraform validate` inside `dambda/`.
4. Run the backend locally with `npm ci` and the project-defined start command inside `backend/`.
5. Run the Flutter app with `flutter pub get` then `flutter run` inside `app/`.

## Deployment

- Backend push to `main` builds an image, pushes it to ECR, then updates the ECS service.
- Infrastructure changes are applied through the Terraform workflow after review.
- The ECS capacity and desired count are configured in Terraform; do not add EKS manifests to this edition.

## Safety

- Do not commit `*.tfvars`, Terraform state, `.terraform/`, `node_modules/`, or build artifacts.
- Check `git status` before committing because this project may contain in-progress application changes.
