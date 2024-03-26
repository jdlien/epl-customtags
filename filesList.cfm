<cfscript>
/**
 * Show a table containing a list of the files in a specific directory for an application.
 *
 *	Attributes
 *  ----------
 *		directory: the local filesystem directory to show. Defaults to the application's UserFilesPath
 *		display: a list of fields to show. Defaults to "thumbnail,name,size,modified". Options are
 *		thumbnail or thumb: An icon with a thumbnail that can be hovered over to show a preview
 *		name: Filename
 *		size: Human readable filesize
 *		modified: The last modified date of the time
 *		time: The time of day of the last modified date
 *		webpath: If necessary, you can manually specify the base URL from which files are accessed by the browser, eg "https://apps.epl.ca/someapp/files". This should be determined automatically from the directory.
 *    noFilesMessage: The message to show if there are no files in the directory. Defaults to "No files found."
 */

if (thisTag.executionMode != 'start') exit;

/** Returns true if any element of the specified list is an element in attributes.display */
boolean function isDisplayingAnyOf(string displayOptionsList, string displayFields=attributes.display) {
  for (var item in displayOptionsList) if (listFindNoCase(displayFields, item)) return true

  return false
}

/** loops through a list of files from the given query and outputs a table of files formateed as per the attributes */
string function fileTable(required query dirContents) {
  // If displayFields *only* contains thumb, thumbnail, or icon, then show a div instead of a table
  if (listFind('thumb,thumbnail,icon', attributes.display)) {
    var html = '<div class="filesList">'

    for (var file in dirContents) {
      // only show files that don't start with periods
      if (left(file.name, 1) == '.') continue;

      var webLink = attributes.webPath & file.name
      html &= '<div class="file">'
      html &= '<a href="#webLink#" class="#file.type#">'
      // if it's a directory, show the special folder icon
      html &= (file.type == 'Dir')
        ? '<img class="fileImage thumbnail" src="/storage_public/icons/folder/256x256.png" />'
        : getIcon(attributes.directory & file.name, 256)
      html &= '</a>'
      html &= '</div><!--.file-->'
    } // end for

    html &= '</div><!--.filesList-->'
    return html
  }

  // Otherwise, we need a table because we are showing multiple fields
  tableStyle = isDefined('attributes.width') ? 'width:#attributes.width#;' : ''
  var html = '<table class="filesList" style="#tableStyle#">'

  for (var file in dirContents) {
    // Skip files that start with periods
    if (left(file.name, 1) == '.') continue;

    html &= '<tr id="filerow-#file.name#">'
    var webLink = attributes.webPath & file.name

    // This creates a cell if there's either a thumb or name, since they share one cell
    if (isDisplayingAnyOf('thumb,thumbnail,icon,name')) {
      html &= '<td class="fileIcon items-center py-1"><div class="flex items-center">'
      if (isDisplayingAnyOf('thumb,thumbnail,icon')) {
        html &= '<a href="#webLink#" class="#file.type# px-1 w-12">'
        html &= file.type == 'Dir'
          ? '<img class="fileImage thumbnail m-1" src="/storage_public/icons/folder/64x64.png" />'
          : getIcon(attributes.directory & file.name, 256)
        html &= '</a>'
      }

      if (isDisplayingAnyOf('name')) html &= '<a href="#webLink#" class="#file.type# link ml-1 truncate text-ellipsis" title="#file.name#">#file.name#</a>'
      html &= '</div></td><!--.fileIcon-->'
    }// either name or thumb

    if (isDisplayingAnyOf('size')) html &= '<td class="sizeTD py-1">#(file.type != 'Dir') ? Util::fileSize(file.size) : ''#</td>'

    if (isDisplayingAnyOf('modified,date')) {
      formattedDate = dateFormat(now(), 'yyyymmdd') == dateFormat(file.dateLastModified, 'yyyymmdd')
        ? 'Today'
        : dateFormat(file.dateLastModified, "yyyy-mmm-dd")
      html &= '<td>#formattedDate#</td>'
    }

    if (isDisplayingAnyOf('modified')) {
      html &= '<td class="dateTD py-1"><span class="time">#timeFormat(file.dateLastModified, "HH:mm")#</span></td>'
    }

    if (isDisplayingAnyOf('delete') && caller?.permissions?.edit == 1) {
      html &= '<td class="delTD"><button type="button"
        class="btn-red text-sm"
        onclick="deleteFile(this)"
        data-path="#relativePath#"
        data-filename="#file.name#"
      ><i class="fas fa-times"></i></button></td>'
    }

    html &= '</tr>'
  } // end for

  html &= '</table><!--filesList-->'

  return html
}// end fileTable


