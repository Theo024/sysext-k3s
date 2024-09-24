#!/usr/bin/env bash
set -euo pipefail

VERSION="$(cat k3s.version)"
SYSEXTNAME="k3s-$VERSION-x86-64"

URL="https://github.com/k3s-io/k3s/releases/download/${VERSION}/k3s"

mkdir -p build/ dist/
cd build/

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"/usr/bin
curl -o "${SYSEXTNAME}/usr/bin/k3s" -fsSL "${URL}"
chmod +x "${SYSEXTNAME}"/usr/bin/k3s
pushd "${SYSEXTNAME}"/usr/bin/
ln -s ./k3s kubectl
ln -s ./k3s crictl
ln -s ./k3s ctr
popd

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/
cat > "${SYSEXTNAME}"/usr/lib/systemd/system/k3s.service << EOF
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-/usr/lib/systemd/system/k3s.service.env
KillMode=process
Delegate=yes
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=/bin/sh -xc '! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service 2>/dev/null'
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/bin/k3s server
EOF

cat > "${SYSEXTNAME}"/usr/lib/systemd/system/k3s-agent.service << EOF
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-/usr/lib/systemd/system/k3s-agent.service.env
KillMode=process
Delegate=yes
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=/bin/sh -xc '! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service 2>/dev/null'
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/bin/k3s agent
EOF

SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH-0}"
export SOURCE_DATE_EPOCH

mkdir -p "${SYSEXTNAME}/usr/lib/extension-release.d"
cat > "${SYSEXTNAME}/usr/lib/extension-release.d/extension-release.${SYSEXTNAME}" << EOF
ID=_any
ARCHITECTURE=x86-64
EXTENSION_RELOAD_MANAGER=1
EOF

rm -f "${SYSEXTNAME}.raw"
mksquashfs "${SYSEXTNAME}" "../dist/${SYSEXTNAME}.raw" -all-root -noappend
echo "Created ${SYSEXTNAME}.raw"

cd ../dist/
sha256sum "${SYSEXTNAME}.raw" > "${SYSEXTNAME}.raw.sha256"
echo "Created ${SYSEXTNAME}.raw.sha256"
