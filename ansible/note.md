testing ansible stuff for ccdc

this is for personal testing

# ansible/

This folder holds all configuration management. See `baseline/README.md` for
the full walkthrough. Quick orientation:

- `ansible.cfg` lives here and is read automatically.
- Everything actionable is under `baseline/`.
- Terraform (one level up, in `../terraform`) creates the VMs that these
  playbooks then configure.

