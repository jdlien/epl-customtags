/**
 * FilterTableSettings contains the user settings for a FilterTable object, including
 *  - the filter settings for each column
 *  - the sort settings
 *  - the pagination settings
 *  - the permissions for the current application
 *
 *  When a user interacts with a FilterTable, the FilterTableSettings object is updated
 *  and saved in the user's session. When the FilterTable is rendered, it can be passed the
 *  FilterTableSettings object to determine how to render the table.
 */
component accessors="true" invokeImplicitAccessor="true" {
  property name="templateHash" type="string"
    hint="Name for cached instance based on hash of path for the cfm using this component.";
  property name="currentPage" type="numeric" setter=true
    hint="The current page number. pg is the URL parameter.";
  property name="rowsPerPage" type="numeric" setter=true
    hint="Number of records per page. Set to 0 to disable pagination. rows is the URL parameter.";
  property name="sort1" type="string" setter=true
    hint="The column to sort by.";
    property name="sort1Desc" type="boolean" setter=true
    hint="The sort order of sort1.";
  property name="sort2" type="string" setter=true
    hint="The secondary sort column.";
    property name="sort2Desc" type="boolean" setter=true default=false
    hint="The sort order of sort2.";
  property name="search" type="string" setter="false" default=""
    hint="The search string used for the global multi-column search.";
  property name="showFilter" type="boolean"
    hint="Whether to show the advanced filter options.";
  property name="filters" type="struct" setter=false
    hint="A struct of filters for each column.";
  property name="permissions" type="struct"
    hint="Permissions for the current application which will determine access to features."

  /** Constructor */
  public any function init(
    struct formData = {},
    struct permissions = {},
    numeric currentPage = 1,
    numeric rowsPerPage,
    string sort1 = '',
    boolean sort1Desc,
    string sort2 = '',
    boolean sort2Desc,
    struct filters = {},
    string search = ''
  ) {
    variables.currentPage = currentPage
    // If rowsPerPage is not set, filterTable will use the default it has set for that instance.
    if (arguments.keyExists('rowsPerPage')) this.setRowsPerPage(rowsPerPage)

    // Sort columns will be validated by filterTable when constructing the actual query,
    // so the need to validate them here is minimal.

    // Default to the last sort column for the secondary sort.
    if (len(variables?.sort1) && variables.sort1 != sort1) {
      variables.sort2 = variables.sort1
      variables.sort2Desc = variables.sort1Desc
    } else variables.sort2 = ''

    if (arguments.keyExists('sort1')) variables.sort1 = sort1
    if (arguments.keyExists('sort1Desc')) variables.sort1Desc = sort1Desc

    // We can override the secondary sort column, but normally it'll be the last sort1.
    if (len(sort2)) {
      variables.sort2 = sort2
      variables.sort2Desc = sort2Desc
    }

    variables.search = arguments.search
    variables.filters = arguments.filters
    variables.permissions = arguments.permissions
    // Set the templateHash that is used for the session variable
    this.setTemplateHash()

    // Apply any settings from formData
    if (!formData.isEmpty()) this.setFromForm(formData)

    // Save this settings instance into the session so it can be retrieved later
    session[variables.templateHash] = this

    return this
  } // end init()

  /**
   * Sets the template hash property used for application/session variables.
   * Can be overridden for testing purposes, but defaults to the hash of the template path.
   */
  public void function setTemplateHash(string templatePath = '') {
    variables.templateHash = len(templatePath) ? templatePath : 'filterTable_' & hash(getBaseTemplatePath())
  }

  /** Normalizes the rowsPerPage property to a positive integer */
  public void function setRowsPerPage(required numeric rowsPerPage) {
    variables.rowsPerPage = abs(floor(rowsPerPage))
  }

  /**
   * Sets the view property struct from any URL parameters, if present.
   * If the url contains a filter parameter, the view will be restored from session.
   */
  public FilterTableSettings function setFromForm(required struct formData = url) {
    if (isNumeric(formData?.pg)) variables.currentPage = abs(floor(formData.pg))
    if (isNumeric(formData?.rows)) variables.rowsPerPage = abs(floor(formData.rows))


    // Typically sort2 will not be set via URL and will default to the previous sort1.
    // If the sort1 has changed, we need to set sort2 to the previous sort1.
    if (len(variables?.sort1) && reReplace(formData?.sort1, '-$', '') != variables.sort1) {
      variables.sort2 = variables.sort1
      variables.sort2Desc = variables.sort1Desc
    }

    // Set the primary sort column or blank it to use the default for the filterTable.
    variables.sort1 = len(formData?.sort1) ? reReplace(formData.sort1, '-$', '') : ''
    variables.sort1Desc = len(formData?.sort1) && right(formData.sort1, 1) == '-' ? true : false

    if (len(formData?.sort2)) {
      variables.sort2 =  reReplace(formData.sort2, '-$', '')
      variables.sort2Desc = right(formData.sort2, 1) == '-' ? true : false
    }

    // Set the search string
    variables.search = formData?.search ?: ''

    // Save advanced filter settings
    variables.showFilter = formData.keyExists('showFilter')

    // Reset the filters struct
    variables.filters = {}

    boolean function setFilter(string prefix, string property) {
      if (left(param, len(prefix)) == prefix) {
        variables.filters[param.replaceNoCase(prefix, '')][property] = formData[param]
        return true
      }
      return false
    }

    // Loop through the keys of formData and set the filters with all potential types of values.
    for (param in formData) {
      switch (true) {
        case setFilter('flt_',      'value'):
        case setFilter('fltFrom_',  'from'):
        case setFilter('fltTo_',    'to'):
        case setFilter('fltYear_',  'year'):
        case setFilter('fltMonth_', 'month'):
        case setFilter('fltDay_',   'day'):
          continue;
      }
    }

    return this
  } // end setFromForm()

  /** Resets settings to default values */
  public FilterTableSettings function reset() {
    this.init(permissions: variables.permissions)

    // This will be set to the previous sort1 in init, so we need to reset it.
    variables.sort1 = ''
    variables.sort2 = ''
    variables.delete('sort1Desc')
    variables.delete('sort2Desc')
    variables.delete('rowsPerPage')
    variables.delete('showFilter')

    return this
  }

  /** Resets only the filters to an empty struct */
  public void function resetFilters() {
    variables.search = ''
    variables.filters = {}
  }

} // end component FilterTableSettings
