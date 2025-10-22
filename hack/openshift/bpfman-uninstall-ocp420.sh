#!/usr/bin/env bash
#
# bpfman-uninstall-ocp420.sh - Cleanup script for bpfman operator
#
# This script cleans up bpfman operator resources that may be left
# behind after uninstalling via the OpenShift console UI. This is
# needed for builds prior to PR #461 [1] which introduces a Config CRD
# with proper owner references for cascading deletion.
#
# The issue: The bpfman ConfigMap is the root of the resource tree. In
# normal development, deleting the ConfigMap triggers the operator's
# reconcile loop to clean up DaemonSets and other child resources.
# However, UI uninstall deletes the operator first, leaving resources
# with finalizers but no owner references orphaned in the cluster.
#
# Usage:
#   ./hack/openshift/bpfman-uninstall-ocp420.sh          # Clean operator resources, preserve CRDs
#   ./hack/openshift/bpfman-uninstall-ocp420.sh --purge  # Remove everything including CRDs
#
# [1] https://github.com/bpfman/bpfman-operator/pull/461

set -euo pipefail

: "${BPFMAN_NAMESPACE:=bpfman}"

command=""
purge_mode=false
cross_namespace=false

show_help() {
    echo "Usage: ${0##*/} list [--x-namespace]"
    echo "       ${0##*/} cleanup [--purge] [--x-namespace]"
    echo ""
    echo "Commands:"
    echo "  list            List bpfman resources (safe, read-only)"
    echo "  cleanup         Remove bpfman operator resources"
    echo ""
    echo "Modifiers:"
    echo "  --purge         Remove everything including CRDs and namespace"
    echo "  --x-namespace   Search/clean across ALL namespaces"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  ${0##*/} list                                 # List resources in bpfman namespace"
    echo "  ${0##*/} list --x-namespace                   # List resources across all namespaces"
    echo "  ${0##*/} cleanup                              # Clean bpfman namespace (preserves CRDs)"
    echo "  ${0##*/} cleanup --x-namespace                # Clean all namespaces (preserves CRDs)"
    echo "  ${0##*/} cleanup --purge                      # Remove everything including CRDs"
    echo "  ${0##*/} cleanup --purge --x-namespace        # Complete purge across all namespaces"
    echo ""
    echo "Standard cleanup mimics OpenShift UI uninstall behaviour:"
    echo "  - Removes operator resources from bpfman namespace only"
    echo "  - Removes finalizers to unblock deletion (additionally required for bpfman on OCP 4.20)"
    echo "  - Preserves CRDs and their associated RBAC resources"
    echo "  - Preserves the bpfman namespace"
    echo "  - Preserves catalog in openshift-marketplace (allows reinstall)"
    echo ""
    echo "With --x-namespace:"
    echo "  - Searches ALL namespaces for bpfman resources"
    echo "  - Removes catalog from openshift-marketplace"
    echo "  - Removes CSI drivers, services, and resources from openshift-operators"
    echo ""
    echo "With --purge:"
    echo "  - All bpfman custom resource instances (BpfApplications, etc.)"
    echo "  - All bpfman CRDs"
    echo "  - bpfman services, ServiceMonitors, and CSIDrivers"
    echo "  - The bpfman namespace itself"
    echo "  - Runs verification pass"
    echo ""
    echo "Combine flags for complete cleanup:"
    echo "  ${0##*/} cleanup --purge --x-namespace        # Remove everything across all namespaces"
}

if [[ $# -gt 0 && "$1" != "-"* ]]; then
    command="$1"
    shift
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --purge)
            purge_mode=true
            shift
            ;;
        --x-namespace)
            cross_namespace=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [[ -z "$command" ]]; then
    echo "Error: Please specify a command (list or cleanup)"
    echo ""
    show_help
    exit 1
fi

case "$command" in
    list)
    ;;
    cleanup|clean)
        command="cleanup"
        ;;
    help)
        show_help
        exit 0
        ;;
    *)
        echo "Error: Unknown command '$command'"
        echo "Valid commands: list, cleanup"
        echo ""
        show_help
        exit 1
        ;;
