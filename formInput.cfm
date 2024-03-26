<cfscript>
/**
 * Custom tag that encapsulates cf_input but puts it inside a form-item div.
 * Note that we ignore the 'end' executionMode because using start and end
 * separately causes issues with persistence of the CFC, and in practice, this tag
 * doesn't really need to have contents inserted inside it (e.g., for textarea or select),
 * as the AppInput CFC handles all that itself.
 */
if (thisTag.executionMode == 'start') {
  writeOutput('<div class="form-item">')
  new AppInput(attributes).writeOutput()
  writeOutput('</div>')
}
</cfscript><!--- No whitespace after this - it adds unwanted space inside textareas --->