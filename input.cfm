<cfscript>
/**
 * This custom tag incorporates the styles used in EPL apps/www2 form inputs.
 * Supports use of apps-validator form validation.
 *
 * Attributes:
 *  id: Creates a matching name attribute by default, unless one is provided.
 *      Also uses this ID for the label "for" element if a label is given
 *
 *  label: Creates a label with specified text that has a for attribute
 *      matching the id attribute.
 *
 *  error: default error text will be set to this value and used unless a more
 *      specific error is set
 *
 *  errorClass: adds the specified class to the error element
 *
 *  description: a description paragraph will be added with the specified
 *      content below the element
 *
 *  prefix: Adds a prefix label to the input field (only regular input fields like text)
 *
 * Note that we ignore the 'end' executionMode because using start and end
 * separately causes issues with persistence of the CFC.
 * Although this precludes you from adding contents between the start and end components,
 * in practice, this tag doesn't really need to have contents inserted inside it
 * (e.g., for textarea or select), as the AppInput CFC handles all that itself.
 */
if (thisTag.executionMode == 'start') new AppInput(attributes).writeOutput()

</cfscript><!--- No whitespace after this - it adds unwanted space inside textareas --->