esac

if [[ "$purge_mode" == "true" && "$command" != "cleanup" ]]; then
    echo "Error: --purge can only be used with cleanup command"
    echo ""
    show_help
    exit 1
fi

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

resource_exists() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-}

    if [[ -n $namespace ]]; then
        kubectl get "$resource_type" "$resource_name" -n "$namespace" &>/dev/null
    else
        kubectl get "$resource_type" "$resource_name" &>/dev/null
    fi
}

remove_finalizers() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-}

    if [[ -n $namespace ]]; then
        if resource_exists "$resource_type" "$resource_name" "$namespace"; then
            log "Removing finalizers from $resource_type/$resource_name in namespace $namespace"
            kubectl patch "$resource_type" "$resource_name" -n "$namespace" \
                    --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
        fi
    else
        if resource_exists "$resource_type" "$resource_name"; then
            log "Removing finalizers from $resource_type/$resource_name (cluster-scoped)"
            kubectl patch "$resource_type" "$resource_name" \
                    --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
        fi
    fi
}

remove_all_finalizers() {
    local resource_type=$1
    local namespace=${2:-}

    local resources
    if [[ -n $namespace ]]; then
        resources=$(kubectl get "$resource_type" -n "$namespace" -o name 2>/dev/null || true)
    else
        resources=$(kubectl get "$resource_type" -o name 2>/dev/null || true)
    fi

    if [[ -n "$resources" ]]; then
        log "Removing finalizers from all $resource_type resources"
        while IFS= read -r resource; do
            if [[ -n $namespace ]]; then
                kubectl patch "$resource" -n "$namespace" --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
            else
                kubectl patch "$resource" --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
            fi
        done <<< "$resources"
    fi
}

delete_by_label() {
    local resource_type=$1
    local label=$2
    local namespace=${3:-}

    local count
    if [[ -n $namespace ]]; then
        count=$(kubectl get "$resource_type" -n "$namespace" -l "$label" --no-headers 2>/dev/null | wc -l || echo "0")
        if [[ $count -gt 0 ]]; then
            log "Deleting $count $resource_type resources with label $label in namespace $namespace"
            remove_all_finalizers "$resource_type" "$namespace"
            kubectl delete "$resource_type" -n "$namespace" -l "$label" --ignore-not-found=true --timeout=60s 2>/dev/null || true
        fi
    else
        count=$(kubectl get "$resource_type" -l "$label" --no-headers 2>/dev/null | wc -l || echo "0")
        if [[ $count -gt 0 ]]; then
            log "Deleting $count $resource_type resources with label $label"
            remove_all_finalizers "$resource_type"
            kubectl delete "$resource_type" -l "$label" --ignore-not-found=true --timeout=60s 2>/dev/null || true
        fi
    fi
}

for_each_label() {
    local func=$1
    local resource_type=$2
    local namespace=${3:-}

    local labels=(
        "app.kubernetes.io/name=bpfman"
        "app.kubernetes.io/part-of=bpfman"
        "app=bpfman"
    )

    for label in "${labels[@]}"; do
        "$func" "$resource_type" "$label" "$namespace"
    done
}

has_resources_with_labels() {
    local resource_type=$1
    local namespace=${2:-}

    local labels=(
        "app.kubernetes.io/name=bpfman"
        "app.kubernetes.io/part-of=bpfman"
        "app=bpfman"
    )

    for label in "${labels[@]}"; do
        local count
        if [[ -n $namespace ]]; then
            count=$(kubectl get "$resource_type" -n "$namespace" -l "$label" --no-headers 2>/dev/null | wc -l || echo "0")
        else
            count=$(kubectl get "$resource_type" -l "$label" --no-headers 2>/dev/null | wc -l || echo "0")
        fi
        if [[ $count -gt 0 ]]; then
            return 0  # true, resources exist
        fi
    done
    return 1  # false, no resources found
}

