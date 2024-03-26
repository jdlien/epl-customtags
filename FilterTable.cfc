<cfscript>
/**
 * FilterTable renders a specified data table with sortable columns, editable fields,
 * and search inputs for specified columns.
 *
 * Refer to /FilterTable.md for full documentation.
 */

component invokeImplicitAccessor="true" {
  property name="handlersPath" type="string" default="/Includes/filterTableHandlers/handler.cfm"
    hint="Path for date, update, delete, etc. handlers.";
  property name="jsPath" type="string" default="/Includes/filterTableHandlers/filterTable.class.js"
    hint="Path for client-side JavaScript FilterTable class.";
  property name="datasource" type="string" default="SecureSource"
    hint="Defaults to SecureSource, but other datasources can be used if necessary.";
  property name="editDatasource" type="string" default="ReadWriteSource"
    hint="Datasource with permission to update and delete from the specified baseTable.";
  property name="dbType" type="string" default="mssql"
    hint="The type of database being used. Used to determine how to build queries.";
  property name="oq" type="string" default="[" hint="Opening quote for SQL queries.";
  property name="cq" type="string" default="]" hint="Closing quote for SQL queries.";
  property name="isNullString" type="string" default="{{FILTERTABLE_QUERY_IS_NULL}}"
    hint="String to use in queries for isNull filters. Defaults to {{FILTERTABLE_QUERY_IS_NULL}}.";
  property name="isNotNullString" type="string" default="{{FILTERTABLE_QUERY_IS_NOT_NULL}}"
    hint="String to use in queries for isNotNull filters. Defaults to {{FILTERTABLE_QUERY_IS_NOT_NULL}}.";
  property name="earliestYear" type="numeric" default="2008"
    hint="The earliest year to show in the year select for date filters.";
  property name="displayJSFns" type="array"
    hint="Array of JS functions to display values in the table. These are added to the page in renderFilterForm().";
  property name="schemaColumns" type="array"
    hint="Array of structs containing column metadata from the dbTable. Used to set default properties for columns.";
  property name="baseSchemaColumns" type="array"
    hint="Array of structs containing column metadata from the baseTable. Used to set default properties for edit and new views in columns.";
  property name="views" type="array"
    hint="Array of views used in filterTable: filter, table, edit, new, csv.";
  property name="columnArray" type="array" default=""
    hint="Bracketed list of columns to use in SQL queries. Init sets this to all column names specified within columns.";
  property name="rowsPerRecord" type="numeric" default="1"
    hint="Number of rows used for each record in the table. Long values can be displayed with a colspan on a different row.";
  property name="useMarkdown" type="boolean" default="false"
    hint="Whether any columns use markdown. If true, the JS for a markdown editor will be loaded.";

  // Properties set from the init() constructor
  property name="templateHash" type="string"
    hint="Name for cached instance based on hash of path for the cfm using this component.";
  property name="appId" type="string" default=""
    hint="The application id for the application using this instance. Used for permissions.";
  property name="dbTable" type="string"
    hint="Database table or view to show data from.";
  property name="columns" type="array"
    hint="Array of field objects containing settings.";
  property name="key" type="string"
    hint="Primary key to identify rows.";
  property name="disableCache" type="boolean" default="false"
    hint="Set to true to disable caching of this instance into the application scope.";
  property name="cacheTimeout" type="numeric" default="6"
    hint="Number of minutes to cache this instance in the application scope.";
  property name="cacheTime" type="numeric" default="0"
    hint="The time this instance was cached in the application scope.";
  property name="rowsPerPageDefault" type="numeric"
    hint="The default number of records per page for this instance. Set to 0 to disable pagination.";
  property name="sort1Default" type="string"
    hint="The default column to sort by.";
  property name="sort1DefaultDesc" type="boolean"
    hint="Whether to sort the default column in descending order.";
  property name="sort2Default" type="string"
    hint="The default column to secondary sort by.";
  property name="sort2DefaultDesc" type="boolean"
    hint="Whether to secondary sort the default column in descending order.";
  property name="create" type="boolean"
    hint="Whether this instance allows creating new records.";
  property name="archive" type="boolean" default="false"
    hint="Whether to allow soft-deleting and show a column of archive toggles that set datetime in deleted_at.";
  property name="delete" type="boolean"
    hint="Whether to allow deleting and show a column of delete buttons.";
  property name="deletePrompt" type="string"
    hint="Class/ID Prefix of the cell to show in the delete prompt.";
  property name="deleteNoConfirm" type="boolean"
    hint="Set to true to delete without a confirmation prompt.";
  property name="edit" type="boolean"
    hint="Whether this instance allows editing records.";
  property name="deleteFromTables" type="array"
    hint="Array of structs, each containing a dbTable and key. DELETE FROM dbTable WHERE key=id will be performed for each element.";
  property name="deleteInfoCols" type="string"
    hint="A list of columns for the deleted row, the data from which will be passed back via JSON to a toast.";
  property name="selectFromTables" type="array"
    hint="An array of tables that can be displayed from in edit views.";
  property name="editInfoCols" type="string"
    hint="A list of columns for the edited row, the data from which will be passed back via JSON to a toast.";
  property name="baseTable" type="string"
    hint="The actual table that updates/inserts are performed on. Defaults to dbTable, but this will be different when views are used.";
  property name="searchCols" type="string"
    hint="List of columns to be used in a universal search. Defaults to all columns except for types like bit.";
  property name="showFilter" type="boolean"
    hint="Whether to show the advanced filters by default and show a button to toggle them.";
  property name="showViewEdit" type="boolean"
    hint="Whether to show the view/edit button in the table view.";
  property name="hiddenViewsDefault" type="string"
    hint="List of views that are hidden by default. Defaults to filter.";
  property name="vAlign" type="string"
    hint="Vertical alignment of table cells within tbody.";
  property name="useBuffer" type="boolean" default="false"
    hint="Whether to use the buffer or directly writeOutput when writing. Can be set to false for testing.";
  property name="buffer" type="string" default=""
    hint="This buffer can be helpful for testing and debugging.";

  /** Initialize properties and normalize configuration. */
  public any function init(
    required string table, // The table or view to show data from
    string baseTable, // The table used for Create, Update, and Delete operations
    string appId = '', // Used to determine permissions for CUD operations
    array columns = [], // Column configuration for all views
    struct options = {} // Options for this instance
  ) {
    variables.views = ['filter', 'table', 'edit', 'new', 'csv']
    this.setTemplateHash()

    // Cache Handling
    // Do not cache the instance during testing
    if (getBaseTemplatePath().find('FilterTableTest.cfc') > 0) options.disableCache = true

    // If disableCache was not defined in options, default to true on dev, otherwise false
    if (!options.keyExists('disableCache')) {
      options.disableCache = cgi.HTTP_HOST.findNoCase('-dev.epl.ca') || cgi.HTTP_HOST.findNoCase('localhost') ? true : false
    }


    // If the instance for this template exists and isn't expired, return it (saves ~15ms of queries)
    var isCacheValid = options.disableCache != true &&
      application.keyExists(variables.templateHash) &&
      getTickCount() / 1000 <= application[variables.templateHash].cacheTime + (variables.cacheTimeout * 60)

    if (isCacheValid) return application[variables.templateHash]

    // Initialize the displayJSFns array
    variables.displayJSFns = []

    // Set the datasource. If it's appsng, dbType will be set to mysql
    if (options.keyExists('datasource')) variables.datasource = options.datasource
    if (options.keyExists('dbType')) variables.dbType = options.dbType
    if (options.keyExists('archive')) variables.archive = options.archive

    if (variables.datasource == 'appsng') {
      variables.dbType = options.dbType ?: 'mysql'
      variables.editDataSource = options.editDataSource ?: 'appsng'
    }

    if (variables.dbType == 'mysql') {
      variables.oq = '`'
      variables.cq = '`'
    }

    variables.dbTable = variables.checkDbTable(table)

    // Default to the baseTable being the same as dbTable (without _view at the end, if possible)
    if (!len(arguments?.baseTable)) {
      arguments.baseTable = variables.dbTable.reReplaceNoCase('(_view$)', '')
    }

    variables.baseTable = variables.checkDbTable(arguments.baseTable, 'base')

    // These must be set before setColumns() is called
    variables.hiddenViewsDefault = options.keyExists('hiddenViewsDefault') ? options.hiddenViewsDefault : 'filter'

    // The key is required before we set columns. Determine it by checking the database if not set.
    if (options.keyExists('key')) variables.key = options.key
    if (!len(variables?.key)) variables.key = variables.checkKey(variables.dbTable)
    if (!len(variables?.key)) variables.key = variables.checkKey(variables.baseTable)
    if (!len(variables?.key)) throw(
      'No primary key found. Use a "key" parameter for this table or view.',
      'FilterTableConfig'
    )

    variables.setColumns(columns)

    // Theses must be set after setColumns() is called
    variables.columnArray = generateColumnArray(variables.columns)
    // Now that we have the columns, we can set the earliest year in any column for date filters
    variables.setEarliestYear()

    variables.appId = appId

    // Default the sort column to the first column (descending)
    // If that doesn't work, try the primary key
    var sort1Default = variables.key
    if (len(variables.columns[1]?.name)) sort1Default = variables.columns[1]?.name

    // The name of the folder that the calling template is in.
    // This is unused but could be used to set the default csv filename.
    var templatePath = getBaseTemplatePath()
    var appFolder = templatePath.replace(getFileFromPath(templatePath), '').listLast('/\')

    // Set default sort order using the 'sort' shorthand, if used
    if (len(options?.sort)) variables.setDefaultSortOrder(options)
    if (isNumeric(options?.rows)) options.rowsPerPageDefault = options.rows

    // Available options and their defaults to set variables struct (cfc properties)
    defaults = {
      // Does not cache the FilterTable instance, requiring it to be reinitialized on each request.
      // This is true by default on dev, but false on production to improve performance.
      disableCache: false,
      // Default number of records to show per page. The user can change this.
      rowsPerPageDefault: 250,
      // Default column to sort by. Defaults to first column, or the key if that column isn't a db column.
      sort1Default: sort1Default,
      // Whether to sort the default column in descending order.
      sort1DefaultDesc: true,
      // Default column to sort by. Defaults to first column, or the key if that column isn't a db column.
      sort2Default: '',
      // Whether to sort the default column in descending order.
      sort2DefaultDesc: false,
      // The datasource to use for reading data from the database.
      datasource: variables.datasource,
      // The datasource to use for editing and deleting data in the database.
      editDatasource: variables.editDatasource,
      // The type of database being used. Used to determine how to build queries.
      dbType: variables.dbType,
      csvFileName: variables.dbTable & '.csv',
      // Whether this instance allows creating new records.
      create: true,
      // Whether this instance allows archiving records (soft delete).
      archive: false,
      // Whether this instance allows deleting records.
      delete: false,
      // Class/ID Prefix of the cell to show in the delete prompt.
      deletePrompt: '',
      deleteNoConfirm: false,
      // A list of tables to delete from when a record is deleted. An array of structs with the 'table' and 'key'
      // which can specify a list of tables to delete from, in order, when foreign keys must be deleted first.
      // For advanced uses, refTable, refTableCol, and refTableKey can be specified in an element to delete
      // from a table based on a subquery (eg: DELETE FROM table WHERE key IN (SELECT refTableCol FROM refTable WHERE refTableKey = 'value')).
      deleteFromTables: [{ table: variables.baseTable, key: variables.key }],
      // A list of columns to be returned in the notification toast when a record is deleted.
      deleteInfoCols: '',
      // An optional array of tables that can be displayed from in edit views
      selectFromTables: [],
      // The primary key for the baseTable. Usually this is set automatically if the baseTable isn't specified. This is mostly relevant for update, delete, and insert operations.
      key: variables.key,
      // Whether this instance allows editing records.
      edit: true,
      // A list of columns to be returned in the notification toast when a record is edited.
      editInfoCols: '',
      // A list of columns to be used in a global search. Defaults to all columns but won't use types like bit.
      searchCols: 'all',
      // Whether to hide the advanced filters by default and show a button to toggle them.
      showFilter: true,
      // Whether to show the view/edit button in the table view.
      showViewEdit: true,
      // Views not to show by default. Defaults to filter (set above before calling setColumns, here for completeness)
      hiddenViewsDefault: variables.hiddenViewsDefault,
      // Vertical alignment of table cells within tbody. Defaults to middle.
      vAlign: 'middle'
    }

    // Set properties (in variables) from the default options, overwriting defaults with options
    for (var opt in defaults) variables[opt] = options.keyExists(opt) ? options[opt] : defaults[opt]

    // Normalizes configuration of deleteFromTables to ensure it is an array of structs
    variables.setDeleteFromTables(variables?.deleteFromTables)

    // Normalizes configuration of selectFromTables to ensure it is an array of structs
    variables.setSelectFromTables(variables?.selectFromTables)

    variables.setSearchCols(variables.searchCols)

    // Save this instance to the application scope (it is still needed for endpoints, even if caching is disabled)
    application[variables.templateHash] = this
    variables.cacheTime = getTickCount() / 1000 // set cacheTime in seconds of stored instance

    return this
  } // end init()

  /** Shortcut for a FilterTable instance that automatically passes in app.id and renders */
  static void function new(
    required string table, // The table or view to show data from
    string baseTable,      // The table used for Create, Update, and Delete operations
    array columns = [],    // Column configuration for all views
    struct options = {},   // Options for this instance
    string appId,          // pass in app.id if it exists
    boolean debug = false  // If true, will output debug info
  ) {
    // Allows '' to override app.id if we want no permission to apply to this instance
    if (!arguments.keyExists('appId')) appId = app.id ?: ''

    var ft = new FilterTable(
      table: table,
      baseTable: baseTable ?: '',
      appId: appId,
      columns: columns,
      options: options
    )

    if (debug) {
      // Dump any useful debug info here
      writeDump(ft.columns)
    }

    ft.render()
  } // end new()

  /**
   * Reset application and/or session scope for FilterTable.
   * This can be useful when working on FilterTable when strange bugs occur due to cached instances.
   *
   * Pass in the application and session scopes to reset FilterTable instances in those scopes.
   */
  static void function reset(struct application, struct session) {
    if (!arguments.keyExists('application') && !arguments.keyExists('session')) {
      throw('You must pass in application and/or session scopes to reset FilterTable instances.
      E.g., FilterTable::reset(application, session);', 'FilterTableConfig')
    }

    if (arguments.keyExists('application')) {
      arguments.application.keyArray()
        .filter((key) => key.startsWith('filtertable_'))
        .each((ft) => application.delete(ft));
    }

    if (arguments.keyExists('session')) {
      arguments.session.keyArray()
        .filter((key) => key.startsWith('filtertable_'))
        .each((ft) => session.delete(ft));
    }
  } // end filterTableReset()

  public numeric function getCacheTime() {
    return variables.cacheTime
  }

  /**
   * Returns an HTML element containing the specified error message displayed in red.
   * Used for non-catastrophic errors that don't cause suffcient failure to warrant a throw.
   */
  private string function error(string message = '') {
    return '<p class="error text-red-600 dark:text-red-500">#message#</p>'
  }

  /**
   * Sets the template hash property used for application/session variables.
   * Can be overridden for testing purposes, but defaults to the hash of the template path.
   * TODO: Extract the templatePath functions to a utility cfc shared with FilterTableSettings.
   */
  public void function setTemplateHash(string templatePath = '') {
    variables.templateHash = len(templatePath) ? templatePath : 'filterTable_' & hash(getBaseTemplatePath())
  }

  public string function getTemplateHash() { return variables.templateHash }

  private void function setDefaultSortOrder(required struct options) {
    if (!len(options?.sort)) return; // No sort was provided
    var sortColumns = options.sort.listToArray()

    var processColumn = (column, index) => {
      var desc = column.endsWith('-')
      options['sort#index#Default'] = desc ? column.left(column.len() - 1) : column
      options['sort#index#DefaultDesc'] = desc
    }

    processColumn(sortColumns[1], 1)

    if (sortColumns.len() >= 2) processColumn(sortColumns[2], 2)
  }

  /** Gets the table name without schema and determines if it is valid in the database */
  public string function checkDbTable(required string dbTable, string type = 'any') {
    if (dbTable == '') throw('dbTable is required.', 'FilterTableConfig')

    // For some of the introspection queries, we cannot have the schema on the table name.
    // The default is 'vsd' so we can remove it if it's there.
    var schemaName = listFirst(arguments.dbTable, '.')
    if (schemaName != 'sys') schemaName = 'vsd'
    var dbTableNoSchema = reReplaceNoCase(arguments.dbTable, '^(vsd\.|sys\.)', '')
    var sql = ''

    if (schemaName == 'sys') {
      // Check system tables.
      sql = "SELECT name AS OBJECT_NAME, type_desc AS TYPE FROM sys.all_objects WHERE name = :tableName"
    } else {
      // Check user tables.
      sql = "SELECT TABLE_NAME, 'table' AS TYPE FROM INFORMATION_SCHEMA.#(dbType == 'mysql' ? 'TABLES' : 'tables')#
             WHERE #(dbType == 'mysql' ? 'TABLE_SCHEMA = DATABASE() AND ' : '')# TABLE_NAME = :tableName "

      if (type == 'any') sql &= " UNION
        SELECT TABLE_NAME, 'view' AS TYPE FROM INFORMATION_SCHEMA.views v
        WHERE TABLE_NAME = :tableName "
    }

    // Check that the DB Table exists
    var checkTable = queryExecute(
      sql,
      {
        tableName: { value: dbTableNoSchema, cfsqltype: 'CF_SQL_VARCHAR' },
        schemaName: { value: schemaName, cfsqltype: 'CF_SQL_VARCHAR' }
      },
      { datasource: variables.datasource }
    )

    if (type != 'any' && !checkTable.recordCount) {
      throw('No base DB table found with name #dbTableNoSchema#. This is required for updating and inserting records.', 'FilterTableConfig')
    } else {
      if (!checkTable.recordCount) throw( 'No DB table or view found with name #dbTableNoSchema#', 'FilterTableConfig')
    }

    return dbTableNoSchema
  }

  public string function getDbTable() { return variables.dbTable }

  /** Returns the primary key for the specified database table */
  private string function checkKey(required string dbTable) {
    var sql = ''

    if (variables.dbType == 'mysql') sql = "
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :dbTable AND CONSTRAINT_NAME = 'PRIMARY'
    "
    else sql = "sp_pkeys :dbTable;"

    // Attempt to look up the primary key
    var pkey = queryExecute(
      sql,
      { dbTable: { value: dbTable, cfsqltype: 'CF_SQL_VARCHAR' } },
      { datasource: variables.datasource }
    )

    return len(pkey?.COLUMN_NAME) ? pkey.COLUMN_NAME : ''
  } // end checkKey()

  public string function getKey() { return variables.key }

  public string function getAppId() { return variables.appId }

  public boolean function getArchive() { return variables.archive }

  public boolean function getDelete() { return variables.delete }

  public string function getDataSource() { return variables.dataSource }

  public string function getEditDataSource() { return variables.editDataSource }

  public string function getDeleteInfoCols() { return variables.deleteInfoCols }

  /**
   * Defaults to deleting from the dbTable using the key.
   * If deleteFromTables is set, we ensure that it is an array of structs containing
   * the table name, and the column name that refers to the primary key of the main table.
   *
   * This allows us to specify a list like 'table1,table2' to delete from without having to specify
   * the primary key column for each table.
   *
   * We also allow the deleteFromTables to be an array of structs with the keys 'dbTable' and 'pk'.
   */
  public void function setDeleteFromTables(any arg) {
    var deleteFromTables = []

    var deleteFromTablesErrMsg = "
      deleteFromTables must be a list of table names, an array of structs, or an array of strings.
      If it is an array of structs, each struct must contain a 'table' key with the table name,
      and optionally a 'key' with the primary key column name.

      For more advanced uses, a refTable, refTableCol, and refTableKey can be specified to delete from a table based on a subquery.
      eg: DELETE FROM table WHERE key IN (SELECT refTableCol FROM refTable WHERE refTableKey = 'value').

      Refer to FilterTable.md for more information."

    if (!isDefined('arg') || !arguments?.arg.len()) {
      variables.deleteFromTables = [
        { table: variables.dbTable, key: variables.key }
      ]
      return
    }

    // Allow for a list of tables, convert to the array of structs format
    if (isSimpleValue(arg)) arg = arg.listToArray()

    if (isArray(arg)) {
      for (el in arg) {
        if (isSimpleValue(el)) deleteFromTables.append({ table: el, key: variables.key })
        else if (isStruct(el) && el.keyExists('table')) {
          if (el.keyExists('refTable')) {
            // Sanity check to ensure that the configuration isn't doing something risky.
            // Provides comprehensive error messages to help the developer fix the issue.
            if (!el.keyExists('key')) {
              throw (
                "If refTable is set in a deleteFromTables struct, a 'key' property must be set for #el.table# to specify the items to delete.
                This will be combined with a subquery to construct a query like:
                DELETE FROM #el.table# WHERE key IN (SELECT refTableCol FROM #el.refTable# WHERE #el.refTable#.refTableKey = 'value').
                Refer to https://apps.epl.ca/web/design for documentation.",
                'FilterTableConfig'
              )
            }
            if (!el.keyExists('refTableCol')) el.refTableCol = el.key
            if (!el.keyExists('refTableKey')) el.refTableKey = variables.key
          }

          if (!el.keyExists('key')) el.key = variables.key

          deleteFromTables.append(el)
        } else throw(deleteFromTablesErrMsg, 'FilterTableConfig')
      }

      // Loop through deleteFromTables and remove any 'vsd' prefix from the table name
      for (el in deleteFromTables) {
        el.table = el.table.reReplaceNoCase('^(vsd\.)+', '')
        if (el.keyExists('refTable')) el.refTable = el.refTable.reReplaceNoCase('^(vsd\.)+', '')
      }

      variables.deleteFromTables = deleteFromTables
      return
    }

    throw(deleteFromTablesErrMsg, 'FilterTableConfig')
  } // end setDeleteFromTables()

  public array function getDeleteFromTables() { return variables.deleteFromTables }

  /** Accepts the user-specified list of searchCols and sets it to the actual list of columns to use. */
  public void function setSearchCols(string searchCols = '') {
    var searchAll = searchCols == 'all'
    var positives = [] // The terms we want
    var negatives = [] // The terms we exclude

    searchCols.listToArray().each((col) => {
      if (left(col, 1) == '-') negatives.append(mid(col, 2, len(col)))
      else positives.append(col)
    })

    // If searchCols is only negatives or positives contains all, searchAll
    searchAll = (positives.isEmpty() && negatives.len()) || positives.containsNoCase('all')

    if (searchAll) {
      // Check the columns to ensure that they exist in the table
      variables.searchCols = variables.columns
        .filter(col => col.keyExists('name') && columnExists(col.name) && !negatives.containsNoCase(col.name))
        .map(col => col.name)
        .toList()
    } else variables.searchCols = positives.toList()
  } // setSearchCols()

  /** Sets the earliest year to be used in date filters. Executed within setColumns. */
  private void function setEarliestYear(numeric year) {
    // If a year was provided, just use that
    if (arguments.keyExists('year')) {
      variables.earliestYear = arguments.year
      return;
    }

    // Query for earliest year in a provided date or datetime field in the table
    var sql = "SELECT MIN(MinYear) AS MinYear FROM ("
    var counter = 0

    for (var col in variables.columns) {
      if ('date,datetime'.listFind(col?.dataType) && len(col?.name)) {
        if (counter++) sql &= " UNION "
        sql &= "SELECT MIN(YEAR(#oq##col.name##cq#)) AS MinYear FROM #dbTable# "
      }
    }

    sql &= counter ? " UNION " : ''
    sql &= variables.dbType == 'mysql'
      ? " SELECT YEAR(NOW()) AS MinYear) AS MinYears"
      : " SELECT YEAR(GETDATE()) AS MinYear) AS MinYears"

    variables.earliestYear = queryExecute(sql, {}, { datasource: variables.datasource }).MinYear
  }

  /** Gets an array of column metadata from the specified dbTable. */
  private array function getSchemaColumns(string dbTable = variables.dbTable) {
    var columnInfo = queryExecute("
      SELECT
        COLUMN_NAME,
        #dbType == 'mysql' ? 'COLUMN_TYPE,' : ''#
        CAST(DATA_TYPE AS #dbType == 'mysql' ? 'CHAR' : 'VARCHAR'#) AS DATA_TYPE,
        CHARACTER_MAXIMUM_LENGTH,
        IS_NULLABLE
      FROM information_schema.Columns
      WHERE LOWER(Table_Name) = LOWER(:dbTable)
      ",
      { dbTable: { value: dbTable, cfsqltype: 'CF_SQL_VARCHAR' } },
      { datasource: variables.datasource, returnType: 'array' }
    )

    // If any COLUMN_TYPE values are tinyint(1), just set DATA_TYPE to BIT
    for (col in columnInfo) {
      if (col?.COLUMN_TYPE == 'tinyint(1)') col.DATA_TYPE = 'bit'
    }

    return columnInfo;
  } // end getSchemaColumns()


  /** Correctly sets the properties of the passed column struct to consistent values */
  private struct function normalizeColumn(
    any originalColumn,
    array schemaColumns = variables.schemaColumns,
    any views = variables.views
  ) {
    var column = isSimpleValue(originalColumn) ? { name: originalColumn } : duplicate(originalColumn)
    if (!isStruct(column)) throw('Column must be a struct or a string.', 'FilterTableConfig')
    if (isSimpleValue(views)) views = views.listToArray()

    // Handle special filterTypes/editTypes where we provide the options.
    var typeMap = {
      branch: {options: application.branches ?: []},
      branches: {options: application.branches ?: []},
      office: {options: application.offices ?: []},
      offices: {options: application.offices ?: []},
      staff: {options: application.staff ?: []}
    }

    // Default properties for in case the column isn't in INFORMATION_SCHEMA
    var defaultProps = { DATA_TYPE: 'VARCHAR', CHARACTER_MAXIMUM_LENGTH: 4096, IS_NULLABLE: true }

    /** Gets properties from DB metadata or uses defaults */
    private struct function columnProps(required string columnName, array schemaColumns = schemaColumns) {
      return schemaColumns[schemaColumns.find(c => c.COLUMN_NAME == columnName)] ?: defaultProps
    }

    var colInfo = columnProps(column.name ?: '')

    private void function setDefault(string key, any value) {
      // For maxLength, we only set it is there's a CHARACTER_MAXIMUM_LENGTH property
      if (key == 'maxLength' && !colInfo.keyExists('CHARACTER_MAXIMUM_LENGTH')) return;

      if (!column.keyExists(key)) column.insert(key, value)
    }

    /** Sets a shorthand property for views if they haven't been set already. Defaults to all views */
    private void function setViewProperty(required string property, string viewList = '') {
      if (!column.keyExists(property)) return;

      var viewArr = len(viewList) ? viewList.listToArray() : views

      for (var view in viewArr) {
        if (!column.views.keyExists(view)) continue;
        // Set the property for the view if it hasn't been set
        if (!column.views[view].keyExists(property)) column.views[view].insert(property, column[property])
      }

      // Discard the shorthand property (except for certain fields) so that it cannot be used
      if (property != 'name') column.delete(property)
    }

    /** Ensure options are arrays of structs with value and label keys */
    private void function normalizeOptions(required string viewName) {
      var view = column.views[viewName]

      if (view.keyExists('options')) {
        // Convert query to array
        if (isQuery(view.options)) view['options'] = Util::toValueLabelArray(view.options)

        // Convert list to simple array
        if (isSimpleValue(view.options)) view['options'] = listToArray(view.options)

        // Convert any simple keys in the array to structs
        var optionsArray = []

        for (var opt in view.options) {
          if (isSimpleValue(opt)) optionsArray.append({ 'value': opt, 'label': opt })
          else {
            // If I end up with more types, convert this to a switch
            if (opt.keyExists('type') && opt.type == 'isNull') {
              opt.value = (opt?.value == false)
                ? variables.isNotNullString
                : variables.isNullString
            }

            // If there's no label, just set the label to be the value ( array notation to preserve case)
            if (opt.keyExists('value') && !opt.keyExists('label')) opt['label'] = opt.value

            // Add the option to the array with lowercase keys
            optionsArray.append(Util::lCaseKeys(opt))
          }
        }

        view['options'] = optionsArray
      }
    }

    /** Normalize the editType based on the dataType of the column */
    private string function getEditType(required string dataType) {
      switch (dataType) {
        case 'int': return 'integer'
        case 'datetime': return 'datetime'
        case 'date': return 'date'
        case 'time': return 'time'
        case 'float': case 'decimal': return 'number'
        case 'bit': return 'radio'
      }

      return 'text'
    }

    /**
     * Convert a string containing a JavaScript function to a function name in window scope
     * and add it to the displayJSFns array. Returns the function name.
     */
    private string function jsCodeToFnName(required string jsCode, string suffix) {
      var fnName = (column.keyExists('name') ? column.name : Util::randStringLowerAlpha())
      if (len(arguments?.suffix)) fnName &= '_' & suffix
      if (arguments?.suffix != 'default') fnName &= '_display'

      // If the JS code isn't a function, make it one with an r parameter
      var functionRE = '^\s*(?:function\s*[\w$]+\s*\([^)]*\)|\([^)]*\)\s*=>|\w+\s*=>)'
      if (!reFindNoCase(functionRE, jsCode)) jsCode = '(r) => ' & jsCode

      variables.displayJSFns.append('window.#fnName# = #jsCode#')

      return fnName
    }

    // Ensure views struct is defined
    setDefault('views', {})

    // 'hidden' is a boolean that will hide the column in all views
    setDefault('hidden', false)

    // Ensure every view exists and has a hidden property. View name properties can be boolean to show/hide the view.
    for (view in views) {
      // If a view is defined at the root of the column, move it to the views struct
      if (column.keyExists(view) && !column.views.keyExists(view)) {
        column.views[view] = column[view]
        column.delete(view)
      }

      // If a view exists, we can determine whether it is hidden or not
      if (column.views.keyExists(view)) {
        // If the view is a boolean, convert it to a struct with a hidden property that matches the boolean
        if (isSimpleValue(column.views[view])) column.views[view] = { 'hidden': column.views[view] == false }
        // else we presume the existence of the view to mean that we want to show it unless otherwise specified
        else if (!column.views[view].keyExists('hidden')) column.views[view]['hidden'] = column.hidden
      } else {
        // Ensure view exists with column.hidden as the default for the view, unless it's in the hiddenViewsDefault list
        column.views[view] = { 'hidden': variables.hiddenViewsDefault.listFindNoCase(view) ? true : column.hidden }
      }
    }

    // The hidden shorthand property can now be removed as every view has a hidden property
    column.delete('hidden')

    // Set defaults
    setDefault('label', column.name ?: '')
    setDefault('dataType', colInfo.DATA_TYPE)
    setDefault('nullable', !!colInfo.IS_NULLABLE)
    // sortable is now referenced from views.table.sortable
    setDefault('sortable', true)

    // Set all view properties with the shorthand properties if they haven't already been set
    setViewProperty('name')
    // Set on all properties except new so that new adopts edit's value as default
    setViewProperty('label', 'filter,table,edit,csv')
    // Convert any JS code to a function name and add it to the displayJSFns array
    if (len(column?.displayJS)) {
      column.displayFn = jsCodeToFnName(column.displayJS)
      column.delete('displayJS')
    }
    setViewProperty('displayFn')
    setViewProperty('displayArgs')
    setViewProperty('type')
    // Allow for multi-select in editors
    setViewProperty('multiple', 'filter,table,edit,csv')
    setViewProperty('class', 'table')
    // Allow specifying what row a cell will be rendered in if a table uses multiple rows
    setViewProperty('row', 'table')
    setViewProperty('colSpan', 'table')
    // TODO: Perhaps I can create references to options structs so the data isn't duplicated for each view in the JS.
    setViewProperty('options')
    setViewProperty('maxLength')
    // Note: defaultValue-related properties are only added to the 'new' view
    setViewProperty('defaultValue', 'filter,new')
    setViewProperty('defaultValueJS', 'new')
    setViewProperty('defaultValueFn', 'new')
    setViewProperty('sortable', 'table')
    setViewProperty('required', 'edit,new')
    setViewProperty('fullWidth', 'edit,new')
    // Associative table for many-to-many relationships
    setViewProperty('joinTable')
    // Key for this record in the associative table
    setViewProperty('joinKey')
    // Key for the related option record in the associative table
    setViewProperty('optionKey')

    // Shorthand properties should now be assigned to all views - process options within views.
    for (var viewName in views) {
      var view = column.views[viewName]

      // If the view has a column name, set column properties (each view could refer to a different column)
      if (view.keyExists('name')) {
        // For edit and new views, use the baseTable rather than the specified view
        var viewColInfo = columnProps(
          view.name,
          'edit,new'.listFind(viewName) ? variables.baseSchemaColumns : schemaColumns
        )
        view['dataType'] = viewColInfo.DATA_TYPE
        view['nullable'] = !!viewColInfo.IS_NULLABLE
        // maxLength could be overridden, for instance, to truncate values for table cells
        // Note: I'm setting a maxLength for all fields, but this isn't relevant to all data types
        if (!view.keyExists('maxLength')) {
          view['maxLength'] = viewColInfo.CHARACTER_MAXIMUM_LENGTH ?: 4096
          // Handle VARCHAR(MAX) which returns -1 for the length. We'll use 10,000 characters as the max.
          if (view.maxLength == -1) view['maxLength'] = 10000
        }
      }

      // If the view has a joinTable, ensure it has a valid joinKey and optionKey
      if (view.keyExists('joinTable')) {
        // Remove the vsd. prefix
        view.joinTable = view.joinTable.reReplaceNoCase('^vsd\.', '')

        // Ensure joinKey and optionKey are set. joinKey defaults to the key of the base table.
        if (!view.keyExists('joinKey')) view.joinKey = variables.key
        if (!view.keyExists('optionKey')) throw('optionKey is missing but required for joinTable #view.joinTable# on column #view.name ?: view.label ?: ''#.', 'FilterTableConfig')

        // Get the column properties for all the columns of the join table to ensure the configuration is valid
        var joinSchema = getSchemaColumns(view.joinTable)
        if (joinSchema.len() < 2) throw('joinTable #view.joinTable# does not exist or does not have at least two columns.', 'FilterTableConfig')

        // Ensure the joinKey and optionKey are valid columns
        var joinKeyColIdx = joinSchema.find(c => c.COLUMN_NAME == view.joinKey)
        var optionKeyColIdx = joinSchema.find(c => c.COLUMN_NAME == view.optionKey)
        if (!joinKeyColIdx) throw('joinKey #view.joinKey# does not exist in joinTable #view.joinTable#.', 'FilterTableConfig')
        if (!optionKeyColIdx) throw('optionKey #view.optionKey# does not exist in joinTable #view.joinTable#.', 'FilterTableConfig')
        // Get the datatype and length for each column. I presume neither are nullable so I don't need that.
        joinKeyCol = joinSchema[joinKeyColIdx]
        view.joinKeyDataType = joinKeyCol.DATA_TYPE
        view.joinKeyMaxLength = joinKeyCol.CHARACTER_MAXIMUM_LENGTH ?: 4096

        optionKeyCol = joinSchema[optionKeyColIdx]
        view.optionKeyDataType = optionKeyCol.DATA_TYPE
        view.optionKeyMaxLength = optionKeyCol.CHARACTER_MAXIMUM_LENGTH ?: 4096
      }

      // Set defaults for filter and edit
      // Any values assigned to 'edit' here will be used in 'new' when not configured in 'new'
      if ('filter,edit,new'.listFindNoCase(viewName)) {
        // Ensure that default radio options exist for boolean columns
        if (view?.dataType == 'bit') {
          if (!view.keyExists('type')) view['type'] = 'radio'
          if (!view.keyExists('options')) {
            view['options'] = [{ value: 1, label: 'Yes' }, { value: 0, label: 'No' }]
            // If we know the column is nullable, add a null option
            if (viewName == 'filter' && view.nullable) view.options.append({ label: 'null', type: 'isNull' })
          }
        }

        // Handle special types where we provide the data, specified in typeMap
        if (view.keyExists('type') && typeMap.keyExists(view.type)) {
          view['options'] = typeMap[view.type].options
          view['type'] = 'select'
        }
      } // filter,edit,new

      if ('filter'.listFindNoCase(viewName)) {
        // Filters are exempt from the rule to set the type to 'display' if a display function is used
        if (!view.keyExists('type') && view.keyExists('dataType')) view['type'] = getEditType(view.dataType)
      }

      if ('table'.listFindNoCase(viewName)) {
        // If the table view has an integer 'row' value, ensure the variables.rows value is at least that
        if (view.keyExists('row') && isNumeric(view.row)) {
          if (view.row > variables.rowsPerRecord) variables.rowsPerRecord = view.row
        } else view['row'] = 1 // Default to row 1 if not specified
      }

      // Properties that only apply to edit and new views
      if ('edit,new'.listFindNoCase(viewName)) {
        if (!view.keyExists('required')) view['required'] = view.keyExists('nullable') ? !view.nullable : false

        // This has to be in if edit,new because we want to simply use a string (I think) for the filter view
        if (view.keyExists('defaultValue') && !view.keyExists('defaultValueJS') && !view.keyExists('defaultValueFn')) {
          view.defaultValueJS = '() => `#view.defaultValue#`'
          view.delete('defaultValue')
        }

        // If a view uses a display function, default its type to 'display'
        if (!view.keyExists('type') && view.keyExists('dataType')) {
          // If this function uses a displayFn, we default to 'display' for the type
          if (view.keyExists('displayFn') || view.keyExists('displayJS')) view['type'] = 'display'
          else view['type'] = getEditType(view.dataType)
        }

        // If a view has a type of 'markdown', ensure that variables.useMarkdown is set to true
        if (view?.type == 'markdown') variables.useMarkdown = true
      } // edit,new

      // Ensure options are arrays of structs with value and label keys.
      // This must come after setting default bit options.
      if (view.keyExists('options')) normalizeOptions(viewName)

      // Handle display JavaScript function related properties
      if (view.keyExists('defaultValueJS')) {
        view.defaultValueFn = jsCodeToFnName(view.defaultValueJS, 'default')
        view.delete('defaultValueJS')
      }

      // If the view has a displayJS property, convert it to a function name and add it to the displayJSFns array
      if (view.keyExists('displayJS')) {
        view.displayFn = jsCodeToFnName(view.displayJS, viewName)
        view.delete('displayJS')
      }
    } // end for (viewName in views)

    // Ensure properties set in edit are also set in new using the edit view settings as defaults
    if (column.views.keyExists('edit')) for (var prop in column.views.edit) {
      if (!column.views.new.keyExists(prop)) column.views.new[prop] = column.views.edit[prop]
    }

    return column
  } // end normalizeColumn()

  /** Sets the columns property, normalizes values and adds defaults if necessary */
  private void function setColumns(array columns = []) {
    // schemaColumns and baseSchemaColumns must be defined before normalizeColumns() is called
    variables.schemaColumns = variables.getSchemaColumns(variables.dbTable)
    variables.baseSchemaColumns = variables.getSchemaColumns(variables.baseTable)

    // If no columns were defined, add all columns from the database table/view
    if (!columns.len()) columns = variables.schemaColumns.map(col => col.COLUMN_NAME)

    // If the primary key isn't in the columns array, add it as a hidden column
    if (!columns.find(col => isStruct(col) ? col?.name == variables.key : col == variables.key)) {
      columns.append({ name: variables.key, hidden: true })
    }

    // If deleted_at is in schemaColumns but isn't in the columns array, add it
    if (variables.archive && !columns.find(col => isStruct(col) ? col?.name == 'deleted_at' : col == 'deleted_at')) {
      columns.append({
        name: 'deleted_at',
        label: 'Archived',
        filter: {
          label: 'Show Archived',
          type: 'radio',
          defaultValue: variables.isNullString,
          options: [
            { value: true, label: 'Active', type: 'isNull' },
            { value: false, label: 'Archived', type: 'isNull' }
          ]
        },
        table: {
          label: 'Arch',
          class: 'text-center',
          displayFn: 'archiveBtn'
        }
      })
    }

    // Assign to variables scope, ensuring all properties are set correctly
    variables.columns = columns.map(col => normalizeColumn(col, variables.schemaColumns))
  } // end setColumns()

  /** Handy for troubleshooting or perhaps initializing frontend tooling */
  public array function getColumns() { return variables.columns }

  /** Normalizes the configuration of selectFromTables used inside edit views */
  private void function setSelectFromTables(array selectFromTables = []) {
    if (!selectFromTables.len()) {
      variables.selectFromTables = []
      return
    }

    for (sft in selectFromTables) {
      if (!len(sft?.table)) throw('selectFromTables must be an array of structs with a table key.', 'FilterTableConfig')

      sft.table = variables.checkDbTable(sft.table)

      if (!len(sft?.label)) sft.label = sft.table
      if (!len(sft?.refKey)) sft.refKey = variables.key

      // Automatically determine the primary key if not set
      if (!len(sft?.key)) sft.key = variables.checkKey(sft.table)
      if (!len(sft?.key)) throw(
        'No primary key found for #sft.table#. Use a "key" parameter for this table or view in selectFromTables.',
        'FilterTableConfig'
      )

      var schema = variables.getSchemaColumns(sft.table)

      // If no columns were defined, add all columns from the database table/view
      if (!sft.keyExists('columns') || !sft.columns.len()) sft.columns = schema.map(col => col.COLUMN_NAME)

      // Make a normalized array using only the 'table' view
      sft.columns = sft.columns.map(col => variables.normalizeColumn(col, schema, 'table'))
    }

    // Assign to variables scope, ensuring all properties are set correctly
    variables.selectFromTables = selectFromTables
  } // end setSelectFromTables()

  /**
   * Returns true if the specified column name really is in the database table.
   */
  private boolean function columnExists(string columnName, schemaColumns = variables.schemaColumns) {
    return schemaColumns.find(c => c.COLUMN_NAME == columnName);
  }

  /**
   * Generates a list of columns for SELECT in SQL queries. Sometimes we look up values in display
   * functions that not the columns array, so add them like: { column: 'name', hidden: true }
   */
  private array function generateColumnArray(array columns = variables.columns) {
    var columnArray = []

    columns.each(col => {
      var columnExists = col.keyExists('name') ? variables.columnExists(col?.name) : false
      // TODO: Check if the name actually exists in the database table
      if (columnExists) columnArray.append('#oq##col.name##cq#')
      // Add any columns that used in views but not in the columns array
      for (var view in variables.views) {
        var colView = col.views[view]
        if (colView.keyExists('name') && colView.name != col?.name && !colView.keyExists('joinTable')) {
          columnArray.append('#oq##colView.name##cq#')
        }

        // Support for many-to-many relationships
        if (colView.keyExists('joinTable')) {
          // Assuming 'id' as a default join key, adjust as needed
          var alias = colView.keyExists('name') ? colView.name : colView.label.replace(' ', '_') ?: 'column'
          // Note the comma in SELECT ', ' - this may cause issues with the list functions in ColdFusion
          var aggregateExpression = "STUFF((
              SELECT ', ' + CAST(#colView.joinTable#.#colView.optionKey# AS NVARCHAR(MAX))
              FROM #colView.joinTable#
              WHERE #colView.joinTable#.#colView.joinKey# = #variables.dbTable#.#colView.joinKey# FOR XML PATH('')
            ), 1, 1, '') AS [#alias#]";

          columnArray.append(aggregateExpression)
        }
      }
    })

    // Remove duplicates from columnArray
    return columnArray.reduce(
      (arr, value) => arr.find(value) ? arr : arr.append(value), []
    )
  } // end getColumnList()

  /**
   * Checks session for a FilterTableSettings object for this instance.
   * If none, creates a FilterTableSettings for the current session based on URL parameters.
   */
  public FilterTableSettings function getFilterTableSettings(struct formData = url, struct permissions = {}) {
    // Attempt to get the user's permissions for this appId
    if (permissions.isEmpty() && isDefined('session.user.appPermissions')) {
      permissions = session.user.appPermissions(variables.appId)
    }

    // We want to use an existing settings object if it exists
    if (session.keyExists(variables.templateHash)) {
      var settings = session[variables.templateHash]

      // Update the settings object with the permissions to ensure any changes take effect
      settings.permissions = permissions

      // If the reset parameter is set, we reset the settings object
      if (formData.keyExists('reset')) return settings.reset()

      // If there are any settings parameters, we update the settings object from the URL
      return FilterTable::hasSettingsParameters(formData) ? settings.setFromForm(formData) : settings
    }

    // Else Initialize the settings object from the URL parameters, if any are present.
    return new FilterTableSettings(formData: formData, permissions: permissions)
  } // end getFilterTableSettings()


  //// Functions used internally by renderFilterForm().

  /** Renders the select element containing options for the number of rows per page */
  private string function renderPageRowsSelect(numeric rowsPerPage = variables.rowsPerPageDefault) {
    var html = ''

    // Create a list of unique, sorted options for rows-per-page that includes the current value
    var pageRowsOpts = [variables.rowsPerPageDefault, rowsPerPage, 25, 100, 250, 500, 1000, 5000]
    pageRowsOpts = pageRowsOpts.sort('numeric').reduce(
      (arr, value) => arr.find(value) ? arr : arr.append(value), []
    )

    html &= '<label class="text-sm"><span class="sm:hidden">Show </span>'
    html &= '  <select name="rows" id="rows" class="text-sm">'
    for (var size in pageRowsOpts) {
      html &= '  <option#rowsPerPage == size ? ' selected' : ''#>#size#</option>'
    }
    html &= '  </select> per page'
    html &= '</label>'

    return html
  } // end renderPageRowsSelect()

  /**
   * Generates year, month, and day select inputs to filter results by each date part.
   * Could be used if users want an easy way to only show certain years or months.
   */
  private string function renderInputDateParts(required string colName, required string colLabel, string year, string month, string day) {
    // Create year, month, day pickers
    var html = '<div class="w-full sm:w-auto mx-1.5 mt-2">'
      & '<span class="sm:col-span-3">#colLabel#</span> '
      & '<div class="flex justify-between sm:justify-start">'
    html &= '<select id="fltYear_#colName#" name="fltYear_#colName#" class="chzn-select-deselect year mr-px" style="width: 5.9rem;" data-placeholder="Year"><option></option>'
    for (y = variables.earliestYear; y <= year(now()); y++) html &= '<option#(year ?: '') == y ? ' selected' : ''#>#y#</option>'
    html &= '</select>'

    html &= '<select id="fltMonth_#colName#" name="fltMonth_#colName#" class="chzn-select-deselect month mr-px" style="width: 5.85rem;" data-placeholder="Month"><option></option>'
    for (m=1; m<=12; m++) html &= '<option value="#m#"#(month ?: '') == m ? ' selected' : ''#>#monthAsString(m).left(3)#</option>'
    html &= '</select>'

    html &= '<select id="fltDay_#colName#" name="fltDay_#colName#" class="chzn-select-deselect day" style="width: 5rem;" data-placeholder="Day"><option></option>'

    for (d=1; d<=31; d++) html &= '<option#(day ?: '') == d ? ' selected' : ''#>#d#</option>'
    html &= '</select>'
    html &= '</div>'
    return html & '</div>'
  } // end renderInputDateParts()

  /** Generates a pair of datepickers to filter results by a date range */
  private string function renderInputDateRange(
    required string colName,
    required string colLabel,
    string fromValue = '',
    string toValue = ''
  ) {
    // TODO: Sanitize or format the date values. This should be handled by frontend validation,
    // but I could check it here.
    var html = '<div class="w-full sm:w-auto mx-1.5 mt-2">'
    html &= '<label class="sm:col-span-3" for="flt_#colName#">#colLabel#</label>'
    html &= '<div class="flex justify-between sm:justify-start space-x-0.5">'
    html &= '<div class="flex-1">'
    html &= new AppInput({
      type: 'date',
      id: 'fltFrom_' & colName,
      name: 'fltFrom_' & colName,
      classDefault: 'w-full sm:w-[110px] text-sm leading-6',
      labelClassDefault: 'font-light',
      value: fromValue,
      noErrorEl: true
    }).html()

    html &= '</div><div class="flex-1">'

    html &= new AppInput({
      type: 'date',
      id: 'fltTo_' & colName,
      name: 'fltTo_' & colName,
      classDefault: 'w-full sm:w-[110px] text-sm leading-6',
      prefix: 'to',
      // Annoying that I have to do this, but this pair of inputs is too wide without overriding the prefix class
      prefixClass: '!px-0.5 !min-w-0 text-sm',
      value: toValue,
      noErrorEl: true
    }).html()

    html &= '</div>'

    html &= '</div>'
    html &= '</div>'

    return html
  } // end renderInputDateRange()

  /** Generates an appropriate input given the properties of the column. */
  private string function renderFilterInput(required struct col, string value = '') {
    var filterView = col.views.filter
    var options = filterView?.options ?: []
    var type = filterView?.type ?: 'text'
    var class = 'w-full sm:w-[270px]'

    // Validate that we have options for the types requiring them
    if (listFindNoCase('select,radio', type) && !options.len()) {
      return error('filterType #(type)# requires a filterOptions array')
    }

    // If the filterType is 'radio' we need to add an option for 'all'
    if (type == 'radio') options.prepend({ value: '', label: 'All' })

    // Add the class for the chosen plugin if we're using a select
    if (type == 'select') class = class.listAppend('chzn-select-deselect', ' ')

    return '<div class="w-full sm:w-auto mx-1.5 mt-2">' & new AppInput({
      type: type,
      multiple: filterView.multiple ?: false,
      name: 'flt_' & filterView.name,
      id: 'flt_' & filterView.name,
      class: class,
      classDefault: 'block transition',
      fullWidth: true,
      label: filterView.label,
      labelClassDefault: '',
      options: options,
      horizontal: true,
      value: value,
      noErrorEl: true
    }).html() & '</div>'
  } // end renderFilterInput()

  /** Generates the filter input for a column given the column properties */
  private string function renderFilter(required struct col, required struct filters) {
    var filterView = col.views.filter
    // Skip columns that don't have filter in showOn
    if (filterView.hidden || !len(filterView?.name)) return ''

    // This dateParts filter will probably not be used very often
    if (filterView?.type == 'dateParts') {
      var year = filters[filterView.name].year ?: ''
      var month = filters[filterView.name].month ?: ''
      var day = filters[filterView.name].day ?: ''
      return variables.renderInputDateParts(filterView.name, filterView.label, year, month, day)
    }

    // Handle date filters
    if (filterView?.type == 'dateRange' || filterView?.type == 'date' || filterView?.type == 'datetime' ||
      (!filterView.keyExists('type') && 'datetime,date,timestamp'.listFindNoCase(filterView.dataType ?: ''))
    ) {
      var from = filters[filterView.name].from ?: ''
      var to = filters[filterView.name].to ?: ''
      return variables.renderInputDateRange(filterView.name, filterView.label, from, to)
    }

    // Set the default to the filter value to a default value if one exists, else empty string
    var filterValue = filterView.keyExists('defaultValue') ? filterView.defaultValue : ''

    // If we already do have a filter value, use that instead
    if (filters.keyExists(filterView.name) && filters[filterView.name].keyExists('value')) {
      filterValue = filters[filterView.name].value
    }

    return renderFilterInput(col, filterValue)
  } // end renderFilter()

  /** Checks if any parameters used by a FilterTable form exist in a struct */
  public static boolean function hasSettingsParameters(required struct params) {
    // Check if 'pg', 'rows', or sort parameters exist
    if (isNumeric(params?.pg) || isNumeric(params?.rows)) return true
    if (len(params?.sort1) || len(params?.sort2)) return true

    // Check if any filter-related parameters exist
    var prefixList = ['flt_', 'fltFrom_', 'fltTo_', 'fltYear_', 'fltMonth_', 'fltDay_']
    for (var prefix in prefixList) {
      for (var param in params) if (left(param, len(prefix)) == prefix) return true
    }

    // If none of the parameters are found, return false
    return false
  }

  public struct function getClientSideOptions(required FilterTableSettings settings) {
    // TODO: Clean up the columns object to remove what isn't needed client-side.
    filterTableOptions = {
      'key' = variables.key,
      'columns' = variables.columns,
      'rowsPerRecord' = variables.rowsPerRecord,
      'canEdit' = (variables.edit && settings.permissions?.edit == 1),
      'canAdd' = (settings.permissions?.edit == 1 && variables.create),
      'canDelete' = (settings.permissions?.delete == 1 && variables.delete),
      'showViewEdit' = variables.showViewEdit,
      'handler' = variables.handlersPath,
      'deletePrompt' = variables?.deletePrompt,
      'deleteNoConfirm' = (variables.deleteNoConfirm == true),
      'csvFilename' = variables.csvFileName,
      'sort1' = len(settings?.sort1) ? settings.sort1 : variables.sort1Default,
      'sort2' = len(settings?.sort2) ? settings.sort2 : variables.sort2Default,
      'sort1Desc' = len(settings?.sort1Desc) ? settings.sort1Desc : variables.sort1DefaultDesc,
      'sort2Desc' = len(settings?.sort2Desc) ? settings.sort2Desc : variables.sort2DefaultDesc,
      'selectFromTables' = variables.selectFromTables,
      'editInfoCols' = variables.editInfoCols.listToArray(),
      'user' = {
        'username' = session?.user?.username,
        'firstName' = session?.user?.firstName,
        'lastName' = session?.user?.lastName,
        'displayName' = session?.user?.displayName,
        'mail' = session?.user?.mail,
        'isManager' = (session?.user?.isManager == true),
        'manager' = session?.user?.manager
      }
    }

    return filterTableOptions
  } // end getClientSideOptions()

  /** Returns the HTML for the filter form. */
  public string function renderFilterForm(FilterTableSettings settings)  {
    if (!arguments.keyExists('settings')) settings = this.getFilterTableSettings()

    var isFilterHidden = !variables.showFilter
    // Settings will override the global showFilter setting
    if (len(settings?.showFilter)) isFilterHidden = !settings.showFilter

    var sort1 =  variables.sort1Default & (variables.sort1DefaultDesc ? '-' : '' )
    if (len(settings?.sort1)) {
      sort1 = settings.sort1 & (settings.sort1Desc ? '-' : '')
    }

    var sort2 =  variables.sort2Default & (variables.sort2DefaultDesc ? '-' : '' )
    if (len(settings?.sort2)) {
      sort2 = settings.sort2 & (settings.sort2Desc ? '-' : '')
    }

    // CSS to make rows highlight when hovering over a delete button. Sorry, Firefox users.
    html = '<style>'
    html &= '
      tbody:has([data-keyval]:hover) {
        background-image: linear-gradient(to top, hsl(60deg 100% 50% / .1), hsl(60deg 100% 50% / .2));
      }

      .data thead th {
        vertical-align: bottom;
      }

      .data tbody:nth-child(even) {
        background-color: hsl(208deg 100% 28% / 15%);
      }

      .data table {
        border-collapse: no-collapse;
      }

      .data td {
        padding: 4px;
        padding-top: 8px;
        padding-bottom: 8px;
      }
    '

    switch (variables.vAlign) {
      case 'top':
        html &= ' .data tbody td { vertical-align: top; } '
        break;
      case 'bottom':
        html &= ' .data tbody td { vertical-align: bottom; } '
        break;
    }

    html &= '</style>'

    // Open tag/heading
    html &= '<form id="filterForm"
              action="#variables.handlersPath#?data"
              class="filterForm max-w-5xl mx-auto bg-zinc-500/20 rounded border border-zinc-500/20 flex flex-wrap items-center p-2 shadow-md"
            >'
      & '  <input name="tph" type="hidden" value="#variables.templateHash#" />'
      // Tracks the current page of results we're on
      & '  <input name="pg" id="filterFormPg" type="hidden" value="#settings.currentPage#" />'
      // Tracks the current sort column
      & '  <input type="hidden" name="sort1" id="sort1" value="#sort1#" />'
      // Tracks the previous sort column to use as a secondary sort
      & '  <input type="hidden" name="sort2" id="sort2" value="#sort2#" />'
      // Top row of filter form
      & '  <div class="flex flex-col sm:flex-row justify-between w-full px-1 my-1 space-y-1 sm:space-y-0">'
      & '    <div class="hidden sm:flex justify-center sm:justify-start items-center w-full sm:w-48">'
      & renderPageRowsSelect(settings.rowsPerPage ?: variables.rowsPerPageDefault)
      & '    </div>'

    html &= '<div class="flex-1 m-auto max-w-lg w-full relative flex items-center">'
    html &= '
        <label for="search"
          class="absolute left-4"
          title="Search All"
        ><i class="fas fa-search text-zinc-500"></i></label>
        <input type="search"
          class="m-1 w-full rounded-full p-1 pl-7 pr-2 text-black text-center"
          placeholder="Search..."
          id="search"
          name="search"
          value="#settings.search ?: ''#"
          autocomplete="off"
        />'

    html &= '</div>'

    // Determine if this is the initial page load with default settings
    var isUsingDefaults = settings.filters.isEmpty() && url.isEmpty() || url.keyExists('reset')

    // This input will be removed after the user submits the form the first time
    if (isUsingDefaults) html &= '<input type="hidden" name="usingDefaults" value="true" />'

    html &= '<div class="w-full sm:w-48 text-sm flex items-center justify-center sm:justify-end">'

    // <input type="hidden" name="showFilter" id="showFilter" value="#isFilterHidden ? 'false' : 'true'#" />

    html &= '<button type="button"
      class="mainResetBtn btn#isUsingDefaults ? ' hidden' :''#"
      onclick="window.location = `${window.location.pathname}?reset`"
      data-tooltip="Clear all filters and set the view to defaults"
      ><i class="fas fa-arrow-rotate-right"></i>&nbsp;Reset</button>'

    // Advanced Filter button shown if any columns have a filter view
    if (variables.columns.find(col => col.views.filter?.hidden == false)) {
      html &= '
      <label class="btn text-sm ml-2">
        <i class="fas fa-filter"></i> Filters
          <input type="checkbox"
          name="showFilter"
          class="invisible w-0 h-0 border-none"
          #isFilterHidden ? '' : 'checked'#
          onclick="const cList = this.nextElementSibling.classList; cList.toggle(''fa-chevron-down''); cList.toggle(''fa-chevron-up'')"
        /><i class="fas #isFilterHidden ? 'fa-chevron-down' : 'fa-chevron-up'#"></i>
      </label>
      '
    }

    html &= '</div>'
    html &= '  </div>'
    html &= '<div class="advancedFilter #isFilterHidden ? 'h-0 overflow-hidden' : ''# transition-all mx-auto flex flex-wrap justify-center">'

    for (col in variables.columns) html &= variables.renderFilter(col, settings.filters)

    // Submit button and closing tag
    // Invisible submit input that still allows 'enter' to submit the form
    html &= ' <input type="submit" value="" class="hidden" />'


    html &= '</div>' // end advancedFilter
    html &= '</form>'

    // Initialize options for the FilterTable JS Class
    // TODO: I could filter this to remove extraneous data the JS doesn't need, like display functions.
    html &= '
    <script>
      // ColdFusion variables passed into the options object
      const options = #this.getClientSideOptions(settings).toJSON()#

      // Consider using this with DOMContentReady to ensure the table is rendered before initializing the JS
      const filterTableEl = document.querySelector(".filterTableAll")
      const filterTable = new FilterTable(filterTableEl, options)
    '

    // Add the display functions to the JS
    for (fn in variables.displayJSFns) html &= chr(10) & chr(13) & fn

    html &= chr(10) & chr(13) & '</script>'

    return html
  } // end renderFilterForm()

  // Checks that the specified column is valid (without an optional trailing hyphen)
  private boolean function isValidTableColumnName(string columnName) {
    if (!len(arguments?.columnName)) return false
    return variables.columns.find(col => col.views.table?.name == columnName) ? true : false
  }

  /**
   * Goes through each word of the search and adds a where clause for each word
   * for each applicable column specified in the searchCols list.
   */
  private struct function buildGlobalSearchWordFilter(required string searchWord, numeric wordIndex = 0) {
    // Start building the SQL query
    var conditions = []
    var params = {}

    if (!searchWord.trim().len()) return { sql: '', params: {} }

    // Loop through the array and build the WHERE clause
    for (var col in variables.columns) {
      // Skip fields with no name, as there's no point trying to search things not in the db
      if (!len(col?.name)) continue;
      // This could use the filters.name but since this is a global search it could work either way.
      if (!variables.searchCols.listFindNoCase(col.name)) continue;

      var condition = ''
      var paramName = 'search_w#wordIndex#_#col.name#'

      // TODO: Add mysql data types
      switch (col.dataType) {
        case 'varchar':
        case 'nvarchar':
        case 'char':
        case 'nchar':
        case 'text':
        case 'ntext':
          condition = "#col.name# LIKE :" & paramName
          params[paramName] = { value: '%#searchWord#%', cfsqltype: 'CF_SQL_VARCHAR' }
          break;

        case 'int':
          if (isNumeric(searchWord) && searchWord >= -2147483648 && searchWord <= 2147483647) {
            condition = "#col.name# = :" & paramName
            params[paramName] = { value: searchWord, cfsqltype: 'CF_SQL_INTEGER' }
          }
          break;

        case 'bigint':
          if (isNumeric(searchWord) && searchWord >= -9223372036854775808 && searchWord <= 9223372036854775807) {
            condition = "#col.name# = :" & paramName
            params[paramName] = { value: searchWord, cfsqltype: 'CF_SQL_BIGINT' }
          }
          break;

        case 'smallint':
          if (isNumeric(searchWord) && searchWord >= -32768 && searchWord <= 32767) {
            condition = "#col.name# = :" & paramName
            params[paramName] = { value: searchWord, cfsqltype: 'CF_SQL_SMALLINT' }
          }
          break;

        case 'tinyint':
          if (isNumeric(searchWord) && searchWord >= 0 && searchWord <= 255) {
            condition = "#col.name# = :" & paramName
            params[paramName] = { value: searchWord, cfsqltype: 'CF_SQL_TINYINT' }
          }
          break;

        case 'decimal':
        case 'numeric':
        case 'float':
        case 'real':
        case 'money':
        case 'smallmoney':
          if (isNumeric(searchWord)) {
            condition = "#col.name# = :" & paramName
            params[paramName] = { value: searchWord, cfsqltype: 'CF_SQL_DECIMAL' }
          }
          break;

        case 'date':
          if (isDate(searchWord)) {
            condition = "#col.name# = :" & paramName
            params[paramName] = { value: searchWord.format('yyyy-mm-dd'), cfsqltype: 'CF_SQL_DATE' }
          }
          break;

        case 'datetime':
        case 'datetime2':
        case 'smalldatetime':
        case 'timestamp':
          if (isDate(searchWord)) {
            condition = "CAST(#col.name# AS DATE) = :" & paramName
            params[paramName] = { value: searchWord.format('yyyy-mm-dd'), cfsqltype: 'CF_SQL_DATE' }
          }
          break;

        case 'time':
          if (isValid('time', searchWord)) {
            condition = "#col.name# = :" & paramName
            params[paramName] = { value: searchWord.format('HH:nn'), cfsqltype: 'CF_SQL_TIME' }
          }
          break;
      } // end switch

      if (condition.trim().len()) conditions.append(condition)

    } // end for col in columns

    // Combine conditions with OR - only one column has to match something
    var sqlWhereClause = conditions.toList(" OR ")

    return { sql: sqlWhereClause, params: params }
  } // end buildGlobalSearchWordFilter()

  // Helper functions for buildQueryFilters()
  /** Checks that the specified value exists in filterOptions (called by handleQueryFilterType) */
  private struct function handleQueryOptions(struct col, required string filterVal) {
    var filterView = col.views.filter
    if (!filterView.keyExists('options')) return { sql: '', params: {} }

    // Support multiple options at once
    if (filterView.keyExists('multiple') && filterView.multiple) {
      for (var val in filterVal.listToArray()) {
        if (!filterView.options.find(opt => opt.value == val)) return { sql: '', params: {} }
      }
    } else if (!filterView.options.find(opt => opt.value == filterVal)) return { sql: '', params: {} }

    // Handle the case that we are filtering by results from joined table
    if (len(filterView?.joinTable)) {
      var filterVals = filterVal.listToArray()

      return {
        sql: "AND #oq##filterView.joinKey##cq# IN (
          SELECT #oq##filterView.joinKey##cq#
          FROM #oq##filterView.joinTable##cq#
          WHERE #oq##filterView.optionKey##cq# IN (:flt#filterView.name#)
          GROUP BY #oq##filterView.joinKey##cq#
          HAVING COUNT(DISTINCT #oq##filterView.optionKey##cq#) = #filterVals.len()#
        )",
        params: {
          'flt#filterView.name#': { value: filterVal, cfsqltype: Util::sqlToCFSQLType(filterView.dataType), list: true }
        }
      }
    } // end if len(filterView.joinTable)

    switch (filterVal) {
      case variables.isNotNullString:
        return { sql: " AND #oq##filterView.name##cq# IS NOT NULL ", params: {} }
      case variables.isNullString:
        return { sql: " AND #oq##filterView.name##cq# IS NULL ", params: {} }
      default:
        return {
          sql: " AND #oq##filterView.name##cq# = :flt#filterView.name# ",
          params: { 'flt#filterView.name#': { value: filterVal, cfsqltype: Util::sqlToCFSQLType(filterView.dataType) } }
        }
    }
  } // end handleQueryOptions()

  private struct function handleQueryDateRange(required struct col, struct filter) {
    var filterView = col.views.filter
    var filterFrom = filter.from ?: ''
    var filterTo = filter.to ?: ''

    // Default to today if no 'to' date is provided
    if (!len(filterTo)) filterTo = dateFormat(now(), 'yyyy-mmm-dd')

    if (!isDate(filterFrom) || !isDate(filterTo)) return { sql: '', params: {} }

    return {
      sql: " AND #oq##filterView.name##cq# BETWEEN :flt#filterView.name#From AND :flt#filterView.name#To ",
      params: {
        'flt#filterView.name#From': { value: filterFrom, cfsqltype: 'CF_SQL_TIMESTAMP' },
        'flt#filterView.name#To': { value: filterTo & ' 23:59:59.999', cfsqltype: 'CF_SQL_TIMESTAMP' }
      }
    }
  } // end handleQueryDateRange()

  /** Handles filtering by separate year, month, and day inputs */
  private struct function handleQueryDateParts(struct col, struct filter) {
    var filterView = col.views.filter
    var sqlPart = ''
    var params = {}
    var filterYear = filter.year ?: ''
    var filterMonth = filter.month ?: ''
    var filterDay = filter.day ?: ''

    if (isNumeric(filterYear)) {
      sqlPart &= " AND YEAR([#filterView.name#]) = :flt#filterView.name#Year "
      params['flt#filterView.name#Year'] = {value: filterYear, cfsqltype: 'CF_SQL_INTEGER', maxlength: 4}
    }

    if (isNumeric(filterMonth)) {
      sqlPart &= " AND MONTH([#filterView.name#]) = :flt#filterView.name#Month "
      params['flt#filterView.name#Month'] = {value: filterMonth, cfsqltype: 'CF_SQL_INTEGER', maxlength: 2}
    }

    if (isNumeric(filterDay)) {
      sqlPart &= " AND DAY([#filterView.name#]) = :flt#filterView.name#Day "
      params['flt#filterView.name#Day'] = {value: filterDay, cfsqltype: 'CF_SQL_INTEGER', maxlength: 2}
    }

    return { sql: sqlPart, params: params }
  } // end handleDateFilters()

  /** Builds the WHERE clause for a query of the dbTable */
  private struct function buildQueryFilters(required FilterTableSettings settings) {
    var result = {
      sql: " WHERE 1=1 ",
      params: {}
    }

    if (settings.search.trim().len()) {
      var searchWords = settings.search.trim().listRemoveDuplicates(' ').listToArray(' ')
      wordIndex = 0
      for (var word in searchWords) {
        if (word.trim().len()) {
          wordIndex++
          var globalSearchWordFilterResult = buildGlobalSearchWordFilter(word, wordIndex)

          if (globalSearchWordFilterResult.sql.trim().len()) {
            result.sql &= "AND (#globalSearchWordFilterResult.sql#)"
            result.params.append(globalSearchWordFilterResult.params)
          }
        }
      }
    }

    var filters = settings.filters ?: {}

    for (col in variables.columns) {
      var filterView = col.views.filter

      // TODO: I think that dateParts don't work because they never get added to the filters struct
      // in a way that the name is added to the filters struct, but the year, month, and day are not.

      // Skip if this column not a real db field or there's no filter for it
      if (!filterView.keyExists('name') || !filters.keyExists(filterView.name)) continue;

      var filter = filters[filterView.name]

      // If the filter has no values (other than empty strings or arrays), skip it
      if (isSimpleValue(filter) && !filter.len()) continue;
      if (!filter.keyArray().some(val => filter[val].len())) continue;

      var colResult = { sql: '', params: {} }

      // If a special filterType is specified, handle that
      if (filterView.keyExists('type')) {
        if ('radio,select'.listFindNoCase(filterView.type)) { // A single option or multiple options from a joined table
          colResult = handleQueryOptions(col, len(filter?.value) ? filter.value : '')
        } else if ('dateParts'.listFindNoCase(filterView.type)) { // A set of dates by year, month, and/or day
          colResult = handleQueryDateParts(col, filter)
        } else if ('dateRange,date,datetime'.listFindNoCase(filterView.type)) { // A date range
          colResult = handleQueryDateRange(col, filter)
        }
      }

      // For date columns, handle the multiple date part filters
      else if ('date,datetime,timestamp'.listFind(filterView?.dataType)) colResult = handleQueryDateRange(col, filter)

      // For any other data type, just an appropriate search, defaulting to LIKE
      else if (filterView.keyExists('dataType') && filter.keyExists('value')) {
        var dataType = lCase(filterView.dataType)
        var value = filter.value
        var sqlOperator = ''
        var sqlValue = ''

        switch (dataType) {
          case 'int': case 'smallint': case 'mediumint': case 'bigint':
            // Treat INTs like varchar for now
            sqlOperator = 'LIKE'
            sqlValue = '%#value#%'
            dataType = 'varchar'
            break;
          case 'float': case 'real': case 'decimal': case 'numeric': case 'double':
            sqlOperator = 'BETWEEN'
            sqlValue = '#value# - 0.1 AND #value# + 0.1'
            break;
          case 'bit': case 'boolean':
            sqlOperator = '='
            sqlValue = value == true ? 1 : 0
            break;
          // Add support for other data types here
          default:
            sqlOperator = 'LIKE'
            sqlValue = '%#value#%'
        }

        colResult = {
          sql: " AND #oq##filterView.name##cq# #sqlOperator# :flt#filterView.name# ",
          params: { 'flt#filterView.name#': { value: sqlValue, cfsqltype: Util::sqlToCFSQLType(dataType) } }
        }
      }

      result.sql &= colResult.sql
      result.params.append(colResult.params)
    }

    return result
  } // end buildQueryFilters()

  /**
   * Returns the total number of records in the dbTable.
   * For very large tables (but not views), it is faster, but less accurate, to use
   * SELECT SUM(row_count) AS totalRows FROM sys.dm_db_partition_stats
   * WHERE object_id=OBJECT_ID('#variables.dbTable#') AND (index_id=0 or index_id=1)
   */
  public numeric function getTotalRowCount() {
    return totalRowCount = queryExecute("SELECT COUNT(*) AS rows FROM #oq##variables.dbTable##cq#",
      {},
      { datasource: variables.datasource }
    ).rows
  } // end getTotalRowCount()

  /** Returns the number of rows matched by the filters across all pages. */
  public numeric function getFilteredRowCount(required FilterTableSettings settings) {
    var sql = "SELECT COUNT(*) AS #oq#rows#cq# FROM #oq##variables.dbTable##cq# "
    var filters = variables.buildQueryFilters(settings)

    sql &= filters.sql

    return filteredRowCount = queryExecute(sql, filters.params, { datasource: variables.datasource }).rows
  } // end getFilteredRowCount()

  /** Returns the paginated results of a query of the dbTable given the filters. */
  private any function getPageRows(required FilterTableSettings settings, boolean returnArray=false) {
    var sql = "SELECT #variables.columnArray.toList()# FROM #oq##variables.dbTable##cq# ";

    // Add the WHERE clause for the filters
    var filters = variables.buildQueryFilters(settings)

    sql &= filters.sql

    // ORDER BY is required before OFFSET. Add sort order from settings or use the default.
    sql &= variables.isValidTableColumnName(settings?.sort1)
      ? " ORDER BY #oq##settings.sort1##cq# " & (settings.sort1Desc ? 'DESC' : 'ASC')
      : " ORDER BY #oq##variables.sort1Default##cq# " & (variables.sort1DefaultDesc ? 'DESC' : 'ASC')

    sql &= variables.isValidTableColumnName(settings?.sort2) && settings.sort2 != settings.sort1
      ? ", #oq##settings.sort2##cq# " & (settings.sort2Desc ? 'DESC' : 'ASC')
      : ""

    // Add the pagination via OFFSET and FETCH or LIMIT and OFFSET
    var rowsPerPage = isDefined('settings.rowsPerPage') ? settings.rowsPerPage : variables.rowsPerPageDefault

    if (rowsPerPage > 0) {
      sql &= variables.dbType == 'mysql'
        ? " LIMIT :rowsPerPage OFFSET :offset"
        : " OFFSET :offset ROWS FETCH NEXT :rowsPerPage ROWS ONLY"
      filters.params.offset = { value: (settings.currentPage - 1) * rowsPerPage, cfsqltype: 'CF_SQL_INTEGER' }
      filters.params.rowsPerPage = { value: rowsPerPage, cfsqltype: 'CF_SQL_INTEGER' }
    }

    // We could return this directly but then we don't get a label for the query in debug output
    return pageRows = queryExecute(
      sql,
      filters.params,
      { datasource: variables.datasource, returnType: returnArray ? 'array' : 'query' }
    )
  } // end getPageRows()

  /** Public method for the getPageRows() function to return a query */
  public query function getPageRowsQuery(required FilterTableSettings settings) {
    return variables.getPageRows(settings, false)
  }

  /** Public method for the getPageRows() function to return an array */
  public array function getPageRowsArray(required FilterTableSettings settings) {
    return variables.getPageRows(settings, true)
  }

  /** Returns a struct containing all the page data. */
  public struct function getPageData(
    FilterTableSettings settings,
    array rows
  ) {
    if (!arguments.keyExists('settings')) settings = this.getFilterTableSettings()
    if (!arguments.keyExists('rows')) {
      try { rows = variables.getPageRowsArray(settings) }
      catch (any e) {
        var message = e.message & (len(e?.detail) ? '<br><br>' & e.detail : '')
        return Util::errorStruct('Error getting page data: ' & message)
      }
    }

    var totalRows = variables.getFilteredRowCount(settings)
    var rowsPerPage = isDefined('settings.rowsPerPage') ? settings.rowsPerPage : variables.rowsPerPageDefault
    var totalPages = rowsPerPage > 0 ? ceiling(totalRows / rowsPerPage) : 1

    // This is fast. But I don't get the ability to do any custom formatting of the data.
    // I might have to use the second option if there are any render functions.
    return {
      'error': false,
      'totalRows': totalRows,
      'totalPages': totalPages,
      'currentPage': settings.currentPage,
      'rows': rows,
      'messages': []
    }
  } // end getPageData()

  public void function clearBuffer() { variables.buffer = '' }

  /** Updates the useBuffer setting. Used in testing. */
  public void function setUseBuffer(boolean useBuffer = false) { variables.useBuffer = useBuffer }

  /** Either directly write to output or append to a buffer based on useBuffer */
  private void function write(string text = '', boolean useBuffer) {
    if (variables.keyExists('useBuffer')) variables.useBuffer = useBuffer

    if (variables.useBuffer) variables.buffer &= text
    else writeOutput(text)
  }

  /** Writes the filter form, container div, pagination links, and table to output */
  public function render(FilterTableSettings settings) {
    if (!arguments.keyExists('settings')) settings = this.getFilterTableSettings()

    // EasyMDE import
    if (variables.useMarkdown) {
      if (app?.dev == true && server?.devServer == true) {
        write('<script type="module" src="http://localhost:5173/dist/Utils/EasyMDE.js"></script>')
      } else include '/dist/Utils/EasyMDE.html'
    }

    write('<script src="#variables.jsPath#"></script>')

    // This parent container can be used as a target for JS event listeners
    write('<div class="filterTableAll">')
    write(variables.renderFilterForm(settings))
    write('<div class="filterTable">')
    // Blank placeholders for page data, which gets loaded with JS on page load
    write('
      <h2 class="pageHeading text-center text-xl mt-3 mb-2"><i class="fas fa-gear fa-spin mr-2"></i> Loading Results...</h2>
      <div class="pageLinks hidden"></div>
      <table class="data hidden"></table>
      <div class="pageLinks hidden"></div>
    ')

    // TODO: Make this 'jump to top' button conditional on there being a certain number of rows
    write('<div class="!ml-0 mt-4 text-center">'
            &   '<a href="##pageLinksTop" class="btn">'
            &     '<i class="fas fa-angle-double-up"></i> Jump to Top <i class="fas fa-angle-double-up"></i>'
            &   '</a>'
            & '</div>'
    )
    write('</div></div><!-- .filterTable -->')
  } // end render()

  /** Generates an array queries based on deleteFromTables to be executed by deleteRecord */
  private array function generateDeleteQueries() {
    var queries = []

    // Loop through the deleteFromTables array and build the delete queries
    for (el in variables.deleteFromTables) {
      var sql = ""

      // Trivial case where we simply delete from a column where the key matches the recordId
      sql = "DELETE FROM #oq##el.table##cq# WHERE #oq##el.key##cq# "

      // If there's a refTable, use a subquery to select all the records related to the recordId
      if (!el.keyExists('refTable')) sql &= "= :id;"
      else {
        // Ensure the configuration makes sense - refTableCol and refTableKey must be defined
        if (!len(el?.refTableCol) || !len(el?.refTableKey)) throw('refTableCol and refTableKey are required when using refTable.', 'FilterTableConfig')

        sql &= "IN (SELECT #oq##el.refTableCol##cq# FROM #oq##el.refTable##cq# WHERE #oq##el.refTableKey##cq# = :id);"
      }

      queries.append(sql)
    }

    return queries
  } // end generateDeleteQueries()

  /** Deletes the specified row from the dbTable and returns a struct with status and messages */
  public struct function deleteRecord(required string recordId, required FilterTableSettings settings) {
    if (!variables.delete) return { 'error': true, 'messages': ['Deleting records is not permitted.'] }
    if (settings?.permissions?.delete != 1) return { 'error': true, 'messages': ['You do not have delete permission.'] }

    var recordArray = queryExecute(
      "SELECT * FROM #oq##variables.dbTable##cq# WHERE #oq##variables.key##cq# = :id",
      { id: { value: recordId } },
      { datasource: variables.datasource, returnType: 'array' }
    )

    if (!recordArray.len()) return { 'error': true, 'messages': ['No record with #variables.key# of #recordId# was found.'] }

    var record = recordArray[1]

    if (!isArray(variables.deleteFromTables) || !variables.deleteFromTables.len()) {
      return { 'error': true, 'messages': ['deleteFromTables was not defined in the filterTable configuration.'] }
    }

    var deleteQueries = variables.generateDeleteQueries()
    var deletedRows = 0

    // Performs delete queries as a single db transaction and rolls back if something goes wrong
    transaction {
      for (sql in deleteQueries) {
        try {
          var delQuery = queryExecute(
            sql,
            { id: { value: recordId } },
            { datasource: variables.editDatasource }
          )

          var deletedRowsQuery = queryExecute(
            "SELECT " & (variables.dbType == 'mysql' ? "ROW_COUNT()" : "@@ROWCOUNT") & " AS #oq#rows#cq#",
            {},
            { datasource: variables.editDatasource }
          )

          deletedRows += deletedRowsQuery.rows
        } catch (any e) {
          transaction action='rollback';
          var msg = e.message
          if (len(e?.detail)) msg &= ' ' & e.detail
          return { 'error': true, 'messages': ['Error deleting record: ' & msg] }
        }
      }
    }

    var delInfo = 'Record #recordId#'

    if (variables.deleteInfoCols.len()) {
      delInfo = ''
      for (col in listToArray(variables.deleteInfoCols)) {
        if (record.KeyExists(col)) {
          var value = encodeForHTML(record[col])
          delInfo &= (delInfo.len() ? ', ' : '') & '<em>#value#</em>'
        }
      }
    }

    delInfo &= ' has been deleted.'

    if (deletedRows != 1) delInfo &= '<br><br>#deletedRows - 1# related records were deleted.'

    return { 'error': false, 'messages': [delInfo] }
  } // end deleteRecord()

  /** Handle the archive/unarchive of the specified row from the dbTable and returns a struct with status and messages */
  private struct function toggleArchiveRecord(
    required string recordId,
    required FilterTableSettings settings,
    string action='archive'
  ) {
    if (settings?.permissions?.edit != 1) return { 'error': true, 'messages': ['You do not have edit permission.'] }

    var sqlColValues = ''
    var params = { id: { value: recordId }}
    var value = ''

    if (variables.shouldAddField('deleted_at')) {
      value = action == 'archive'
        ? (variables.dbType == 'mysql' ? 'NOW()' : 'GETDATE()')
        : 'NULL'
      sqlColValues = sqlColValues.listAppend("#oq#deleted_at#cq# = #value#")
    }

    if (len(session?.identity) > 2 && len(session.identity) < 30 && variables.shouldAddField('deleted_by')) {
      value = action == 'archive'
        ? ':filterTableUserDeletedBy'
        : 'NULL'
      sqlColValues = sqlColValues.listAppend("#oq#deleted_by#cq# = #value#")
      params.filterTableUserDeletedBy = { value: session.identity, cfsqltype: 'CF_SQL_VARCHAR', maxLength: 30 }
    }

    var result = queryExecute("
      UPDATE #oq##variables.dbTable##cq#
      SET #sqlColValues#
      WHERE #oq##variables.key##cq# = :id
      ",
      params,
      { datasource: variables.editDatasource }
    )

    return { 'error': false, 'messages': [action == 'archive' ? 'Record has been archived. Select "Show Archived: Archived" to view and restore.' : 'Record has been restored.'] }
  }

  /** Archive/Soft-Delete the specified row from the dbTable and returns a struct with status and messages */
  public struct function archiveRecord(required string recordId, required FilterTableSettings settings) {
    return toggleArchiveRecord(recordId, settings, 'archive')
  }

  /** Restore the specified row from the dbTable and returns a struct with status and messages */
  public struct function restoreRecord(required string recordId, required FilterTableSettings settings) {
    return toggleArchiveRecord(recordId, settings, 'restore')
  }



  /** Displays the descriptive name of the record using editInfoCols */
  private string function getEditTitleName(required query record) {
    var editTitleName = ''

    for (var col in listToArray(variables.editInfoCols)) {
      if (record.keyExists(col)) {
        // Need to evaluate colValue before passing to encodeForHTML
        var colValue = record[col]
        editTitleName &= (editTitleName.len() ? ', ' : '') & encodeForHTML(colValue)
      }
    }

    var recordId = record[variables.key]

    return len(editTitleName) ? editTitleName & ' (ID #recordId#)' : 'ID #recordId#'
  }

  /** Returns a single record (all fields) from the dbTable */
  public struct function getRecord(required string recordId, FilterTableSettings settings) {
    if (!arguments.keyExists('settings')) settings = this.getFilterTableSettings()

    var records = queryExecute(
      "SELECT * FROM #oq##variables.dbTable##cq# WHERE #oq##variables.key##cq# = :id",
      { id: { value: recordId } },
      { datasource: variables.datasource, returnType: 'array' }
    )

    // If there's more than one record (because the key is not unique), return an error
    if (records.len() > 1) {
      return {
        'error': true,
        'record': {},
        'messages': ['Multiple records with #variables.key# of #recordId# were found.']
      }
    }

    // Get data for related tables
    var relatedData = {}

    for (sft in variables.selectFromTables) {
      var sql = "SELECT * FROM #oq##sft.table##cq# WHERE #oq##sft.refKey##cq# = :id"
      var sortCols = ''
      if (len(sft?.sort)) {
        for (col in sft.sort.listToArray()) {
          sortCols = sortCols.listAppend(col.endsWith('-') ? col.reReplace('-$', '') & ' DESC' : col)
        }
      }

      if (len(sortCols)) sql &= " ORDER BY #sortCols#"

      var params = { id: { value: recordId } }
      var relatedRecords = queryExecute(sql, params, { datasource: variables.datasource, returnType: 'array' })

      if (relatedRecords.len()) relatedData[sft.table] = relatedRecords
    }

    return {
      'error': records.len() != 1,
      'record': records.len() == 1 ? records[1] : {},
      'relatedData': relatedData,
      'messages': records.len() == 1 ? [] : ['Record ID #recordId# not found.']
    }
  }

  /** Checks that this field exists in baseSchemaColumns but not in the specified list */
  private boolean function shouldAddField(fieldName, list='') {
    // Doesn't seem to exist in the db table at all, so false
    if (!variables.baseSchemaColumns.find((col) => col.COLUMN_NAME == fieldName)) return false;

    // Already in the list, so false (note we check with and without square brackets)
    if (list.find(fieldName) || list.find("#oq##fieldName##cq#")) return false;

    // Is in the schema and not in the list, so we should add the field
    return true
  }

  /** Adds records to an associative table relating records in baseTable to joinTable. */
  private struct function insertJoinTableData(
    required any recordId,
    required array values,
    required struct view
  ) {
    // Return immediately if the view has no joinTable or values is empty
    if (!view.keyExists('joinTable') && !values.len()) return {'error': false };

    var joinKey = view.joinKey
    var optionKey = view.optionKey

    // Insert into the joinTable
    var sql = "INSERT INTO #oq##view.joinTable##cq# (#oq##joinKey##cq#, #oq##optionKey##cq#) VALUES"
    var sqlColValues = ''
    var params = {}
    count = 0
    for (value in values) {
      count++
      sqlColValues = sqlColValues.listAppend(" (:value_#joinKey#_#count#, :value_#optionKey#_#count#)")
      params['value_#joinKey#_#count#'] = { value: recordId, cfsqltype: Util::sqlToCFSQLType(view.joinKeyDataType) }
      params['value_#optionKey#_#count#'] = { value: value, cfsqltype: Util::sqlToCFSQLType(view.optionKeyDataType) }
    }

    try {
      queryExecute(sql & sqlColValues, params, { datasource: variables.editDatasource })
      return {'error': false }
    } catch (any e) {
      var msg = e.message
      if (len(e?.detail)) msg &= ' ' & e.detail
      return { 'error': true, 'messages': ['Error inserting record: ' & msg] }
    }
  } // end insertJoinTableData()

  /** Creates a new record in the dbTable and returns a struct with an status and messages */
  public struct function createRecord(
    required struct formData = form,
    required FilterTableSettings settings
  ) {
    // Ensure this instance is configured to allow creation
    if (!variables.create) return { 'error': true, 'messages': ['Creating records is not permitted.'] }
    // Ensure the user has permission to edit
    if (settings?.permissions?.edit != 1) return { 'error': true, 'messages': ['You do not have edit permission for this app.'] }

    // Iterate through columns to build up the SQL and params
    var sqlColList = ''
    var sqlColValues = ''
    var params = {}

    // TODO: Is there a way to ensure that the column name is actually a column in the db?
    // I could do a check like that and then remove showOn 'new' from any such columns
    for (col in variables.columns) {
      var newView = col.views.new
      // If there's no db column specified, or if this is the primary key
      // (presumes primary keys auto-increment),or if this is not shown on new, skip it
      if (!newView.keyExists('name') || newView.name == variables.key || newView.hidden) continue;
      // If this is a type of 'display' then skip it as it doesn't have an associated input
      if (newView.type == 'display') continue;

      // If there's a joinTable, we skip it because we need a separate query to insert those records
      if (newView.keyExists('joinTable')) continue;

      // If this is an auditing field, we skip it as those will automatically be added
      if ('created_at,created_by,updated_at,updated_by,deleted_at,deleted_by'.listFindNoCase(newView.name)) continue;

      // If the value is not present in formData, default to empty string
      var colValue = formData.keyExists(newView.name) ? formData[newView.name] : ''
      var isNull = newView?.nullable == true && !colValue.len()
      sqlColList = sqlColList.listAppend("#oq##newView.name##cq#")
      sqlColValues = sqlColValues.listAppend(":#newView.name#")

      // If the column is nullable and the value is empty, set it to null
      params[newView.name] = isNull
        ? { isNull: true }
        : { value: colValue, cfsqltype: Util::sqlToCFSQLType(newView.dataType) }
    } // end for col in variables.columns

    // If there are no columns to update, return an error
    if (!sqlColValues.len()) return { 'error': true, 'messages': ['No columns to insert to.'] }

    // Add the created auditing fields, if they exist in baseSchemaColumns but not in columns
    if (variables.shouldAddField('created_at', sqlColList)) {
      sqlColList = sqlColList.listAppend("#oq#created_at#cq#")
      sqlColValues = sqlColValues.listAppend(dbType == 'mysql' ? "NOW()" : "GETDATE()")
    }

    if (len(session?.identity) > 2 && len(session.identity) < 30 && variables.shouldAddField('created_by', sqlColList)) {
      sqlColList = sqlColList.listAppend("#oq#created_by#cq#")
      sqlColValues = sqlColValues.listAppend(":filterTableUserCreatedBy")
      params.filterTableUserCreatedBy = { value: session.identity, cfsqltype: 'CF_SQL_VARCHAR', maxLength: 30 }
    }

    try {
      var sql = "INSERT INTO #oq##variables.baseTable##cq# (#sqlColList#) VALUES(#sqlColValues#); "

      var insertRecord = queryExecute(sql, params, { datasource: variables.editDatasource, result: 'insertInfo' })

      // This must be done within this transaction or else the recordID won't be set correctly
      var recordID = insertInfo.generatedKey ?: insertInfo.identityCol

      var record = queryExecute("
        SELECT * FROM #oq##variables.dbTable##cq# WHERE #oq##variables.key##cq# = :id
        ",
        { id: { value: recordID } },
        { datasource: variables.datasource }
      )
    } catch (any e) {
      var msg = e.message
      if (len(e?.detail)) msg &= ' ' & e.detail
      return { 'error': true, 'messages': ['Error inserting record: ' & msg] }
    }

    var editTitleName = variables.getEditTitleName(record)

    // Insert records into that joinTable for selected options. This only happens if joinTable is defined
    for (col in variables.columns) {
      if (!col.views.new.keyExists('joinTable')) continue;
      var values = formData[col.views.new.name].listToArray() ?: []
      var result = insertJoinTableData(recordId, values, col.views.new)
      if (result.error) return result
    }

    return { 'error': false, 'messages': [ editTitleName & ' created successfully.'] }
  } // end createRecord()

  /** Updates a database record with the values from the form. */
  public struct function updateRecord(
    required struct formData = form,
    required FilterTableSettings settings
  ) {
    var ftRecordId = formData.ftRecordId ?: ''

    // Ensure the user has permission to edit
    if (settings?.permissions?.edit != 1) return { 'error': true, 'messages': ['You do not have edit permission for this app.'] }

    // If there's no recordId,  create a new record
    if (!len(ftRecordId)) return createRecord(formData, settings)

    // Iterate through columns to build up the SQL and params
    var sqlColValues = ''
    var sqlColList = ''
    var params = {}
    var isJoinRequired = false

    var originalRecord = queryExecute("
      SELECT * FROM #oq##variables.dbTable##cq# WHERE #oq##variables.key##cq# = :ftRecordId
      ",
      { ftRecordId: { value: ftRecordId } },
      { datasource: variables.datasource }
    )

    if (!originalRecord.recordCount) return { 'error': true, 'messages': ['Record ID #ftRecordId# not found.'] }

    for (col in variables.columns) {
      var editView = col.views.edit
      // If there's no db column specified, it's hidden, or it's display-only, skip it
      if (!editView.keyExists('name') || editView.hidden == true || editView.type == 'display') continue;

      // If there's a joinTable, we skip it because we need a separate query to update those records
      if (editView.keyExists('joinTable')) {
        isJoinRequired = true
        continue;
      }

      // Value must be present in the formData or it will be skipped
      if (!formData.keyExists(editView.name)) continue;

      var colValue = formData[editView.name]
      var originalValue = originalRecord[editView.name]

      // Skip columns that have not changed at all (use case sensitive comparison for strings)
      if ('varchar,nvarchar,text'.listFindNoCase(col.dataType)) {
        if (!colValue.compare(originalValue)) continue;
      } else if (colValue == originalValue) continue;

      sqlColList = sqlColList.listAppend(editView.name)
      sqlColValues = sqlColValues.listAppend(" #oq##editView.name##cq# = :#editView.name#")

      // If the column is nullable and the value is empty, set it to null
      var isNull = editView?.nullable == true && !colValue.len()

      params[editView.name] = isNull
        ? { isNull: true }
        : { value: colValue, cfsqltype: Util::sqlToCFSQLType(editView.dataType) }
    }

    // If there are any columns to update we do the update query
    if (!sqlColValues.len() && !isJoinRequired) return { 'error': false, 'messages': ['No columns required an update.'] }

    // Add the updated auditing fields, if they exist in baseSchemaColumns but not in columns
    if (variables.shouldAddField('updated_at', sqlColList)) {
      sqlColValues = sqlColValues.listAppend("#oq#updated_at#cq# = " & (dbType == 'mysql' ? 'NOW()' : 'GETDATE()'))
    }

    if (len(session?.identity) > 2 && len(session.identity) < 30 && variables.shouldAddField('updated_by', sqlColList)) {
      sqlColValues = sqlColValues.listAppend("#oq#updated_by#cq# = :filterTableUserUpdatedBy")
      params.filterTableUserUpdatedBy = { value: session.identity, cfsqltype: 'CF_SQL_VARCHAR', maxLength: 30 }
    }

    // I'm unsure why this is necessary
    var editTitleName = variables.getEditTitleName(originalRecord)

    if (sqlColValues.len()) {
      try {
        sql = "UPDATE #oq##variables.baseTable##cq# SET #sqlColValues# "

        sql &= variables.dbType == 'mysql'
          ? " WHERE #oq##variables.key##cq# = :ftRecordId;"
          : " OUTPUT INSERTED.* WHERE #oq##variables.key##cq# = :ftRecordId;"

        params.ftRecordId = { value: ftRecordId }

        var record = queryExecute(sql, params, { datasource: variables.editDatasource })

        // Since MySQL doesn't support "OUTPUT INSERTED", we need to fetch the record
        if (dbType == 'mysql') record = queryExecute(
          "SELECT * FROM #oq##variables.baseTable##cq# WHERE #oq##variables.key##cq# = :ftRecordId;",
          { ftRecordId: { value: ftRecordId } },
          { datasource: variables.datasource }
        )
      } catch (any e) {
        var msg = e.message
        if (len(e?.detail)) msg &= ' ' & e.detail
        return { 'error': true, 'messages': ['Error updating record: ' & msg] }
      }

      editTitleName = variables.getEditTitleName(record)
    }

    // Update any records in the joinTable for selected options. This only happens if joinTable is defined.
    for (col in variables.columns) {
      var editView = col.views.edit
      if (!editView.keyExists('joinTable')) continue;

      // Retrieve the existing records from the joinTable
      var existingRecords = queryExecute("
        SELECT #oq##editView.joinKey##cq#, #oq##editView.optionKey##cq# FROM #oq##editView.joinTable##cq#
        WHERE #oq##editView.joinKey##cq# = :ftRecordId
        ",
        { ftRecordId: { value: ftRecordId } },
        { datasource: variables.editDatasource }
      )

      // Convert the existing records to a struct for easy comparison
      var existingRecordsStruct = {}
      for (record in existingRecords) existingRecordsStruct[record[editView.optionKey]] = true

      var values = formData[editView.name].listToArray() ?: []
      // Values added from the form but not in existing records
      var newValues = []
      for (value in values) if (!existingRecordsStruct.keyExists(value)) newValues.append(value)

      // Values in existing records but not in the form
      var deletedValues = []
      for (value in existingRecordsStruct) if (!values.find(value)) deletedValues.append(value)

      // If records need to be deleted, delete records in existingValues but not in the form
      if (deletedValues.len()) var deleteQuery = queryExecute("
        DELETE FROM #oq##editView.joinTable##cq#
        WHERE #oq##editView.joinKey##cq# = :ftRecordId
        AND #oq##editView.optionKey##cq# IN (:deletedValues)
        ",
        {
          ftRecordId: { value: ftRecordId, cfsqltype: Util::sqlToCFSQLType(editView.joinKeyDataType) },
          deletedValues: { value: deletedValues.toList(), cfsqltype: Util::sqlToCFSQLType(editView.optionKeyDataType), list: true }
        },
        { datasource: variables.editDatasource }
      ) // end if deletedValues.len()

      if (newValues.len()) {
        var result = insertJoinTableData(ftRecordId, newValues, editView)
        if (result.error) return result
      } // end if newValues.len()
    }

    return { 'error': false, 'messages': [editTitleName & ' updated successfully.'] }
  } // end updateRecord()

} // end component FilterTable
</cfscript>