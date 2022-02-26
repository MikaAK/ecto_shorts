## Changelog

#### WIP
- Added support for passing ecto `dynamic` filters
- Added support for passing functions to use for custom filtering
- Added `EctoShorts.filter` as a shortcut to `CommonFilters.convert_params_to_filter` 
- Added a default order_by field and direction for queries
- Added `:id` to common filters
- Added the readme to generated docs, which becomes the main source of documentation, with additional docs inline specific modules and functions

#### V1.1.1
- Fix support for order_by filtering

#### V1.1.0
- Added support for querying by relation
- Remove order_by from `convert_params_to_filter` arguments and implement as a parameter

#### V1.0.0
- Multi-repo & Replica support 
- Add `find_and_update`
- Add `find_or_create_many`
- Add `stream`
- Passing nil as a param results in an error (BREAKING)
- find now returns an `Ecto.MultipleResultsError` if more than one result is being returned from the query (BREAKING)

#### V0.1.5
- Add `find_or_create` for Actions

#### V0.1.4
- Update schema
- Add better specs
- Bug fixes for update

#### V0.1.3
- Add `like` filter param
- Add more documentation

#### V0.1.2
- Add more documentation

#### V0.1.1
- Add some documentation fixes

#### V0.1.0
- Initial Release
