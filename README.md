# GitHub Actions Self-Hosted Runner CI/CD

A practice project demonstrating a full CI/CD pipeline using GitHub Actions with an AWS EC2 self-hosted runner. Includes matrix builds, dependency caching, Docker image publishing to ECR, environment protection rules, and manual approval gates.

## Architecture

```
Push / PR
    │
    ▼
┌─────────────────────────────────────────────────┐
│                  CI Workflow                     │
│                                                  │
│  lint ──► test (Node 18 │ 20 │ 22) ──► build    │
│                  matrix                          │
└─────────────────────────────────────────────────┘
    │ merge to main
    ▼
┌─────────────────────────────────────────────────┐
│                  CD Workflow                     │
│                                                  │
│  ci-gate ──► deploy staging ──► [approval] ──► deploy production
└─────────────────────────────────────────────────┘
         ▲
         │  all jobs run on
    ┌────┴────┐
    │  EC2    │  self-hosted runner
    │ Runner  │  (Ubuntu, Docker, AWS CLI)
    └─────────┘
```

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── ci.yml               # lint → test matrix → build
│       ├── cd.yml               # staging deploy → approval → prod deploy
│       ├── reusable-build.yml   # shared build logic (called by cd.yml)
│       └── runner-health.yml    # hourly runner diagnostics
├── src/
│   ├── app.js                   # Express API
│   └── calculator.js            # business logic
├── tests/
│   ├── app.test.js              # API integration tests
│   └── calculator.test.js       # unit tests
├── scripts/
│   ├── setup-ec2-runner.sh      # installs + registers runner on EC2
│   ├── deploy.sh                # SSH deploy script (used by cd.yml)
│   └── build.js                 # writes dist/build-info.json
├── Dockerfile
└── package.json
```

## Workflows

### CI (`ci.yml`)
Triggered on every push and pull request.

| Job | What it does |
|-----|-------------|
| `lint` | ESLint on `src/` and `tests/` |
| `test` | Jest with coverage, runs on Node 18, 20, and 22 in parallel |
| `build` | Generates `dist/build-info.json`, builds Docker image |

Key features: `actions/cache` for npm, `actions/upload-artifact` for coverage and test results, `fail-fast: false` on the matrix.

### CD (`cd.yml`)
Triggered on merge to `main` or manually via `workflow_dispatch`.

| Job | What it does |
|-----|-------------|
| `ci-gate` | Calls the reusable build workflow as a quality gate |
| `deploy-staging` | Pushes Docker image to ECR, deploys to staging EC2, smoke tests |
| `deploy-production` | Promotes staging image, deploys to prod — **requires manual approval** |

### Runner Health (`runner-health.yml`)
Runs every hour via cron. Checks disk, memory, Docker, Node, and AWS CLI. Writes a summary to the GitHub Actions job summary page.

## Self-Hosted Runner Setup (EC2)

### Prerequisites
- EC2 instance running Ubuntu 22.04+
- Security group with **outbound HTTPS (443)** open
- IAM role attached with `AmazonEC2ContainerRegistryFullAccess` (for ECR pushes)

### Register the runner

1. Get a registration token from GitHub:
   ```
   Repo → Settings → Actions → Runners → New self-hosted runner
   ```

2. Copy the setup script to your EC2 instance:
   ```bash
   scp -i ~/your-key.pem scripts/setup-ec2-runner.sh ubuntu@<EC2-IP>:~/
   ```

3. SSH in and run it:
   ```bash
   ssh -i ~/your-key.pem ubuntu@<EC2-IP>

   chmod +x ~/setup-ec2-runner.sh
   ~/setup-ec2-runner.sh \
     --repo   https://github.com/YOUR_ORG/YOUR_REPO \
     --token  <TOKEN> \
     --name   ec2-runner-prod \
     --labels self-hosted,linux,x64,ec2
   ```

The script installs Docker, AWS CLI, downloads the runner binary, registers it with GitHub, and starts it as a systemd service.

### Manage the runner service

```bash
# Status
sudo systemctl status actions.runner.*.service

# Logs (live)
sudo journalctl -u actions.runner.*.service -f

# Restart
sudo systemctl restart actions.runner.*.service

# Remove runner
cd /opt/github-runner
sudo ./svc.sh stop && sudo ./svc.sh uninstall
./config.sh remove --token <REMOVE_TOKEN>
```

## Required Secrets and Variables

Configure these in **Settings → Secrets and variables → Actions**.

### Secrets

| Name | Description |
|------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key for ECR push |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `STAGING_DEPLOY_KEY` | SSH private key for staging EC2 |

### Variables (non-sensitive)

| Name | Example | Description |
|------|---------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region |
| `ECR_REPO_NAME` | `cicd-practice-app` | ECR repository name |
| `STAGING_HOST` | `1.2.3.4` | Staging EC2 public IP |
| `PROD_HOST` | `5.6.7.8` | Production EC2 public IP |

## Environment Protection Rules

The `production` environment requires a manual approval before deploy jobs run. Set this up at:
```
Settings → Environments → production → Required reviewers
```

Add yourself (or your team) as a required reviewer. The CD workflow will pause at `deploy-production` and send a notification to approve.

## Local Development

```bash
npm install
npm run lint      # ESLint
npm test          # Jest with coverage
npm run build     # writes dist/build-info.json
npm start         # starts Express on port 3000
```

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Lists available endpoints |
| `GET` | `/health` | Health check + version info |
| `POST` | `/calculate` | Runs a calculation |

**POST /calculate example:**
```bash
curl -X POST http://localhost:3000/calculate \
  -H "Content-Type: application/json" \
  -d '{"operation": "add", "a": 5, "b": 3}'
# {"result": 8}
```

Supported operations: `add`, `subtract`, `multiply`, `divide`.
