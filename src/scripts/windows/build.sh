#!/bin/false
# shellcheck shell=bash
# shellcheck disable=SC2016,SC2154

trap_exit() {
  local exit_status="$?"

  if [ "$exit_status" -ne 0 ]; then
    printf '%s\n' 'The script did not complete successfully.'

    printf '%s\n' "Removing the container \"$CONTAINER_NAME\"."
    docker rm -f "$CONTAINER_NAME" &> /dev/null || true

    exit "$exit_status"
  fi
}
trap trap_exit EXIT

# Create the build folder
docker exec "$CONTAINER_NAME" powershell mkdir C:/build

# Add the build target and build name in the environment variables.
docker exec "$CONTAINER_NAME" powershell "[System.Environment]::SetEnvironmentVariable('BUILD_NAME','$PARAM_BUILD_NAME', [System.EnvironmentVariableTarget]::Machine)"
docker exec "$CONTAINER_NAME" powershell "[System.Environment]::SetEnvironmentVariable('BUILD_TARGET','$PARAM_BUILD_TARGET', [System.EnvironmentVariableTarget]::Machine)"
docker exec "$CONTAINER_NAME" powershell "[System.Environment]::SetEnvironmentVariable('BUILD_METHOD','$build_method', [System.EnvironmentVariableTarget]::Machine)"
docker exec "$CONTAINER_NAME" powershell "[System.Environment]::SetEnvironmentVariable('CUSTOM_PARAMS','$custom_parameters', [System.EnvironmentVariableTarget]::Machine)"

build_args=(
  '-batchmode'
  '-quit'
  '-nographics'
  '-projectPath $Env:PROJECT_PATH'
  '-buildTarget $Env:BUILD_TARGET'
  '-customBuildTarget $Env:BUILD_TARGET'
  '-customBuildName $Env:BUILD_NAME'
  '-customBuildPath "C:/build/"'
  '-executeMethod $Env:BUILD_METHOD'
)

[ -n "$custom_parameters" ] && build_args+=( '$Env:CUSTOM_PARAMS.split()' )

# Build the project
# Versioning of the project needs work. This is how it's done in the GHA:
# https://github.com/game-ci/unity-builder/blob/main/src/model/versioning.ts
set -x
docker exec "$CONTAINER_NAME" powershell "& 'C:\Program Files\Unity\Hub\Editor\*\Editor\Unity.exe' ${build_args[*]} -logfile | Out-Host"
exit_code="$?"
set +x

if [ "$exit_code" -ne 0 ]; then
  printf '%s\n' "Failed to build the project."
  printf '%s\n' "Please try again, open an issue or reach out to us on Discord."
  exit "$exit_code"
fi

# Compress the build folder.
docker exec "$CONTAINER_NAME" powershell 'tar -czf "C:/$Env:BUILD_NAME-$Env:BUILD_TARGET.tar.gz" -C "C:/build" .'

# Copy the build directory to the host.
docker cp "$CONTAINER_NAME":"$PARAM_BUILD_NAME"-"$PARAM_BUILD_TARGET".tar.gz "$base_dir"/"$PARAM_BUILD_TARGET".tar.gz
