# Gobo Tiltfile — deploy to devkube
#
# Usage: tilt up (or tiltup gobo)
#
# Loads tilt_functions from the devtools checkout instead of
# /usr/local/lib/dd-tilt/ (which requires root to set up).

load(
    os.path.join(os.environ.get("HOME", ""), "devtools/devenv/tilt/tilt_functions/kubernetes/load_context.sky"),
    "load_context",
)

# Validate we're targeting a devkube namespace on an allowed cluster
ctx = load_context()

# Build the Docker image from the existing Dockerfile
# Tilt pushes to the staging ECR registry automatically
docker_build(
    "gobo-image",
    ".",
    dockerfile="Dockerfile",
)

# Apply K8s manifests
k8s_yaml("k8s/deployment.yaml")

# Tell Tilt which resource to track
k8s_resource("gobo", port_forwards="8080:8080")
