# bashrc

---

![License](https://img.shields.io/github/license/Redstoneur/bashrc)
![Top Language](https://img.shields.io/github/languages/top/Redstoneur/bashrc)
![Size](https://img.shields.io/github/repo-size/Redstoneur/bashrc)
![Contributors](https://img.shields.io/github/contributors/Redstoneur/bashrc)
![Last Commit](https://img.shields.io/github/last-commit/Redstoneur/bashrc)
![Issues](https://img.shields.io/github/issues/Redstoneur/bashrc)
![Pull Requests](https://img.shields.io/github/issues-pr/Redstoneur/bashrc)

---

![Forks](https://img.shields.io/github/forks/Redstoneur/bashrc)
![Stars](https://img.shields.io/github/stars/Redstoneur/bashrc)
![Watchers](https://img.shields.io/github/watchers/Redstoneur/bashrc)

---

![Latest Release](https://img.shields.io/github/v/release/Redstoneur/bashrc)
![Release Date](https://img.shields.io/github/release-date/Redstoneur/bashrc)

---

## Description

This project is a collection of shell scripts and configuration files designed to enhance the command-line experience
for developers. It includes a variety of custom aliases, functions, and exports to streamline common tasks and improve
productivity.

### Features

- **Custom Aliases**: Simplify complex commands into short, memorable keywords.
- **Custom Functions**: Automate repetitive tasks with custom shell functions.
- **Custom Exports**: Define environment variables for use across multiple sessions.
- **GNU General Public License**: The project is licensed under the GNU General Public License v3.0, ensuring the
  freedom to use, modify, and distribute the software.

### Files

- `.bashrc`: The main configuration file that sources all other files.
- `.shells/alias`: Contains custom aliases for various commands.
- `.shells/functions`: Contains custom shell functions.
- `.shells/exports`: Contains custom environment variables.

## Usage

To use this project, simply clone the repository to your home directory and source the `.bashrc` file in your shell

You can get the latest version of the project by running the following commands:

```bash
git clone https://github.com/Redstoneur/bashrc.git bashrc # clone the repository
cd bashrc # change to the project directory
source .bashrc # if you want to use the project in the current shell
```

If you want to use the project instead of your current configuration, you can run the following commands:

```bash
rm -rf $HOME/.bashrc $HOME/.shells # remove the existing configuration
git clone https://github.com/Redstoneur/bashrc.git bashrc_tmp # clone the repository to a temporary directory
mv bashrc_tmp/.* $HOME # move the configuration files to the home directory
rm -rf bashrc_tmp # remove the temporary directory
source $HOME/.bashrc # source the main configuration file
```

### Notes on Compatibility

GitHub may change encoding of the files in the repository, which can cause issues when sourcing the files in the shell.
To avoid this, you can convert the files to Unix format by running the following command:

```bash
dos2unix .bashrc .shells/*
```

## Deployer

### Online Deployer

A script named `.bashrc_deploy.sh` has been added to simplify deployment on Linux machines. It allows you to:

- Install the project by fetching the latest GitHub release (or the `master` branch as a fallback),
- Update an existing installation,
- Uninstall the project.

Basic usage:

```bash
# install
./.bashrc_deploy.sh --install

# update an existing installation
./.bashrc_deploy.sh --update

# uninstall
./.bashrc_deploy.sh --uninstall
```

Notes:

- The script requires `git` to clone the repository.

### Local Deployer

A script named `bashrc_deploy_local.sh` has been added to simplify local deployment on Linux machines. It allows you to:
- Install the project from a local copy of the repository,
- Update an existing installation from a local copy,
- Uninstall the project.

Basic usage:

```bash
# install
./bashrc_deploy_local.sh --install my-local-ref

# update an existing installation
./bashrc_deploy_local.sh --update my-local-ref

# uninstall
./bashrc_deploy_local.sh --uninstall
```

Notes:
- The script requires you to clone the repository with git and copy it to the local machine.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.