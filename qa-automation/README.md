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
