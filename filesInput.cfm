<!--- cf_FilesInput offers a sophisticated input allowing a user to upload multiple files instantly,
	showing progress of the upload, completion status, errors for files that aren't allowed,
	and optionally, the user can drag and drop files from Windows Explorer or Finder.

	This works in a way that bypasses the problem uploading to apps from iOS.
 --->
<cfif thisTag.executionMode EQ "start">
<cfparam name="attributes.label" default="Add files" />
<cfparam name="attributes.accept" default="all" />
<cfif isDefined('attributes.single') AND attributes.single NEQ false AND attributes.single NEQ "No">
	<cfset attributes.single=true/>
<cfelse>
	<cfparam name="attributes.single" default="false" />
</cfif>
<cfif isDefined('attributes.multiple') and attributes.multiple NEQ false AND attributes.single NEQ "No">
	<cfset attributes.single=false />
<cfelseif isDefined('attributes.multiple') AND (attributes.multiple EQ false OR attributes.multiple EQ "No")>
	<cfset attributes.single=true />
</cfif>

<cfif isDefined('attributes.max') AND isNumeric(attributes.max)>
	<cfset attributes.maxFiles = attributes.max />
</cfif>
<cfparam name="attributes.maxFiles" default="0" />
<cfparam name="attributes.dropText" default="" />
<cfparam name="attributes.maxFileSize" default="200000000" />
<!--- CF Doesn't allow zero-length files --->
<cfparam name="attributes.minFileSize" default="1" />
<!--- How to handle name conflicts in the temporary upload directory --->
<cfparam name="attributes.nameConflict" default="makeUnique" />
<cfif attributes.nameConflict NEQ "MakeUnique"
  AND attributes.nameConflict NEQ "Error"
  AND attributes.nameConflict NEQ "Overwrite"
  AND attributes.nameConflict NEQ "Skip">
  <cfset attributes.nameConflict="makeUnique" />
</cfif>

<cfparam name="attributes.errorMessage" default="A file is required" />

<!--- Remove any dots from accept (ie if someone wrote something like .jpg,.gif) --->
<cfset attributes.accept = Replace(attributes.accept, ".", "", "all")/>
<!--- Can specify "all", a list of file extensions like "mp3,mp4,aac,ogg", or "images" --->


	<div class="formItem<cfif isDefined('attributes.class')><cfoutput> #attributes.class#</cfoutput></cfif>" id="allFiles">
<!--- I know this looks weird to put the style here, but that prevents the style tag from messing up some of the other form styling I'm using. Same with the script tag below --->
<style type="text/css">
@keyframes barberpole {
  from { background-position: 0 0; }
  to   { background-position: 60px 30px; }
}

@keyframes fadeout {
  from { opacity: 1; }
  to   { opacity: 0; }
}

	#allFiles {
		background-color:#eeeeee;
		background-color:rgba(127,127,127,0.15);
		padding:4px;
		border: solid rgba(127, 127, 127, 0.6) 1px;
		display:block;
		display:flex;
		flex-flow:row wrap;
		justify-content:space-between;
		margin-top:20px;
		<cfif isDefined('attributes.width')>width:<cfoutput>#attributes.width#</cfoutput></cfif>;
		max-width:800px;
	}

	#progress {
		width:100%;
		flex: 1 100%;
	}

	#progress .bar {
		background-color:#7bc143;
		opacity: 0;
		height:10px;
		border-radius:5px;
		/*display:inline-block;*/
		background-size: 30px 30px;
	}

	#progress .status {
		margin-top:15px;
		text-align: center;
	}

	.animated {
		background-image: linear-gradient(45deg, rgba(0,0,0, 0.4) 25%, transparent 25%, transparent 50%, rgba(0,0,0, 0.4) 50%, rgba(0,0,0, 0.4)  75%, transparent 75%, transparent);
		animation: barberpole 0.5s linear infinite;
	}

	.fadeout {
		animation: fadeout 2s forwards;
	}

	#uploadedFiles, #uploadedFilesInfo {
		display:none;
	}

	#uploadedFileList {
		width:100%;
		flex: 1 100%;
		margin-bottom:0;
	}

	#uploadedFileList td {
		padding-bottom:7px;
		padding-top:0;
	}

	#uploadedFileList .chk {
		width:24px;
	}

	#uploadedFileList .del {
		width:18px;
	}

	.uploadedFilesLabel {
		margin-bottom:10px;
	}

	#fileupload {
		/*float:none;*/
		align-self:flex-end;
		margin-bottom:5px;
		width:236px;
		padding:5px;
	}

	/* This row can be shown if the application wants to put additional stuff there */
	.fileUExtraRow, .fileUErrorRow {
		display:none;
	}

	#allFiles label[for="fileupload"] {
		margin-bottom:10px;
	}

	.deleteUploadedFile {
		padding: 3px 5px;
		font-size: 16px;
		display: flex;
	}

	.deleteUploadedFile:hover {
		text-decoration: none;
	}

