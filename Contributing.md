# Contributing
Contributions to this project are welcome via [Merge Requests](https://docs.gitlab.com/ee/user/project/merge_requests/creating_merge_requests.html) on [GitLab](https://gitlab.com/).

## General
Refer to the [`.editorconfig`](.editorconfig) file for general formatting rules that apply to all files. This project's [Continuous Integration (CI)](https://docs.gitlab.com/ee/ci/) will check this using [editorconfig-checker](https://github.com/editorconfig-checker/editorconfig-checker).

## Shell
All shell scripts should:
- Pass [ShellCheck](https://github.com/koalaman/shellcheck).
- Pass [shfmt](https://github.com/mvdan/sh#shfmt).

Both of these will be checked by CI.

Additionally, the [Google Shell Style Guide](https://google.github.io/styleguide/shell.xml) should be followed. The exceptions/additions to this reference practiced are:
- `main` is not used.
- Executable scripts should be named with kebab case.
- Prefer `printf` over `echo` because the latter is nonstandard.
- Comments should be made as described below.

### Function Documentation
Functions must have certain attributes marked, if applicable.

#### Description
The first line of a function's documentation must describe what the function does. Example:
```sh
# Sets up a new system.
```

##### TODOs
The lines proceeding a function's documentation must describe general TODOs for it, if there are any. Example:
```sh
# TODO: Add licensing info.
```

#### Arguments
If a function reads any arguments, they must be documented. Example:
```sh
# Arguments:
#   - Whether to require root or to require non root.
```

#### Outputs
If a function outputs anything, it must be documented. Example:
```sh
# Outputs:
#   - The bootnum of the boot entry.
```

#### Returns
If a function has cases in which it returns a non-0 exit code, they must be documented. Example:
```sh
# Returns:
#   - 1 if the file couldn't be found.
```

#### Variables Read
If a function reads any variables, they must be documented. Example:
```sh
# Variables Read:
#   - dry_run: Whether to actually perform actions.
```

#### Variables Written
If a function writes to any variables, they must be documented. Example:
```sh
# Variables Written:
#   - install_home: Location of the home directory of the current install user.
```

#### Variables Exported
If a function exports any variables, they must be documented. Example:
```sh
# Variables Exported:
#   - WINEPREFIX: See Wine documentation.
```

Exiting with a non-0 value for non-fatal errors is permitted.

## Infrastructure
Infrastructure scripts, such as Docker and CI code, are held to a high standard. They should be exemplary, well commented pieces of code. Prefer long options to programs that support it, to improve readability. - note that BusyBox variants of common Unix tools often do not.
