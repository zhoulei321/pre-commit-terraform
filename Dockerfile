ARG base_image_version=3.9.9-alpine3.14
FROM python:${base_image_version} as builder

ARG PRE_COMMIT_VERSION=${PRE_COMMIT_VERSION:-latest}
ARG TERRAFORM_VERSION=${TERRAFORM_VERSION:-latest}
ARG CHECKOV_VERSION=${CHECKOV_VERSION:-false}
ARG INFRACOST_VERSION=${INFRACOST_VERSION:-false}
ARG TERRAFORM_DOCS_VERSION=${TERRAFORM_DOCS_VERSION:-false}
ARG TERRAGRUNT_VERSION=${TERRAGRUNT_VERSION:-false}
ARG TERRASCAN_VERSION=${TERRASCAN_VERSION:-false}
ARG TFLINT_VERSION=${TFLINT_VERSION:-false}
ARG TFSEC_VERSION=${TFSEC_VERSION:-false}
ARG INSTALL_ALL=${INSTALL_ALL:-false}

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN apk add --no-cache gcc libc-dev linux-headers git curl jq libffi-dev

# setup build venv
ENV VIRTUAL_ENV=/opt/build-venv
RUN python3 -m venv --system-site-packages $VIRTUAL_ENV
ENV OLD_PATH=$PATH
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# install build tools
RUN python3 -m pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir --upgrade setuptools wheel build

# build
COPY . /src/
WORKDIR /src
RUN python3 -m build --wheel
WORKDIR /

# setup runtime venv
ENV VIRTUAL_ENV=/opt/venv
ENV PATH=$OLD_PATH
RUN python3 -m venv --system-site-packages $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$OLD_PATH"

# install package
WORKDIR /src
RUN pip install --no-cache-dir --disable-pip-version-check --use-feature=in-tree-build ./dist/*.whl
WORKDIR /

RUN /src/docker-scripts/handle_architecture.sh

# pre-commit
RUN /src/docker-scripts/install_pre-commit.sh
RUN python3 -m pip install --no-cache-dir --upgrade pip

# Terraform
RUN /src/docker-scripts/install_terraform.sh

# Tricky thing to install all tools by set only one arg.
# In RUN command below used `. /.env` <- this is sourcing vars that
# specified in step below
RUN /src/docker-scripts/handle_install-all.sh

# Checkov
RUN /src/docker-scripts/install_checkov.sh
RUN python3 -m pip install --no-cache-dir --upgrade pip

# terraform-docs
RUN /src/docker-scripts/install_terraform-docs.sh

# remove build tools
RUN python3 -m pip uninstall -y setuptools wheel pip

# runtime image
FROM python:${base_image_version}

# copy venv
ENV VIRTUAL_ENV=/opt/venv
COPY --from=builder /opt/venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

ENV PYTHONUNBUFFERED=1

CMD ["block-pvc-scanner"]
