# Adding build version information to downstream OpenShift binaries

## Background

Upstream bpfman-operator now embeds build-time version information
into all four binaries (bpfman-operator, bpfman-agent, metrics-proxy,
bpfman-crictl) via Go linker flags. The version package lives at:

    github.com/bpfman/bpfman-operator/internal/version

It exposes two variables set via `-X` ldflags:

    -X 'github.com/bpfman/bpfman-operator/internal/version.buildVersion=...'
    -X 'github.com/bpfman/bpfman-operator/internal/version.buildDate=...'

When neither is set the binary reports `(devel)` -- no crashes, no
placeholder noise, just an obvious signal that nobody injected version
metadata. The upstream Makefile (line 95-99) constructs these from
`git describe` and `date -u`.

## Current downstream state

The downstream OpenShift Containerfiles already declare and receive a
`BUILDVERSION` ARG sourced from `OPENSHIFT-VERSION` (currently
`BUILDVERSION=0.6.0`). This value is passed to the container build via
the Konflux pipeline's `build-args-file` parameter, but it is only
used in image labels -- the `go build` commands have no `-ldflags` at
all.

The Tekton pipeline also has the commit SHA available as
`$(tasks.clone-repository.results.commit)` and the commit timestamp as
`$(tasks.clone-repository.results.commit-timestamp)`, both of which
are already used in image labels (see `single-arch-build-pipeline.yaml`
lines 95-100).

## What needs to change

### 1. Add ldflags to go build commands in both Containerfiles

**Containerfile.bpfman-operator.openshift** (line 58):

Before:

```dockerfile
RUN CGO_ENABLED=1 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -tags strictfipsruntime -mod vendor -o bpfman-operator ./cmd/bpfman-operator/main.go
```

After:

```dockerfile
RUN CGO_ENABLED=1 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -tags strictfipsruntime -mod vendor \
    -ldflags "-X 'github.com/bpfman/bpfman-operator/internal/version.buildVersion=${BUILDVERSION}' -X 'github.com/bpfman/bpfman-operator/internal/version.buildDate=${BUILDDATE}'" \
    -o bpfman-operator ./cmd/bpfman-operator/main.go
```

**Containerfile.bpfman-agent.openshift** (lines 29-31):

Before:

```dockerfile
RUN CGO_ENABLED=1 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -tags strictfipsruntime -mod vendor -o bpfman-agent ./cmd/bpfman-agent/main.go
RUN CGO_ENABLED=1 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -tags strictfipsruntime -mod vendor -o metrics-proxy ./cmd/metrics-proxy/main.go
RUN CGO_ENABLED=1 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -tags strictfipsruntime -mod vendor -o bpfman-crictl ./cmd/bpfman-crictl/main.go
```

After:

```dockerfile
ARG BUILDDATE
RUN CGO_ENABLED=1 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -tags strictfipsruntime -mod vendor \
    -ldflags "-X 'github.com/bpfman/bpfman-operator/internal/version.buildVersion=${BUILDVERSION}' -X 'github.com/bpfman/bpfman-operator/internal/version.buildDate=${BUILDDATE}'" \
    -o bpfman-agent ./cmd/bpfman-agent/main.go
RUN CGO_ENABLED=1 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -tags strictfipsruntime -mod vendor \
    -ldflags "-X 'github.com/bpfman/bpfman-operator/internal/version.buildVersion=${BUILDVERSION}' -X 'github.com/bpfman/bpfman-operator/internal/version.buildDate=${BUILDDATE}'" \
    -o metrics-proxy ./cmd/metrics-proxy/main.go
RUN CGO_ENABLED=1 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -tags strictfipsruntime -mod vendor \
    -ldflags "-X 'github.com/bpfman/bpfman-operator/internal/version.buildVersion=${BUILDVERSION}' -X 'github.com/bpfman/bpfman-operator/internal/version.buildDate=${BUILDDATE}'" \
    -o bpfman-crictl ./cmd/bpfman-crictl/main.go
```

