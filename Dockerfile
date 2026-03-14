FROM --platform=${BUILDPLATFORM} nix-docker.registry.twcstorage.ru/ci/build/dotnet-build:9.0007 AS builder

ARG TARGETARCH
ARG GITHUB_USERNAME
# Path to main .csproj (always set by pipeline).
ARG CSPROJ_PATH

WORKDIR /src

ENV DOTNET_NOLOGO=true \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
    DOTNET_GENERATE_ASPNET_CERTIFICATE=false \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    GITHUB_USERNAME=${GITHUB_USERNAME}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --chown=1000:1000 . .

RUN --mount=type=secret,id=github_token,uid=1000,gid=1000 \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) && export GITHUB_TOKEN && \
    DOTNET_RID="linux-${TARGETARCH/amd64/x64}" && \
    dotnet restore "$CSPROJ_PATH" -r "$DOTNET_RID" -p:SelfContained=true

RUN DOTNET_RID="linux-${TARGETARCH/amd64/x64}" && \
    dotnet publish "$CSPROJ_PATH" \
        --no-restore \
        --configuration Release \
        -r "$DOTNET_RID" \
        -p:AssemblyName=app \
        -p:SelfContained=true \
        -p:UseAppHost=true \
        -p:PublishDir=/src/dist

FROM nix-docker.registry.twcstorage.ru/base/redhat/ubi10-minimal:10.1002-1766033715

RUN microdnf -y --refresh \
                --setopt=install_weak_deps=0 \
                --setopt=tsflags=nodocs install libicu \
    && microdnf clean all \
    && rm -rf /var/cache/dnf /var/cache/yum

WORKDIR /dist

COPY --from=builder --chmod=755 /src/dist/ .

ENTRYPOINT ["/dist/app"]