</style>
	<input type="hidden" name="nameConflict" value="<cfoutput>#attributes.nameConflict#</cfoutput>" />
	<!--- These hidden fields are sent to fileupload and used in the construction of the temporary path --->
	<input type="hidden" name="fuAppID" value="<cfoutput>#caller.app.id#</cfoutput>" />
	<cfif len(session?.identity)>
		<input type="hidden" name="fuUser" value="<cfoutput>#session.identity#</cfoutput>" />
	<cfelse>
		<cfset fileSessionID = uCase(Util::randString(32)) />
		<input type="hidden" name="fuUser" value="<cfoutput>#fileSessionID#</cfoutput>" />
	</cfif>

	<div id="uploadedFiles"><!---hidden inputs with uploaded filenames will go here ---></div>
	<div id="uploadedFilesInfo"><!---hidden inputs with uploaded filenames will go here ---></div>
	<cfoutput><label for="fileupload" class="uploadedFilesLabel">#attributes.label#</label>
		<cfset counter=0 />
		<input type="file" name="filesIn" id="fileupload" <cfif NOT attributes.single>multiple</cfif>
		<cfif attributes.accept IS "image" OR attributes.accept IS "images">
		accept="image/*,.jpg,.gif,.png,.bmp,.jpeg,.webp,.heic,.svg"
		<cfelseif attributes.accept IS "all" OR attributes.accept IS ""><!--- attributes.accept IS "all"--->
		accept="image/*,video/*,.jpg,.gif,.png,.bmp,.jpeg,.webp,.heic,.webm,.avi,.mkv,.mov,.divx,.7z,.zip,.pdf,.aac,.mp4,.bz,.bz2,.csv,.ico,.tex,.xls,.xlsx,.xlt,.xlm,.xlsm,.xltx,.xltm,.doc,.docx,.docm,.dotx,.dotm,.docb,.dot,.ppt,.pptx,.pot,.pps,.pptm,.potx,.potm,.ppsx,.vsd,.vsdx,.wmv,.ogg,.mp3,.txt,.svg,.psd,.eps,.ai,.aiff,.wav,.stl,.obj"
		<cfelse><!--- treat it as a list of file extensions. Remove any dots --->
		accept="<cfloop list="#attributes.accept#" delimiters=",|" index="ext"><cfif counter GT 0>,</cfif>.#ext#<cfset counter++
		/></cfloop>"
		</cfif>
		/>
	</cfoutput>
		<div id="progress">
			<div class="status"><cfif len(attributes.dropText)><cfoutput>#attributes.dropText#</cfoutput><cfelse>Drop <cfif attributes.maxFiles GT 0>up to <cfoutput>#attributes.maxFiles#</cfoutput> </cfif>file<cfif NOT attributes.single>s</cfif> here.</cfif></div>
			<div class="bar"></div>
		</div>
		<table id="uploadedFileList">
		</table>
		<span class="error hidden" id="fileuploadError"></span>

		<input id="lastUploadedFile" name="lastUploadedFile" type="hidden" class="<cfif isDefined('attributes.required')>required</cfif>" value="" />
		<div class="error hidden" id="lastUploadedFileError"><cfoutput>#attributes.errorMessage#</cfoutput></div>