Both Containerfiles also need `ARG BUILDDATE` declared in the build
stage (alongside the existing `ARG BUILDVERSION`).

### 2. Pass commit timestamp as BUILDDATE via pipeline

The simplest approach: use the commit timestamp that Konflux already
extracts (`commit-timestamp`). Add `BUILDDATE` to `OPENSHIFT-VERSION`:

```
BUILDVERSION=0.6.0
BUILDDATE=
```

Then override it in each PipelineRun YAML via the `build-args`
parameter (which takes precedence over `build-args-file`). For example
in `bpfman-operator-ystream-push.yaml`:

```yaml
spec:
  params:
  - name: build-args
    value:
    - BUILDDATE=$(tasks.clone-repository.results.commit-timestamp)
```

Alternatively, if PipelineRun params cannot reference task results
directly (they run before tasks execute), construct the date inside the
Containerfile itself:

```dockerfile
RUN BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) && \
    CGO_ENABLED=1 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build ... \
    -ldflags "-X '...buildDate=${BUILD_DATE}'" ...
```

This gives you the image build time rather than the commit time, which
is still useful and requires no pipeline changes.

### 3. Optional: embed commit SHA as the version instead of BUILDVERSION

If you want the binaries to report the commit SHA rather than (or in
addition to) the version from `OPENSHIFT-VERSION`, you can pass it as
a build arg. The commit SHA is already available in the pipeline as
`$(tasks.clone-repository.results.commit)`. You would:

1. Add a `COMMIT_SHA` ARG to both Containerfiles
2. Pass it from the pipeline:
   ```yaml
   - name: build-args
     value:
     - COMMIT_SHA=$(tasks.clone-repository.results.commit)
   ```
3. Combine it in the ldflags:
   ```
   -X '...buildVersion=${BUILDVERSION}-${COMMIT_SHA}'
   ```

This gives you output like `0.6.0-abc1234def5678 2026-03-27T12:00:00Z go1.25.7 linux/amd64`.

## Summary of files to modify

| File | Change |
|------|--------|
| `Containerfile.bpfman-operator.openshift` | Add `ARG BUILDDATE`, add `-ldflags` to `go build` |
| `Containerfile.bpfman-agent.openshift` | Add `ARG BUILDDATE`, add `-ldflags` to all three `go build` commands |
| `OPENSHIFT-VERSION` | Add `BUILDDATE=` (if using pipeline override) |
| `.tekton/bpfman-operator-ystream-push.yaml` | Add `build-args` with BUILDDATE (if using pipeline override) |
| `.tekton/bpfman-operator-ystream-pull-request.yaml` | Same |
| `.tekton/bpfman-agent-ystream-push.yaml` | Same |
| `.tekton/bpfman-agent-ystream-pull-request.yaml` | Same |
| `.tekton/bpfman-operator-zstream-push.yaml` | Same |
| `.tekton/bpfman-operator-zstream-pull-request.yaml` | Same |
| `.tekton/bpfman-agent-zstream-push.yaml` | Same |
| `.tekton/bpfman-agent-zstream-pull-request.yaml` | Same |

## Minimum viable change

If you want to keep it as small as possible and avoid touching the
Tekton pipelines at all, just add the `-ldflags` with `BUILDVERSION`
(which is already wired) and compute the date inside the Containerfile
at build time:

```dockerfile
ARG BUILDVERSION
RUN BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) && \
    CGO_ENABLED=1 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -tags strictfipsruntime -mod vendor \
    -ldflags "-X 'github.com/bpfman/bpfman-operator/internal/version.buildVersion=${BUILDVERSION}' -X 'github.com/bpfman/bpfman-operator/internal/version.buildDate=${BUILD_DATE}'" \
    -o bpfman-operator ./cmd/bpfman-operator/main.go
```

This requires changes only to the two Containerfiles and gives you
version + build timestamp with zero pipeline modifications.
