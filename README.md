<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="logo/cosyses-logo-dark.svg">
    <img src="logo/cosyses-logo.svg" alt="Cosyses" width="408">
  </picture>
</p>

<p align="center">Reproducible install routines for server software on Ubuntu.</p>

Cosyses collects installation and configuration routines that are known to work: Bash scripts for PHP, Nginx, Apache, MySQL, Varnish, Redis, OpenSearch, Node.js and more, each tested for a specific combination of software version and Ubuntu release. Instead of following a different how-to for every server, you run one command and get the same result every time.

## Installation

```
wget --no-cache -q -O - https://raw.githubusercontent.com/cosyses/app/master/setup.sh | bash
```

This downloads the latest release to `/usr/local/lib/cosyses/<version>`, links it as `/usr/local/lib/cosyses/current` and installs the `cosyses` command to `/usr/local/bin`. It also installs the helper commands the scripts use (`install-package`, `add-gpg-repository`, `replace-file-content`, `ensure-user`, …) to `/usr/local/bin`.

To install a specific release instead of the latest:

```
wget --no-cache -q -O - https://raw.githubusercontent.com/cosyses/app/master/setup.sh | bash -s -- --applicationVersion 1.131.0
```

The scripts install packages system-wide, so run them as root on the server or container you want to set up.

## Usage

Install an application, optionally in a specific version:

```
cosyses Nginx           # latest version available for this Ubuntu release
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
cosyses list            # applications available for this Ubuntu release
cosyses list PHP        # versions of an application available for this release
```

The repository currently covers Apache, Box, Caddy, Claude Code, CodeGraph, CodeSniffer, Composer, ddev, Elasticsearch, GitHub CLI, Go, Graphify, Kubernetes, MagentoServer, MailCatcher, MariaDB, mhsendmail, MongoDB, MySQL, Nginx, Node.js, OpenSearch, OpenSSH, PHP, Python, RabbitMQ, Redis, Ruby, Tini, Valkey, Varnish, WP-CLI and Xdebug, on Ubuntu 16.04 to 26.04. Not every version exists for every release; `cosyses list` shows what works on the current machine.

### Updating and removing

```
cosyses update          # install the latest release
```

`/usr/local/lib/cosyses/current/remove.sh` removes the `cosyses` command and all downloaded releases. Software installed with Cosyses stays installed.

## How it works

Scripts live in a tree of application, version, distribution and release:

```
<Name>/<Version>/Ubuntu/<Release>/install.sh   # e.g. Varnish/7.7/Ubuntu/22.04/install.sh
<Name>/<Version>/Ubuntu/install.sh             # one script for several releases, listed in a releases file
<Name>/vhost.sh                                # version-independent scripts at the application root
```

`cosyses` detects the Ubuntu release and picks the most specific script that exists, falling back from the release directory to the version, the distribution and finally the application root. A `releases` file next to a script limits it to the releases listed there, which are the ones it was tested on. Without a version, the highest version that has a matching script is used.

Scripts build on each other: a framework script like `cosyses PHP 8.4 magento.sh` installs the PHP CLI first if it is missing, and `Nginx/vhost.sh` puts together a virtual host from prepared building blocks (HTTP or SSL, path or proxy, PHP-FPM, basic auth) plus optional settings for Magento, Shopware, Symfony, Laravel, WordPress or Pimcore.

## Development

Never run the scripts on your development machine. `test.sh` runs them from your working copy in throwaway `cosyses/ubuntu:<release>` Docker containers:

```
./test.sh Varnish 7.7 22.04                     # one combination
./test.sh Varnish                               # every version and release
./test.sh --prepare "PHP 8.4" Composer 2.9      # install dependencies first
./test.sh --shell Varnish 7.7 22.04             # keep a shell open afterwards
```

It prints a PASS/FAIL summary and writes the full output to `${TMPDIR:-/tmp}/cosyses-test/`. Run `./test.sh --help` for all options.

When adding or changing a script:

- Put it in the most specific directory it was tested in, and add the release to the `releases` file when a shared script was tested on another release.
- Versions that only differ in version numbers share an `install-base.sh` and get a small wrapper per version that sets the variables. A change to shared logic must be tested on every version using it.
- Check scripts with `shellcheck`, and commit them as executable (`100755`). CI runs both on every push and pull request.

Servers and containers only receive changes through a GitHub release; `./release.sh` tags and publishes the next version.

## License

Cosyses is released under the [MIT License](LICENSE).