<script src="/Javascript/jQuery-File-Upload-9.23.0/js/jquery.fileupload.js"></script>
<script src="/Javascript/jQuery-File-Upload-9.23.0/js/jquery.fileupload-process.js"></script>
<script src="/Javascript/jQuery-File-Upload-9.23.0/js/jquery.fileupload-validate.js"></script>
<script>
var fileCount = 0;
var acceptFileTypesRE = new RegExp;
<cfif attributes.accept IS "image" OR attributes.accept IS "images">
	acceptFileTypesRE = /(\.|\/)(jpg|gif|png|bmp|jpeg|webp|heic|svg)$/i;
<cfelseif attributes.accept IS "all" OR attributes.accept IS ""><!--- attributes.accept IS "all"--->
	acceptFileTypesRE = /(\.|\/)(jpg|gif|png|bmp|jpeg|webp|heic|webm|avi|mkv|mov|divx|7z|zip|pdf|aac|mp4|bz|bz2|csv|ico|tex|xls|xlsx|xlt|xlm|xlsm|xltx|xltm|doc|docx|docm|dotx|dotm|docb|dot|ppt|pptx|pot|pps|pptm|potx|potm|ppsx|vsd|vsdx|wmv|ogg|mp3|txt|svg|psd|eps|ai|aiff|wav|stl|obj)$/i;
