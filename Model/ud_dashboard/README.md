# Project Title

User Dataset Diagnostic Dashboard

## Getting Started

The project is found at ud_dashboard_ under ApiCommonModel/Model

### Prerequisites

You will need cx_Oracle and python-irodsclient on the system this is to be run on.

### Installing

The project contains a configuration directory which has a config.json.template.  The template must be
populated with connection information for the irods to be tested, for the account database from which 
additional user information is obtained (since irods knows users by their wdk ids only), and for one of
the app dbs to which the irods connects.  Database information provided will only be relevant to the
specific app db configured here.

Note that, the user may dispense with the workspace object completely in favor of having the software query
the user's irods_environment.json file instead.  In fact, this appears to be the only way to successfully
connect to the production iRODS system as the information in the irods_environment.json file is more
extensive than simply host, port, username, password and zone.

Additionally, the entry point into the project, located in bin/ud_dashboard, needs a modification since the
actual package (user\_dataset\_dashboard) resides under the lib/python directory and python will not look
there for packages.  So python needs to be instructed to include that directory as a source for packages.
That is done by changing this line at the top of the file:
```
sys.path.insert(0, "/vagrant/scratch/ud_dashboard/lib/python")
```
to be the current path to the package.

## Deployment

In the bin directory the user may lauch the help by using:

```
./ud_dashboard -h
```
```
usage: ud_dashboard [-h] {workspace_report,user_report,dataset_report} ...

User Dataset Dignostics

positional arguments:
  {workspace_report,user_report,dataset_report}
                        diagnostic subcommand
    workspace_report    report on the iRODS workspace
    user_report         report on a user identified by his/her email address
    dataset_report      report on a user dataset identified by its id

optional arguments:
  -h, --help            show this help message and exit
```

Presently the project contains three sub-commands or reports:  workspace_report, user_report, and dataset_report.
Each has options and in the later two cases, positional parameters.  Those can be identified by running the
help on each of the sub-commands.  For instance,

```bash
./ud_dashboard user_report -h

usage: ud_dashboard user_report [-h] [--show_events] user_email

positional arguments:
  user_email     email address user uses to log into wdk

optional arguments:
  -h, --help     show this help message and exit
  --show_events  indicate whether events should be shown - default is false
```