delete_resources_by_labels() {
    local resource_type=$1
    local namespace=${2:-}

    if has_resources_with_labels "$resource_type" "$namespace"; then
        log "  Deleting $resource_type resources..."
        for_each_label delete_by_label "$resource_type" "$namespace"
    fi
}

delete_resources_across_namespaces() {
    local resource_type=$1
    local resources
    local ns
    local name

    local labels=(
        "app.kubernetes.io/name=bpfman"
        "app.kubernetes.io/part-of=bpfman"
        "app=bpfman"
    )

    for label in "${labels[@]}"; do
        # Get all resources with this label across all namespaces
        resources=$(kubectl get "$resource_type" --all-namespaces -l "$label" -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

        if [[ -n "$resources" ]]; then
            while IFS= read -r resource; do
                if [[ -n "$resource" ]]; then
                    ns=$(echo "$resource" | cut -d'/' -f1)
                    name=$(echo "$resource" | cut -d'/' -f2)
                    log "    Deleting $resource_type $name from namespace $ns"
                    remove_finalizers "$resource_type" "$name" "$ns"
                    kubectl delete "$resource_type" "$name" -n "$ns" --ignore-not-found=true 2>/dev/null || true
                fi
            done <<< "$resources"
        fi
    done
}

get_namespaces_with_bpfman_resources() {
    local namespaces
    namespaces=$(kubectl get all --all-namespaces -o jsonpath='{range .items[?(@.metadata.name contains "bpfman")]}{.metadata.namespace}{"\n"}{end}' 2>/dev/null | sort -u || true)
    echo "$namespaces"
}

list_bpfman_resources() {
    log "=== Listing bpfman resources ==="

    if [[ "$cross_namespace" == "true" ]]; then
        log "Searching across ALL namespaces..."
    else
        log "Searching in namespace: $BPFMAN_NAMESPACE"
    fi
    echo ""

    local total=0

    # Resource types to check
    local resource_types=(
        "deployment"
        "daemonset"
        "service"
        "serviceaccount"
        "configmap"
        "secret"
        "role"
        "rolebinding"
        "servicemonitor"
    )

    local cluster_types=(
        "clusterrole"
        "clusterrolebinding"
        "crd"
        "csidrivers"
    )

    # Check namespaced resources
    for resource_type in "${resource_types[@]}"; do
        local count=0
        local resources

        if [[ "$cross_namespace" == "true" ]]; then
            resources=$(kubectl get "$resource_type" --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep bpfman || true)
        else
            resources=$(kubectl get "$resource_type" -n "$BPFMAN_NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep bpfman || true)
        fi

        if [[ -n "$resources" ]]; then
            count=$(echo "$resources" | wc -l)
            total=$((total + count))
            echo "$resource_type: $count"
            # shellcheck disable=SC2001
            echo "$resources" | sed 's/^/  /'
            echo ""
        fi
    done

    # Check cluster-scoped resources
    for resource_type in "${cluster_types[@]}"; do
        local count=0
        local resources
        resources=$(kubectl get "$resource_type" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep bpfman || true)

        if [[ -n "$resources" ]]; then
            count=$(echo "$resources" | wc -l)
            total=$((total + count))
            echo "$resource_type: $count"
            # shellcheck disable=SC2001
            echo "$resources" | sed 's/^/  /'
            echo ""
        fi
    done

    # Check CatalogSources in openshift-marketplace
    if [[ "$cross_namespace" == "true" ]]; then
        local catalogs
        local count
        catalogs=$(kubectl get catalogsource -n openshift-marketplace -o jsonpath='{range .items[*]}{"openshift-marketplace/"}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep bpfman || true)
        if [[ -n "$catalogs" ]]; then
            count=$(echo "$catalogs" | wc -l)
            total=$((total + count))
            echo "catalogsource: $count"
            # shellcheck disable=SC2001
            echo "$catalogs" | sed 's/^/  /'
            echo ""
        fi
    fi

    # Check namespaces
    local ns_count=0
    if kubectl get namespace "$BPFMAN_NAMESPACE" &>/dev/null; then
        ns_count=1
        total=$((total + 1))
        echo "namespace: $ns_count"
        echo "  $BPFMAN_NAMESPACE"
        echo ""
    fi

    log "Total bpfman resources found: $total"

    if [[ $total -eq 0 ]]; then
        log "No bpfman resources found - cluster appears clean"
    else
        echo ""
        log "To clean up these resources, run:"
        if [[ "$cross_namespace" == "true" ]]; then
            log "  ${0##*/} cleanup --x-namespace         # Remove operator resources"
            log "  ${0##*/} cleanup --purge --x-namespace # Remove everything including CRDs"
        else
            log "  ${0##*/} cleanup                      # Remove operator resources (bpfman namespace only)"
            log "  ${0##*/} cleanup --purge              # Remove everything including CRDs (bpfman namespace only)"
            log "  ${0##*/} cleanup --x-namespace        # Remove operator resources (all namespaces)"
            log "  ${0##*/} cleanup --purge --x-namespace # Remove everything including CRDs (all namespaces)"
        fi
    fi
}

if [[ "$command" == "list" ]]; then
    list_bpfman_resources
    exit 0
fi

if [[ "$purge_mode" == "true" ]]; then
    log "=== PURGE MODE: Removing ALL bpfman resources including CRDs ==="
else
    log "=== Standard cleanup: Removing operator resources, preserving CRDs ==="
fi

if [[ "$cross_namespace" == "true" ]]; then
    log "=== CROSS-NAMESPACE MODE: Searching across ALL namespaces ==="
    log "Primary namespace: $BPFMAN_NAMESPACE"
else
    log "Using namespace: $BPFMAN_NAMESPACE"
fi
echo ""

if [[ "$purge_mode" == "true" ]]; then
    log "Step 1: Deleting custom resource instances..."

    # Delete CRD instances across all namespaces
    for crd in bpfapplications.bpfman.io bpfapplicationstates.bpfman.io \
                                         clusterbpfapplications.bpfman.io clusterbpfapplicationstates.bpfman.io; do
        if kubectl get crd "$crd" &>/dev/null; then
            log "  Removing finalizers from $crd instances"
            remove_all_finalizers "$crd"
            log "  Deleting all $crd instances"
            kubectl delete "$crd" --all --all-namespaces --ignore-not-found=true --timeout=60s 2>/dev/null || true
        fi
    done
else
    log "Step 1: Skipping custom resource deletion (use --purge to remove)"
fi

log "Step 2: Removing finalizers from DaemonSets"
remove_finalizers "daemonset" "bpfman-daemon" "$BPFMAN_NAMESPACE"
remove_finalizers "daemonset" "bpfman-metrics-proxy" "$BPFMAN_NAMESPACE"

log "Step 3: Deleting DaemonSets"
kubectl delete daemonset bpfman-daemon bpfman-metrics-proxy -n "$BPFMAN_NAMESPACE" --ignore-not-found=true 2>/dev/null || true

log "Step 4: Waiting for pods to terminate (max 60s)"
kubectl wait --for=delete pods -l name=bpfman-daemon -n "$BPFMAN_NAMESPACE" --timeout=60s 2>/dev/null || true

log "Step 5: Deleting ServiceAccount"
kubectl delete serviceaccount bpfman-daemon -n "$BPFMAN_NAMESPACE" --ignore-not-found=true

log "Step 6: Deleting Roles and RoleBindings"
kubectl delete role bpfman-prometheus-k8s -n "$BPFMAN_NAMESPACE" --ignore-not-found=true
kubectl delete rolebinding bpfman-agent-rolebinding bpfman-prometheus-k8s -n "$BPFMAN_NAMESPACE" --ignore-not-found=true

log "Step 7: Deleting operator-specific ClusterRoles"
kubectl delete clusterrole \
        bpfman-agent-role \
        bpfman-bpfapplication-editor-role \
        bpfman-bpfapplication-viewer-role \
        bpfman-clusterbpfapplication-editor-role \
        bpfman-clusterbpfapplication-viewer-role \
        bpfman-metrics-reader \
        bpfman-user \
        --ignore-not-found=true

log "Step 8: Deleting ClusterRoleBindings"
kubectl delete clusterrolebinding \
        bpfman-agent-rolebinding \
        bpfman-auth-delegator \
        bpfman-privileged-scc \
        bpfman-prometheus-metrics-reader \
        --ignore-not-found=true

log "Step 9: Deleting OperatorGroup"
kubectl delete operatorgroup -n "$BPFMAN_NAMESPACE" --all --ignore-not-found=true

log "Step 10: Deleting ConfigMap"
remove_finalizers "configmap" "bpfman-config" "$BPFMAN_NAMESPACE"
kubectl delete configmap bpfman-config -n "$BPFMAN_NAMESPACE" --ignore-not-found=true

log "Step 11: Deleting OLM-generated resources"
kubectl delete clusterrole -l "olm.owner.namespace=$BPFMAN_NAMESPACE" --ignore-not-found=true

if [[ "$cross_namespace" == "true" ]]; then
    log "Step 12: Cleaning resources across ALL namespaces..."

    # Namespaced resources to clean across all namespaces
    namespaced_types=(
        "deployment"
        "daemonset"
        "service"
        "serviceaccount"
        "configmap"
        "secret"
        "role"
        "rolebinding"
        "servicemonitor"
    )

    for resource_type in "${namespaced_types[@]}"; do
        delete_resources_across_namespaces "$resource_type"
    done

    # Specifically clean up catalog resources in openshift-marketplace
    log "  Cleaning catalog resources from openshift-marketplace..."
    kubectl delete catalogsource -n openshift-marketplace -l "olm.catalogSource=bpfman-dev-catalog" --ignore-not-found=true 2>/dev/null || true
    kubectl get catalogsource -n openshift-marketplace -o name 2>/dev/null | grep bpfman | xargs -r kubectl delete -n openshift-marketplace --ignore-not-found=true 2>/dev/null || true
    kubectl get service -n openshift-marketplace -o name 2>/dev/null | grep bpfman | xargs -r kubectl delete -n openshift-marketplace --ignore-not-found=true 2>/dev/null || true
    kubectl get serviceaccount -n openshift-marketplace -o name 2>/dev/null | grep bpfman | xargs -r kubectl delete -n openshift-marketplace --ignore-not-found=true 2>/dev/null || true
else
    log "Step 12: Skipping cross-namespace cleanup (use --x-namespace to enable)"
fi

if [[ "$purge_mode" == "true" ]]; then
    log "Step 13: Deleting resources by bpfman labels in $BPFMAN_NAMESPACE..."

    # Namespaced resources
    namespaced_types=(
        "deployment"
        "daemonset"
        "service"
        "serviceaccount"
        "configmap"
        "secret"
        "role"
        "rolebinding"
        "servicemonitor"
    )

    # Cluster-scoped resources
    cluster_types=(
        "clusterrole"
        "clusterrolebinding"
    )

    # Delete namespaced resources
    for resource_type in "${namespaced_types[@]}"; do
        delete_resources_by_labels "$resource_type" "$BPFMAN_NAMESPACE"
    done

    # Delete cluster-scoped resources
    for resource_type in "${cluster_types[@]}"; do
        delete_resources_by_labels "$resource_type"
    done

    # CSIDriver - handle separately as it may not have labels
    log "  Checking for bpfman CSIDrivers..."
    csi_drivers=$(kubectl get csidrivers -o name 2>/dev/null | grep bpfman || true)
    if [[ -n "$csi_drivers" ]]; then
        log "  Removing finalizers from CSIDrivers..."
        echo "$csi_drivers" | while IFS= read -r driver; do
            kubectl patch "$driver" --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
        done
        log "  Deleting bpfman CSIDrivers..."
        echo "$csi_drivers" | xargs -r kubectl delete --ignore-not-found=true 2>/dev/null || true
    fi
else
    log "Step 13: Skipping label-based cleanup (use --purge to remove)"
fi

if [[ "$purge_mode" == "true" ]]; then
    log "Step 14: Deleting bpfman CRDs..."

    # First remove finalizers from CRDs
    for crd in bpfapplications.bpfman.io bpfapplicationstates.bpfman.io \
                                         clusterbpfapplications.bpfman.io clusterbpfapplicationstates.bpfman.io; do
        if kubectl get crd "$crd" &>/dev/null; then
            log "  Removing finalizers from CRD $crd"
            remove_finalizers "crd" "$crd"
        fi
    done

    # Delete CRDs
    kubectl delete crd \
            bpfapplications.bpfman.io \
            bpfapplicationstates.bpfman.io \
            clusterbpfapplications.bpfman.io \
            clusterbpfapplicationstates.bpfman.io \
            --ignore-not-found=true --timeout=60s 2>/dev/null || true

    # Delete CRD-related ClusterRoles
    log "  Deleting CRD-related ClusterRoles..."
    kubectl get clusterrole -o name 2>/dev/null | grep "bpfman.io.*-v1alpha1-" | xargs -r kubectl delete --ignore-not-found=true 2>/dev/null || true

    # Delete namespace
    log "Step 15: Deleting bpfman namespace..."
    if kubectl get namespace "$BPFMAN_NAMESPACE" &>/dev/null; then
        # First remove any remaining resources
        log "  Ensuring namespace is empty..."
        kubectl delete all --all -n "$BPFMAN_NAMESPACE" --ignore-not-found=true --timeout=30s 2>/dev/null || true

        # Remove finalizers from namespace if needed
        if kubectl get namespace "$BPFMAN_NAMESPACE" -o jsonpath='{.metadata.finalizers}' 2>/dev/null | grep -q .; then
            log "  Removing finalizers from namespace..."
            kubectl patch namespace "$BPFMAN_NAMESPACE" --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
        fi

        log "  Deleting namespace $BPFMAN_NAMESPACE..."
        kubectl delete namespace "$BPFMAN_NAMESPACE" --ignore-not-found=true --timeout=60s 2>/dev/null || true

        # Wait a moment for namespace to be deleted
        sleep 2
    fi

    # Verification pass
    log "Step 16: Running verification pass..."
    verification_issues=0

    # Check for remaining CRDs
    remaining_crds=$(kubectl get crd 2>/dev/null | grep bpfman || true)
    if [[ -n "$remaining_crds" ]]; then
        log "  WARNING: Found remaining bpfman CRDs:"
        echo "$remaining_crds" | while IFS= read -r line; do
            log "    $line"
        done
        ((verification_issues++))
    fi

    # Check for remaining ClusterRoles
    remaining_clusterroles=$(kubectl get clusterrole 2>/dev/null | grep bpfman || true)
    if [[ -n "$remaining_clusterroles" ]]; then
        log "  WARNING: Found remaining bpfman ClusterRoles:"
        echo "$remaining_clusterroles" | while IFS= read -r line; do
            log "    $line"
        done
        ((verification_issues++))
    fi

    # Check for remaining ClusterRoleBindings
    remaining_clusterrolebindings=$(kubectl get clusterrolebinding 2>/dev/null | grep bpfman || true)
    if [[ -n "$remaining_clusterrolebindings" ]]; then
        log "  WARNING: Found remaining bpfman ClusterRoleBindings:"
        echo "$remaining_clusterrolebindings" | while IFS= read -r line; do
            log "    $line"
        done
        ((verification_issues++))
    fi

    # Check for remaining CSIDrivers
    remaining_csidrivers=$(kubectl get csidrivers 2>/dev/null | grep bpfman || true)
    if [[ -n "$remaining_csidrivers" ]]; then
        log "  WARNING: Found remaining bpfman CSIDrivers:"
        echo "$remaining_csidrivers" | while IFS= read -r line; do
            log "    $line"
        done
        ((verification_issues++))
    fi

    # Check if namespace still exists
    if kubectl get namespace "$BPFMAN_NAMESPACE" &>/dev/null; then
        log "  WARNING: Namespace $BPFMAN_NAMESPACE still exists"
        ((verification_issues++))
    fi

    if [[ $verification_issues -eq 0 ]]; then
        log "  ✓ Verification passed: No bpfman resources remaining"
    else
        log "  ✗ Verification found $verification_issues issue(s)"
    fi
else
    log "Step 14: Preserving CRDs (use --purge to remove)"
fi

log "Step 17: Checking remaining resources"
echo ""
echo "=== Cleanup Summary ==="
echo ""

if [[ "$purge_mode" == "true" ]]; then
    # In purge mode, namespace should be deleted
    if kubectl get namespace "$BPFMAN_NAMESPACE" &>/dev/null; then
        echo "Namespace $BPFMAN_NAMESPACE status: Still exists (may be terminating)"
        echo "Remaining resources in namespace $BPFMAN_NAMESPACE:"
        if kubectl get all -n "$BPFMAN_NAMESPACE" 2>&1 | grep -v "DeploymentConfig" | grep -v "^NAME" | grep -q .; then
            kubectl get all -n "$BPFMAN_NAMESPACE" 2>&1 | grep -v "DeploymentConfig"
        else
            echo "  No workload resources found"
        fi
    else
        echo "Namespace $BPFMAN_NAMESPACE: Deleted"
    fi
    echo ""

    echo "CRDs (should be removed):"
    if kubectl get crd 2>/dev/null | grep -q bpfman; then
        kubectl get crd 2>/dev/null | grep bpfman
        echo ""
        echo "WARNING: Some CRDs still exist. They may be in the process of deletion."
    else
        echo "  All bpfman CRDs have been removed"
    fi
else
    echo "Remaining resources in namespace $BPFMAN_NAMESPACE:"
    if kubectl get all -n "$BPFMAN_NAMESPACE" 2>&1 | grep -v "DeploymentConfig" | grep -v "^NAME" | grep -q .; then
        kubectl get all -n "$BPFMAN_NAMESPACE" 2>&1 | grep -v "DeploymentConfig"
    else
        echo "  No workload resources found"
    fi
    echo ""

    echo "CRDs (preserved by design):"
    if kubectl get crd 2>/dev/null | grep -q bpfman; then
        kubectl get crd 2>/dev/null | grep bpfman
    else
        echo "  No bpfman CRDs found"
    fi
fi
echo ""

if [[ "$purge_mode" == "false" ]]; then
    crd_roles=$(kubectl get clusterrole 2>/dev/null | grep -c "bpfman.io.*-v1alpha1-" || echo "0")
    echo "CRD-related ClusterRoles (preserved): $crd_roles"
    echo ""
fi

log "Cleanup complete!"

if [[ "$purge_mode" == "false" ]]; then
    echo ""
    echo "Note: CRDs and their associated ClusterRoles are preserved to prevent data loss."
    echo "To remove ALL bpfman resources including CRDs, run:"
    echo "  ${0##*/} cleanup --purge"
fi
