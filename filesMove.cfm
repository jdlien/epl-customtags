<cfscript>
/**
 * cf_FilesInput offers a sophisticated input allowing a user to upload multiple files instantly,
 * showing progress of the upload, completion status, errors for files that aren't allowed,
 * and optionally, the user can drag and drop files from Windows Explorer or Finder.
 *
 * This works in a way that bypasses the problem uploading to apps from iOS.
 */

if (thisTag.executionMode != 'start') exit;

if (!isDefined('attributes.destination')) {
  writeOutput('You must specify a destination for the files.')
  exit;
}

if (!isDefined('caller.app.id')) {
  writeOutput('app.id is not set. You must set an appID before calling cf_filesmove.')
  exit;
}

fm = new fileMover(
  appId: caller.app.id,
  destination: attributes.destination,
  nameConflict: attributes.nameConflict ?: 'makeUnique',
  copy: attributes.copy ?: false,
  data: attributes.data ?: ''
).moveFiles()

// Filemove returns a struct, so we can use it to output results.
caller.FilesMove = fm

</cfscript>