if (len(caller?.app?.id)) {
  param attributes.deleteappid = caller.app.id;

  appInfo = queryExecute("SELECT * FROM vsd.WebResources WHERE AppID = :appId",
    { appId: {value: caller.app.id, cfsqltype: 'CF_SQL_VARCHAR'} }
  )

  // If there's a userfiles path, we set that as the path if one isn't specified
  if (len(appInfo.UserFilesPath)) {
    // Replace forward slashes with backslashes in UserFilesPath
    appInfo.UserFilesPath = replace(appInfo.UserFilesPath, '/', '\', 'all')
    param attributes.directory = appInfo.UserFilesPath;
  }
}

// If there was no userFiles path, we specify the current directory's fileUploads subdirectory
param attributes.directory = getDirectoryFromPath(caller.cgi.CF_TEMPLATE_PATH) & 'fileUploads\';

// If directory was specified, but is a partial relative path, assume that it's a subdirectory of UserFilesPath
if (!reFindNoCase('[a-z]:[\\\/]\w.*', attributes.directory) && len(appInfo.UserFilesPath)) {
    // if the first folder specified by attributes.directory is also the last folder in UserFilesPath,
    // remove that before concatenating them
    lastUserFilesDir = reReplace(appInfo.UserFilesPath, ".*[\\\/](.*)[\\\/]?", "\1")
    firstAttributeDirectory = reReplace(attributes.directory, "[\\\/]?(.*?)[\\\/](.*)", "\1")
    if (uCase(lastUserFilesDir) == uCase(firstAttributeDirectory)) {
      // This should give us the directory attribute without the final directory
      // If the attributes.directory is really just only the last userfilesDir directory and nothing else,
      // just turn it into an empty string
      if (uCase(attributes.directory) == uCase(lastUserFilesDir)) attributes.directory = ''

      attributes.directory = reReplace(attributes.directory, '[\\\/]?(.*?)[\\\/](.*)', '\2')
    }

  // Remove trailing slash from UserFilesPath
  appInfo.UserFilesPath = reReplace(appInfo.UserFilesPath, '(.*)[\\\/]$', "\1")
  // Remove leading slash from attributes.directory
  attributes.directory = reReplace(attributes.directory, '^[\\\/](.*)', "\1")
  attributes.directory = appInfo.UserFilesPath&"\"&attributes.directory
}

// To ensure consistency for comparisons, replace any forward slashes with backslashes
attributes.directory = reReplace(attributes.directory, '\/', '\', 'all')


// Set a relative filename from the directory (now an absolute filesystem path)
// This is used by the JS that calls fileDeleter.cfm
relativePath = replaceNoCase(attributes.directory, appInfo.UserFilesPath, '')

// Remove slashes from beginning and end to ensure consistency. I feel like I'm doing this a lot...
relativePath = reReplace(relativePath, "^\\?(.*)\\?$", "\1")

// I can probably take a pretty good guess at webpath based on directory
if (!isDefined('attributes.webpath')) {
  if (findNoCase(application.storage_staff, attributes.directory)) {
    attributes.webpath = replaceNoCase(attributes.directory, application.storage_staff, '/File?p=/')
  } else {
    attributes.webpath = reReplaceNoCase(attributes.directory, 'D:\\inetpub\\(storage_public\\)?', 'https://#CGI.HTTP_HOST#/storage_public/')
  }

  attributes.webpath = replace(attributes.webpath, '\', '/', 'all')
}

// This is the full set. Also: date, time
param attributes.display = 'thumbnail,name,size,modified';
// strip spaces from display
attributes.display = replace(attributes.display, ' ', '', 'all')

param attributes.sort = 'directory ASC';
// By Default, show an error if no directory has been created
param attributes.noDirError = true;

include '/appsRoot/public/Includes/functions/makeThumbnail.cfm'

// Sanitization of attributes
// Ensure directories have trailing slashes
attributes.directory = reReplace(attributes.directory, '(.*)[\\\/]$', '\1')&'\'
attributes.webpath = reReplace(attributes.webpath, '(.*)[\\\/]$', '\1')&'/'

// Construct html for output
html = ''

// If the directory doesn't exist, we can show a message instead
if (directoryExists(attributes.directory)) {
  dirContents = directoryList(attributes.directory, false, 'query', '', attributes.sort)
  if (dirContents.recordCount) html = fileTable(dirContents, attributes.display)
} else if (attributes.noDirError == true) {
  html = '<div class="noDirError">There is no "#attributes.directory#" folder.</div>'
}

// If there's no html, we there are no files so we can show a message instead
if (!len(html) && len(attributes?.noFilesMessage)) html = '<div>#attributes.noFilesMessage#</div>'

writeOutput(html)
</cfscript>