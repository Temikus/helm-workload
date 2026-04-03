# Contributing to helm-workload

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Development Setup

1. Install prerequisites:
   - [Helm](https://helm.sh/) 3.x
   - [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin: `helm plugin install https://github.com/helm-unittest/helm-unittest`
   - [just](https://github.com/casey/just) (optional, for task automation)

2. Clone the repository:
   ```bash
   git clone https://github.com/Temikus/helm-workload.git
   cd helm-workload
   ```

3. Run the tests to verify your setup:
   ```bash
   helm unittest .
   ```

## Making Changes

### Template Structure

- Each Kubernetes resource has a top-level template file in `templates/`
- Helper templates live in `templates/_helpers/` with `_name.tpl` naming
- Addons follow a consistent pattern — see the existing addons for reference

### Testing

Every change should include corresponding tests:

- Test files go in `tests/` and match the template name (e.g., `tests/deployment_test.yaml`)
- Use `matchSnapshot` for complex structures
- Use `failedTemplate` assertions to test validation guards
- Run `helm unittest .` to execute all tests
- Run `helm unittest . -u` to update snapshots after intentional changes

### Schema Validation

If you add or modify values, update `values.schema.json` accordingly. The schema uses JSON Schema Draft-07.

## Submitting Changes

1. Fork the repository and create a feature branch
2. Make your changes with tests
3. Ensure all tests pass: `helm unittest .`
4. Ensure linting passes: `helm lint .`
5. Submit a pull request with a clear description of the changes

## Reporting Issues

Please use [GitHub Issues](https://github.com/Temikus/helm-workload/issues) to report bugs or request features. Include:

- Chart version
- Kubernetes version
- Helm version
- Minimal values.yaml to reproduce the issue
- Expected vs actual behavior
