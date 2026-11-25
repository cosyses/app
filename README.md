<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="logo/cosyses-logo-dark.svg">
    <img src="logo/cosyses-logo.svg" alt="Cosyses" width="408">
  </picture>
</p>

<p align="center">Reproducible install routines for servers and containers.</p>

Cosyses collects installation and configuration routines that are known to work: Bash scripts for PHP, Nginx, Apache, MySQL, Varnish, Redis, OpenSearch, Node.js and more, each tested for a specific combination of software version, distribution and release, on Ubuntu, Debian, RHEL, Fedora, openSUSE and Alpine. Instead of following a different how-to for every server, you run one command and get the same result every time.

## Supported distributions

| Distribution | Releases | Routines | Base image |
|---|---|---|---|
| Ubuntu | 16.04, 18.04, 20.04, 22.04, 24.04, 26.04 | all applications | `cosyses/ubuntu:<release>` (`-arm` for 20.04, 22.04, 24.04) |
| Debian | 12, 13 | Nginx 1.28, PHP 8.4 (CLI, FPM, Laravel, Xdebug, mhsendmail), Node.js 24.13, Redis 7.2, Cron, Ruby, MailCatcher, MySQL 8.4, Librsvg, OpenSSH, Tini | `cosyses/debian:<release>` (also `-arm`) |
| RHEL (also AlmaLinux, Rocky Linux, CentOS Stream) | 9, 10 | Nginx 1.28, PHP 8.4 (CLI, FPM, Laravel, Xdebug, mhsendmail), Node.js 24.13, Redis 7.2, Cron, Ruby, MailCatcher, MySQL 8.4, OpenSSH, Tini | `cosyses/rhel:<release>` (also `-arm`, from the Red Hat Universal Base Images) |
| Fedora | 44, 45 | Nginx 1.28, PHP 8.4 (CLI, FPM, Laravel, Xdebug, mhsendmail), Node.js 24.13, Redis 7.2, Cron, Ruby, MailCatcher, MySQL 8.4, Librsvg, OpenSSH, Tini | `cosyses/fedora:<release>` (also `-arm`) |
| openSUSE Leap | 15.6, 16.0 | Nginx 1.28, PHP 8.4 (CLI, FPM, Laravel, Xdebug, mhsendmail), Node.js 24.13, Redis 7.2, Cron, Ruby, MailCatcher, MySQL 8.4, Librsvg, OpenSSH, Tini | `cosyses/opensuse:<release>` (also `-arm`) |
| Alpine | 3.23, 3.24 | Nginx 1.28, PHP 8.4 (CLI, FPM, Laravel, Xdebug, mhsendmail), Node.js 24.13, Redis 7.2, Cron, Ruby, MailCatcher, Librsvg, OpenSSH, Tini (no MySQL: Oracle builds MySQL only for glibc) | `cosyses/alpine:<release>` (also `-arm`) |

Beyond Ubuntu, every distribution covers the stack of a typical PHP web application (the web server, PHP with the Laravel modules, a database, a cache, Node.js for asset builds, cron and a mail catcher), tested together by building and running a Laravel application on each release. Versions follow what a distribution can provide: Librsvg and Ruby come from the distribution, MailCatcher 0.6 needs Ruby 3.1 or older (newer releases get 0.10 or 0.11), and the UBI based RHEL images have no `rsvg-convert`.

