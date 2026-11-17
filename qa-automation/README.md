# QA automation

Showroom's Nookbag QA buttons run these playbooks from the repository root.

## `healthcheck.yml`

Read-only provisioned-environment healthcheck. It imports the Module 01
validator, which checks the core OSAC platform services without changing the
cluster.

## `e2e.yml`

Full end-to-end automation. It runs the existing Showroom module playbooks in
order:

1. `runtime-automation/module-01/solve.yml`
2. `runtime-automation/module-01/validate.yml`
3. `runtime-automation/module-02/solve.yml`
4. `runtime-automation/module-02/validate.yml`
5. `runtime-automation/module-03/solve.yml`
6. `runtime-automation/module-03/validate.yml`
7. `runtime-automation/module-04/solve.yml`
8. `runtime-automation/module-04/validate.yml`

Run manually with:

```bash
ansible-playbook qa-automation/healthcheck.yml
ansible-playbook qa-automation/e2e.yml
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

Module 4 checks the current Metal3/libvirt workflow: `virtual-bmh-1`, the
platform-provided RHCOS image and cluster version, Alice's
`sai-corp-cluster-1`, its generated ClusterOrder/HostedCluster, the worker,
and public API/console access. It does not require the retired
`hardware-inventory` KubeVirt worker setup. A full e2e run provisions the
VM and hosted cluster and can take an hour or more.
