LPE Scanned Document Importer
=================================

## Installation

To install the Scanned Document Importer on a Windows Server:

1. Install the latest (stable) release of [Ruby][ruby-lang] from the [Ruby
   Installer][ruby-inst] project.
2. Install the latest [Oracle Instant Client][ora-client] release compatible
   with the version of the Oracle Database on which IFS is running.

   _Note:_ the “Basic Lite” package contains everything required.
3. Add the Oracle client directory to the system `PATH` variable.

   _Note:_ if you’ve accepted the defaults the directory will be
   `C:\instantclient_<major-version>_<minor-version>`, e.g.
   `C:\instantclient_12_2`.
4. Install the Ruby OCI8 Gem:

   1. As a system administrator, open a Command Prompt.
   2. Run the command `gem install ruby-oci8`.
5. [Download this project][download].
6. Extract the downloaded archive to a suitable location.

[ruby-lang]: https://www.ruby-lang.org/en/
[ruby-inst]: https://rubyinstaller.org
[ora-client]: http://www.oracle.com/technetwork/database/database-technologies/instant-client/overview/index.html
[download]: https://github.com/lymingtonprecision/scanned-document-importer/archive/master.zip

## Configuration

Inside the program directory created in step 6 above you will find a file called `config.yml.example`.  Copy this file to `config.yml` and open it in Notepad (or another text editor of your choice) and alter as follows.

At the top of the file you can set the default username and password used to
connect to _every_ database instance:

    defaults: &defaults
      username: <db username to use>
      password: <their password>
      
These can be overridden in the subsequent environment specific sections as
needed.

There are two “environments” defined: `development` and `production`. Each has a
configurable database `instance` to connect to and a base directory,
`scanbasedir`, in which to look for files to import:

    production:
      <<: *defaults
      instance: //db-test-server/PRODDBSID
      scanbasedir: //production/document/location
      
Replace the placeholders with the appropriate values for your environment. Note
that the path specified for the `scanbasedir` **must** use forward-slashes and
_not_ backslashes.

Also included in the program directory are batch files and scripts for running
the importer for various document types.

There are two “primary” import jobs:

* `import` (`.bat` and `.rb`) runs the “main” import routine—importing every
  document type _except_ Supplier Invoices.
* `import_supplier_invoices` runs the import routing for _only_ Supplier
  Invoices_.
  
There are two more batch/script files for running ad-hoc imports of specific
document types:

* `import_del_notes` (importing Customer Delivery Notes.)
* `import_gauge_service_records` (import Gauge Service Records.)

_Note:_ the batch files exist only to execute the Ruby interpreter with the
appropriate script file. **However** they also define the environment under
which the script will run. The first line of each contains a line `set
RACK_ENV=production`—the value of which (`production` in this case) defines
which configuration (from the `config.yml` file) will be loaded.

## Running

Having configured the program and verified that a batch/script file combination
exists that meets your needs all you need to do is execute the batch command.
This can either be done from the Windows “Run” dialog, the command line, or as a
scheduled task.

In order to ensure proper operation you **must** execute the batch file using
it’s _full_ path—and not the relative path, even if you are running it from the
program directory.

### Log Output

Log files are output to:

* A `log` directory within each document classes `processed` files directory
  (the directory from which files are imported.)
  
  These log files contain only the log entries pertaining to the specific
  document class of the folder in which they reside.
* A `log` directory under the `scanbasedir` specified in the configuration.

  These logs contain all of the log entries for the program—including those of
  all document classes processed.

### Performing a “Dry Run”

It is possible to configure the program to perform a “dry run” and have it
execute _without_ creating any database entries, moving any files on disk, or
logging anything to the log files.

Instead, all log entries will be output to the console. This enables you to see
what _would_ happen were an import to be run using the provided configuration
without any changes being made.

To perform a “dry run” you need to alter the import _script_ (the `.rb` file)
being used such that the `perform` call ends with `, dry_run: true`.

Taking the `import_supplier_invoices.rb` script as an example:

```ruby
require File.join(File.dirname(__FILE__), "lib", "scan_import", "ifs", "import_job")

if __FILE__ == $0
  IFS.load_config

  IFS::ImportJob.perform("SupplierInvoice")
end
```

We would change the second to last line to:

```ruby
  IFS::ImportJob.perform("SupplierInvoice", dry_run: true)
```

Now when the script is executed it’s operation can be verified without any
changes being made to either the scanned files or the database.

## Copyright

Copyright © 2018 Lymington Precision Engineers Co. Ltd.
