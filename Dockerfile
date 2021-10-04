ARG base_image_version=3.9.7-alpine3.14
FROM python:${base_image_version} as builder

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG PRE_COMMIT_VERSION=${PRE_COMMIT_VERSION:-latest}
ARG TERRAFORM_VERSION=${TERRAFORM_VERSION:-latest}
ARG CHECKOV_VERSION=${CHECKOV_VERSION:-false}
ARG TERRAFORM_DOCS_VERSION=${TERRAFORM_DOCS_VERSION:-false}
ARG TERRAGRUNT_VERSION=${TERRAGRUNT_VERSION:-false}
ARG TERRASCAN_VERSION=${TERRASCAN_VERSION:-false}
ARG TFLINT_VERSION=${TFLINT_VERSION:-false}
ARG TFSEC_VERSION=${TFSEC_VERSION:-false}
ARG INSTALL_ALL=${INSTALL_ALL:-false}

# hadolint ignore=DL3018
RUN apk add --no-cache jq curl unzip && rm -rf "/var/cache/apk/*"

# setup build venv
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv --system-site-packages $VIRTUAL_ENV
ENV OLD_PATH=$PATH
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# install build tools
# hadolint ignore=DL3013
RUN python3 -m pip install --no-cache-dir --upgrade pip

# Install pre-commit
# hadolint ignore=DL3013
RUN if [ "${PRE_COMMIT_VERSION}" = "latest" ]; then \
      pip3 install --no-cache-dir pre-commit \
    ; else \
      pip3 install --no-cache-dir pre-commit==${PRE_COMMIT_VERSION} \
    ; fi

WORKDIR $VIRTUAL_ENV/bin

RUN if [ "${TERRAFORM_VERSION}" = "latest" ]; then \
      TERRAFORM_VERSION=$(curl -sS https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r .name | sed -r 's/v([0-9]+\.[0-9]\.+[0-9]+)/\1/g') && \
      export TERRAFORM_VERSION \
    ; fi && \
    curl -sS -L "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" > terraform.zip && \
    unzip -q terraform.zip terraform && rm terraform.zip && chmod a+x terraform

