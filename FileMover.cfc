/** Moves files uploaded via the cf_filesupload custom tag into the appropriate location */
component {
  property name='nameConflict' type='string';
  property name='copy' type='string' default='false';
  property name='destination' type='string';
  property name='includes' type='string';
  property name='filesMove' type='array';
  property name='userFilesPath' type='string';
  property name='tempFilePath' type='string';
  property name='fieldNames' type='string';
  property name='data' type='string';

  /** Init sets up the variables */
  void function init(
    required string appId,
    required string destination,
    string nameConflict = 'makeunique',
    boolean copy,
    string data,
    string fieldNames
  ) {
    variables.includes = '/appsRoot/public/Includes/'
    variables.filesMove = []
    variables.nameConflict = arguments.nameConflict
    if (len(arguments?.data)) variables.data = arguments.data
    variables.appId = arguments.appId

    // Get the destination path from vsd.WebResources
    variables.userFilesPath = queryExecute("
      SELECT userFilesPath FROM vsd.WebResources WHERE appID = :appId
      ",
      { appId: { value: variables.appId, cfsqltype: 'cf_sql_varchar' } }
    ).userFilesPath

    if (!len(arguments?.fieldNames) && isDefined('form.fieldNames')) arguments.fieldNames = form.fieldNames

    if (!isDefined('arguments.fieldNames')) {
      throw('<b>form</b> not defined. filesMove should be used on POST requests after form submission.')
    }

    variables.fieldNames = arguments.fieldNames

    var tempFileBasePath = 'D:\inetpub\temp\fileUploads\'
    var tempFilePath = tempFileBasePath & variables.appId & '\'

    if (len(session?.identity)) tempFilePath = tempFilePath & session.identity & '\'
    else if (len(form?.fuUser)) tempFilePath = tempFilePath & form.fuUser & '\'

    variables.tempFilePath = tempFilePath

    variables.destination = getFullPath(arguments.destination)
  }

  string function toSafeFilename(string filename) {
    // Replace spaces with underscores (Disabled)
    //filename = filename.replaceAll(' ', '_')

    // Replace special characters with safe equivalents
    filename = filename.replaceAll('[^\w\-\.\(\) ]+', '-')

    return filename
  }

  array function moveFiles() {
    /** Sets some values if there's a failure in handling naming conflicts */
    void function failInfo(required string message) {
      fileInfo.message = message
      fileInfo.status = 'fail'
      fileInfo.error = true
      fileInfo.pathName = fileInfo.fileName = ''
    }

    var uploadedFiles = []
    for (field in listToArray(variables.fieldNames)) {
      if (reFindNoCase('UPLOADEDFILE\[\d+\]', field)) uploadedFiles.append(form[field])
    }

    for (filename in uploadedFiles) {
      fileInfo = {}
      fileInfo.fileNameOriginal = fileName
      fileInfo.pathNameOriginal = tempFilePath & fileName

      // If the file does not exist, skip it and add the info to the filesMove array
      if (!fileExists(tempFilePath & fileName)) {
        failInfo('#fileName# cannot be found in #tempFilePath#.')
        variables.filesMove.append(fileInfo)
        continue;
      }

      // If the destination directory does not exist, create it
      if (!directoryExists(variables.destination)) directoryCreate(variables.destination)

      moveDest = variables.destination & '\' & variables.toSafeFilename(fileName)

      // If the file already exists, handle the naming conflict as per the nameConflict argument
      if (fileExists(moveDest)) fileInfo = handleNameConflict(fileInfo, moveDest)
      else { // else there's no conflict. Just move the file
        // We can optionally copy the file if variables.copy is true
        try {
          if (variables.copy == true) fileCopy(tempFilePath & fileName, moveDest)
          else fileMove(tempFilePath & fileName, moveDest)
        } catch (any e) { failInfo(e.message) }
      }

      // Get the ultimate destination if everything worked out
      if (!isDefined('fileInfo.pathName')) fileInfo.pathName = moveDest
      if (!isDefined('fileInfo.fileName')) fileInfo.fileName = getFileFromPath(moveDest)
      if (!isDefined('fileInfo.status')) fileInfo.status = 'success'
      if (!isDefined('fileInfo.error')) fileInfo.error = false
      if (!isDefined('fileInfo.message')) fileInfo.message = ''
      variables.filesMove.append(fileInfo)

      // Insert into the fileUploads database table
      insertUpload = queryExecute("
        INSERT INTO vsd.FilesInputUploads (Filename, FilePath, Directory, UploadedBy, AppID, Data)
        VALUES (
          :filename,
          :filepath,
          :directory,
          :username,
          :appId,
          :data
        )
        ",
        {
          filename: { value: fileName, cfsqltype: 'CF_SQL_NVARCHAR' },
          filepath: { value: variables.destination & '\' & fileName, cfsqltype: 'CF_SQL_NVARCHAR' },
          directory: { value: variables.destination, cfsqltype: 'CF_SQL_NVARCHAR' },
          username: { value: session.identity ?: 'ANONYMOUS', cfsqltype: 'CF_SQL_VARCHAR' },
          appId: { value: variables.appId, cfsqltype: 'CF_SQL_VARCHAR' },
          data: { value: variables?.data, cfsqltype: 'CF_SQL_NVARCHAR', null: !isDefined('variables.data')}
        },
        { datasource: 'ReadWriteSource' }
      )
    }

    return variables.filesMove
  }

  /** Takes a partial or full destination path and returns the full path on disk. */
  string function getFullPath(required string destination) {
    // Swap forward slashes for backslashes
    arguments.destination = replace(arguments.destination, '/', '\', 'ALL')

    // If we already have a full path, just return it
    if (reFindNoCase('[a-z]:[\\\/]\w.*', arguments.destination)) return arguments.destination

    // Handle errors where we aren't able to determine a full path and output them
    if (len(variables.userFilesPath) <= 3) {
      throw('No <b>userFilesPath</b> is set for this app.id
        at <a href="https://apps.epl.ca/web/resources/">apps/web/resources</a>.
        You must therefore use the full local server path.')
    }

    // This could be risky if someone wants a folder with the same name as its parent.
    // If the first folder specified by arguments.destination is the last folder in UserFilesPath, strip it
    var lastUserFilesDir = reReplace(variables.userFilesPath, '.*[\\\/](.*)[\\\/]?', '\1')
    var firstAttributeDirectory = reReplace(arguments.destination, '[\\\/]?(.*?)[\\\/](.*)', '\1')

    if (uCase(lastUserFilesDir) == uCase(firstAttributeDirectory)) {
      // This should give us the directory attribute without the final directory
      // If arguments.destination is only the last userfilesDir directory and nothing else, set it to empty string
      var directoryNoSlashes = reReplace(arguments.destination, '[\\\/]?(.*?)[\\\/]?', '\1')

      if (uCase(directoryNoSlashes) == uCase(lastUserFilesDir)) arguments.destination = ''

      arguments.destination = reReplace(arguments.destination, '[\\\/]?(.*?)[\\\/](.*)', '\2')
    }

    // Remove trailing slash from variables.UserFilesPath
    variables.userFilesPath = reReplace(variables.userFilesPath, '(.*)[\\\/]$', '\1')
    // Remove leading slash from arguments.destination
    arguments.destination = reReplace(arguments.destination, '^[\\\/](.*)', '\1')
    arguments.destination = variables.userFilesPath&'\'&arguments.destination

    return arguments.destination
  }

  /** Handles naming conflicts, taking the setting into account. */
  struct function handleNameConflict(required struct fileInfo, required string moveDest) {
    // our nameConflict handling will happen here
    switch (variables.nameConflict) {
      case 'overwrite':
        fileInfo.status = 'overwritten'
        try {
          if (variables.copy == true) fileCopy(tempFilePath & fileName, moveDest)
          else fileMove(tempFilePath & fileName, moveDest)
        } catch (any e) { failInfo(e.message) }
        break;

      case 'skip':
        // We just delete the file. This is not considered an error.
        fileInfo.error = false
        fileInfo.status='skipped'
        try {
          fileDelete(tempFilePath & fileName)
          fileInfo.message = 'The uploaded file already exists and the new file was not uploaded.'
          fileInfo.pathName = fileInfo.fileName = ''
        } catch (any e) { failInfo(e.message) }
        break;

      default: // default is 'makeUnique'
        pathWithoutExt = reReplace(moveDest, '(.*)(\..*)$', '\1')
        fileExt = reReplace(moveDest, '.*(\..*)$', '\1')
        incr = 0
        while (fileExists(moveDest)) moveDest = pathWithoutExt & '_' & ++incr & fileExt

        // Try to avoid overwriting the existing file
        try {
          fileInfo.status = 'renamed'
          if (variables.copy == true) fileCopy(tempFilePath&fileName, moveDest)
          else fileMove(tempFilePath & fileName, moveDest)
        } catch (any e) { failInfo(e.message) }
    } // end switch

    return fileInfo
  }

}