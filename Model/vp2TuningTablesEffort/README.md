# VP2 Tuning Table Effort
A directory that provides utilities and data to help guide creation of VP2 tuning tables and model queries that use them

- `dumpTableGroupsYaml` - a script to dump out a yaml file showing table groups... only includes those with non-apidbtuning tables
- `tableGroups.yml` - the table groups file, which can have `comment:` fields added to the groups by humans
- `tableGroupStats.txt` - a file containing stats about the table groups
- `tables.txt` - an extract from `tableUsage.txt` that only contains table names
- `tableUsage.txt` - JB's original file showing which queries use which tables
- `tableUsageMap.json` - a file ryan made that shows a map of queries to tables found in `tables.txt`
- `uniqueTableGroups.json` - a json file containing all table groups, including those just having apidbtuning tables
