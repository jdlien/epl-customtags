<!-- prettier-ignore-file -->
# FilterTable.cfc

FilterTable takes a database table or view and generates an HTML table and editor. It can:

- Sort
- Filter
- Search
- Paginate
- Export CSV
- Create, edit, and delete records

FilterTable saves hours of development time by generating a high-quality CRUD interface in minutes.

## Table of Contents

- [Usage](#usage)
  - [Basic Example](#basic-example)
  - [Typical Example](#typical-example)
  - [FilterTable::new() Helper Function](#filtertablenew-helper-function)
- [Column Configuration](#column-configuration)
  - [Views](#views)
  - [Column Properties](#column-properties)
- [Options](#options)
- [Display Functions](#display-functions)
  - [Custom Display Functions](#custom-display-functions)
  - [Built-In Display Functions and Arguments](#built-in-display-functions-and-arguments)
- [Deleting Records](#deleting-records)
  - [Single Table Deletion](#single-table-deletion)
  - [Deleting from Multiple Tables Using The Same Column Name](#deleting-from-multiple-tables-using-the-same-column-name)
  - [Deleting from Multiple Tables Using Different Column Names](#deleting-from-multiple-tables-using-different-column-names)
  - [Deleting from Multiple Tables with Many-to-Many Relationships](#deleting-from-multiple-tables-with-many-to-many-relationships)
  - [deleteFromTables Options](#deletefromtables-options)
- [Working with Many-to-Many Relationships](#working-with-many-to-many-relationships)
  - [Showing Many-to-Many Relationships in Table and CSV Views](#showing-many-to-many-relationships-in-table-and-csv-views)
  - [Filtering on Many-to-Many Relationships](#filtering-on-many-to-many-relationships)
  - [Showing Related Data in the Edit View With selectFromTables](#showing-related-data-in-the-edit-view-with-selectfromtables)
  - [selectFromTables Options](#selectfromtables-options)
- [Automatic Time and User Auditing Fields](#automatic-time-and-user-auditing-fields)
- [Complete Examples](#complete-examples)
  - [Online Registration Report](#online-registration-report)
  - [Cost Savings Report](#cost-savings-report)
  - [Deleting from Multiple Nested Tables Demo](#deleting-from-multiple-nested-tables-demo)
  - [Activity Assessment Series with Many-to-Many Relationships](#activity-assessment-series-with-many-to-many-relationships)
  - [Using Options to Show Names of FK IDs](#using-options-to-show-names-of-fk-ids)
- [Troubleshooting](#troubleshooting)
  - [Invalid construct: Either argument or name is missing](#invalid-construct-either-argument-or-name-is-missing)
  - [Viewing the Columns Configuration](#viewing-the-columns-configuration)
  - ["undefined" Shows Instead of The Column Value](#undefined-shows-instead-of-the-column-value)

## Usage

To use FilterTable, create a new instance of `FilterTable` and pass in configuration arguments:

| Argument    | Description |
|-------------|-------------|
| `table`     | The name of the database table/view to use.                                                                                                                                                                                                             |
| `baseTable` | Specify the actual database table upon which a view is based. This is only required when using a database view. If not specified, it defaults to the same value as `table`.
| `appId`     | The application ID (set in https://apps.epl.ca/Web/Resources) that determines required permissions for the table. Functions that modify the database require this to be set and check certain permissions:<br>**Editing & creating:** user requires `edit` permission<br>**Deleting:** the user requires `delete` permission.
| `columns`   | An array of column names to be used in the table. Each entry can be a string representing the column name or a struct with keys that provide additional configuration. For more details, see the [Column Configuration](#column-configuration) section.
| `options`   | A struct of options that allows you to customize the default behavior of the table views. For more details, see the [Options](#options) section.


### Basic Example

To use FilterTable, you can create a new FilterTable instance specifying a table name or view, then call the `render()` method to output the HTML for the table. Here's a simple example in a typical apps page with a header using the most basic configuration:

```js
app.title = 'Registration Report'
include '/Includes/appsHeader.cfm'

new FilterTable('vsd.ILSRegistrationLog_view').render()
```

The above configuration will output a table with all columns. Deleting is not enabled by default, and editing and inserting new records will not work until the `appId` is set to a valid application ID where the user has appropriate permissions, and even then, a `baseTable` may need to be set if this is a view. (By default, FilterTable assumes that the baseTable is `table` view name without the `_view` suffix, if there is one.)

### FilterTable::new() Helper Function
To simplify creating a FilterTable instance, use the `FilterTable::new()` function, which takes the same arguments as the `FilterTable` constructor.

There are three main benefits to this over using the constructor directly:
1. It automatically sets the `appId` to the current application ID (`app.id`).
2. It automatically calls the `render` method.
3. An optional `debug` argument shows the `columns` array (and potentially other information) for debugging purposes.

Here's how to use it:

```js
FilterTable::new(
  // debug: true, // Uncomment to show debug info
  table: 'table_view',
  baseTable: 'table', // Optional
  // appId: app.id, // Optional - automatically uses app.id but can be overridden
  columns: [
    'id',
    {
      name: 'name',
      label: 'Name'
    }
  ],
  options: {} // Optional - specify options here
)
```

This `new` helper makes it simpler to use FilterTable so it's recommended to use it (`FilterTable::new()`) instead of the constructor directly (ie `new FilterTable()`).

### Typical Example

```js
app.title = 'Users'
app.id = 'UserAdmin'
include '/Includes/appsHeader.cfm'

FilterTable::new(
  table: 'vsd.AppsUsers_view',
  baseTable: 'vsd.AppsUsers', // Optional. Only required when using a view.
  appId: app.id, // Optional. Automatically assigned app.id, if defined.
  columns: [
    // Optional. Specify column structs here.
    // If columns is empty/undefined, all columns from table are displayed.
  ],
  options: {
    // Optional. Specify desired options here
  }
)
```

This configuration supports editing and creating new records for the AppsUsers table while showing additional information in a view based partly on that column. With an empty or undefined `columns` array, FilterTable shows all columns in the database, but typically an array of structs is used to specify the columns to display and any configuration options for them.

## Column Configuration

When instantiating FilterTable, a `columns` array is created within the `FilterTable` instance. By default, this contains every column in the specified `table`. For trivial applications, this may be sufficient, but you will usually want to specify the columns to show. You can specify a column as a string or a struct with a [column properties](#column-properties), including the required `name`. Both are shown below:

```js
FilterTable::new(
  table: 'vsd.TableName',
  columns: [
    'colName1', // Shorthand for { name: 'colName1' }
    {
      name: 'colName2',
      label: 'Column Name 2',
      filter: true
    }
  ]
)
```

`name` is the only required property for a column object, which is the column name in the database, but many properties can be configured for each column.

### Views

FilterTable has five views that can be configured for each column:

| View     | Description |
| -------- | ----------- |
| `filter` | The form inputs to filter data. Can have a variety of input types.
| `table`  | The table with data and a header for the column.
| `edit`   | A dialog for a record showing its data, with inputs to edit the field.
| `new`    | A dialog like the edit view allowing entry of data for a new record.
| `csv`    | A CSV file containing all data given the filter, search, and sort settings.

Each view in FilterTable has its own set of properties that can be configured. Internally, these view structs are stored in the `views` property of the column struct, although in actual applications they are usually specified as a property of the column struct itself for simplicity.

Note that by default, if any view is specified for a column, it will be shown in that view, unless it is a boolean value, which is a shorthand for setting hidden to the opposite value. For example, the `filter` view is not shown for a column by default, so to show it, you may simply set `filter: true`. This is equivalent to `filter: {hidden: false}`.

For example, the following will show a filter for `colName` and not show it in the `new` view:

```js
{
  name: 'colName',
  label: 'Column Name',
  filter: true,
  new: false
}
```

### Column Properties

If a column property is specified at the column level, it will become the default for all views. A property specified at the view level will override the column-level property for that view. For example, if a column has a `label` property set to `First Name`, but the `table` view has a `label` property set to `First`, the column will be labelled `First` in the table view, but `First Name` in all other views (`filter`, `edit`, `new`, and `csv`). This also means that a completely different column can be used in the `table` view than in the other views by specifying a different `name` property for a view, for instance, so that an id could be used for filtering but the human-friendly name of the foreign key could be displayed in the table.

Here is a list of all properties that can be configured for columns:

| Property         | Views                         | Description |
| ---------------- | ----------------------------- | ----------- |
| `name`           | all                           | The _case sensitive_ name of the column in the database.<br>**required**
| `label`          | all                           | Label to display in the view.<br>**Default:** `name`
| `hidden`         | all                           | Boolean indicating whether the column should be hidden in the view.<br>**Default:** `false` (except `filter`)
| `maxLength`      | `table`, `edit`, `new`        | The maximum length of the input allowed. If specified in the table view this will truncate the data shown to that length.<br>**Default:** 4096
| `type`           | `filter`, `edit`, `new`       | Type of input to use. Refer to AppInput documentation for a full list, including `text`, `textarea`, `select`, `checkbox`, `date`, `time`, `number`, `integer`, `radio`. <br><br>There are also special types that automatically set a list of options including `branch`, `office`, and `staff`.<br>**Default:** Based on `dataType`
| `required`       | `edit`, `new`                 | Whether the input is required before submitting changes.<br>**Default:** `!nullable`
| `fullWidth`      | `edit`, `new`                 | Whether the input uses the full width of the form.<br>**Default:** `false`
| `options`        | all                           | An array of options to use for a select or radio input type.<br>In `table` or `csv` views this is used to find the label matching the value to show a name instead of an ID.<br>Can be a list, array, or struct with `value` and `label` properties.<br>`type: 'isNull'` allows filtering on the nullness of a field. Use `value: true` for null and `value: false` for not null.
| `multiple`       | `edit`, `new`                 | Whether to allow multiple selections in a select or check input.<br>**Default:** `false`
| `sortable`       | `table`                       | Whether the column can be sorted.<br>**Default:** `true`
| `class`          | `table`                       | A CSS class to apply to table cells for the column.
| `row`            | `table`                       | Specifies which row to show the column in. You can use this to place very wide columns with long text in a separate row to avoid making the table too wide.<br>**Default:** `1`
| `colSpan`        | `table`                       | Sets the colspan of the column in the table for rows other than 1. Use this when placing multiple columns in a row to make them span multiple columns.<br>**Default:** The number of columns on row 1 (i.e., it spans the entire row)
| `displayFn`      | `table`, `edit`, `new`, `csv` | The name of a JavaScript function used when displaying column data. See [Display Functions](#display-functions) for more info.
| `displayArgs`    | `table`, `edit`, `new`, `csv` | Arguments to pass to the display function. This is a struct with argument names and values like `{len: 8}`.
| `displayJS`      | `table`, `edit`, `new`, `csv` | A string of JavaScript code to use when displaying column data. See [Custom Display Functions](#custom-display-functions) for more info.
| `defaultValue`   | `filter`, `new`               | The default value for filter on initial load or when creating a new record.
| `defaultValueFn` | `new`                         | Name of a JS function that returns the default value used when creating a new record. This can be a custom function or a built-in function that has access to limited user data.
| `defaultValueJS` | `new`                         | A string of JavaScript code that will be evaluated to determine a default value when creating a new record. See [Custom Display Functions](#custom-display-functions) for more info.
| `joinTable`      | `filter`, `new`, `edit`                 | The name of an associative table for many-to-many relationships. Must be used with `key` and `optionKey` properties.
| `joinKey`        | `filter`, `new`, `edit`                 | The key used to refer to the record to be inserted in the associative table. Used with `joinTable` and `optionKey`.<br>**Default:** `key`
| `optionKey`      | `filter`, `new`, `edit`                 | The key used to refer to the id for each option joined to the record. Used with `joinTable` and `joinKey`.

## Options

FilterTable has several options that can be passed in the `options` struct when instantiating a new FilterTable instance. These mostly configure the default behaviour and appearance of the views.

The options are:

| Property             | Type       | Description |
| -------------------- | -----------| ----------- |
| `disableCache`       | boolean    | Whether or not to cache the FilterTable instance. <br>**Default:** `true` on dev, `false` on prod.
| `rows`               | integer    | Shorthand for `rowsPerPageDefault`. <br>**Default:** 250.
| `rowsPerPageDefault` | integer    | The default number of records to show per page. <br>**Default:** 250.
| `sort`               | list       | Shorthand for setting the four `sortBy` properties.
| `sort1Default`       | string     | The default column to sort by. <br>**Default:** The first column name
| `sort1DefaultDesc`   | boolean    | Whether to sort the default column in descending order. <br>**Default:** `true`.
| `sort2Default`       | string     | Secondary default column to sort by.
| `sort2DefaultDesc`   | boolean    | Whether to sort the secondary default column in descending order. <br>**Default:** `false`.
| `datasource`         | string     | The datasource to use for reading data. <br>**Default:** `SecureSource`.
| `editDatasource`     | string     | The datasource to use for altering data. <br>**Default:** `ReadWriteSource`.
| `dbType`             | string     | The database type for queries - `mssql` or `mysql`. <br>**Default:** `mssql`. Automatically set to `mysql` for datasource `appsng`.
| `csvFileName`        | string     | Name for the exported CSV file. A timestamp will be added. <br>**Default:** value of `table`.
| `create`             | boolean    | Whether or not to allow record creation. <br>**Default:** `true`.
| `archive`            | boolean    | Whether or not to allow record archiving. <br>**Default:** `false`. Only works if the table has a `deleted_at` datetime column.
| `delete`             | boolean    | Whether or not to allow record deletion. <br>**Default:** `false`.
| `deletePrompt`       | string     | Name of the column's value to show in the delete prompt for the deleted record.
| `edit`               | boolean    | Whether or not to allow editing records. <br>**Default:** `true`.
| `editInfoCols`       | list       | List of columns' data to show in the notification toast when a record is edited. <br>**Default:** the record's primary key value.
| `deleteNoConfirm`    | boolean    | Whether to skip the confirmation prompt when deleting a record. <br>**Default:** `false`.
| `handler`            | string     | URL for the handler used for user actions <br>**Default:** `handler.cfm` in /Includes/filterTableHandlers/.
| `deleteFromTables`   | list/array | List of table names or array of structs specifying tables to delete from when a record is deleted. Default contains the main table.
| `deleteInfoCols`     | list       | List of columns to be returned in the notification toast when a record is deleted.
| `key`                | string     | The primary key for the `baseTable`, needed for create, update, and delete operations. Set automatically.
| `hiddenViewsDefault` | list       | List of views to not show columns in by default. <br>**Default:** `filter`.
| `searchCols`         | list       | List of columns to be used in a global search. Specify columns to exclude from the search prefixed with `-`, e.g., `'-field2,-badField' adds all fields except `field2` and `badField`.<br>**Default:** `all`.
| `showFilter`         | boolean    | Whether or not to show the filter fields for each column. <br>**Default:** `true`.
| `showViewEdit`       | boolean    | Whether to show the view/edit button in the table view. <br>**Default:** `true`.
| `vAlign`             | string     | Vertical alignment of table cells in tbody elements. <br>**Default:** `middle`.
## Display Functions

Often data should be displayed differently than it is stored in the database. For example, it might be useful to display a link with a url from one field in the DB and use another field in the DB as a label. This can be done using display functions.

For most purposes, you can use FilterTable's built-in display functions, which are listed below. These functions are available in the `FilterTable` instance as well as in the `FilterTable.displayFns` struct.

Some of these functions support arguments, which can be passed in via the `displayArgs` struct. For example, to display the first 8 characters of a string, you could use the `left` display function with the `len` argument:

```js
col = {
  name: 'colName',
  label: 'Column Name',
  displayFn: 'left',
  displayArgs: { len: 8 },
}
```

| Function   | Description |
| ---------- | ----------- |
| `number`   | Formats a number with commas and three decimal places (using `toLocaleString`).
| `date`     | Formats a date string in the format `YYYY-MMM-DD`.
| `year`     | Formats a date string in the format `YYYY`.
| `username` | Displays the current username (useful for `defaultFn`)
| `today`    | Displays the current date in `YYYY-MMM-DD` format (useful for `defaultFn`)
| `left`     | Displays the first `len` characters of a string.
| `link`     | Displays a link with the given `href` and `label`. Can be truncated to `len` characters.

### Custom Display Functions

You can also create your own display functions in two ways. The first is by defining them yourself and assigning them to the `window` scope in your .cfm file, then set `displayFn` in the column to the function name, and it will be called with row of the record as the first argument and the value of the column as its second argument.

The other way, particularly useful for short, simple functions, is to just write them in a string in a `displayJS` property, and it will automatically be assigned to a function and called.

For example, you could display someone's full name on the username field by creating a function like this:

```js
col = {
  name: 'user',
  label: 'Name',
  displayJS: '(r, val) => `${val} ${r.first_name} ${r.last_name}`',
}
```

### Built-In Display Functions and Arguments

To use built-in display functions, specify them with `displayFn` along with any arguments in `displayArgs`, if necessary. Note that values of `displayArgs` properties can also be JS functions. Here's an example showing how to make a link only for the table view, using a value from another column as the href attribute, with the label limited to a length of 30 characters:

```js
col = {
  name: 'name',
  label: 'URL',
  table: {
    displayFn: 'link',
    displayArgs: { len: 30, href: '(r) => `/appname/?id=${r.id}' },
  },
}
```

## Deleting Records

FilterTable enables users to delete records from one or more tables. You can achieve this by setting the `delete: true` option. This section covers to configure deleting from:

- A single table
- Multiple tables with the same column name
- Multiple tables with different column names
- Many-to-many relationships involving multiple tables

### Single Table Deletion

By default, a delete of the specified record is done with a query like this:
```SQL
DELETE FROM [<baseTable>] WHERE <key> = :recordId
```

If a database has multiple related tables with foreign key dependencies, you can use the ```deleteFromTables``` option to specify multiple tables, in order, from which to delete.

### Deleting from Multiple Tables Using The Same Column Name

The simplest way to use this is to specify a list of tables, in order. The instance's `key` value will be used in the `WHERE` clause for the delete. For example, say we have a `users` table, and another `user_settings` table stores settings for each user. Before deleting the user, we must delete each user's settings. If both tables refer to the user by `user_id`, we can use the following simple list for `deleteFromTables`.

```js
FilterTable::new(
  table: 'users_view',
  baseTable: 'users',
  options: {
    key: 'user_id',
    deleteFromTables: 'user_settings,users'
  }
)
```
This results in a query like so:
```sql
DELETE FROM [user_settings] WHERE [user_id] = :recordId
DELETE FROM [users] WHERE [user_id] = :recordId
```

### Deleting from Multiple Tables Using Different Column Names

A simple list of tables works if each table refers to the record you want gone with the same key name, but in most cases, you should also specify the name of the key to filter by in each table. This is necessary, for instance, when a database uses Laravel conventions (eg, PK of `id`, FK of `table_id`). In this case, specify deleteFromTables as an array of structs with table and key properties.

```js
FilterTable::new(
  table: 'users_view',
  baseTable: 'users',
  options: {
    key: 'id',
    deleteFromTables: [
      { table: 'user_settings', key: 'user_id' },
      { table: 'users', key: 'id' }
    ]
  }
)
```
The resulting SQL:
```sql
DELETE FROM [user_settings] WHERE [user_id] = :recordId
DELETE FROM [users] WHERE [id] = :recordId
```

### Deleting from Multiple Tables with Many-to-Many Relationships

If a set of tables uses many-to-many relationships, more complicated queries are needed to delete the record as well as the relationships from an associative table, and other records 'belonging to' the record we are deleting. In such a case, use the `refTable`, `refTableCol`, and `refTableKey` properties to help FilterTable generate queries to delete the relevant records from the tables.

Say we have a table of `users`, a table of submissions for users named `user_submissions`, and a table of actions on a submission called `user_submission_actions`. To delete a user, we must delete their submissions, and before that we must delete the submission's actions.

Here is what `user_submission_actions` might look like - it associates a submission with an action, and each submission can have multiple actions, but the user isn't directly referenced here, so we need to use the `user_submissions` table to find the submission ids for the user.

| submission_id | action   |
| ------------- | -------- |
| 1             | 'submit' |
| 1             | 'edit'   |
| 2             | 'submit' |


To solve this, we get FilterTable to create a query with a subquery to filter the records to delete:
```sql
DELETE FROM [user_submission_actions]
WHERE [submission_id] IN (SELECT [submission_id] FROM [user_submissions] WHERE [user_id] = :recordId)
```

By specifying the `refTable`, `refTableCol`, and `refTableKey` properties, FilterTable will append the `WHERE ... IN` clause to the delete query for us, like so:
```sql
DELETE FROM <table>
WHERE <key> IN (SELECT <refTableCol> FROM <refTable> WHERE <refTableKey> = :recordId)
```

Here is the configuration for the above example:

```js
FilterTable::new(
  table: 'users_view',
  baseTable: 'users',
  options: {
    // key is usually determined automatically by the baseTable's primary key
    key: 'id',
    deleteFromTables: [
      {
        table: 'user_submission_actions',
        key: 'submission_id',
        refTable: 'user_submissions',
        refTableCol: 'submission_id',
        refTableKey: 'user_id'
      },
      {
        table: 'user_submissions',
        key: 'user_id'
      },
      {
        table: 'users',
        key: 'id'
      }
    ]
  }
)
```

### deleteFromTables Options
Here are some additional notes about the options in the `deleteFromTables` array:
| Option        | Description |
| ------------- | ----------- |
| `table`       | The table to delete from.
| `key`         | The column to use in the `WHERE` clause.<br>**Default:** baseTable's `key` option. Required when using `refTable`.
| `refTable`    | The table to use in the `WHERE ... IN` clause.
| `refTableCol` | The column name to SELECT in the `WHERE ... IN` clause.<br>**Default:** `key` from this deleteFromTable element.
| `refTableKey` | The column to match to the selected record's ID in `WHERE` clause of the `refTable` subquery.<br>**Default:** baseTable's `key` option.

If `refTable` is specified, `refTableCol` and `refTableKey` must also be specified, except:
- When `refTableCol` is the same as `key`, it can be omitted.
- When `refTableKey` is the same as the main `baseTable`'s `key` (which can specified in `options`), it can be omitted.

In the above example, if `users` had a `user_id` column (instead of `id`) in the `users` table, we could use the following shorthand, and the defaults would be assumed:

```js
FilterTable::new(
  table: 'users_view',
  baseTable: 'users',
  options: {
    // key is usually determined automatically by the baseTable's primary key
    key: 'user_id', // Default refTableKey when using refTable, default key for deleteFromTables without refTable
    deleteFromTables: [
      {
        table: 'user_submission_actions',
        // key is required when using a refTable - no default is assumed
        key: 'submission_id', // Also the refTableCol by default
        refTable: 'user_submissions'
      },
      { table: 'user_submissions' },
      { table: 'users' }
    ]
  }
)
```
## Working with Many-to-Many Relationships
If a table has a many-to-many relationship with another table, you can use the `joinTable`, `optionKey`, and optionally `joinKey` properties on views to support showing, sorting, and filtering records based on the relationship with another table. Additionally, with these types of relationships you will generally use the `multiple` property to allow multiple selections in the filter, and this allows support for showing multiple labels for a list of values in a field.

Note that you'll still need to add a `name` property to the column that is **not** the name of an actual column in the database, but this will serve as a reference for the display values and filters.

### Showing Many-to-Many Relationships in Table and CSV Views
Here's an example of how you'd show a many-to-many relationship in the table or CSV views. This will show a comma-separated list of names from the join table, and allow sorting and filtering based on the join table's values. If you specify options, FilterTable will attempt to parse the list of options and show the labels instead of the raw values.

### Filtering on Many-to-Many Relationships
To filter on a many-to-many relationship, you can use the `joinTable` and `optionKey` properties to specify the table and column to join to, and the column to use as the option key. This will allow you to filter records based on the values in the join table, and the filter will show the options from the join table.

```js
FilterTable::new(
  table: 'vsd.ChangeLogDetails_view',
  baseTable: 'vsd.ChangeLog',
	columns: [
    'AppName',
    {
      // This is a generated field aggregating all names from many-to-many relationship.
      // The filter will query against the joinTable, and supports filtering on multiple options
      name: 'ownerNameList', // This isn't a real column in the database
      label: 'Owner(s)',
      type: 'select',
      multiple: true,
      joinTable: 'vsd.ChangeLogOwners',
      optionKey: 'OwnerName',
      // joinKey: 'CID', // Optional - defaults to the baseTable's key
      options: changeOwners,
      filter: true // Show the filter for this column. This will allow selection of multiple options.
    }
  ]
)
```

### Showing Related Data in the Edit View With selectFromTables
If a record has multiple related records in another database table, FilterTable can show this data in the edit view. Multiple tables can be specified in the `selectFromTables` option, and each table can have its own `key` and `refKey` properties to specify the foreign key relationship. For example, if a `users` table has a `user_id` column that is referenced by a `user_settings` table's `user_id` column, you can show the user's settings in the edit view by specifying the following within the options struct:

```js
FilterTable::new(
  table: 'users',
  options: {
    selectFromTables: [
      {
        table: 'user_settings',
        label: 'User Settings',
        key: 'id', // Automatically set to table's primary key
        refKey: 'user_id', // Automatically set to baseTable's key
        columns: ['id', 'name', 'value'] // Same format as FilterTable columns
      },
      {
        table: 'user_submissions',
        sort: 'created_at-,id',
        refKey: 'user_id',
        columns: ['id', 'created_at']
      }
    ]
  }
)
```

### selectFromTables Options
Here are some additional notes about the options in the `selectFromTables` array:
| Option        | Description |
| ------------- | ----------- |
| `table`       | The table to show data from.<br>**Required**
| `label`       | The label to show above the table.<br>**Default:** The table name.
| `key`         | The primary key for the table. Used in the generation of HTML IDs and names.<br>**Default:** The table's primary key.
| `refKey`      | The column to use in the `WHERE` clause.<br>**Default:** baseTable's `key` option.
| `sort`        | A list of columns to sort by, using the shorthand format. Add `-` for descending order.
| `columns`     | The columns to display in the data table. Uses the same options as the main FilterTable columns array, except that it only supports the `table` view.<br>**Default:** All columns in the table.


## Automatic Time and User Auditing Fields

If present in the database table, these fields will automatically be updated when a record is created, updated, or archived/soft-deleted. They will also be displayed in the detailed view (or editor) for a record if they have a value.

| Field        | Type        | Description |
| ------------ | ----------- | ----------- |
| `created_at` | datetime    | The timestamp when the record was created.
| `created_by` | varchar(30) | The username of the user who created the record.
| `updated_at` | datetime    | The timestamp when the record was last updated.
| `updated_by` | varchar(30) | The username of the user who last updated the record.
| `deleted_at` | datetime    | The timestamp when the record was archived.
| `deleted_by` | varchar(30) | The username of the user who archived the record.

When creating a new record or updating an existing one, FilterTable will attempt to set the relevant timestamps in the `created_at` or `update_at` field, and set the current `session.identity` value in the `created_by` or `updated_by` field.

So if you add these fields to a database table used by a FilterTable app, they will automatically be updated when a user edits or creates records, even if you don't add these fields into your FilterTable configuration.

Additionally, if you add a `deleted_at` field to a table, FilterTable will automatically set it to the current timestamp when a record is archived, and set it to `NULL` when a record is restored. Similarly, `deleted_by` will be set to the current user's username when a record is archived, and set to `NULL` when a record is restored.

## Complete Examples

This section contains fully working examples of FilterTable instances on apps.epl.ca that can be copied and pasted as a starting template for a new instance. Note that these all must be inside of `<cfscript>` tags.

### Online Registration Report

This is a read-only view of registration data using links to the patron records with filters on bit and date fields.

```js
FilterTable::new(
  table: 'vsd.ILSRegistrationLog_view',
  baseTable: 'vsd.ILSRegistrationLog',
  columns: [
    'RegID',
    'UserKey',
    {
      name: 'Barcode',
      filter: true,
      table: {
        displayFn: 'link',
        displayArgs: { href: '(r) => `/Web/patronInfo.cfm?id=${r.Barcode}`' }
      }
    },
    {
      name: 'RegisteredSelf',
      label: 'Self',
      edit: { label: 'Registered Self' }
    },
    {
      name: 'RegistrationDate',
      label: 'Date',
      filter: true
    },
    {
      name: 'ChildBarcode',
      label: 'Child Barcode',
      filter: true,
      table: {
        displayFn: 'link',
        displayArgs: { href: '(r) => `/Web/patronInfo.cfm?id=${r.ChildBarcode}`' }
      },
      new: false
    },
    {
      name: 'Test',
      label: 'Test',
      filter: { label: 'Show Tests', type: 'radio' },
      table: { class: 'text-center' }
    }
  ],
  options: {
    create: false
  }
)
```

### Deleting from Multiple Nested Tables Demo
This uses a test database that has nested relationships, so that in order to delete a record, you have to delete from two other tables using a subquery. This is a practical demonstration of how to use the `deleteFromTables` option.

```js
/** FilterTable demonstration of a hierarchical delete with nested foreign key relationships */
FilterTable::new(
  table: 'FilterTableTestUsers',
  options: {
    delete: true,
    // This is a complex example where we need a subquery to delete related records
    deleteFromTables: [
      {
        table: 'FilterTableTestPostActions',
        key: 'PostID',
        refTable: 'FilterTableTestPosts'
      },
      {
        table: 'FilterTableTestPosts',
        key: 'UserID'
      },
      'FilterTableTestUsers'
    ]
  }
)
```

### Cost Savings Report
This is a fairly complex example of a FilterTable that has a read-only view of two tables UNIONed together. Some of the notable things this example does are:
- Queries for a custom list of options for an input
- Custom links on 'columns' with no column name
- Uses fairly different presentation in the CSV and table views
- Disallows editing and new records

```js
scmStaff = queryExecute("
  SELECT DisplayName AS label, UserName AS value FROM vsd.AppsUsers
	WHERE location='SCM'
	ORDER BY DisplayName
")

FilterTable::new(
  table: 'vsd.PWPWorkplanCostSavings_view',
  baseTable: 'vsd.PWPWorkplan', // This also unions PWPWorkplanCS
  columns: [
    {
      name: 'Item',
      label: 'Project##'
    },
    {
      name: 'PurchContact',
      label: 'SCM Contact',
      filter: {
        type: 'select',
        options: scmStaff
      },
      table: { label: 'SCM<br>Contact' }
    },
    {
      name: 'EntryDate',
      label: 'Created',
      displayFn: 'date',
      csv: { displayFn: false }
    },
    {
      name: 'CloseDate',
      label: 'Closed',
      displayFn: 'date',
      filter: true,
      csv: { displayFn: false }
    },
    {
      name: 'Dept',
      label: 'Requesting Dept',
      table: { label: 'Dept' },
      csv: { label: 'Dept' }
    },
    {
      name: 'TargetValue',
      label: 'Estimated Amount',
      displayFn: 'dollars',
      table: { label: 'Est.<br>Amount' },
      csv: { displayFn: false }
    },
    {
      name: 'ActualValue',
      label: 'Actual Amount',
      displayFn: 'dollars',
      table: { label: 'Actual<br>Amount' },
      csv: { displayFn: false }
    },
    {
      name: 'AdditionalSavs',
      label: 'Additional Savings',
      displayFn: 'dollars',
      table: { label: 'Add''l<br>Savings' },
      csv: { label: 'Additional Savings', displayFn: false }
    },
    {
      name: 'Savings',
      displayFn: 'dollars',
      csv: { displayFn: false }
    },
    {
      name: 'CostSavingCategory',
      label: 'CostSavCat',
      table: { label: 'Cost Sav<br>Category' }
    },
    {
      name: 'ProjectActivity',
      label: 'Description'
    },
    'POs',
    {
      name: 'AdditionalInfo',
      label: 'Additional Notes',
      displayFn: 'left20'
    },
    {
      label: 'Report',
      displayFn: 'link',
      displayArgs: {
        label: 'Report',
        href: '(r) => `costSavingsDetail.cfm?id=${r.VWID}&type=${r.PWPType}`'
      },
      csv: false
    },
    {
      label: 'Edit',
      displayFn: 'link',
      displayArgs: {
        label: '(r) => r.PWPType === "C" ? "Edit" : ""',
        href: '(r) => `costSavingsDetailEdit.cfm?id=${r.VWID}&type=${r.PWPType}`'
      },
      csv: false
    },
    {
      name: 'PWPType',
      hidden: true
    }
  ],
  options: {
    key: 'VWID',
    sort: 'Item-',
    edit: false,
    create: false
  }
)
```

### Activity Assessment Series with Many-to-Many Relationships
Activity Assessments can apply to multiple branches, and each branch can have multiple Activity Assessments. This is a many-to-many relationship, and FilterTable can handle this by using an associative table.

This example uses the `joinTable` and `joinKey` on a special `branchList` column which is not a real column, but a list generated by a view. In this way, FilterTable is able to insert multiple records into the `ActivityAssessmentBranch` table when creating a new Activity Assessment, and can update or remove records from that table when editing an Activity Assessment.

```js
// This include has the heading with links for all Activity Assessment admin pages
include 'adminInclude.cfm'

types = queryExecute("SELECT AATID AS value, SeriesTypeName FROM vsd.ActivityAssessmentType")

officeCodes = queryExecute("SELECT OfficeCode FROM vsd.Offices ORDER BY OfficeCode")

// Default officeCodes for new records
defaultOffices = queryExecute("
  SELECT OfficeCode FROM vsd.Offices
  WHERE OfficeType IN ('BRANCH')
  OR OfficeCode IN ('CIP', 'DLI', 'GMR', 'MKR', 'LTV')
  ORDER BY OfficeCode
")

FilterTable::new(
  table: 'vsd.ActivityAssessmentSeries_view',
  baseTable: 'vsd.ActivityAssessmentSeries',
  columns: [
    {
      name: 'AASID',
      label: 'ID'
    },
    {
      name: 'SeriesTypeName',
      hidden: true
    },
    {
      name: 'AATID',
      label: 'Type',
      required: true,
      type: 'select',
      options: types,
      filter: true
    },
    {
      name: 'SeriesName',
      label: 'Series Name',
      class: 'nowrap',
      required: true
    },
    {
      name: 'SeriesBegin',
      label: 'Begin Date',
      class: 'nowrap',
      required: true,
      filter: true,
      table: { displayFn: 'date' }
    },
    {
      name: 'SeriesEnd',
      label: 'End Date',
      class: 'nowrap',
      required: true,
      table: { displayFn: 'date' }
    },
    {
      name: 'BranchList',
      label: 'Branches/Offices',
      required: true,
      table: {
        displayJS: '(r) => (r.BranchList ?? "").length
          ? r.BranchList.replace(/,/g, ", ").replace(/, $/, "")
          : `<span class="text-zinc-500">- no branches -</span>`
        '
      },
      edit: {
        type: 'select',
        options: officeCodes,
        // Convert query to a list of OfficeCodes
        defaultValue: valueList(defaultOffices.OfficeCode)
      },
      multiple: true,
      joinTable: 'vsd.ActivityAssessmentSeriesBranch',
      joinKey: 'AASID',
      optionKey: 'Branch',
      csv: { displayFn: false }
    }
  ],
  options: {
    delete: true,
    deleteFromTables: [
      'vsd.ActivityAssessmentSeriesBranch',
      'vsd.ActivityAssessmentSeries'
    ]
  }
)
```

### Using Options to Show Names of FK IDs
Often you have a field that is a meaningless (to humans) id value and want to show its value from a related table. There are a few solutions for this:
- Use a view with joins to add a column with the name
- Use display functions to show find the value from a JS object with an array of the values and labels. This likely requires adding a serialized version of the object to the window scope.
- Simply add an `options` struct with an array of the values and labels to the `table` or `csv` views.

Such options are also used to generate select lists for the `filter`, `edit`, and `new` views. FilterTable will accept column/view options in several formats, and convert them into an array of structs with value and label keys internally.
- An array of structs with value and label keys. This is the native format used internally.
  - e.g., `[ { value: 1, label: 'One' } ]`
- An array of structs with one key or two keys, one of which is named value or label. This will be converted to an array of structs with value and label keys.
  - e.g., `[ { value: 1, name: 'One' }, { value: 2 } ]`
- A query object with one column *or* two columns, one of which is named label or column.
  - e.g., `SELECT username FROM users`
  - or `SELECT username AS value, display_name FROM users`
- A comma-separated list. This will be converted to an array of structs with the same value and label.
  - e.g., `'One,Two,Three'`
- An array of values. This will be converted to an array of structs with the same value and label.
  e.g., `[1,2,3]`

This example uses the latter, simplest approach to show the names of branches and views instead of the ids.

```js
// This is returned as an array, nbut leaving it as a query also works
locations = queryExecute("
  SELECT CommonName AS label, LibCalId AS value FROM vsd.Offices
  WHERE LibCalId IS NOT NULL
  ORDER BY CommonName
  ", {}, { returnType: 'array' }
)

spaces = queryExecute("
  SELECT name AS label, eid AS value FROM vsd.LibCalSpaces
  ORDER BY name
")

FilterTable::new(
  table: 'vsd.LibCalBookings',
  columns: [
    {
      name: 'eid',
      label: 'Room',
      type: 'select',
      options: spaces,
      filter: true
    },
    { name: 'cid', hidden: true },
    {
      name: 'lid',
      label: 'Location',
      type: 'select',
      options: locations,
      filter: true
    },
    { name: 'fromDate', label: 'From', filter: true },
    { name: 'toDate', label: 'To' },
    { name: 'firstName', label: 'First Name' },
    { name: 'lastName', label: 'Last Name' },
    {
      name: 'status',
      label: 'Status',
      type: 'select',
      options: [
        'Booked in Outlook/Exchange',
        'Cancelled by Admin',
        'Cancelled by API',
        'Cancelled by User',
        'Confirmed',
        'Mediated Approved',
        'Mediated Approved (Payment Pending)'
      ],
      filter: true
    },
    { name: 'eventTitle', label: 'Event Title' },
    { name: 'nameOfOrganization', label: 'Name of Org' }
  ],
  options: {
    sort: 'fromDate'
  }
)
```

## Troubleshooting

In many cases, FilterTable will throw an error if something is misconfigured.

### Invalid construct: Either argument or name is missing

If you see an error like

```
Invalid construct: Either argument or name is missing.
```

This is likely because your configuration 'struct' is missing a comma between values or has a trailing comma, which ColdFusion does not allow.

One approach to edit complex FilterTable configs is to save your arguments to FilterTable in a JavaScript object inside a temporary JS file, then in VSCode, use Prettier with the following `.prettierrc.json` to ensure there are no trailing commas in your config:

```json
{
  "trailingComma": "none",
  "semi": false,
  "singleQuote": true
}
```

```js
// In a temporary JS file
FilterTable = {
  // Your FilterTable config here
}
```

This takes advantage of the fact that a CFScript function call with named parameters can use a very similar syntax to a JavaScript object.

[ChatGPT](https://chat.openai.com) is also good at spotting such issues if you are having further trouble.

### Viewing the Columns Configuration

For tricky issues where something isn't right, it might be helpful to dump the columns configuration. FilterTable takes your configuration and normalizes it into a standard format, so it may be different than what you specified. To see the normalized configuration, you can dump the `columns` property (or others) on the FilterTable instance. For example:

```js
FilterTable::new(
  debug: true,
  // Your config here
  table: 'table_name' // etc.
)
```

For advanced debugging, you can directly instantiate the `FilterTable` class assigned to a variable and dump the `columns` property or others:
```js
ft = new FilterTable(
  // Your config here
)
writeDump(ft.deleteFromTables)
writeDump(ft.columns)
// etc.
ft.render()
```

### "undefined" Shows Instead of The Column Value

If you see "undefined" in a column instead of the value you expect, this is likely because the column name is not in the `columns` configuration. FilterTable only selects columns specified in its `columns` configuration.

Column names are also **case sensitive**, so if you don't correctly capitalize the column names, they may show as "undefined" in the edit view, or in any JS functions in which you refer to the column name. If you see an issue like this, double check the table schema and the column names in your configuration and any JavaScript functions.
