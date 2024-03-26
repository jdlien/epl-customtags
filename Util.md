<!-- prettier-ignore-file -->
# Util.cfc

Util is a library of utility functions that can be used in any application, mostly for simple but tedious tasks used in many places. This includes things like generating random strings, writing JSON, and converting month names to numbers. If you have a small, standalone utility function that can be used across multiple pages, this is a good place to put it.

Most functions in this library are static, with the exception of `markdownToHTML`, so you can call them without an instance of the Util component. For example, you can call `Util::randString()` without `new Util()`.

Application.cfc on apps/www2 should ensure a singleton instance of the Util component is available in the `server` scope and referenced in the variables scope, so you can also simply call `util.randString()`, however this is not recommended for the following reasons:

- The instance will not be updated until a server restart if Util.cfc changes
- The util instance could change names or go away

Using the instance is only recommended for instance functions, like `markdownToHTML` or barcode and QR functions which cannot be static.

## Table of Contents

- [ref](#refstring-methodName)
- [dd](#ddvariable)
- [NL](#NL)
- [writeError](#writeErrorstring-heading-string-message)
- [writeJSON](#writeJSONrequired-any-data)
- [writeJSONError](#writeJSONErrorstring-message--An-error-has-occurred)
- [randString](#randStringnumeric-length--9)
- [rangeNumeric](#rangeNumericrequired-numeric-start-required-numeric-end)
- [rangeAlpha](#rangeAlpharequired-string-start-required-string-end)
- [range](#rangerequired-start-end)
- [randStringLowerAlpha](#randStringLowerAlphanumeric-length--9)
- [randStringLowerAlphanumeric](#randStringLowerAlphanumericnumeric-length--8)
- [fileSize](#fileSizerequired-numeric-size)
- [toValueLabelArray](#toValueLabelArrayrequired-query-query-string-valueFieldvalue-string-labelFieldlabel)
- [listDelete](#listDeleterequired-string-list-required-string-itemToDelete-boolean-noCase)
- [listDeleteNoCase](#listDeleteNocaserequired-string-list-required-string-itemToDelete)
- [canRedirectFromPage](#canRedirectFromPagepageUrl)
- [cleanURL](#cleanURLrequired-string-url-boolean-returnProtocoltrue)
- [monthNumber](#monthNumberstr-boolean-addPaddingtrue)
- [weekdayToNum](#weekdayToNumrequired-string-dayName)
- [hourMeridiem](#hourMeridiemrequired-numeric-hour-string-formatAM)
- [hourTo12](#hourTo12required-numeric-hour)
- [hourTo12M](#hourTo12Mrequired-numeric-hour)
- [ntTimeToEpoch](#ntTimeToEpochrequired-numeric-ntTime)
- [timePicker](#timePickerstring-prefix-string-time0900)
- [createCSV](#createCSVrequired-string-filePath-required-string-queryString-required-string-fieldsList-numeric-lineBufferSize500)
- [sqlToCFSQLType](#sqlToCFSQLTyperequired-string-sqlType)
- [getQRCode](#getQRCoderequired-string-data-numeric-width150-numeric-height150-string-errorCorrectionL)
- [getBarcode](#getBarcoderequired-string-data-numeric-width350-numeric-height52)
- [getQRCodeBase64](#getQRCodeBase64required-string-data-numeric-width150-numeric-height150-string-errorCorrectionL)
- [getBarcodeBase64](#getBarcodeBase64required-string-data-numeric-width350-numeric-height52)
- [markdownToHTML](#markdownToHTMLrequired-string-markdown)
- [lCaseKeys](#lCaseKeysstruct-inputStruct)
- [buildFormCollections](#buildFormCollectionsrequired-struct-formScope)

## Functions

### `ref(string methodName)`

**Purpose**: Creates a method reference, enabling the function to be called without specifying the `Util` component name.

**Example Usage**:

```js
fn = Util::ref('fn')
fn(argument)
```

---

### `dd(variable)`

**Purpose**: A "dump and die" function for debugging.

**Example Usage**:

```js
dd(variableToInspect)
```

---

### `NL()`

**Purpose**: Returns the newline constant.

**Example Usage**:

```js
newLine = Util::NL()
```

---

### `writeError(string heading, string message)`

**Purpose**: Outputs an error message and aborts the page.

**Example Usage**:

```js
Util::writeError('Error Heading', 'Error Message')
```

---

### `writeJSON(required any data)`

**Purpose**: Outputs a data structure, as JSON and aborts the request.

**Example Usage**:

```js
Util::writeJSON({key: 'value'})
```

---

### `writeJSONError(string message = 'An error has occurred.')`

**Purpose**: Returns a JSON object that is the standard for error responses.

**Example Usage**:

```js
Util::writeJSONError('Custom Error Message')
// Returns
// {
//   error: true,
//   messages: ['Custom Error Message'],
//   message: 'Custom Error Message'
// }
```

---

### `randString(numeric length = 9)`

**Purpose**: Returns a random string containing mixed-case letters and numbers.

**Example Usage**:

```js
randomStr = Util::randString(12)
```

---

### `rangeNumeric(required numeric start, required numeric end)`

**Purpose**: Returns an array containing a range of numbers from `start` to `end`. Used by `range` function.

**Example Usage**:

```js
numericRange = Util::rangeNumeric(1, 5) // Returns [1, 2, 3, 4, 5]
```

---

### `rangeAlpha(required string start, required string end)`

**Purpose**: Returns an array of letters from `start` to `end`. Used by `range` function.

**Example Usage**:

```js
alphaRange = Util::rangeAlpha('a', 'e') // Returns ['a', 'b', 'c', 'd', 'e']
```

---

### `range(required start, end)`

**Purpose**: A flexible array generator allowing either numeric or alpha ranges. Can be used with a single argument to start from '1' or 'a'. Can output in reverse order by calling with larger values first.

**Example Usage**:

```js
Util::range(4)
// Returns [1, 2, 3, 4]

Util::range(2, 5)
// Returns [2, 3, 4, 5]

Util::range('e', 'a')
// Returns ['e', 'd', 'c', 'b', 'a']
```

---

### `randStringLowerAlpha(numeric length = 9)`

**Purpose**: Returns a random string containing only lowercase alphabets.

**Example Usage**:

```js
randomStr = Util::randStringLowerAlpha(12)
```

---

### `randStringLowerAlphanumeric(numeric length = 8)`

**Purpose**: Returns a random string containing lowercase alphabets and numbers.

**Example Usage**:

```js
randomStr = Util::randStringLowerAlphanumeric(9)
```

---

### `fileSize(required numeric size)`

**Purpose**: Converts a file size in bytes to a human-readable string representation.

**Example Usage**:

```js
readableSize = Util::fileSize(1024) // Returns "1 kB"
```

---

### `toValueLabelArray(required query query, string valueField='value', string labelField='label')`

**Purpose**: Transforms a query into an array of value-label pairs. This is used in AppInput and FilterTable components to homogenize the input of options.

Accepts the following formats:
- An array of structs with value and label keys. This is the native format used internally.
<br>e.g., `[ { value: 1, label: 'One' } ]`

- An array of structs with one key or two keys, one of which is named value or label. This will be converted to an array of structs with value and label keys.
<br>e.g., `[ { value: 1, name: 'One' }, { value: 2 } ]`

- A query or array with `id` and `name` columns.
   This will be converted to an array of structs with value and label keys.
<br>e.g., `SELECT id, name FROM blog_categories`

- A query object with one column *or* two columns, one of which is named label r column.
<br>e.g., `SELECT username FROM users`
- or `SELECT username AS value, display_name FROM users`

- A comma-separated list. This will be converted to an array of structs with he same value and label.
<br>e.g., `'One,Two,Three'`

- An array of values. This will be converted to an array of structs with the ame value and label.
<br>e.g., `[1,2,3]`

**Example Usage**:

```js
valueLabelArray = Util::toValueLabelArray(myQuery)
```

---

### `listDelete(required string list, required string itemToDelete, boolean noCase = true)`

**Purpose**: Removes an item from a list, case-insensitive by default.

**Example Usage**:

```js
modifiedList = Util::listDelete('apple,orange,banana', 'orange')
```

---

### `listDeleteNoCase(required string list, required string itemToDelete)`

**Purpose**: Case-insensitive version of `listDelete`.

**Example Usage**:

```js
modifiedList = Util::listDeleteNoCase('Apple,orange,Banana', 'orange')
```

---

### `canRedirectFromPage(pageUrl)`

**Purpose**: Checks if it's safe to redirect to a specific page. Used in redirection from OAuth login pages.

**Example Usage**:

```js
if (Util::canRedirectFromPage('/some/page.cfm')) {
  // Safe to redirect
}
```

---

### `cleanURL(required string url, boolean returnProtocol=true)`

**Purpose**: Cleans up and standardizes a URL, optionally returning the protocol.

**Example Usage**:

```js
cleanedUrl = Util::cleanURL('https://example.com')
```

---

### `monthNumber(str, boolean addPadding=true)`

**Purpose**: Returns the numerical month from a given string.

**Example Usage**:

```js
monthNum = Util::monthNumber('January') // Returns 01
```

---

### `weekdayToNum(required string dayName)`

**Purpose**: Converts a weekday name to its ColdFusion integer representation.

**Example Usage**:

```js
dayNum = Util::weekdayToNum('Monday') // Returns 2
```

---

### `hourMeridiem(required numeric hour, string format='AM')`

**Purpose**: Returns the 12-hour meridiem (AM or PM) for a given 24-hour time.

**Example Usage**:

```js
meridiem = Util::hourMeridiem(15) // Returns 'PM'
```

---

### `hourTo12(required numeric hour)`

**Purpose**: Converts a 24-hour format hour to a 12-hour format.

**Example Usage**:

```js
twelveHour = Util::hourTo12(15) // Returns 3
```

---

### `hourTo12M(required numeric hour)`

**Purpose**: Returns the 12-hour format with the meridiem.

**Example Usage**:

```js
twelveHourM = Util::hourTo12M(15) // Returns '3 PM'
```

---

### `ntTimeToEpoch(required numeric ntTime)`

**Purpose**: Converts NT Epoch Time to a ColdFusion date object. This is used to convert the AD last password reset time to a date format that is easier to work with.

**Example Usage**:

```js
cfDate = Util::ntTimeToEpoch(132537600000000000)
```

---

### `timePicker(string prefix='', string time='09:00')`

**Purpose**: Returns a pair of HTML select elements for picking hours and minutes. This will likely be replaced by an AppInput type="time" component along with FlatPickr.

**Example Usage**:

```js
timePickerHTML = Util::timePicker('prefix_', '15:30')
```

---

### `createCSV(required string filePath, required string queryString, required string fieldsList, numeric lineBufferSize=500)`

**Purpose**: Generates a CSV file from a query string and saves it to the given file path.

**Example Usage**:

```js
Util::createCSV(filePath, queryString, 'Column1,Column2')
```

---

### `sqlToCFSQLType(required string sqlType)`

**Purpose**: Maps SQL data types to their corresponding ColdFusion SQL types.

**Example Usage**:

```js
cfSqlType = Util::sqlToCFSQLType('int') // Returns 'CF_SQL_INTEGER'
```

---

### `markdownToHTML(required string markdown)`

**Purpose**: Converts markdown text to HTML. This must be run as an instance method as it requires the instance's parser and renderer.

**Example Usage**:

```js
// Assuming util is an instance of Util set in Application.cfc...
htmlText = util.markdownToHTML('# Heading')
```

---

### `getQRCode(required string data, numeric width=150, numeric height=150, string errorCorrection='L')`

**Purpose**: Generates a QR code image from the given data.

**Example Usage**:

```js
qrCodeImage = util.getQRCode('https://example.com/', 200, 200, 'M')
```

---

### `getBarcode(required string data, numeric width=350, numeric height=52)`

**Purpose**: Generates a CODABAR barcode image from the given data.

**Example Usage**:

```js
<cfcontent reset="true" variable="#util.getBarcode('1234567890', 350, 52)#" type="image/png"/>
```

---

### `getQRCodeBase64(required string data, numeric width=150, numeric height=150, string errorCorrection='L')`

**Purpose**: Generates a QR code image from the given data and returns it as a Base64 encoded string.

**Example Usage**:

```js
qrCodeBase64 = util.getQRCodeBase64('https://example.com/', 200, 200, 'M')
```

---

### `getBarcodeBase64(required string data, numeric width=350, numeric height=52)`

**Purpose**: Generates a CODABAR barcode image from the given data and returns it as a Base64 encoded string.

**Example Usage**:

```js
barcodeBase64 = util.getBarcodeBase64('1234567890', 350, 52)
writeOutput('<img src="data:image/png;base64,#barcodeBase64#" />')
--
```

---

### `lCaseKeys(struct inputStruct)`

**Purpose**: Converts all keys in a struct to lowercase.

**Example Usage**:

```js
lowerKeysStruct = Util::lCaseKeys(myStruct)
```

---

### `buildFormCollections(required struct formScope)`

**Purpose**: Transforms a struct of form fields into a more structured collection.

**Example Usage**:

```js
formCollection = Util::buildFormCollections(form)
```

---

Please extend this documentation as new utility functions are added to the library.