# hadolint ignore=DL3013,SC1091
RUN if [ "${CHECKOV_VERSION}" != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then \
    ( \
      if [ ${CHECKOV_VERSION} = "latest" ] || [ "${INSTALL_ALL}" = "true" ]; then \
        pip3 install --no-cache-dir checkov \
      ; else \
        pip3 install --no-cache-dir checkov==${CHECKOV_VERSION} \
      ; fi \
    ) \
    ; fi

# Terraform docs
RUN if [ "$TERRAFORM_DOCS_VERSION" != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then \
    ( \
        TERRAFORM_DOCS_RELEASES="https://api.github.com/repos/terraform-docs/terraform-docs/releases" && \
        [ "$TERRAFORM_DOCS_VERSION" = "latest" ] || [ "${INSTALL_ALL}" = "true" ] && curl -sS -L "$(curl -sS ${TERRAFORM_DOCS_RELEASES}/latest | grep -o -E -m 1 "https://.+?-linux-amd64.tar.gz")" > terraform-docs.tgz \
        || curl -sS -L "$(curl -sS ${TERRAFORM_DOCS_RELEASES} | grep -o -E "https://.+?v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz")" > terraform-docs.tgz \
    ) && tar -xzf terraform-docs.tgz terraform-docs && rm terraform-docs.tgz && chmod a+x terraform-docs \
    ; fi

# hadolint ignore=SC1091
RUN if [ "${TERRAGRUNT_VERSION}" != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then \
    ( \
        TERRAGRUNT_RELEASES="https://api.github.com/repos/gruntwork-io/terragrunt/releases" && \
        [ "${TERRAGRUNT_VERSION}" = "latest" ] || [ "${INSTALL_ALL}" = "true" ] && curl -sS -L "$(curl -sS ${TERRAGRUNT_RELEASES}/latest | grep -o -E -m 1 "https://.+?/terragrunt_linux_amd64")" > terragrunt \
        || curl -sS -L "$(curl -sS ${TERRAGRUNT_RELEASES} | grep -o -E -m 1 "https://.+?v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64")" > terragrunt \
    ) && chmod a+x terragrunt \
    ; fi

# Terrascan
RUN if [ "$TERRASCAN_VERSION" != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then \
    ( \
        TERRASCAN_RELEASES="https://api.github.com/repos/accurics/terrascan/releases" && \
        [ "$TERRASCAN_VERSION" = "latest" ] || [ "${INSTALL_ALL}" = "true" ] && curl -sS -L "$(curl -sS ${TERRASCAN_RELEASES}/latest | grep -o -E -m 1 "https://.+?_Linux_x86_64.tar.gz")" > terrascan.tar.gz \
        || curl -sS -L "$(curl -sS ${TERRASCAN_RELEASES} | grep -o -E "https://.+?${TERRASCAN_VERSION}_Linux_x86_64.tar.gz")" > terrascan.tar.gz \
    ) && tar -xzf terrascan.tar.gz terrascan && rm terrascan.tar.gz && \
    ./terrascan init \
    ; fi

# TFLint
RUN if [ "$TFLINT_VERSION" != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then \
    ( \
        TFLINT_RELEASES="https://api.github.com/repos/terraform-linters/tflint/releases" && \
        [ "$TFLINT_VERSION" = "latest" ] || [ "${INSTALL_ALL}" = "true" ] && curl -sS -L "$(curl -sS ${TFLINT_RELEASES}/latest | grep -o -E -m 1 "https://.+?_linux_amd64.zip")" > tflint.zip \
        || curl -sS -L "$(curl -sS ${TFLINT_RELEASES} | grep -o -E "https://.+?/v${TFLINT_VERSION}/tflint_linux_amd64.zip")" > tflint.zip \
    ) && unzip -q tflint.zip tflint && rm tflint.zip && chmod a+x tflint \
    ; fi

# TFSec
RUN if [ "$TFSEC_VERSION" != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then \
    ( \
        TFSEC_RELEASES="https://api.github.com/repos/aquasecurity/tfsec/releases" && \
        [ "$TFSEC_VERSION" = "latest" ] || [ "${INSTALL_ALL}" = "true" ] && curl -sS -L "$(curl -sS ${TFSEC_RELEASES}/latest | grep -o -E -m 1 "https://.+?/tfsec-linux-amd64")" > tfsec \
        || curl -sS -L "$(curl -sS ${TFSEC_RELEASES} | grep -o -E -m 1 "https://.+?v${TFSEC_VERSION}/tfsec-linux-amd64")" > tfsec \
    ) && chmod a+x tfsec \
    ; fi

# In one environemt it gives me 255
#RUN F=tools_versions_info && \
#    pre-commit --version >> $F && \
#    terraform --version | head -n 1 >> $F && \
#    (if [ "$CHECKOV_VERSION"        != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then echo "checkov $(checkov --version)" >> $F;     else echo "checkov SKIPPED" >> $F       ; fi) && \
#    (if [ "$TERRAFORM_DOCS_VERSION" != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then ./terraform-docs --version >> $F;              else echo "terraform-docs SKIPPED" >> $F; fi) && \
#    (if [ "$TERRAGRUNT_VERSION"     != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then ./terragrunt --version >> $F;                  else echo "terragrunt SKIPPED" >> $F    ; fi) && \
#    (if [ "$TERRASCAN_VERSION"      != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then echo "terrascan $(./terrascan version)" >> $F; else echo "terrascan SKIPPED" >> $F     ; fi) && \
#    (if [ "$TFLINT_VERSION"         != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then ./tflint --version >> $F;                      else echo "tflint SKIPPED" >> $F        ; fi) && \
#    (if [ "$TFSEC_VERSION"          != "false" ] || [ "${INSTALL_ALL}" = "true" ]; then echo "tfsec $(./tfsec --version)" >> $F;       else echo "tfsec SKIPPED" >> $F         ; fi) && \
#    cat $F

RUN python3 -m pip uninstall -y setuptools wheel pip

# runtime image
FROM python:${base_image_version}

# hadolint ignore=DL3018
RUN apk add --no-cache git bash perl && rm -rf "/var/cache/apk/*"

# copy venv
ENV VIRTUAL_ENV=/opt/venv
COPY --from=builder /opt/venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

ENV PYTHONUNBUFFERED=1

ENV PRE_COMMIT_COLOR=${PRE_COMMIT_COLOR:-always}

ENTRYPOINT [ "pre-commit" ]
