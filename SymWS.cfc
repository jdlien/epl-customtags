/** Wrapper for Symphony Web Services and ILS related functionality. */
component {
  property name="wsUrl"            type="string"
    default="https://sdmtlws01.sirsidynix.net/edpl_ilsws"
    hint="Protocol, host, and root path for production Symphony Web Services API endpoints.";
  property name="wsUrlDev"         type="string"
    default="https://sdmtlws01.sirsidynix.net/edpltest_ilsws"
    hint="Protocol, host, and root path for DEVELOPMENT Symphony Web Services API endpoints.";
  property name="dev"              type="boolean"
    default="false"
    hint="Specify whether we want to use dev or production endpoints.";
  property name="sessionToken"     type="string"
    default=""
    hint="If one is not provided, an access token will be acquired for the API that is used for all requests.";
  property name="minBarcodeLength" type="numeric"
    default="5"
    hint="Don't allow the use of Symphony Web Services with barcodes shorter than this.";
  property name="maxBarcodeLength" type="numeric"
    default="20"
    hint="Don't allow the use of Symphony Web Services with barcodes longer than this.";
  property name="maxAttempts"      type="numeric"
    default="15"
    hint="The maximum number of attempts a user has to login. If they exceed this within lockoutMinutes,
    they are prevented from being able to log in.";
  property name="lockoutMinutes"   type="numeric"
    default="60"
    hint="The number of minutes over which a user may not exceed the maxAttempts login failures.";
  property name="allowedProfiles"  type="string"
    default="EPL_ADULT,EPL_ADU01,EPL_ADU05,EPL_ADU10,EPL_ONLIN,EPL_LIFE,EPL_STAFF,EPL_XDLOAN"
    hint="The profiles we allow to login. For certain applications, certain profiles may be allowed or disallowed";
  property name="appID"            type="string"
    default="apps.epl.ca"
    hint="Allow auditing by grouping all the requests from apps/www2 under a single name.";
  property name="error"            type="boolean"
    default="false"
    hint="Specifies whether an error condition has occurred.";
  property name="errorMessage"     type="string"
    default="There is a problem accessing ILS data with Symphony Web Services."
    hint="The error message to show users.";

  // Credentials stored in .appsenv file in the root of apps.epl.ca and www2.epl.ca projects
  property name="configFile"       type="string" default="/../.appsenv"
    hint="Path to the config file that contains the Symphony Web Services credentials.";
  property name="SymWSClientID"    type="string"
    hint="Required by Symphony Web Services.";
  property name="SymWSUser"        type="string"
    hint="Username to log in and get a sessionToken.";
  property name="SymWSPass"        type="string"
    hint="Password to log in and get a sessionToken.";

  /** On init, determine if using dev mode and ensure we have a token. */
  public function init(boolean dev=false, string sessionToken='') {
    // Get the config file path
    var configPath = expandPath(variables.configFile)
    variables.SymWSClientID = getProfileString(configPath, 'credentials', 'SYMWS_CLIENT_ID')
    variables.SymWSUser = getProfileString(configPath, 'credentials', 'SYMWS_USER')
    variables.SymWSPass = getProfileString(configPath, 'credentials', 'SYMWS_PASS')

    variables.dev = dev
    if (dev) variables.wsUrl = variables.wsUrlDev

    setSessionToken(sessionToken)

    return this
  } // end init()

  /** Getters */
  public string function getWsUrl() { return variables.wsUrl }
  public boolean function getDev() { return variables.dev }
  public string function getAllowedProfiles() { return variables.allowedProfiles }
  public string function getSessionToken() { return variables.sessionToken }

  /** Set allowed profiles for this session to limit who may authenticate successfully. */
  public void function setAllowedProfiles(required string profileList) {
    variables.allowedProfiles = profileList
  }

  /** Returns a random string of the specified length from selected alphanumeric characters. */
  public string function makePin(numeric length = 8) {
    var str = ''
    var chars = 'abcdfghjkmnpqrstvwxyz123456789'
    for (var i = 0; i < length; i++) str &= mid(chars, randRange(1, len(chars)), 1)
    return str
  }

  /**
   * Checks if fileContent returned from an HTTP request contains valid JSON and
   * whether or not the data contains an error condition.
   * Optionally checks that a certain property is defined.
   *
   * If errors are found, they will be appended to the data struct's messages property.
   */
  public struct function validateContent(string content, string requiredProperty) {
    if (!isJSON(content)) return { error: true, messages: [content] }

    resultData = deserializeJSON(content)

    if (isDefined('resultData.faultResponse')) return {
      error: true,
      code: resultData.faultResponse.code ?: '',
      messages: [resultData.faultResponse.string ?: 'There was a problem with the request.']
    }

    if (len(arguments?.requiredProperty) && !resultData.keyExists(requiredProperty)) return {
      error: true,
      messages: [requiredProperty & ' was not returned from Symphony Web Services.']
    }

    return { error: false }
  } // end validateContent()

  /**
   * Check that the HTTP response from the server was valid JSON and doesn't have any errors.
   * If this returns a struct with error == true, things should be good.
   * If you want to be sure a certain property is defined, pass its name as a second argument.
   * Returns struct with an array of error messages.
   */
  public struct function validateResponse(required struct responseData, string requiredProperty = '') {
    // Initialize response struct without a default statusCode
    var data = { error: true, messages: [], statusCode: '' }

    // Check for a response code within responseData and compare against only the numbers from the code.
    if (responseData.keyExists('Statuscode')) data.statusCode = responseData.Statuscode.replaceAll('\D', '')
    else if (responseData.keyExists('ResponseHeader') && responseData.ResponseHeader.keyExists('Status_Code')) {
      data.statusCode = responseData.ResponseHeader.Status_Code.replaceAll('\D', '')
    }

    // Default statusCode to '200' if not set
    if (!len(data?.statusCode)) data.statusCode = '200'

    // Update the data based on errorDetail or fileContent
    if (responseData.keyExists('errorDetail')) data.messages.append(responseData.errorDetail)

    if (responseData.keyExists('fileContent')) data.append(validateContent(responseData.fileContent, requiredProperty))

    if (data.error) data.messages.append('There was a problem communicating with Symphony Web Services.')

    return data
  } // end validateResponse()


  /** Sets a session token required for authentication. If one isn't passed, requests a new one. */
  public void function setSessionToken(string sessionToken = '') {
    // Set a token if one was passed
    if (len(arguments?.sessionToken)) {
      variables.sessionToken = trim(sessionToken)
      return
    }

    // If we already have a valid token, just use that.
    if (len(variables.sessionToken)) return;

     // Else we fetch a new token from Symphony Web Services
    cfhttp(method: 'POST', charset: 'utf-8', url: '#variables.wsUrl#/rest/security/loginUser', result: 'result')
    {
      cfhttpparam(type: 'header', name: 'Accept', value: 'application/json')
      cfhttpparam(type: 'header', name: 'Content-Type', value: 'application/x-www-form-urlencoded')
      cfhttpparam(type: 'header', name: 'SD-Originating-App-Id', value: variables.appID)
      cfhttpparam(type: 'header', name: 'X-sirs-clientID', value: variables.SymWSClientID)
      cfhttpparam(type: 'formfield', name: 'login', value: variables.SymWSUser)
      cfhttpparam(type: 'formfield', name: 'password', value: variables.SymWSPass)
    }

    validate = validateResponse(result, 'sessionToken')

    if (validate.error == true) throw('Error getting session token: ' & validate.messages.toList())

    variables.sessionToken = deserializeJSON(result.fileContent).sessionToken
   } // end setSessionToken()

  /**
  * Gets detailed information about a specific patron given a card number.
  * @barcode	EPL library card number (almost always, but not necessarily numeric)
  * @dev 		Specify whether using development server. Default="no"
  * @sessionToken If a token already exists from a previous session, it can be passed here
   * 		to avoid having to get a new token
  */
  public struct function patronInfo(required string barcode, boolean dev=variables.dev) {
    // Here's where we store payload data.
    var data = {}
    // Default to error condition. We set this to false if we're about to succeed.
    var data.error = true
    // Array of messages
    var data.messages = []

    // Clean any spaces from the card number.
    barcode = reReplace(barcode, '\s', '', 'all')

    // Check if the length suggests a valid card number
    if (len(barcode) < variables.minBarcodeLength) {
      data.error = true
      if (len(barcode) == 0) data.messages.append('No card number entered.')
      else data.messages.append('Card number is too short (#len(barcode)# characters).')

      return data
    }

    // We are set up and ready to request the patron info.
    cfhttp(method: 'POST', charset: 'utf-8', url: '#variables.wsUrl#/rest/patron/lookupPatronInfo', result: 'result')
    {
      cfhttpparam(type: 'header', name: 'Accept', value: 'application/json')
      cfhttpparam(type: 'header', name: 'Content-Type', value: 'application/x-www-form-urlencoded')
      cfhttpparam(type: 'header', name: 'SD-Originating-App-Id', value: variables.appID)
      cfhttpparam(type: 'header', name: 'X-sirs-clientID', value: variables.SymWSClientID)
      cfhttpparam(type: 'header', name: 'X-sirs-sessionToken', value: variables.sessionToken)
      cfhttpparam(type: 'formfield', name: 'includePatronInfo', value: 'true')
      cfhttpparam(type: 'formfield', name: 'includePatronStatusInfo', value: 'true')
      cfhttpparam(type: 'formfield', name: 'includePatronAddressInfo', value: 'true')
      cfhttpparam(type: 'formfield', name: 'includePatronCirculationInfo', value: 'true')
      cfhttpparam(type: 'formfield', name: 'userID', value: barcode)
    }

    // Validate response
    validate = validateResponse(result, 'patronInfo')
    if (validate.error == true) return validate

    resultData = deserializeJSON(result.fileContent)

    // We are good, set the user info
    data.error = false
    customer = {}

    customer.barcode = barcode
    customer.name = resultData.patronInfo.displayName
    customer.first = customer.name.reReplace('.*, (.*)', '\1')
    customer.last = customer.name.reReplace('(.*), .*', '\1')
    customer.fullName = customer.first&' '&customer.last
    customer.dept = resultData.patronInfo.department
    // Create blank fields to ensure that they are all defined
    customer.careOf = ''
    customer.cityState = ''
    customer.city = ''
    customer.province = ''
    customer.postal = ''
    customer.address = ''
    customer.phone = ''
    customer.email = ''

    // Loop through the Address Array and fill in all the data based on the field name
    for (info in resultData.patronAddressInfo.Address1Info) {
      switch (lCase(info.addressPolicyDescription)) {
        case 'c/o':
          customer.careOf = info.addressValue
          break;

        case 'city, state':
          customer.city = info.addressValue.reReplace('(.*), \w+', '\1')
          customer.province = info.addressValue.reReplace('.*, (\w+)', '\1')
          break;

        case 'postal code':
          customer.postal = info.addressValue
          break;

        case 'street':
          customer.address = info.addressValue
          break;

        case 'phone':
          customer.phone = info.addressValue
          break;

        case 'email':
          customer.email = info.addressValue
          break;

        default:
          customer[info.addressPolicyDescription.reReplace('[\s,/.]', '', 'all')] = info.addressValue
      }
    }// end for

    // Note: This status will later be overwritten with the "standing"
    customer.status = resultData.patronStatusInfo.statusType

    // Ensure Status is acceptable (OK or DELINQUENT)
    if (customer.status != 'OK' && customer.status != 'DELINQUENT' && customer.status != 'BLOCKED') {
      arrayAppend(data.messages, 'Status is '&customer.status)
    }

    // Ensure card is not expired
    if (isDefined('resultData.patronStatusInfo.datePrivilegeExpires')) {
      customer.expiry = resultData.patronStatusInfo.datePrivilegeExpires
        // if we NEED an expiry, make one up customer.expiry='1914-01-01'
      if (dateCompare(customer.expiry, now()) < 1) data.messages.append('This card expired #customer.expiry#.')
    }// if expiry defined

    // Ensure card is not LOST
    if (customer.dept == 'LOST') {
      arrayAppend(data.messages, 'This card has been flagged as lost')
      data.error = true
    }

    // New fields (address, etc) - 2018-05-31
    customer.dob = resultData?.patronInfo?.birthDate ?: ''

    if (len(customer.dob) == 0) {
      customer.dob = resultData?.LookupPatronInfoResponse?.patronInfo?.birthDate ?: ''
    }

    if (isDefined('customer.dob') && isDate(customer.dob)) {
      customer.age = dateDiff("YYYY", customer.dob, now())
    }

    // Now get the user's circulation info.
    cfhttp(method: 'POST', charset: 'utf-8', url: '#variables.wsUrl#/rest/circulation/getUser', result: 'circResult')
    {
      cfhttpparam(type: 'header', name: 'Accept', value: 'application/json')
      cfhttpparam(type: 'header', name: 'Content-Type', value: 'application/x-www-form-urlencoded')
      cfhttpparam(type: 'header', name: 'SD-Originating-App-Id', value: variables.appID)
      cfhttpparam(type: 'header', name: 'X-sirs-clientID', value: variables.SymWSClientID)
      cfhttpparam(type: 'header', name: 'X-sirs-sessionToken', value: variables.sessionToken)
      cfhttpparam(type: 'formfield', name: 'userID', value: barcode)
    }

    // I won't do as stringent of error checking here. If the first part worked, this should too.
    var circData = deserializeJSON(circResult.fileContent)

    // Circulation Patron Info - UserCats, profile, etc
    if (isDefined('resultData.Fault')) data.messages.append('Error: ' & resultData.Fault.string)
    else {
      customer.userKey = circData.user.userKey
      customer.language = circData.user.languageID
      customer.library = circData.user.libraryID
      // JDL: 2021-09-08 As per Vicky Varga, standing is now renamed to status
      // The original status is no longer showing
      customer.standing = circData.user.userstandingID

      // Status will be overwritten by userstandingID
      customer.status = circData.user.userstandingID
      customer.checkoutHistoryRule = circData.user.checkoutHistoryRule
      customer.profileID = circData.user.profileID
    }

    // Get user categories
    if (isDefined('circData.user.userCategory') && circData.user.userCategory.len()) {
      // Loop through the Address Array and fill in all the data based on the field name
      for (userCat in circData.user.userCategory) {
        if (userCat.index == '2') customer.gender = userCat.entryID
        else if (userCat.index == '3') customer.school = userCat.entryID
        else if (userCat.index == '4') customer.disability = userCat.entryID
        else if (userCat.index == '5') customer.emailconsent = userCat.entryID
      }
    }

    if (!isDefined('customer.gender')) customer.gender = ''

    // Ensure customer data is added to the data struct.
    if (isDefined('customer')) data.customer = customer

    return data
  } // end patronInfo()


  /**
  * Attempts to authenticate a patron given a barcode and password.
  * Keeps track of authentication attempts in the vsd.ILSAuthenticationLog table
  * and does rate-limiting for requests to mitigate brute-force attacks.
  * A successful authentication will return BOTH authenticated==true AND error==false.
  * To determine if the user was authenticated only check authenticated==true.
  * Authentication may be limited to users with a particular profile by using
  * symws.setAllowedProfiles('profile1,profile2') before patronAuth.
  * @barcode	EPL library card number (almost always, but not necessarily numeric)
  * @sessionToken If a token already exists from a previous session, it can be passed here
   * 		to avoid having to get a new token
   * @allowedProfiles A list of profiles we allow to login. Set to "all" or "any" if you
   * want to allow login even from blocked/barred cards.
  */
  public struct function patronAuth(
    required string barcode,
    required string password, // also called PIN
    string allowedProfiles
  ) {
    /** Logs a failure to authenticate as the specified barcode. Updates the data struct. */
    private void function logFailure(required string barcode) {
      queryExecute("
        INSERT INTO vsd.ILSAuthenticationLog (Barcode, IPAddress, Attempted, Succeeded)
        VALUES (:barcode, :ip, GETDATE(), 0)
        ",
        {
          barcode: {value: barcode, cfsqltype: 'CF_SQL_VARCHAR', maxlength: 21},
          ip: {value: CGI.REMOTE_ADDR, cfsqltype: 'CF_SQL_VARCHAR', maxlength: 40}
        },
        { datasource: 'ReadWriteSource' }
      )
    } // end logFailure()

    if (!isDefined('allowedProfiles')) allowedProfiles = variables.allowedProfiles

    var data = {
      error: true,
      messages: [],
      authenticated: false
    }

    // Remove spaces from barcode
    barcode = barcode.replaceAll('\s', '')

    // Check that the barcode and password are a valid length
    var lengthMessage = 'Barcode must be between #variables.minBarcodeLength# and #variables.maxBarcodeLength# characters.'
    if (len(barcode) <= variables.minBarcodeLength) data.messages.append(lengthMessage)
    if (len(barcode) >= variables.maxBarcodeLength) data.messages.append(lengthMessage)
    if (!len(password)) data.messages.append('No password was entered.')

    // If invalid credentials were attempted, return now and don't bother checking the database.
    if (data.messages.len()) return data;

    // Check that the user is allowed to attempt login based on the previous attempts.
    var authAttempts = queryExecute("
      SELECT COUNT(*) AS failedAuthAttempts FROM vsd.ILSAuthenticationLog
      WHERE Barcode = :barcode AND Succeeded = 0
      AND DATEDIFF(minute, Attempted, GETDATE()) < :lockout
      ",
      {
        barcode: { value: barcode, cfsqltype: 'CF_SQL_VARCHAR', maxlength:30 },
        lockout: { value: variables.lockoutMinutes, cfsqltype: 'CF_SQL_INTEGER' }
      }
    )

    // Only allow authentication attempt if the maximum number of failures has not been exceeded.
    if (authAttempts.failedAuthAttempts >= variables.maxAttempts) data.messages.append(
      'This account is unable to log in because there were too many failed attempts. '
      & 'You may try again in #variables.lockoutMinutes# minutes.'
    )

    // If there are any errors, return now.
    if (data.messages.len()) return data;

    // Check the web services API to see if the credentials are valid.
    cfhttp(method: 'POST', charset: 'utf-8', url: '#variables.wsUrl#/user/patron/authenticate', result: 'result')
    {
      cfhttpparam(type: 'header', name: 'Accept', value: 'application/json')
      cfhttpparam(type: 'header', name: 'Content-Type', value: 'application/json')
      cfhttpparam(type: 'header', name: 'SD-Originating-App-Id', value: variables.appID)
      cfhttpparam(type: 'header', name: 'X-sirs-clientID', value: variables.SymWSClientID)
      cfhttpparam(type: 'header', name: 'X-sirs-sessionToken', value: variables.sessionToken)
      cfhttpparam(type: 'body', value: serializeJSON({ barcode, password }))
    }

    // Failure:
    // {"messageList":[{"code":"unableToAuthenticate","message":"Unable to authenticate."}]}
    // Success:
    // {"name":"Lien, Joseph Donald","patronKey":"821000"}
    var validate = validateResponse(result)
    if (validate.error == true) return validate;

    var responseData = deserializeJSON(result.fileContent)

    // If response doesn't have a name or patronKey, authentication failed. Log and return error.
    if (!responseData.keyExists('name') || !isNumeric(responseData?.patronKey)) {
      logFailure(barcode)

      for (message in responseData.messageList ?: []) {
        // The default message is 'Unable to authenticate.'
        if (message.code == 'unableToAuthenticate') data.messages.append('Incorrect password.')
        else if (message.keyExists('message')) data.messages.append(message.message)
        data.code = message.code
      }

      return data
    }

    // Log the successful authentication
    queryExecute("
      INSERT INTO vsd.ILSAuthenticationLog (Barcode, IPAddress, Attempted, Succeeded)
      VALUES (:barcode, :ip, GETDATE(), 1)
      ",
      {
        barcode: {value: barcode, cfsqltype: 'CF_SQL_VARCHAR', maxlength: 21},
        ip: {value: CGI.REMOTE_ADDR, cfsqltype: 'CF_SQL_VARCHAR', maxlength: 40}
      },
      { datasource: 'ReadWriteSource' }
    )

    // Get the customer info
    var patronInfo = this.patronInfo(barcode)
    if (patronInfo?.error != false) return patronInfo
    var customer = patronInfo.customer

    // Check that card is not lost or barred and that is has an allowed profile
    var isDenied = 'lost,barred'.listFindNoCase(customer.dept) || lCase(customer.status) == 'barred'
    var isAllowed = lCase(allowedProfiles) == 'all' || allowedProfiles.listFindNoCase(customer.profileID)

    if (isDenied || !isAllowed) {
      data.messages.append('This account is not permitted to use this service.')
      return data
    }

    // If we got here, everything checks out. Return the customer info.
    data.error = false
    data.customer = customer
    data.customer.barcode = barcode
    data.customer.name = responseData.name
    // Called userkey in patronInfo for some reason
    data.customer.patronKey = responseData.patronKey
    data.authenticated = true

    return data
  } // end patronAuth()


  /**
   * Looks up patronids (NOT BARCODES) using name and email search
   * @name	Patron's partial name
   * @email Patron's (partial) email
   * @j Join operator - AND by default
   * @ct Count of results you want to show on each "page".
   * @rw Start record to show
   * @fields List of items to show. If one is specified an array will be returned.
   * If you need many results quickly, set this to only return one or more of the following:
   * - barcode
   * - key (or userkey)
   * - firstName
   * - lastName
   * - displayName
   */
  public struct function patronSearch(
    string name,
    string email,
    string birthDate,
    string phone,
    string street,
    string comment,
    string j = 'AND',
    numeric ct = 20, // 20 by default
    numeric rw = 1, // Start on first page by default
    string fields = '')
  {
    var data = {
      error = true,
      messages = []
    }

    // Build the query string to send to Symphony Web Services
    var query = ''

    // Don't look for searchable arguments with these names
    var excludedArgs = ['J', 'CT', 'RW', 'FIELDS']

    // Build queryFields array with all arguments that can be searched
    var queryFields = []
    for (var key in arguments.keyArray()) {
      if (!excludedArgs.contains(key)) queryFields.append(key)
    }

    // Create a query struct for debugging
    data.query.j = arguments?.j

    for (field in queryFields) {
      if (arguments.keyExists(field) && len(trim(arguments[field]))) {
        switch(uCase(field)) {
          case 'BIRTHDATE':
            // Validate date and format it to the US format Symphony Web Services expects
            if (!isDate(birthDate)) return { error: true, messages: ['Specified birthdate is invalid.'] }
            birthDate = birthDate.format('mm/dd/yyyy')
            break;

          case 'PHONE':
            // Remove leading 1 and all non-digits
            phone = phone.reReplace('\D', '', 'all').reReplace('^1', '')
            break;

          default:
            // For all other fields, just trim spaces
            arguments[field] = trim(arguments[field])
        }

        query = query.listAppend(field & ':"' & arguments[field] & '"')
        // Add to data.query for debugging
        data.query[field] = arguments[field]
      }
    }

    if (!len(query)) {
      data.messages.append('At least one of these parameters is required: ' & queryFields.toList())
      return data
    }

    // Clean spaces out of fields
    fields = fields.reReplace('\s', '', 'all')

    searchUrl = '#variables.wsUrl#/user/patron/search?ct=#ct#&rw=#rw#&j=#j#&includeFields=barcode,#fields#&q='

    cfhttp(method: 'GET', charset: 'utf-8', url: searchUrl & query, result: 'result')
    {
      cfhttpparam(type: 'header', name: 'Accept', value: 'application/json')
      cfhttpparam(type: 'header', name: 'Content-Type', value: 'application/json')
      cfhttpparam(type: 'header', name: 'SD-Originating-App-Id', value: variables.appID)
      cfhttpparam(type: 'header', name: 'X-sirs-clientID', value: variables.SymWSClientID)
      cfhttpparam(type: 'header', name: 'X-sirs-sessionToken', value: variables.sessionToken)
    }

    validate = validateResponse(result, 'result')
    if (validate.error == true) return validate

    responseData = deserializeJSON(result.fileContent)

    if (isDefined('responseData.Fault')) data.messages.append('Error: ' & responseData?.fault)
    else if (!isDefined('responseData.result')) data.messages.append('Unknown error')

    // If there are any errors, return now.
    if (data.messages.len()) return data

    data.totalResults = responseData.totalResults
    result = responseData.result

    if (fields.listLen() == 1) {
      // Make an array of keys or barcodes
      if (fields.listContainsNoCase('key')) data.results = result.map(item => item.key)
      else data.results = result.map(item => item.fields[fields])
    } else if (listLen(fields) > 1) {
      // Make a simple struct with just the data from the search.
      data.results = result.map((item) => return {
        key: item.key ?: '',
        barcode: item.fields.barcode ?: '',
        displayName: item.fields.displayName ?: '',
        firstName: item.fields.firstName ?: '',
        lastName: item.fields.lastName ?: ''
      })
    } else {
      // Query each patron to get the complete record for each.
      data.results = []
      barcodes = result.map(item => item?.fields?.barcode)

      for (barcode in barcodes) data.results.append(this.patronInfo(barcode))
    }

    data.error = false
    return data
  } // end patronSearch()

  /**
   * Allows creation of a temporary library card given enough data. It is recommended to use named
   * Parameters with this function
   * @first Patron's first name
   * @last Patron's last name
   * @birthDate Birthdate
   * @phone Patron's home phone number
   * @email Patron's email address
   * @street Customer's street address
   * @postalCode Postal code
   * @pin Password. Will generate a default one if left blank.
   * @city City name (Edmonton by default)
   * @state Province name (Alberta by default)
   * @branch Branch name (will be prefixed with EPL automatically)
   */
  public struct function patronRegister(
    required string first,
    required string last,
    required string birthDate,
    required string email,
    required string street,
    required string postalCode,
    string phone='',
    string apartment='',
    string pin,
    string city='Edmonton',
    string province='Alberta',
    string branch='MNA' // Default to Stanley A. Milner
    ) {
    var data = { error = true, messages = [] }

    // Ensure a random pin is generated if one is not provided.
    if (!len(arguments?.pin)) pin = makePin()

    // Validate and sanitize fields.
    if (isNumeric(birthDate)) {
      if (len(birthDate) == 6) birthDate = birthDate.reReplace('(\d\d)(\d\d)(\d\d)', '\1-\2-\3')
      else birthDate = birthDate.reReplace('(\d\d\d\d)(\d\d)(\d\d)', '\1-\2-\3')
    }

    if (!isDate(birthDate)) data.messages.append('Birthdate is not a valid date.')
    else birthDate = birthDate.format('yyyy-mm-dd')

    if (len(phone)) {
      phone = phone.reReplace('1?\D', '', 'all')
      if (!isNumeric(phone) || len(phone) < 10) data.messages.append('Phone number is not valid.')
      else phone = phone.reReplace('(\d\d\d)(\d\d\d)(\d\d\d\d)', '\1-\2-\3')
    }

    // We only check the email address validity if it has any length, we do allow empty email.
    email = trim(email)
    if (len(email) && !isValid('email', email)) data.messages.append('Email address is not valid.')

    // Capitalize, remove spaces, then add space after the first three digits.
    postalCode = uCase(postalCode).reReplace('\s', '', 'all').reReplace('^(...)(.*)', '\1 \2')

    var postalCodeRegex = '^(?!.*[DFIOQU])[A-VXY][0-9][A-Z] ?[0-9][A-Z][0-9]$'
    if (!postalCode.reFindNoCase(postalCodeRegex)) data.messages.append('Postal code is not valid.')

    // If any validation errors were added to the messages array before, show them and stop.
    if (data.messages.len()) return data

    cfhttp(method: 'POST', charset: 'utf-8', url: '#variables.wsUrl#/rest/patron/createSelfRegisteredPatron', result: 'result')
    {
      cfhttpparam(type: 'header', name: 'Accept', value: 'application/json')
      cfhttpparam(type: 'header', name: 'Content-Type', value: 'application/x-www-form-urlencoded')
      cfhttpparam(type: 'header', name: 'SD-Originating-App-Id', value: variables.appID)
      cfhttpparam(type: 'header', name: 'X-sirs-clientID', value: variables.SymWSClientID)
      cfhttpparam(type: 'header', name: 'X-sirs-sessionToken', value: variables.sessionToken)
      cfhttpparam(type: 'formfield', name: 'pin', value: pin)
      cfhttpparam(type: 'formfield', name: 'firstName', value: first)
      cfhttpparam(type: 'formfield', name: 'lastName', value: last)
      cfhttpparam(type: 'formfield', name: 'birthDate', value: birthDate)
      cfhttpparam(type: 'formfield', name: 'street', value: street)
      cfhttpparam(type: 'formfield', name: 'city', value: city)
      cfhttpparam(type: 'formfield', name: 'state', value: province)
      cfhttpparam(type: 'formfield', name: 'apartment', value: apartment)
      cfhttpparam(type: 'formfield', name: 'postalCode', value: postalCode)
      cfhttpparam(type: 'formfield', name: 'homePhone', value: phone)
      cfhttpparam(type: 'formfield', name: 'emailAddress', value: email)
      cfhttpparam(type: 'formfield', name: 'workstationID', value: 'EPLITV')
      // Note that branch must be prefixed with EPL
      cfhttpparam(type: 'formfield', name: 'patronLibraryID', value: 'EPL#branch#')
    }

    // Response is just the card number (quoted)
    // There is a Text field with the value "YES"

    var validate = validateResponse(result)
    if (validate.error == true) return validate

    if (result.text == 'YES') data.error = false

    // All this contains is the barcode
    var barcode = deserializeJSON(result.fileContent)

    // Customer struct contains cleaned info with generated or submitted PIN and new barcode.
    // It is important to show data.customer.pin and data.customer.barcode fields to the user.
    data.customer = {
      barcode, pin, first, last, birthDate, phone, email, street, postalCode, city, province, branch
    }

    return data
  } // end patronRegister
} // end SymWS.cfc
