/**
* A userInfo object (typically 'user' for the logged-in user) stores metadata about a user on apps.epl.ca
* and handles calculating effective permissions for that user.
*/
component accessors="true" invokeImplicitAccessor="true" {
  // Properties can be overridden for web staff
  property name="uuid"         type="string" setter="false"
    hint="Universally unique identifier used in AppsNG and MS Azure/Graph.";
  property name="username"    type="string" setter="false"
    hint="Primary key in AppsUsers, derived from AD SAMAccountName";
  property name="firstName"   type="string" setter="false" default=""
    hint="Derived from AD givenName";
  property name="initials"    type="string" setter="false" default=""
    hint="Middle initials";
  property name="lastName"    type="string" setter="false" default=""
    hint="Derived from AD SN";
  property name="displayName" type="string" setter="false"
    hint="Typically the first and last name, but can also include variations.";
  property name="distinguishedName"   type="string" setter="false"
    hint="Full path of item in AD. Used to reference in LDAP when SAMAccountName/username is not known.";
  property name="title"       type="string" setter="false" default=""
    hint="Job title";
  property name="city"        type="string" setter="false"
    hint="City user is based in.";
  property name="department"  type="string" setter="false"
    hint="Descriptive name for main department the user works in.";
  property name="description" type="string" setter="false"
    hint="Various metadata including part time, full time or LOA status.";
  property name="director"    type="string" setter="false"
    hint="Username of the director this user works under.";
  property name="directorDN"  type="string" setter="false"
    hint="Distinguished name of director over this user.";
  property name="manager"     type="string" setter="false" default=""
    hint="Username of this user's manager.";
  property name="managerDN"   type="string" setter="false"
    hint="Distinguished name of this user's manager.";
  // Note that managerObj and directorObj are not properties as
  // that makes quite a bit of a mess when dumping as it becomes recursive.
  // Get the actual manager and director object via the managerInfo() and directorInfo() methods.
  property name="mail"        type="string" setter="false"
    hint="User's email address. Usually Firstname.Lastname@epl.ca";
  property name="SMTPAddress" type="string" setter="false"
    hint="RFC822 email address in angle-brackets with quoted full name.";
  property name="isManager"   type="boolean" setter="false" default =0
    hint="True if user is a manager.";
  property name="isDirector"  type="boolean" setter="false" default=0
    hint="True if user is a director.";
  property name="isUnion"     type="boolean" setter="false" default=0
    hint="True if user is a union member.";
  property name="isGeneric"   type="boolean" setter="false" default=1
    hint="iAccounts that are shared by many users. These have limited access to some apps.";
  property name="trustedContractorID" type="string" setter="false"
    hint="For a user who is a trusted contractor, this contains an ID.";
  property name="isDisabled"  type="boolean" setter="false" default=1
    hint="If user account is disabled the employee is typically no longer at EPL.";
  property name="isDonor"     type="boolean" setter="false" default=0
    hint="User is donating monthly.";
  property name="donorSince"  type="integer" setter="false"
    hint="Year user started donating.";
  property name="employeeID"  type="integer" setter="false"
    hint="COE employee ID.";
  property name="phoneNumber" type="string" setter="false"
    hint="VOIP phone number.";
  property name="mobile"      type="string" setter="false"
    hint="EPL-issued cellular phone number.";
  property name="otherPhone"  type="string" setter="false"
    hint="Alternative phone number some employees use.";
  property name="faxNumber"   type="string" setter="false"
    hint="God I don't know why we still have these in here.";
  property name="floor"       type="string" setter="false"
    hint="This was used to store a floor number at MNP, actually from AD postOfficeBox.";
  property name="groupList"   type="string" setter="false"
    hint="Cleaned-up list of AD groups the user belongs to. Useful to determine certain things sometimes.";
  property name="info"        type="string" setter="false"
    hint="Assorted metadata, often contains list of additional branches a user works at other than their primary.";
  property name="location"    type="string" setter="false" default=""
    hint="OfficeCode for primary service point, derived from physicalDeliveryOfficeName";
  property name="locationList" type="string" setter="false" default=""
    hint="Cleaned list of ALL service points a user works at.";
  property name="locationOthers" type="string" setter="false"
    hint="Cleaned list of service points a user works at OTHER THAN the primary one.";
  property name="passwordLastSetDate" type="date" setter="false"
    hint="Date and time the user last changed their password.";
  property name="personalTitle" type="string" setter="false"
    hint="Professional designations, educational credentials, etc.";
  property name="postOfficeBox" type="string" setter="false"
    hint="Formerly used to store floor number for MNP building.";
  property name="postalCode" type="string" setter="false"
    hint="Postal code of office address.";
  property name="province" type="string" setter="false"
    hint="Full name of province user works in.";
  property name="streetAddress" type="string" setter="false"
    hint="Address of user's primary workplace.";
  property name="pronounSubject" type="string" setter="false"
    hint="Users's subject pronoun, eg He, She, or They";
  property name="pronounObject" type="string" setter="false"
    hint="Users's object pronoun, eg Him, Her, or Them";
  property name="pronounPossessive" type="string" setter="false"
    hint="Users's possessive pronoun, eg His, Hers, or Their";
  property name="permissionCache" type="struct" setter="false"
    hint="Cache of permission() and appPermissions() lookup results.";
  property name="cacheTimeoutMinutes" type="numeric" setter="false" default="2"
    hint="Minutes to cache permissions. Set this to a low value so permission updates don't take long.";

  /** Static function that returns true if the given username exists in AppsUsers. */
  public static boolean function exists(required string usernameOrUuid) {
    var uq = queryExecute("
      SELECT username FROM vsd.AppsUsers WHERE uuid = :usernameOrUuid OR username = :usernameOrUuid
      ",
      { usernameOrUuid: {value: usernameOrUuid, cfsqltype: 'CF_SQL_VARCHAR', maxlength: 36} }
    )

    return uq.recordCount > 0
  }

  /** Constructor populates all values from vsd.AppsUsers. */
  public function init(required string usernameOrUuid) {
    variables.permissionCache = {}
    var uq = ''

    // We support passing in either UUID or username. If it's 36 characters, it's a UUID.
    uq = queryExecute("
      SELECT * FROM vsd.AppsUsers WHERE #len(usernameOrUuid) == 36 ? 'uuid' : 'username'# = :uuid
      ",
      { uuid: {value: usernameOrUuid, cfsqltype: 'CF_SQL_VARCHAR', maxlength: 36} },
      { returnType: 'array' }
    )

    // Ensure required values are defined appropriately
    if (uq.len()) variables.append(uq[1])
    else variables.username = variables.displayName = arguments.usernameOrUuid

    return this
  }

  /**
   * Returns object for manager so all data can be retrieved from it.
   * Note that when dumping this, it recursively gets all the managers up to CEO.
   */
  public userInfo function managerInfo() {
      if (isDefined('variables.manager') && len(variables.manager))
          return createObject("component", "userInfo").init(variables.manager)
      // FIXME: Should throw error here, null does nothing
      else return null
  }

  /**
   * Returns object for director so all data can be retrieved from it.
   * Note that when dumping this, it recursively gets all the directors up to CEO.
   */
  public userInfo function directorInfo() {
      if (isDefined('variables.director') && len(variables.director))
          return createObject("component", "userInfo").init(variables.director)
      // FIXME: Should throw error here, null does nothing
      else return null
  }

  /** Returns an array of usernames managed by the current user. */
  public array function managedUsernames() {
    return queryExecute("
      SELECT * FROM vsd.AppsUsers WHERE manager = :mgr AND isDisabled = 0
      ",
      { mgr: { value: variables.username, maxlength: 36, cfsqltype: 'CF_SQL_VARCHAR' } },
      { returnType: 'array' }
    ).map((row) => row.username)
  }

  /** Returns full user objects for each user managed by the current user. Rarely needed and slower. */
  public array function managedUsers() {
    return this.managedUsernames().map((username) => new UserInfo(username))
  }

  /**
   * Returns an array of usernames managed by the current user,
   * and their manager if they act in a managerial role, including the current user.
   *
   * Also account for exceptions for chief executives and such.
   */
  public array function extendedManagedUsernames() {
    managedUsernames = this.managedUsernames()
    managerialTitles = 'Library Services Coordinator,Associate Manager,Facilities Coordinator'

    if (managerialTitles.listFind(variables.title)) {
      managedUsernames.append(variables.managerInfo().managedUsernames(), true)
    }

    // Special exceptions not readily discernable from AD data
    // CFO needs to see requests for the CEO
    if (variables.title == 'Chief Financial Officer') managedUsernames.append('PMartinez')

    // Lisette Lalchan is the CEO's assistant, so she needs to see requests for the CEO
    if (variables.username == 'LLalchan') managedUsernames.append(new userInfo('PMartinez').managedUsernames(), true)

    // Add the user's own username to the list
    managedUsernames.append(variables.username, true)

    return managedUsernames
  }

  /** If the cache has a valid entry for the given cacheKey, return it. Otherwise return null. */
  private any function getFromCache(string cacheKey) {
    if (variables.permissionCache.keyExists(cacheKey)) {
      var cacheEntry = variables.permissionCache[cacheKey]
      if (dateDiff('n', cacheEntry.cacheTime, now()) < variables.cacheTimeoutMinutes) {
        return cacheEntry.value
        // Else if the cache has expired, remove it
      } else variables.permissionCache.delete(cacheKey)
    }
  }

  /** Stores a value and a time in variables.permissionCache */
  private void function addToCache(required string cacheKey, required any value) {
    variables.permissionCache[cacheKey] = {
      value: value,
      cacheTime: now()
    }
  }

  /** A query function used by the permission functions */
  public query function permissionsQuery(string appId, numeric pageId, string permType) {
    return queryExecute("
      SELECT AppID, PageID, PermType, Allowed FROM vsd.PagesPermissions
      WHERE ((DeptOrUser = 'U' AND DeptOrUsername = :user)
          OR (DeptOrUser = 'D' AND DeptOrUsername IN (:locations))
          OR (DeptOrUser = 'T' AND DeptOrUsername = :title)
          OR (DeptOrUsername = 'Managers' AND :isManager = 1)
          OR (DeptOrUsername = 'GenericAccounts' AND :isGeneric = 1)
          OR DeptOrUsername = 'Everyone'
      )
      #arguments.keyExists('appId') ? 'AND AppID = :app' : ''#
      #isNumeric(arguments?.pageId) ? 'AND (pageID = :page OR pageID = 0)' : ''#
      #arguments.keyExists('permType') ? 'AND permType = :perm' : ''#
      ",
      {
        user: {value: variables.username, maxlength: 36, cfsqltype: 'CF_SQL_VARCHAR'},
        locations: {value: variables.locationList, cfsqltype: 'CF_SQL_VARCHAR', list: true},
        title: {value: variables.title, maxlength: 200, cfsqltype: 'CF_SQL_VARCHAR'},
        isManager: {value: variables.isManager, maxlength: 1, cfsqltype: 'CF_SQL_BIT'},
        isGeneric: {value: variables.isGeneric, maxlength: 1, cfsqltype: 'CF_SQL_BIT'},
        app: {value: arguments.appID ?: '', maxlength: 40, cfsqltype: 'CF_SQL_VARCHAR'},
        page: {value: arguments.pageID ?: 0, maxlength: 6, cfsqltype: 'CF_SQL_INTEGER'},
        perm: {value: arguments.permType ?: '', maxlength: 40, cfsqltype: 'CF_SQL_VARCHAR'}
      }
    )
  } // end permissionsQuery()

  /**
   * Returns a structure with all the permissions a user has. Not cached.
   *
   * Used on Permissions/PermissionsUser.cfm to show all of a user's permissions.
   */
  public struct function permissions() {
    var perms = {}

    var permsQuery = variables.permissionsQuery()

    for (p in permsQuery) {
      var page = p.PageID == 0 ? 'root' : 'id' & p.PageID

      if (!perms.keyExists(p.AppID)) perms[p.AppID] = {}
      if (!perms[p.AppID].keyExists(page)) perms[p.AppID][page] = {}

      // Deny overrides Allow, so only set the permission if it's either not set or not denied
      if (!perms[p.AppID][page].keyExists(p.permType) || perms[p.AppID][page][p.PermType] != 0) {
        perms[p.AppID][page][p.PermType] = p.Allowed
      }
    }

    return perms
  } // end permissions()

  /** Returns a structure with this user's permissions for a particular application page. */
  public struct function appPermissions(required string appId, integer pageId=0) {
    var cacheKey = '#appId#_#pageId#' // eg 'Web_0'
    // Check for cached permissions with a cacheKey using the provided arguments
    var cachedPermissions = variables.getFromCache(cacheKey)
    if (!isNull(cachedPermissions) && isStruct(cachedPermissions)) return cachedPermissions

    var permsQuery = variables.permissionsQuery(appId, pageId)

    var perms = {}

    // Loop through the permissions and ensure that each possible permission is set once.
    for (p in permsQuery) {
      // If the permission has never been set, set it to whatever p.Allowed is (0 or 1)
      // Otherwise, if this permission is Denied, set it to 0 to override any Allow
      perms[p.PermType] = perms.keyExists(p.PermType) && perms[p.PermType] && p.Allowed == 0
        ? 0
        : p.Allowed
    }

    // Cache the permission lookup
    variables.addToCache(cacheKey, perms)

    return perms
  } // end appPermissions()

  /**
   * Returns 1 if permission is allowed, 0 if denied, or empty string if not granted permission.
   * @appId ApplicationID for desired permission
   * @permType Type of desired permission
   * @pageId Only return permission for a specific pageID. Defaults to 0 (global)
   */
  public string function permission(required string appId, required string permType, integer pageID=0) {
    var cacheKey = '#appId#_#pageID#_#permType#' // eg 'Web_0_view'
    // Check for cached permission with a cacheKey using the provided arguments
    var cachedPermission = variables.getFromCache(cacheKey)
    if (!isNull(cachedPermission) && isSimpleValue(cachedPermission)) return cachedPermission

    var permQuery = variables.permissionsQuery(appId, pageID, permType)

    var perm = ''

    // Set permissions based on the above Query
    for (p in permQuery) {
        // Ensure Deny permission always overrides Allow, otherwise set to value of Allowed
        if (p.allowed == 0) {
          perm = 0
          break;
        } else perm = p.allowed
    }

    // Cache the permission lookup
    variables.addToCache(cacheKey, perm)

    return perm
  } // end permission()

  // Reverse compatibility getters
  /** maps userName->SAMAccountName for reverse compatibility with LDAP queries */
  public string function getSAMAccountName() {return variables.userName}

  /** maps firstName->givenName for reverse compatibility with LDAP queries */
  public string function getGivenName() {return variables.firstName}

  /** maps lastName->SN for reverse compatibility with LDAP queries */
  public string function getSN() {return variables.lastName}

  /** maps location->physicalDeliveryOfficeName for reverse compatibility with LDAP queries */
  public string function getPhysicalDeliveryOfficeName() {return variables.location}

  /** Returns the username when object is treated as a string */
  public string function toString() {return variables.userName}

  /** Returns the user's email address along with full name in RFC822 format */
  public string function getSMTPAddress() {
      return '"#variables.displayName#" <#variables.mail#>'
  }

  /** Ensures a valid date is returned if no password last set date is defined. */
  public date function getPasswordLastSetDate() {
    if (isDate(variables.passwordLastSetDate)) return variables.passwordLastSetDate
    else return createDateTime(1900, 01, 01, 00, 00, 00)
  }
}// end userInfo component
