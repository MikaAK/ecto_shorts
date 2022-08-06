## Changelog

#### V2.2.1
- Use a backup error module if set to nil

#### V2.2.0
- no longer require `create_changeset`, it is now optional
- Fix dialyzer issues

#### V2.1.2
- fix typings a bit
- add lower/upper filters

#### V2.1.1
- fix update returning wrong error format

#### V2.1.0
- Make responses for Errors return as ErrorMessage

#### V2.0.0
- refactor: change find_and_update to find_and_upsert and make find_and_update not do a create
- fix: make sure we can do partial updates or create with associations

#### V1.1.5
- Add support for querying arrays and using filters around those
- Add ability to set `repo` option in `CommonChanges.preload_change_assoc` to set which repo to preload from

#### V1.1.4
- fix change to dropping associations from find instead of taking fields so other filters pass through

#### V1.1.3
- Fix relational filtering on `find_*`

#### V1.1.2
- Remove relational filtering on `find_*` functions

#### V1.1.2
- Add support for not equals filtering

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