<cfelse><!--- treat it as a list of file extensions. Remove any dots --->
	<cfset extensionList="" />
	<cfset counter=0 />
	<cfloop list="#attributes.accept#" delimiters=",|" index="ext">
		<cfif counter GT 0><cfset extensionList&="|" /></cfif>
		<cfset extensionList&=ext /><cfset counter++/>
	</cfloop>
	acceptFileTypesRE = /(\.|\/)(<cfoutput>#extensionList#</cfoutput>)$/i;
</cfif>

// Make the file upload container work
$(function () {
    $('#fileupload').fileupload({
    	acceptFileTypes: acceptFileTypesRE,

		maxFileSize: <cfoutput>#attributes.maxFileSize#</cfoutput>, //200MB Default
		minFileSize: <cfoutput>#attributes.minFileSize#</cfoutput>, //1 Byte Default
		fail: function(e, data) {
			// Re-enable any submit buttons. Anything else we should disable?
			// $('input[type="submit"]').prop('disabled', false);

			// console.log(data);
		},

    	url:'//<cfoutput>#CGI.HTTP_HOST#</cfoutput>/Includes/uploadHandler.cfm',
        dataType: 'json',
        autoUpload: true,
        dropzone: '#allFiles',
        maxNumberOfFiles: <cfoutput>#attributes.maxFiles#</cfoutput>,
		progressall: function (e, data) {
			// Disable any submit buttons.
			// I should not re-enable submit buttons unless I know for a fact that they were enabled before file uploads happened.
			$('#progress .status').html('Uploading...');
			$('#progress .bar').removeClass('fadeout');
			$('#progress .bar').addClass('animated');
		    var progress = parseInt(data.loaded / data.total * 100, 10);
		    //console.log(progress);
		    $('#progress .bar').css('width', progress+'%');
		    $('#progress .bar').css('opacity', '1');

		},
		// This runs if no files get uploaded
		processfail: function (e, data) {
			$('#fileuploadError').show();
			if (typeof data.files[0].error !== 'undefined' && data.files[0].error != 'undefined') {
				$('#fileuploadError').append("<strong>"+data.files[0].name+"</strong>: ");
				$('#fileuploadError').append(data.files[0].error+"<br />");
			}
		},
		change: function (e, data) {
	        if(data.files.length-1 >=<cfoutput>#attributes.maxFiles#</cfoutput> && <cfoutput>#attributes.maxFiles#</cfoutput> > 0){
	            $('#progress .status').html('<div class="error">Only up to <cfoutput>#attributes.maxFiles#</cfoutput> files are allowed.</div>');
	            return false;
	        } else {
	        	//fileCount +=data.files.length;
	        }
    	},
		add: function (e, data) {
			var uploadErrors = [];
			// console.log(data.originalFiles);
	        if(fileCount>=<cfoutput>#attributes.maxFiles#</cfoutput> && <cfoutput>#attributes.maxFiles#</cfoutput> > 0){
	            $('#progress .status').html('<div class="error">Only up to <cfoutput>#attributes.maxFiles#</cfoutput> files are allowed.</div>');
	            return false;
	        } else {
	        	// Loop through all files and make sure all types are allowed. If any filetypes aren't allowed, return errors.
	        	for (var i=0; i<data.originalFiles.length; i++) {
					var fileExt = data.originalFiles[i].name.replace(/.*(\..*)$/, '$1');
					if (data.originalFiles[i].name.length && !acceptFileTypesRE.test(fileExt)) {
					    uploadErrors.push(fileExt+' is not an accepted file type.');
					}
					if (data.originalFiles[i].size < <cfoutput>#attributes.minFileSize#</cfoutput>) {
						uploadErrors.push(data.originalFiles[i].name+' is too small a file size.');
					}
					if (data.originalFiles[i].size > <cfoutput>#attributes.maxFileSize#</cfoutput>) {
						uploadErrors.push(data.originalFiles[i].name+' is too big.<br />Files must be under <cfoutput>#NumberFormat(attributes.maxFileSize, "999,999,999")#</cfoutput> bytes.');
					}
	        	}
	        	if (uploadErrors.length > 0) {
		            $('#progress .status').html('<div class="error">'+uploadErrors.join("<br />\n")+'</div>');
        		} else {
		        	fileCount++;
				    if (data.autoUpload || (data.autoUpload !== false && $(this).fileupload('option', 'autoUpload'))) {
				        data.process().done(function () {
				            data.submit();
				        });
				   	}
        		}
	        }//end else (fileCount within limit)
    	},
        done: function (e, data) {
        	var qtyUploaded = document.querySelectorAll('.uploadedFile').length;
        	$('#progress .bar').removeClass('animated');
        	$('#progress .bar').addClass('fadeout');

        	//If there was an error, we show an error here and return.
			if (data._response.result.error === true) {
				$('#progress .status').html('');
    			data._response.result.messages.forEach(function(item){
    				$('#progress .status').append('<div class="error">'+item+'</div>');
    			});
    			//fileCount is in two scopes - ensure we use Window.
    			//Decrement filecount because the upload must've failed.
    			window.fileCount--;
    			//End execution
    			return;
    		}

        	if (qtyUploaded+1 >= <cfoutput>#attributes.maxFiles#</cfoutput> && <cfoutput>#attributes.maxFiles#</cfoutput> > 0) {
        		$('#progress .status').html('Upload Complete. <div class="error">No more files are allowed.</div>');
        		$('#fileupload').prop('disabled', true);
        		//disable dropzone
        	} else {
        		$('#progress .status').html('Upload Complete.<cfif NOT attributes.single> You may add more files.</cfif>');
        	}
        	// Show the completed file in the list
            $('#uploadedFileList').<cfif attributes.single>html<cfelse>append</cfif>('<tr class="fileURow" data-filename="'+data.result.SERVERFILE+'"><td class="chk"><img src="/images/checkmark-filled.svg" /></td><td class="fname">'+data.result.SERVERFILE+'</td><td class="del"><button type="button" class="delete btn-red deleteUploadedFile" title="Remove this file" data-filename="'+data.result.SERVERFILE+'">&times;</button></td></tr><tr class="fileUExtraRow" data-filename="'+data.result.SERVERFILE+'"><td></td><td class="fileUExtraCell" colspan="2"></td></tr><tr class="fileUErrorRow" data-filename="'+data.result.SERVERFILE+'"><td colspan="3"></td></tr>');
            // Count the number of uploaded files
            var fileCount = $('#uploadedFiles input.uploadedFile').length;
            //Increment this number for the filename
            fileCount++;
            // Insert the resulting filename into a hidden field
            <cfif attributes.single>
            if (typeof fileDeleted === "function" && $('#uploadedFiles input').length == 1) {
            	var oldFileName = $('#uploadedFiles input[name="uploadedFile\\[1\\]"]').attr("value");
            	//This deletes the first file. This function must run without the name parameter!
            	fileDeleted(oldFileName);
            }
            </cfif>
            // Add another input for the "array" of filenames that can be passed to another CF action page
            $('#uploadedFiles').<cfif attributes.single>html<cfelse>append</cfif>('<input type="hidden" name="uploadedFile['+fileCount+']" class="uploadedFile" value="'+data.result.SERVERFILE+'" data-filename="'+data.result.SERVERFILE+'" />');
            //Add the name of the last file to the lastUploadedFile input that is used for required validation
            $('#lastUploadedFile').val(data.result.SERVERFILE);

            // A new array of structures to store more sophisticated metadata about the files
            $('#uploadedFilesInfo').append('<input type="hidden" name="uploadedFilesInfo['+fileCount+'].filename" class="uploadedFileInfoName" value="'+data.result.SERVERFILE+'" data-filename="'+data.result.SERVERFILE+'" />');
            $('#uploadedFilesInfo').append('<input type="hidden" name="uploadedFilesInfo['+fileCount+'].filesize" class="uploadedFileInfoSize" value="'+data.result.FILESIZE+'" data-filename="'+data.result.SERVERFILE+'" />');

            // If there is a fileAdded function, run it so the page is adjusted in the desired way.
            if (typeof fileAdded === "function" ) {
            	fileAdded(data.result.SERVERFILE, data.files);
            }

        },

    });
});

// Handle clicks on the deleteUploadedFile buttons
$('#uploadedFileList').on('click', '.deleteUploadedFile', function() {
	var file = $(this).attr('data-filename');
	var fileRow = $(this).parents('tr');
	var extraRow = $(fileRow).next();
	var fileInput = $('input.uploadedFile[value="'+file+'"]');
	var fileInputName = $('input.uploadedFileInfoName[data-filename="'+file+'"]');
	var fileInputSize = $('input.uploadedFileInfoSize[data-filename="'+file+'"]');
	// console.log(fileRow);
	// console.log(fileInput);
	var user = $('input[name="fuUser"]').val();
	var appID = $('input[name="fuAppID"]').val();
	$(fileRow).remove();
	$(extraRow).remove();
	$(fileInput).remove();
	$(fileInputName).remove();
	$(fileInputSize).remove();
	fileCount--;
	//renumber uploadedfiles
	$('.uploadedFile').each(function(i){
		var cfi = i+1;
		$(this).prop('name', 'uploadedFile['+cfi+']');
	});

	$('.uploadedFileInfoName').each(function(i){
		var cfi = i+1;
		$(this).prop('name', 'uploadedFileInfoName['+cfi+'].filename');
	});

	$('.uploadedFileInfoSize').each(function(i){
		var cfi = i+1;
		$(this).prop('name', 'uploadedFileInfoSize['+cfi+'].filesize');
	});

	$('#fileupload').prop('disabled', false);
	$('#progress .status').html('<cfif NOT attributes.single> You may add more files.</cfif>');

	// If there is a fileDeleted function, run it so the page is adjusted in the desired way.
    if (typeof fileDeleted === "function") {
    	fileDeleted(file);
    }

	$.post('//<cfoutput>#CGI.HTTP_HOST#</cfoutput>/Includes/uploadHandler.cfm', {del: file, fuAppID: appID, fuUser: user}).done(function(data){
	});
});


</script>

	</div><!--.formItem-->

</cfif><!--- if thistag.execuationMode EQ Start --->