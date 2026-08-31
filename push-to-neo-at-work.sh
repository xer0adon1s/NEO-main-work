#!/usr/bin/env bash
# Push entire NEO-main workspace to neo-at-work remote.
# Run from repo root on a machine with git + gh (or manual remote URL).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${REPO_ROOT}"

REMOTE_NAME="${NEO_AT_WORK_REMOTE:-neo-at-work}"
BRANCH="${NEO_AT_WORK_BRANCH:-main}"
CREATE_GH_REPO="${CREATE_GH_REPO:-1}"   # set 0 if remote already exists

echo "== NEO-at-work push script =="
echo "Root: ${REPO_ROOT}"

if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git not found in PATH" >&2
    exit 1
fi

# Init if needed
if [[ ! -d .git ]]; then
    echo "Initializing git repository..."
    git init -b "${BRANCH}"
fi

# Sensible gitignore if missing or incomplete
if [[ ! -f .gitignore ]]; then
    cat > .gitignore <<'EOF'
projects/
vpn/
wordlists/*.txt
results/
.env
.env.*
*.pem
*.key
vendor/
knowledge/vectors/*/vendor/
__pycache__/
*.pyc
.DS_Store
EOF
fi

# Stage everything (respects .gitignore)
git add -A
if git diff --cached --quiet; then
    echo "Nothing to commit (working tree clean after gitignore)."
else
    git commit -m "$(cat <<'EOF'
NEO-at-work snapshot: v0.5 reference + NEO 1.0 design workspace

Includes complete NEO-1.0-DESIGN (19 projects review_ready), prototype
neo-next, professional scope policy template, integration plan, and
AGENT-START-HERE roadmap for home-lab implementation.

Production v0.5 source unchanged; integration happens on separate branch.
EOF
)"
fi

# Remote setup
if ! git remote get-url "${REMOTE_NAME}" >/dev/null 2>&1; then
    if [[ "${CREATE_GH_REPO}" == "1" ]] && command -v gh >/dev/null 2>&1; then
        echo "Creating private GitHub repo neo-at-work via gh..."
        gh repo create neo-at-work --private --source=. --remote="${REMOTE_NAME}" --push
        echo "Done. Remote: $(git remote get-url ${REMOTE_NAME})"
        exit 0
    fi
    echo ""
    echo "No remote '${REMOTE_NAME}'. Add one, then re-run:"
    echo "  git remote add ${REMOTE_NAME} <your-repo-url>"
    echo "  git push -u ${REMOTE_NAME} ${BRANCH}"
    exit 1
fi

echo "Pushing to ${REMOTE_NAME}/${BRANCH}..."
git push -u "${REMOTE_NAME}" "${BRANCH}"
echo "Push complete."
