<cfscript>
/** General purpose utility functions that are available to all applications. */
 component {
  property name="PS" hint="Path separator for the current OS" default='\';
  property name="libraryPath" hint="Path for JavaLoader to load libraries from";
  // Barcode rendering variables/methods
  property name="loaderZX" hint="JavaLoader object for ZXing classes";
  property name="fmtCodaBar" hint="Reference to CodaBar barcode format";
  property name="fmtQRCode" hint="Reference to QR Code format";
  property name="codaBarWriter" hint="Java object for generating CODABAR barcodes";
  property name="qrCodeWriter" hint="Java object for generating QR codes";
  property name="qrHintMaps" hint="Hashtable instances for QR Code error correction";

  // Markdown rendering variables/methods
  property name="markdownParser" hint="Java object for parsing markdown";
  property name="markdownRenderer" hint="Java object for rendering markdown";

  /** Perform any initialization for the class. An instance of this is typically stored in server scope. */
  function init() {
    variables.PS = application.pathSeparator ?: '\'
    // Set the library path for JavaLoader
    variables.libraryPath = application.libraryPath ?: 'D:\inetpub\lib'

    // Load instance methods and variables for barcode and QR code generation
    variables.loadZxing()

    // Load the markdown library into two instance functions: markdownParser and markdownRenderer
    variables.loadMarkdown()

    return this
  }

  /**
   * Shortcut to create a method reference so a function can be called without needing to
   * specify the Util component name. For example, instead of:
   *  Util::fn(argument)
   *
   *  in Application.cfc, assign
   *  fn = Util::ref('fn')
   *  then in your code you can call
   *  fn(argument)
   */
  static function function ref(string methodName) {
    // TODO: Check if the method exists. Turns out to be a bit challenging
    return function() {
      return invoke('Util', methodName, { argumentCollection=arguments })
    }
  }

  /** Simple "dump and die" helper function for debugging */
  static void function dd(variable) {
    writeDump(variable)
    abort
  }

  /** Static method to represent the newline constant */
  static string function NL() { return chr(13) & chr(10) }

  /** A simple function to show an error message and abort the page. */
  static void function writeError(string heading, string message) {
    // Check if the current site is www2*, otherwise assume it's apps
    var isW2 = !!reFindNoCase('inetpub\\www2', getCurrentTemplatePath())

    if (!isDefined('heading') && !isDefined('message')) {
      heading = 'Error'
      message = 'An error has occurred.'
    } else if (!isDefined('message')) {
      message = arguments.heading
      heading = 'Error'
    } else if (!isDefined('heading')) heading = 'Error'

    if (isW2) if (!isDefined('pageTitle')) include '/w2Header.cfm'
    else if (!isDefined('app.initialized')) include '/Includes/appsHeader.cfm'

    writeOutput('<h2 class="text-2xl font-bold">#heading#</h2>')
    writeOutput('<p class="text-red-600 dark:text-red-500 my-4">#message#</p>')

    if (isW2) include '/w2Footer.cfm'
    else include '/Includes/appsFooter.cfm'

    abort
  }

  // Experimental: Create a case-sensitive struct that preserves the case of keys
  static struct function structCS(required struct data) {
    var struct = structNew('caseSensitive')
    data.each((key, value) => { struct[key] = value })
    return struct
  }

  /** Returns a struct with a error: false and an error message and aborts */
  static struct function errorStruct(string message = 'An error has occurred.') {
    // I'm unsure of why the struct key case is preserved here despite me not doing anything special to do so.
    return Util::structCS({ error: true, message, messages: [message] })
  }

  /** Outputs a data struct, array, etc. as JSON and aborts */
  static void function writeJSON(required any data) {
    setting showdebugoutput = false;
    cfheader(name: 'Content-Type', value: 'application/json')
    writeOutput(serializeJSON(data))
    abort
  }

  /** Return a JSON object that is the standard for error responses */
  static void function writeJSONError(string message = 'An error has occurred.') {
    writeJSON(Util::errorStruct(message))
  }

  /** Returns the a random string including lowercase & uppercase letters and numbers */
  static string function randString(numeric length = 9) {
    var str = ''
    for (var i = 1; i <= length; i++) {
      var rng = randRange(0, 2)
      str &= rng
        ? rng == 1 ? chr(randRange(65, 90)) : chr(randRange(97, 122)) // A-Z or a-z
        : chr(randRange(48, 57)) // 0-9
    }

    return str
  }

  /**
   * Checks that the specified variable name is set in both `form` and `url` scopes.
   * NOTE: This cannot be used statically and must be used as an instance of Util.
   * Generally, one is available to all pages called `util` in the variables scope,
   * which is a copy of the server.util in the server scope. Reset it at: /web/?resetUtil
   */
  void function syncPostAndUrlVars(required any variableList) {
    if (!isArray(variableList) && !isSimpleValue(variableList)) {
      throw('variableList must be a comma-separated string or an array.', 'InvalidArgumentTypeException')
    }

    var variables = isArray(variableList) ? variableList : variableList.listToArray()
    for (var v in variables) {
      if (form.keyExists(v) && !url.keyExists(v)) url[v] = form[v]
      else if (url.keyExists(v) && !form.keyExists(v)) form[v] = url[v]
    }
  }

  // Binary or bitwise functions

  /** Counts the number of one-bits set in a number using Brian Kernighan's efficient algorithm */
  static numeric function bitCount(numeric value) {
    var count = 0
    for (; value; count++) value = bitAnd(value, value - 1)
    return count
  }

  /** Converts IP addresses into binary used by the DB and returns branch code, if applicable */
  static string function getIPLocation(ipAddress) {
    // Use the vsd.IPOfficesHR_view view for human readable IP addresses
    var ipQuery = queryExecute("
      DECLARE @BinaryIP BINARY(4) =
        CAST(CAST(PARSENAME(:ip, 4) AS INT) AS BINARY(1)) +
        CAST(CAST(PARSENAME(:ip, 3) AS INT) AS BINARY(1)) +
        CAST(CAST(PARSENAME(:ip, 2) AS INT) AS BINARY(1)) +
        CAST(CAST(PARSENAME(:ip, 1) AS INT) AS BINARY(1));

      SELECT OfficeCode FROM vsd.IPOffices
        WHERE ScopeStart <= @BinaryIP AND ScopeEnd>= @BinaryIP
      ",
      { ip: {value: ipAddress, cfsqltype: 'CF_SQL_VARCHAR', maxlength: 16} }
    )

    return (ipQuery.recordCount > 0 && len(ipQuery.OfficeCode) > 0) ? ipQuery.OfficeCode : 'External'
  }

  /** Returns an array containing a range of numbers from start to end */
  static array function rangeNumeric(required numeric start, required numeric end) {
    var range = []
    if (start < end) for (var i = start; i <= end; i++) range.append(i)
    else for (var i = start; i >= end; i--) range.append(i)

    return range
  }

  /** Returns an array of letters from start to end or from */
  static array function rangeAlpha(required string start, required string end) {
    var range = []
    var startChr = asc(arguments.start)
    var endChr = asc(arguments.end)

    if (startChr < endChr) for (var i = startChr; i <= endChr; i++) range.append(chr(i))
    else for (var i = startChr; i >= endChr; i--) range.append(chr(i))

    return range
  }

  /**
   * Allows either numeric or alpha ranges, with optional second argument.
   * If an 'end' argument is omitted, it is assumed to be 1 for numeric or 'a' for alpha.
   */
  static array function range(required start, end) {
    if (isNumeric(arguments?.start)) {
      if (!isDefined('end')) return rangeNumeric(1, start)
      if (isNumeric(end)) return rangeNumeric(start, end)
    }

    if (reFind('^[a-zA-Z]$', arguments?.start)) {
      if (!isDefined('end')) return rangeAlpha('a', start)
      if (reFind('^[a-zA-Z]$', arguments?.end)) return rangeAlpha(start, end)
    }

    throw('Invalid range arguments: ' & arguments.start & ', ' & arguments.end)
  }


  static string function randStringLowerAlpha(numeric length = 9) {
    var str = ''
    for (var i = 1; i <= length; i++) str &= chr(randRange(97, 122)) // a-z
    return str
  }

  static string function randStringLowerAlphanumeric(numeric length = 8) {
    var str = ''
    for (var i = 1; i <= length; i++) str &= chr(randRange(0, 1) ? randRange(97, 122) : randRange(48, 57))
    return str
  }

  /** Prints a filesize in human readable form. */
  static string function fileSize(required numeric size) {
    if (size >= 1048576) return numberFormat(size / 1048576, '999,999,999.9') & ' MB'

    if (size >= 1024) return numberFormat(size / 1024, '999,999,999') & ' kB'

    return numberFormat(size, '999,999,999') & ' B'
  }

  /**
   * Accepts a query and returns an array of values and labels. Used in AppInput and FilterTable.
   *
   * Accepts the following formats:
   * - An array of structs with value and label keys. This is the native format used internally.
   *   - e.g., `[ { value: 1, label: 'One' } ]`
   *
   * - An array of structs with one key or two keys, one of which is named value or label.
   *   This will be converted to an array of structs with value and label keys.
   *   - e.g., `[ { value: 1, name: 'One' }, { value: 2 } ]`
   *
   * - A query or array with `id` and `name` columns.
   *   This will be converted to an array of structs with value and label keys.
   *  - e.g., `SELECT id, name FROM blog_categories`
   *
   * - A query object with one column *or* two columns, one of which is named label or column.
   *   - e.g., `SELECT username FROM users`
   *   - or `SELECT username AS value, display_name FROM users`
   *
   * - A comma-separated list. This will be converted to an array of structs with the same value and label.
   *   - e.g., `'One,Two,Three'`
   *
   * - An array of values. This will be converted to an array of structs with the same value and label.
   *   e.g., `[1,2,3]`
   */
  static array function toValueLabelArray(required query query, string valueField='value', string labelField='label') {
    if (!query.recordCount) return []

    var colList = query.columnList

    // If the query only has one column, use it for both value and label
    if (colList.listLen() == 1) valueField = colList

    // If there are two fields, set the label field to the one that is not the value field or vice-versa
    if (colList.listLen() == 2) {
      if (!query.keyExists(valueField)) valueField = colList.listDeleteAt(colList.listFindNoCase(labelField))
      if (!query.keyExists(labelField)) labelField = colList.listDeleteAt(colList.listFindNoCase(valueField))
    }

    if (!query.keyExists(valueField)) {
      if (query.keyExists('id') && query.keyExists('name')) {
        valueField = 'id'
        labelField = 'name'
      } else throw('Value field "#valueField#" not found in query.')
    }

    return query.reduce((arr, row) => arr.append({
      'value': row[valueField],
      'label': row[labelField] ?: row[valueField]
    }), [])
  }

  /** Removes an item from a list and returns the modified list. Case-insensitive by default. */
  static string function listDelete(required string list, required string itemToDelete, boolean noCase = true) {
    var listIndex = noCase ? list.listFindNoCase(itemToDelete) : list.listFind(itemToDelete)
    return listIndex ? list.listDeleteAt(listIndex) : list
  }

  /** For completeness, the definititvely case-insensitive version of listDelete. */
  static string function listDeleteNoCase(required string list, required string itemToDelete) {
    return listDelete(list, itemToDelete, true)
  }

  // String helper functions

  /** Simple function to take a string and return the words with uppercase first letters */
  static string function titleCase(required string str, forceLowercase=false) {
    if (forceLowercase) str = lCase(str)
    return str.reReplace('\b([a-z])', '\U\1', 'ALL')
  }

  /** Truncates a string to a given length, ending on discrete words, adds an ellipsis if truncated */
  static string function truncateWords(required string str, required numeric maxLength, string ellipsis='&hellip;') {
    // If within maxLength, return as is
    if (len(str) <= maxLength) return str

    // Find the last space or hyphen before the length limit
    var match = str.reFind('(.{1,#maxLength#}[\s-])', 1, true)

    // If a match is found and it doesn't start at the first character (empty match), truncate up to that point
    if (match.pos[1]) return str.left(match.len[1] - 1) & ellipsis

    // If no truncation point is found (e.g., string is a long word), truncate to maxLength
    return str.left(maxLength) & ellipsis
  }

  /**
   *  Returns true if it makes sense to allow a redirect to the specified page.
   *  This mainly scans for instances of an include using appsHeader.cfm (script or tag)
   */
  static boolean function canRedirectFromPage(pageUrl) {
    // Only these file extensions are allowed to be redirected to
    var allowedExts = 'cfm|cfc|htm|html'

    // Ensure this path is a filesystem path (on Windows, for now)
    var path = reFindNoCase('[A-Z]:\\\w+', pageUrl) ? pageUrl : expandPath(pageUrl)

    // TODO: I should take into account redirects (cflocation), includes,
    // and figure out what page is ultimately loaded.

    // If a directory with no filename, allow it - these are typically app homepages
    var hasNoFilename = reFindNoCase('[\\\/][a-z0-9\-_]+[\\\/]?$', path)
    var hasNoFilenameWithParams = reFindNoCase('[\\\/][a-z0-9\-_]+[\\\/]?[?##]', path)
    if (hasNoFilename || hasNoFilenameWithParams) return true

    // Only allow .htm, .html, .cfm, or .cfc files and directories without files specified
    var hasAllowedFileExt = reFindNoCase('\.(#allowedExts#)$', path)
    var hasAllowedFileExtWithParams = reFindNoCase('\.(#allowedExts#)[?##]', path)
    if (!(hasAllowedFileExt || hasAllowedFileExtWithParams)) return false

    // Allow index files (often these include or redirect to something else, but are user-facing)
    var isIndexFile = reFindNoCase('[\\\/]index\.(#allowedExts#)', path)
    if (isIndexFile) return true

    // File or directory must exist
    if (!fileExists(path)) return false

    // Read the file and search for for an appsHeader include
    var fileObject = fileOpen(path)

    while (!fileIsEOF(fileObject)) {
      // The page includes the appsHeader, which means this is user facing
      if (reFindNoCase('include.*appsHeader\.cfm', fileReadLine(fileObject))) {
        fileClose(fileObject)
        return true
      }
    }

    fileClose(fileObject)
    return false
  } // end canRedirectFromPage()

  /**
   * Accepts a web address and returns it with (or without) http:// or https://
   * If no protocol identifier is in the string, 'http://' will be added.
   *
   * Sanitized user input URLs so that they link to external sites.
   *
   * Usage Examples:
   *
   * cleanURL('https://epl.com', 0) -> epl.com
   * cleanURL('epl.com') -> http://epl.com
   * cleanURL('https://epl.com') -> https://epl.com
   */
  static string function cleanURL(required string url, boolean returnProtocol=true) {
    // Grabs the protocol identifier from the URL, if there is one
    var protocol = lCase(url.reReplaceNoCase('(http[s]?://)(.*)', '\1'))

    // sets http:// as the default protocol identifier if it is less than 7 characters long
    if (len(protocol) <= 7) protocol = 'https://'

    // This gets the base URL without a trailing slash, if there is one
    var baseURL = url.reReplaceNoCase('(http[s]?://)?(.*?)\/?$', '\2')

    if (returnProtocol) return protocol & baseURL;

    return baseURL
  }

  /** Gets 1-12 from a case-insensitive partial or full month name. Unknown months return 0. */
  static numeric function monthNumber(str, boolean addPadding=true) {
    var pad = addPadding ? '0' : '';

    if (isNumeric(str)) return numberFormat(str, pad&'9')

    switch(lcase(left(str, 3))) {
      case 'jan': return pad&1
      case 'feb': return pad&2
      case 'mar': return pad&3
      case 'apr': return pad&4
      case 'may': return pad&5
      case 'jun': return pad&6
      case 'jul': return pad&7
      case 'aug': return pad&8
      case 'sep': return pad&9
      case 'oct': return 10
      case 'nov': return 11
      case 'dec': return 12
      default: return pad&0
    }
  }

  /** Accepts a weekday (2+ letters) and returns the ColdFusion weekday integer */
  static numeric function weekdayToNum(required string dayName) {
    // If we received a number just return it
    if (isNumeric(dayName)) return dayName

    switch(left(dayName, 2)) {
      case 'Su': return 1
      case 'M':
      case 'Mo': return 2
      case 'Tu': return 3
      case 'W':
      case 'We': return 4
      case 'Th': return 5
      case 'F':
      case 'Fr': return 6
      case 'Sa': return 7
      default: throw('Invalid weekday passed to weekdayToNum: ' & dayName)
    }
  } // end weekdayToNum()

  /**
   * Accepts a 24-hour hour and returns the 12-hour meridiem (AM or PM).
   * Format can be A, AM, am, a. a.m. (or PM variants)
   */
  static string function hourMeridiem(required numeric hour, string format='AM') {
    // Standardize PM to AM
    format = format.reReplace('P', 'A')

    // Change lowercase a or p to another letter (b) as switch doesn't consider case
    format = format.reReplace('[ap]', 'b', 'all')

    // 24 = midnight, 25 = 1am, 26 = 2am, etc.
    if (hour >= 24) hour -= 24

    switch (left(format, 3)) {
      case 'A.': return hour < 12 ? 'A.' : 'P.'
      case 'b.': return hour < 12 ? 'a.' : 'p.'
      case 'A': return hour < 12 ? 'A' : 'P'
      case 'b': return hour < 12 ? 'a' : 'p'
      case 'bm':
      case 'bb': return hour < 12 ? 'am' : 'pm'
      case 'A.M': return hour < 12 ? 'a.m.' : 'p.m.'
      case 'b.m': return hour < 12 ? 'a.m.' : 'p.m.'
      default: return hour < 12 ? 'AM' : 'PM'
    }
  } // end hourMeridiem()

  /** Accepts a 24-hour hour and returns the 12-hour hour. */
  static numeric function hourTo12(required numeric hour) {
    return hour % 12 || 12
  }

  /** Accepts 24-hour hour and returns 12-hour hour with meridiem */
  static string function hourTo12M(required numeric hour) {
    return hourTo12(hour) & ' ' & hourMeridiem(hour)
  }

  /** Accepts an integer, returns 12h formatted time range over one hour */
  static string function hourTo12hRange(numeric h) {
    return Util::hourTo12(h) & '-' & Util::hourTo12(h + 1) & Util::hourMeridiem(h, 'a')
  }

  /** Accepts NT Epoch Time (100s of ns since Jan 1 1601) returns a CF date */
  static date function ntTimeToEpoch(required numeric ntTime) {
    if (ntTime == 0) return createDate(1900, 01, 01)

    ntTime /= 10000000
    var epochNTDiff = dateDiff('s', createDate(1601, 01, 01), createDate(1970, 01, 01))
    var epoch = ntTime - epochNTDiff

    return dateAdd('s', epoch, dateConvert('utc2Local', 'January 1 1970 00:00'))
  }

  /**
   * Returns a pair of selects for hours and minutes.
   * Specify a prefix for input names, and a time to pre-select.
   * This could be a custom tag but is probably obsoleted by appInput with a time type.
   */
  static string function timePicker(string prefix='', string time='09:00') {
    var hour = timeFormat(time, 'H')
    var minute = timeFormat(time, 'm')
    var html = '<span class="timePicker">'
    html &= '<select name="#prefix#Hour" '
      & 'id="#prefix#Hour" class="hour" '
      & 'onchange="'
      // Add JS to selector to update the meridiem automatically
      & "document.getElementById('#prefix#Meridiem').innerHTML='&nbsp;'+(this.value<12?'AM':'PM')"
      & '" style="width:70px">'

    for (var h = 9; h <= 21; h++) {
      html &= '<option value="#h#" ' & (h == hour ? 'selected' : '') & '>' & hourTo12(h) & '</option>'
    }

    html &= '</select>'
    html &= '<span class="px-1">:</span>'
    html &= '<select name="#prefix#Minute" id="#prefix#Minute" class="minute" style="width:70px">'

    for (var m = 0; m <= 55; m += 5) {
      html &= '<option value="#m#" ' & (m == minute ? 'selected' : '') & '>#numberFormat(m, '09')#</option>'
      if (minute > m && minute < m + 5 && minute != 59) {
        html &= '<option value="#minute#" selected>#numberFormat(minute, '09')#</option>'
      }
    }

    html &= '<option value="59" ' & (minute == 59 ? 'selected' : '') & '>59</option>'
    html &= '</select>'

    html &= '<span id="#prefix#Meridiem" class="meridiem">&nbsp;' & Util::hourMeridiem(hour) & '</span>'
    html &= '</span>'

    return html
  } // end timePicker()

  /** Removes surrounding double quotes and unescape double quotes within a CSV value */
  private static string function dequote(string value) {
    value = trim(value)
    // If the value is empty or only contains one character, it can't be quoted
    if (len(value) < 2) return value

    if (left(value, 1) == '"' && right(value, 1) == '"') {
      value = value.mid(2, len(value) - 2)
      value = value.replace('""', '"', 'ALL')
    }

    return value
  }

  /** Parse a single line of a CSV, respecting quoted sections */
  private static array function csvLineToArray(string line) {
    var values = []
    var currentField = ''
    var inQuotes = false

    for (var i = 1; i <= len(line); i++) {
      var char = mid(line, i, 1);

      if (char == '"' && (i == 1 || mid(line, i - 1, 1) != '"')) inQuotes = !inQuotes
      else if (char == ',' && !inQuotes) {
        values.append(Util::dequote(currentField))
        currentField = ""
      } else currentField &= char
    }

    // Add the last field
    values.append(Util::dequote(currentField))
    return values
  }

  /** Reads CSV file and returns array of structs. Requires the first line to be a header. */
  static array function csvFileToArray(string filePath) {
    // Ensure file exists
    if (!fileExists(filePath)) throw("CSV File not found: " & filePath)

    // Read the CSV file content as a string and split into lines
    var lines = fileRead(filePath).listToArray(chr(10))

    // Check for empty file
    if (lines.isEmpty() || lines.len() <= 1) return []

    // Assume the first line contains headers
    var headers = lines[1].listToArray(',')

    // Remove the double quotes from the headers
    for (var i = 1; i <= headers.len(); i++) {
      headers[i] = Util::dequote(headers[i])
    }

    // Prepare an array to hold the data, pre-allocate size for performance
    var data = []
    data.resize(lines.len() - 1)

    // Process data starting from the second line
    for (var i = 1; i < lines.len(); i++) {
      var line = lines[i + 1]
      if (line == '') continue;

      var values = Util::csvLineToArray(line)
      var row = {}

      for (var j = 1; j <= headers.len(); j++) {
        row[headers[j]] = j <= values.len() ? dequote(values[j]) : ''
      }

      data[i] = row
    }

    return data
  }

  /**
   * Creates a CSV file from a query string.
   *
   *  Required arguments:
   *  filePath: Absolute path where file will be created:
   *      e.g. D:\inetpub\storage_staff\Folder\file.csv
   *
   *  queryString: Query from which file will be created.
   *     Format dates as "mmm dd, yyyy" for Excel compatibility.
   *      e.g. Select OfficeCode,OfficeName from vsd.Offices
   *
   *  fieldsList: Comma separated list of fields for the heading.
   *      e.g. Project,Name,Dept,EntryDate,CloseDate
   */
  static void function createCSV(
    required string filePath,
    required string queryString,
    required string fieldsList,
    numeric lineBufferSize=500
  ) {
    var fields = fieldsList.listToArray()
    var lineBuffer = ''
    var lineBufferCount = 0

    fileWrite(filePath, fieldsList & NL())

    for (var row in queryExecute(queryString.replace("''", "'", 'All'))) {
      var line = fields.map(field => '"' & replace(row[field], '"', '""') & '"').toList()

      lineBuffer &= (lineBufferCount++ ? NL() : '') & line

      if (lineBufferCount >= lineBufferSize) {
        fileAppend(filePath, lineBuffer)
        lineBuffer = ''
        lineBufferCount = 0
      }
    }

    // Write final lines
    fileAppend(filePath, lineBuffer)
  }

  /** Using the SQL data type, returns the appropriate CF_SQL type */
  static string function sqlToCFSQLType(required string sqlType) {
    sqlType = sqlType.trim().lCase()

    switch (sqlType) {
      case 'int':
        return 'CF_SQL_INTEGER'
      case 'tinyint':
        return 'CF_SQL_TINYINT'
      case 'smallint':
        return 'CF_SQL_SMALLINT'
      case 'bigint':
        return 'CF_SQL_BIGINT'
      case 'bit':
        return 'CF_SQL_BIT'
      case 'float':
        return 'CF_SQL_FLOAT'
      case 'real':
        return 'CF_SQL_REAL'
      case 'decimal': case 'numeric': case 'money': case 'smallmoney':
        return 'CF_SQL_DECIMAL'
      case 'char': case 'nchar': case 'varchar': case 'text':
        return 'CF_SQL_VARCHAR'
      case 'nvarchar': case 'ntext': case 'string':
        return 'CF_SQL_NVARCHAR'
      case 'date':
        return 'CF_SQL_DATE'
      case 'time':
        return 'CF_SQL_TIME'
      case 'datetime': case 'datetime2': case 'smalldatetime':
        return 'CF_SQL_TIMESTAMP'
      case 'binary': case 'varbinary': case 'image':
        return 'CF_SQL_BINARY'
      case 'uniqueidentifier':
        return 'CF_SQL_CHAR'
      default:
        throw('Unsupported SQL data type: ' & sqlType)
    }
  }

  /** Loads the ZXing Java library into the instance variables for barcodes generation */
  private void function loadZxing() {
    // TODO: Make this path configurable in the .appsenv file
    variables.loaderZX = new JavaLoader([
      variables.libraryPath & '#PS#zxing#PS#core-3.5.2.jar',
      variables.libraryPath & '#PS#zxing#PS#javase-3.5.2.jar'
    ])

    var barcodeFormat = variables.loaderZX.create('com.google.zxing.BarcodeFormat')

    variables.fmtCodaBar = barcodeFormat.CODABAR
    variables.fmtQRCode = barcodeFormat.QR_CODE
    variables.qrCodeWriter = variables.loaderZX.create('com.google.zxing.qrcode.QRCodeWriter')
    variables.codaBarWriter = variables.loaderZX.create('com.google.zxing.oned.CodaBarWriter')

    // Create hints maps for each mode of QR Code error correction
    variables.qrHintMaps = {}
    var errorLevels = ['L', 'M', 'Q', 'H']

    for (var level in errorLevels) {
      var hintsMap = variables.loaderZX.create('java.util.Hashtable')
      hintsMap.put(
        variables.loaderZX.create('com.google.zxing.EncodeHintType').ERROR_CORRECTION,
        variables.loaderZX.create('com.google.zxing.qrcode.decoder.ErrorCorrectionLevel')[level]
      )
      variables.qrHintMaps[level] = hintsMap
    }
  }

  /** Generates a barcode image from the given data.
   * TODO: Implement some kind of cache for frequently used codes.
   *
   * @param data The data to be encoded
   * @param width The width of the image
   * @param height The height of the image
   * @param type The type of barcode to generate (QR or CODABAR)
   * @param errorCorrection The error correction level for QR codes: L 7%, M 15%, Q 25%, H 30%
   * @return The generated image as a byte array
   */
  private any function getCode(
    required string data,
    numeric width=150,
    numeric height=150,
    string type='QR',
    string errorCorrection='L'
  ) {
    errorCorrection = uCase(errorCorrection)
    if (!listFind('L,M,Q,H', errorCorrection)) errorCorrection = 'L'

    var code = (type == 'CODABAR')
      ? variables.codaBarWriter.encode('A#data#A', variables.fmtCodaBar, width, height)
      : variables.qrCodeWriter.encode(data, variables.fmtQRCode, width, height, variables.qrHintMaps[errorCorrection])

    var bufferedImage = variables.loaderZX.create('com.google.zxing.client.j2se.MatrixToImageWriter').toBufferedImage(code)
    var imageStream = createObject('java', 'java.io.ByteArrayOutputStream').init()
    createObject('java', 'javax.imageio.ImageIO').write(bufferedImage, 'png', imageStream)
    return imageStream.toByteArray()
  }

  public any function getQRCode(required string data, numeric width=150, numeric height=150, string errorCorrection='L') {
    return variables.getCode(data, width, height, 'QR', errorCorrection)
  }

  public any function getBarcode(required string data, numeric width=350, numeric height=52) {
    return variables.getCode(data, width, height, 'CODABAR')
  }

  public string function getQRCodeBase64(required string data, numeric width=150, numeric height=150, string errorCorrection='L') {
    return toBase64(this.getQRCode(data, width, height, errorCorrection))
  }

  public string function getBarcodeBase64(required string data, numeric width=350, numeric height=52) {
    return toBase64(this.getBarcode(data, width, height))
  }

  /** Loads the Flexmark markdown library into markdownParser and markdownRenderer instance functions */
  private void function loadMarkdown() {
    var loader = new JavaLoader([
      variables.libraryPath & '#PS#flexmark#PS#flexmark-0.50.50.jar',
      variables.libraryPath & '#PS#flexmark#PS#flexmark-util-0.50.50.jar',
      variables.libraryPath & '#PS#flexmark#PS#flexmark-ext-autolink-0.50.50.jar',
      variables.libraryPath & '#PS#flexmark#PS#autolink-0.11.0.jar',
      variables.libraryPath & '#PS#flexmark#PS#flexmark-ext-tables-0.50.50.jar',
      variables.libraryPath & '#PS#flexmark#PS#flexmark-formatter-0.50.50.jar'
    ])

    var autolinkExtension = loader.create('com.vladsch.flexmark.ext.autolink.AutolinkExtension').create()
    var tablesExtension = loader.create('com.vladsch.flexmark.ext.tables.TablesExtension').create()

    var extensions = [autolinkExtension, tablesExtension]

    var parserBuilder = loader.create('com.vladsch.flexmark.parser.Parser').builder()
    var variables.markdownParser = parserBuilder.extensions(extensions).build()

    var rendererBuilder = loader.create('com.vladsch.flexmark.html.HtmlRenderer').builder()
    var variables.markdownRenderer = rendererBuilder.extensions(extensions).build()
  }

  /** Converts markdown to HTML. This is an instance method, so requires util to be instantiated. */
  public string function markdownToHTML(required string markdown) {
    var document = variables.markdownParser.parse(markdown)
    return variables.markdownRenderer.render(document)
  }

  /** Returns given struct with keys in lowercase. Useful when CF uppercases things when case matters */
  public static struct function lCaseKeys(struct inputStruct) {
    var result = {}
    for (var key in inputStruct) result[lCase(key)] = inputStruct[key]
    return result
  }

  /**
   * Returns a struct of arrays and structs based on names form fields.
   *
   * For example, if you have a form with the following fields:
   * item[1].name item[1].price item[2].name item[2].price
   *
   * buildFormCollections(form) returns
   * [ { name: 'Item One', price: 10 }, { name: 'Item Two', price: 20 } ]
   */
  public static any function buildFormCollections(required struct formScope) {
    var struct = {}

    formScope.each((field, value) => {
      var currentEl = struct
      var delimiterCount = 0

      // Loop over the field using . as the delimiter
      for (var el in field.listToArray('.')) {
        // If the current field piece has a bracket, determine the index and element name
        var tempIndex = el.contains('[') ? el.reReplace('.+\[|\]', '', 'all') : ''
        el = el.reReplace('\[.+\]', '', 'all')

        // If temp element exists, field is an array/struct. Can't use {} or [] in static context here.
        if (!currentEl.keyExists(el)) currentEl[el] = tempIndex == '' ? structNew() : arrayNew(1)

        // If this is the last element defined by dots in the field name, assign value to the variable
        if (++delimiterCount == field.listLen('.')) {
          if (tempIndex == '') currentEl[el] = value
          else currentEl[el][tempIndex] = value
        } else {
          // If this field was a struct, make the next element the current element for the next iteration
          if (tempIndex == '') currentEl = currentEl[el]
          else {
            if (!currentEl[el].isDefined(tempIndex)) currentEl[el][tempIndex] = {}
            currentEl = currentEl[el][tempIndex]
          }
        }
      }
    }) // end each in formScope

    return struct
  } // end buildFormCollections()
} // end component Util
</cfscript>