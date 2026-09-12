# Local tooling image: Python-based validators that have no official Docker image.
#   skills-ref       reference validator for the Agent Skills spec
#                    https://github.com/agentskills/agentskills/tree/main/skills-ref
#   check-jsonschema validates action.yml against the GitHub Actions JSON schema
#                    https://github.com/python-jsonschema/check-jsonschema
FROM python:3.12-slim

ARG AGENTSKILLS_REF=69ef37e9424c0a7ea9dd2293b559e43ec8176379
ARG CHECK_JSONSCHEMA_VERSION=0.38.0

RUN apt-get update \
  && apt-get install -y --no-install-recommends git \
  && rm -rf /var/lib/apt/lists/* \
  && pip install --no-cache-dir \
       "git+https://github.com/agentskills/agentskills.git@${AGENTSKILLS_REF}#subdirectory=skills-ref" \
       "check-jsonschema==${CHECK_JSONSCHEMA_VERSION}"

WORKDIR /repo
