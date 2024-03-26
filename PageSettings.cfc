/** Typically 'app' stores settings and metadata about a page on apps.epl.ca */
component accessors="true" invokeImplicitAccessor="true" {
  // Properties can be overridden for web staff
  property name="includes" 	type="string" default="/Includes/"
    hint="Path passed to includes for header files. Can be modified to use dev includes. Will be removed as this is no longer needed";
  property name="dev"			type="boolean"
    hint="If true, we are on a dev site and can use different, less secure settings.";
  property name="initialized" type="boolean" default="false"
    hint="Specifies that appsHeader.cfm loaded successfully.";
  property name="error" type="boolean" default="false"
    hint="Flags that we are in an error state. Used within appsErrorReport.cfm";
  property name="parents" 	type="array"
    hint="Array of ancestor page title/link to be shown as breadcrumb links under the titleBar.";
  property name="adminButtons" type="array"
    hint="Array of metadata structs to be used to display links in adminButtons";
  property name="disablePermissionsButton" type="boolean" default="false"
    hint="If true, no permissions button will be displayed on the titleBar.";
  property name="id" 			type="string"
    hint="The ApplicationID which is used to determine permissions. Undefined by default.";
  property name="page"		type="numeric" default="0"
    hint="The section of the application to be granted permission to, the id of page or resource.";
  property name="permissionsRequired" default="view"
    hint="If permissions are required, the list of permissions required to access this page.";
  property name="securedSite" type="boolean"
    hint="If false, the full header will not be shown. This is used to show unauthenticated resources using apps header on www2 where access to the rest of apps is not desired.";
  property name="title"		type="string"  default=""
    hint="Sets the title of head title and shows in titleBar at top of main content.";
  property name="titleHead"	type="string"
    hint="If defined, this overrides title for the head/title tag value.";
  property name="disableTitleBar" type="boolean" default="false"
    hint="If true, the titleBar does not show on the page.";

  // Javascript library toggles
  property name="formTools"	type="boolean" default="false"
    hint="JD's form validation library.";
  property name="jEditable"	type="boolean" default="true"
    hint="In-place editing";
  property name="jQuery"		type="boolean" default="true"
    hint="If jQuery is false, many other libraries and apps pages don't work. Only use this if the normal version is being overridden with another one or you are sure there are no dependencies on jQuery.";
  property name="jQueryUI"	type="boolean" default="true"
    hint="Mainly used for datepicker support.";
  property name="moment"		type="boolean" default="true"
    hint="Include the moment.js date/time handling library.";
  property name="toastr"		type="boolean" default="true"
    hint="Support for showing success, warning, and error pop-up 'toast' messages.";
  property name="EasyMDE"   type="boolean" default="false"
    hint="Include the EasyMDE markdown editor library.";
  property name="contentType" type="string"
    hint="The content type of the page can be specified. Typically either text/html or application/json.";

  /** Use init to specify some variables on instantiation. */
  public function init(boolean initialized=false) {
    // If this is on a dev site, app.dev will be true
    variables.dev = !!CGI.HTTP_HOST.findNoCase('dev.epl')

    // Set securedSite to false to hide sensitive information and links to apps on www2.epl.ca
    secureHosts = 'apps.epl.ca,apps-dev.epl.ca,localhost,127.0.0.1'
    variables.securedSite = listFind(secureHosts, cgi.http_host.reReplace(':\d+', '')) ? true : false

    // Set any overrides for web staff in the list passed to setOverrides
    setOverrides('JLien,Sharegh.Yusefi,Jason.Harris')

    // Default to empty arrays for variables that can't be set to defaults
    variables.parents = []
    variables.adminButtons = []
    //equivalent to variables.initialized=arguments.initialized
    setInitialized(arguments.initialized)
    return this
  }

  /**
   * setOverrides runs at initialization and checks if any web staff have overrides set
   * in the AppsWebStaffOverrides table. If so, it sets them accordingly.
   * @output false
   */
  private void function setOverrides(required string webStaffList) {
    if (listFindNoCase(webStaffList, session?.identity)) {
      webStaffOverrides = queryExecute("
        SELECT OverrideAsUser, devCSS
        FROM vsd.AppsWebStaffOverrides
        WHERE WebUser= :username
        ",
        {username: session.identity}
      )

      for (row in webStaffOverrides) {
        if (len(row?.OverrideAsUser)) {
          session.identity = row.OverrideAsUser
          // specify that user is being overridden
          session.loginOverride = row.OverrideAsUser
        }
      }
    }
  }

  /**
   * Adds an element to the parents array used for breadcrumbs links.
   * @title Title of link displayed in breadcrumbs.
   * @link  Relative URL of link in breadcrumbs.
   */
  public void function addParent(required string title, string link='./') {
    variables.parents.append({ title, link })
  }

  /**
   * Adds adminButton to adminButtons array to show on titleBar.
   * @label	Text shown on the button
   * @link		Relative link URL
   * @tooltip 	Tooltip or title attribute
   * @permType Required permission for button to show
   * @appID	AppID of permission required to show if not the current app.id
   * @pageID   PageID for permission required to show the link
   * @id       Specify an id for the link element
   * @class    Specify additional classes for the link element
   * @target	html target attribute for link (eg _blank to open in new tab)
   * @allowed if false, button shown if user does NOT have access
   * @links an array of label/link structs that can be shown in a dropdown
   */
  public void function addAdminButton(
     string label,
     string link,
     string tooltip,
     string permType='no_permission_required',
     string appID,
     string pageID=variables.page,
     string id,
     string class,
     string target,
     string allowed=true,
    array links
  ) {
    if (!len(arguments?.label) && !len(arguments?.link)) throw ('addAdminButton requires a label or link argument')

    adminButton = {}
    if (len(arguments?.label) && !len(arguments?.link)) arguments.link = arguments.label
    adminButton.label = label ?: link
    adminButton.link = link
    if (isDefined('arguments.tooltip')) adminButton.tooltip = arguments.tooltip
    if (isDefined('arguments.permType')) adminButton.permType = arguments.permType
    // appID needs a default - however, if the button was defined before the appID, this won't be set.
    if (isDefined('arguments.appID')) adminButton.appID = arguments.appID
    else if (isDefined('variables.id')) adminButton.appID = variables.id
    if (isDefined('arguments.pageID')) adminButton.pageID = arguments.pageID
    if (isDefined('arguments.id')) adminButton.id = arguments.id
    if (isDefined('arguments.class')) adminButton.class = arguments.class
    if (isDefined('arguments.target')) adminButton.target = arguments.target
    if (isDefined('arguments.allowed')) adminButton.allowed = arguments.allowed
    if (isDefined('arguments.links')) adminButton.links = arguments.links
    variables.adminButtons.append(adminButton)
  }

  /** Returns titleHead with assigned value, otherwise uses title. Returns "Apps" if no title set. */
  public string function getTitleHead() {
    if (isDefined('variables.titleHead')) return variables.titleHead
    else if (len(variables?.title)) return variables.title
    // Default
    return 'Apps'
  }
}// end pageSettings component
