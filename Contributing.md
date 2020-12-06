# Contributing
Contributions to this project are welcome via [Merge Requests](https://docs.gitlab.com/ee/user/project/merge_requests/creating_merge_requests.html) on [GitLab](https://gitlab.com/). The general guidelines to follow for most files are:
- All text files in this repository should use 2 spaces per level of indentation.
- Most text files should use no more than 100 characters on each line. See the [`.editorconfig`](.editorconfig) file for what files this applies to.

This project's [Continuous Integration (CI)](https://docs.gitlab.com/ee/ci/) will check this using [editorconfig-checker](https://github.com/editorconfig-checker/editorconfig-checker).

## Bash
All Bash scripts should:
- Pass [ShellCheck](https://github.com/koalaman/shellcheck).
- Pass [shfmt](https://github.com/mvdan/sh#shfmt).

Both of these will be checked by CI.

Additionally, the [Google Shell Style Guide](https://google.github.io/styleguide/shell.xml) should be followed. The exceptions to this reference practiced are:
- `main` is not used.
- Executable scripts should be named with kebab case.
- Comments should be made as described below.

### Function Documentation
Functions must have certain attributes marked, if applicable.

#### Description
The first line of a function's documentation must describe what the function does. Example:
```bash
# Sets up a new system.
```

##### TODOs
The lines proceeding a function's documentation must describe general TODOs for it, if there are any. Example:
```bash
# TODO: Add licensing info.
```

#### Arguments
If a function reads any arguments, they must be documented. Example:
```bash
# Arguments:
#   - Whether to require root or to require non root.
```

#### Outputs
If a function outputs anything, it must be documented. Example:
```bash
# Outputs:
#   - The bootnum of the boot entry.
```

#### Returns
If a function has cases in which it returns a non-0 exit code, they must be documented. Example:
```bash
# Returns:
#   - 1 if the file couldn't be found.
```

#### Variables Read
If a function reads any variables, they must be documented. Example:
```bash
# Variables Read:
#   - DRY_RUN: Whether to actually perform actions.
```

#### Variables Written
If a function writes to any variables, they must be documented. Example:
```bash
# Variables Written:
#   - INSTALL_HOME: Location of the home directory of the current install user.
```

#### Variables Exported
If a function exports any variables, they must be documented. Example:
```bash
# Variables Exported:
#   - WINEPREFIX: See Wine documentation.
```

Exiting with a non-0 value for non-fatal errors is permitted.
