# QA automation

Showroom's Nookbag QA buttons run these playbooks from the repository root.

## `healthcheck.yml`

Read-only provisioned-environment healthcheck. It always imports the optional
Module 05 platform exploration validator, which checks the core OSAC platform
services without changing the cluster.

## `e2e.yml`

Core end-to-end automation. It solves and validates each required module in
order: Module 1 (tenant onboarding), Module 2 (VMaaS), Module 3 (CaaS), and
Module 4 (BMaaS).

1. `runtime-automation/module-01/solve.yml`
2. `runtime-automation/module-01/validate.yml`
3. `runtime-automation/module-02/solve.yml`
4. `runtime-automation/module-02/validate.yml`
5. `runtime-automation/module-03/solve.yml`
6. `runtime-automation/module-03/validate.yml`
7. `runtime-automation/module-04/solve.yml`
8. `runtime-automation/module-04/validate.yml`

Module 5 (platform exploration) is fully optional and skipped by default.
Pass `-e run_optional_exploration=true` to append its solve placeholder and
read-only validator after the core modules. The standalone healthcheck always
runs the platform validator, independently of this flag.

Run manually with:

```bash
ansible-playbook qa-automation/healthcheck.yml
ansible-playbook qa-automation/e2e.yml
ansible-playbook qa-automation/e2e.yml -e run_optional_exploration=true
```

Both entry points need the lab's AgnosticD user-info variables (supplied by
Nookbag). For a manual run, pass them with `-e @/path/to/user-info.yml`.
The file must contain the bastion connection variables, OSAC and Keycloak
credentials, and the URLs exported by the OSAC workload.

All cluster and OSAC checks run on the bastion as the lab user, using its
installed `oc` and `osac` commands and `$HOME/.kube/config`. The QA container
needs Ansible and the Showroom `validation_check` plugin. Validation results
are reported on localhost, and a failed validation stops the end-to-end run.

Shared lab settings live in `runtime-automation/vars.yml`. Each module can
also run independently: it registers the bastion and copies the device-login
helper using paths relative to the module, including when imported by QA.

Module 3 checks the current Metal3/libvirt workflow: `virtual-bmh-1`, the
platform-provided RHCOS image and cluster version, Alice's
`sai-corp-cluster-1`, its generated ClusterOrder/HostedCluster, the worker,
and public API/console access. It does not require the retired
`hardware-inventory` KubeVirt worker setup. A full e2e run provisions the
VM and hosted cluster and can take an hour or more.

Module 4 adds separate BMaaS capacity (`virtual-bmh-2`, MAC ending `02`,
`host-type=bmaas`) and a matching `c1-bmaas-amd64` profile. It publishes the
BMaaS catalog, orders `sai-corp-bm-1` as Alice, waits for provisioning,
checks actual power off/on through the tenant API, and verifies guest SSH
through BMF. The solve playbook leaves the instance running and refuses to
reuse a host occupied by another workload. It requires Module 1 and the
provisioned Metal3/BMF network; a Module 3 cluster is not required.
It detects whether the deployed CLI requires a registered `ssh-public-key`
Secret or accepts legacy inline public key text, and registers Alice's key
when required.
For RHCOS it also passes explicit Ignition user data for the `core` account;
the template's SSH-key metadata alone does not configure guest login. The
solver verifies SSH before the power cycle and again after the restart.

The default validator checks the running state. After the optional manual
release exercise, check the released state with:

```bash
ansible-playbook runtime-automation/module-04/validate.yml \
  -e @/path/to/user-info.yml -e bmaas_expected_state=released
```

The validator only reads cluster and workload state; authentication updates
the CLI configs. It verifies current power and ownership, while the solver
also waits for both lifecycle transitions. A validation snapshot does not
prove a previous power cycle. Module 4 uses built-in Ansible assertions and
reports each failed check without requiring the `validation_check` plugin.
For RHCOS, it checks that Ignition configures `core` with the bastion public
key and verifies SSH with that key. User data can supply authentication
without a separate SSH-key reference in the instance API response.

BMaaS standalone verification (2026-11-17, RHDP `cluster-ndhm9`, CLI
`0.0.134`) passed real host inspection, provisioning, SSH before and after
the halt/start cycle, and release back to an unclaimed host. All 14 running
checks and all 8 released checks passed. Negative tests rejected a missing
instance and an attempt to reuse the CaaS host. The final solve preserved
the CaaS host's UID and consumer and left `sai-corp-bm-1` running. AsciiDoc
rendering, executable shell blocks, and playbook syntax were also checked.