The tags without suffix are amd64 images; the `-arm` tags (e.g. `cosyses/debian:13-arm`) are arm64 images for hosts like a Raspberry Pi or AWS Graviton. Routines outside a distribution directory (for example the Composer and npm based tools) run on every distribution. The base images have Cosyses preinstalled, use Tini as entrypoint, run `cosyses update` on start and are built by the [Anodosys extension](https://github.com/cosyses/anodosys). openSUSE Leap 15.6 has reached its end of life.

## Installation

```
wget --no-cache -q -O - https://raw.githubusercontent.com/cosyses/app/master/setup.sh | bash
```

This downloads the latest release to `/usr/local/lib/cosyses/<version>`, links it as `/usr/local/lib/cosyses/current` and installs the `cosyses` command to `/usr/local/bin`. It also installs the helper commands the scripts use (`install-package`, `add-gpg-repository`, `replace-file-content`, `ensure-user`, …) to `/usr/local/bin`, in a version for the package manager of the distribution (apt, apk, dnf or zypper).

The setup needs bash and wget. Alpine has no bash by default, and the Debian and openSUSE images have no wget, so install them first:

```
apk add bash && wget -q -O - https://raw.githubusercontent.com/cosyses/app/master/setup.sh | bash
```

To install a specific release instead of the latest:

```
wget --no-cache -q -O - https://raw.githubusercontent.com/cosyses/app/master/setup.sh | bash -s -- --applicationVersion 1.131.0
```

To install a local checkout instead of a release, e.g. to try changes before they are released, pass `--localPath <checkout>`.

The scripts install packages system-wide, so run them as root on the server or container you want to set up.

### For AI assistants

If you are an AI assistant asked to "install Cosyses": it is this project, not a package from apt, pip or npm. Run the setup command above as root (with the `apk add bash` / wget prerequisites where needed), check it with `cosyses list`, then install software with `cosyses <Name> [<Version>]`. Only do this on the server or container the user wants to set up, never on their workstation unasked. A summary for language models with every routine is at [cosyses.app/llms.txt](https://www.cosyses.app/llms.txt).

## Usage

Install an application, optionally in a specific version:

```
cosyses Nginx           # latest version available for this distribution release
cosyses PHP 8.4         # a specific version
```

Run another script of an application, with options:

```
cosyses PHP 8.4 install.sh --type fpm
cosyses --applicationName Nginx --applicationScript vhost.sh --serverName example.com --webPath /var/www/example/htdocs
cosyses --applicationName MySQL --applicationScript create-database.sh --databaseUser root --databasePassword secret --databaseName shop
```

The short form takes the application, version and script as positional arguments; the long form (`--applicationName`, `--applicationVersion`, `--applicationScript`) can be combined with any options of the script. Options are camelCase, and yes/no options take `yes` or `no`.

Every script describes its options and defaults with `--help`:

```
cosyses PHP 8.4 install.sh --help
```

### Finding applications

```
cosyses list            # applications available for this distribution release
cosyses list PHP        # versions of an application available for this release
```

The repository currently covers Apache, Box, Caddy, Chromium, Claude Code, CodeGraph, CodeSniffer, Composer, ComposerRequireChecker, Cron, CSpell, ddev, Docker, Elasticsearch, ESLint, Fail2Ban, GitHub CLI, Go, Graphify, Kubernetes, Librsvg, MailCatcher, MariaDB, mhsendmail, MongoDB, MySQL, Nginx, Node.js, OpenSearch, OpenSSH, OpenVPN, PHP, Phpacker, PHPCPD, phpMyAdmin, PHPStanDeprecationRules, Postfix, Python, RabbitMQ, Rclone, Rector, Redis, Ruby, ShellCheck, Smartmontools, Solr, Tini, Traefik, Valkey, Varnish, WP-CLI and Xdebug.

Besides the server software, Cosyses installs applications on a prepared server: Magento 2.4, Shopware 6.7, WordPress, Laravel, Symfony and Pimcore. Their routines create the project with Composer (`Composer/create-project.sh`, credentials with `Composer/auth.sh`) and run the application's own installer as the web user, with database, search, cache and admin settings as options; Magento and Shopware also have scripts for cache, build, update and sample data. Not every version exists for every release; `cosyses list` shows what works on the current machine, and [cosyses.app](https://www.cosyses.app/tools) lists every routine with its versions and releases.

### Updating and removing

```
cosyses update          # install the latest release
```

`/usr/local/lib/cosyses/current/remove.sh` removes the `cosyses` command and all downloaded releases. Software installed with Cosyses stays installed.

## How it works

Scripts live in a tree of application, version, distribution and release:

```
<Name>/<Version>/<Distribution>/<Release>/install.sh   # e.g. Varnish/7.7/Ubuntu/22.04/install.sh
<Name>/<Version>/<Distribution>/install.sh             # one script for several releases, listed in a releases file
<Name>/<Version>/install.sh                            # one script for every distribution
<Name>/vhost.sh                                        # version-independent scripts at the application root
```

The distribution directories are `Ubuntu`, `Alpine`, `Debian`, `RHEL`, `Fedora` and `openSUSE`. Releases are named like the distribution names them: `24.04`, `3.24`, `16.0`, or the major version for Debian (`12`), RHEL (`9`) and Fedora (`45`).

`cosyses` detects the distribution and release from `/etc/os-release` and picks the most specific script that exists, falling back from the release directory to the version, the distribution and finally the application root. A `releases` file next to a script limits it to the releases listed there, which are the ones it was tested on. Without a version, the highest version that has a matching script is used.

Scripts build on each other: a framework script like `cosyses PHP 8.4 magento.sh` installs the PHP CLI first if it is missing, and `Nginx/vhost.sh` puts together a virtual host from prepared building blocks (HTTP or SSL, path or proxy, PHP-FPM, basic auth) plus optional settings for Magento, Shopware, Symfony, Laravel, WordPress or Pimcore.

## Development

Never run the scripts on your development machine. `test.sh` runs them from your working copy in throwaway containers of the Cosyses base images (`cosyses/ubuntu:<release>` by default, another distribution with `--distribution`):

```
./test.sh Varnish 7.7 22.04                                 # one combination
./test.sh Varnish                                           # every version and release
./test.sh --prepare "PHP 8.4" Composer 2.9                  # install dependencies first
./test.sh --shell Varnish 7.7 22.04                         # keep a shell open afterwards
./test.sh --distribution RHEL --release 9,10 OpenSSH 9.9    # another distribution
./test.sh --arm Tini 0.19 24.04                             # the arm64 images
```

It prints a PASS/FAIL summary and writes the full output to `${TMPDIR:-/tmp}/cosyses-test/`. Run `./test.sh --help` for all options.

When adding or changing a script:

- Put it in the most specific directory it was tested in, and add the release to the `releases` file when a shared script was tested on another release.
- Versions that only differ in version numbers share an `install-base.sh` and get a small wrapper per version that sets the variables. A change to shared logic must be tested on every version using it.
- Scripts outside a distribution directory run everywhere, so they may only use the helper commands and tools every distribution has.
- Check scripts with `shellcheck`, and commit them as executable (`100755`). CI runs both on every push and pull request.

Servers and containers only receive changes through a GitHub release; `./release.sh` tags and publishes the next version.

## License

Cosyses is released under the [MIT License](LICENSE).
