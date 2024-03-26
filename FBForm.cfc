<cfscript>
/**
 * FBForm - Form Builder Form Component
 * Supports generating the inputs for a form made with the Apps Legacy FormBuilder.
 */
component {
  property name="formId" type="numeric" hint="The ID of the form being submitted.";
  property name="formSubmissionId" type="numeric" default="0" hint="The ID of the form submission being edited.";
  property name="submissionValuesMap" type="struct" hint="Map of field IDs to their values for the current submission.";
  property name="formUser" type="UserInfo" hint="UserInfo object for the user submitting the form.";
  property name="formUserManager" type="UserInfo" hint="UserInfo object for the user's manager.";
  // Cache variables for data
  property name="staff" type="query";
  property name="staffIncludingInactive" type="query";
  property name="managers" type="query";
  property name="cipStaff" type="query";
  property name="costCentres" type="query";
  property name="costElements" type="query";

  property name="defaultDataValues" type="array" hint="Default values for form inputs.";

  public any function init(
    required numeric formId,
    string onBehalf = '',
    numeric stageNumber = 1, // TODO: This could be determined from the formSubmissionId, write function to get submission data
    numeric formSubmissionId = 0
  ) {
    variables.formId = formId
    variables.onBehalf = onBehalf
    variables.stageNumber = stageNumber
    variables.formSubmissionId = formSubmissionId

    // Reflect the data of an onBehalf user for the first stage, if it exists
    var formUsername = (len(onBehalf) && stageNumber == 1) ? onBehalf : session.identity ?: ''

    variables.formUser = new userInfo(formUsername)

    variables.formUserManager = len(thisUser?.manager) ? new userInfo(thisUser.manager) : {}

    //Set up
    // Next pay Date after loop runs
    var payDate = variables.nextPayDate().format('yyyy-mmm-dd')

    // Pay date 40 pay periods from now
    var payDate40 = payDate.add('ww', 80).format('yyyy-mmm-dd')

    // Used to populate default values for fields
    variables.defaultDataValues = [
      now().format('yyyy-mmm-dd'),     // 1: Today's date
      formUser.displayName,            // 2: Name of the user
      formUser.mail,                   // 3: Email for the user
      formUser.employeeID,             // 4: EmployeeID of the user
      formUser.title,                  // 5: Title of the user
      formUser.location,               // 6: Service Point of the user
      formUserManager?.displayName,    // 7: User's manager's name
      formUserManager?.mail,           // 8: User's manager's email
      formUsername,                    // 9: Username of the user
      formUser.phoneNumber,            // 10: Phone number of the user
      payDate,                         // 11: Next pay date
      payDate40                        // 12: Pay date 40 days from now
    ]

    // Load the submission values if they haven't been loaded yet
    loadSubmissionValues()

    return this
  }

  private void function loadSubmissionValues() {
    if (variables.formSubmissionID <= 0) return;

    // Could also query 'optIDs' lists here if needed
    var submissionValues = queryExecute("
      SELECT FieldID, Value
      FROM vsd.FormsSubmissionsValues
      WHERE SubID = :subID
      ",
      {subID: {value: variables.formSubmissionID, cfsqltype: 'CF_SQL_INTEGER'}}
    );

    variables.submissionValuesMap = {}
    for (var sv in submissionValues) variables.submissionValuesMap[sv.FieldID] = sv.Value;
  }


  /** Getters for data that may be used by form inputs. Caches to cfc properties. */
  private query function getStaff() {
    if (!variables.keyExists('staff')) {
      variables.staff = queryExecute("
        SELECT userName AS value, displayName AS label
        FROM vsd.AppsUsers WHERE isDisabled = 0 ORDER BY displayName
      ")
    }

    return variables.staff
  }

  private query function getStaffIncludingInactive() {
    if (!variables.keyExists('staffIncludingInactive')) {
      variables.staffIncludingInactive = queryExecute("
        SELECT userName AS value, displayName AS label
        FROM vsd.AppsUsers ORDER BY displayName
      ")
    }

    return variables.staffIncludingInactive
  }


  private query function getManagers() {
    if (!variables.keyExists('managers')) {
      variables.managers = queryExecute("
        SELECT userName AS value, displayName AS label
        FROM vsd.AppsUsers WHERE isManager = 1 AND isDisabled = 0
        ORDER BY displayName
      ")
    }

    return variables.managers
  }

  private query function getCipStaff() {
    if (!variables.keyExists('cipStaff')) {
      variables.cipStaff = queryExecute("
        SELECT userName AS value, displayName AS label
        FROM vsd.AppsUsers WHERE (location='CIP' OR locationList LIKE '%CIP%') AND isDisabled = 0
        ORDER BY displayName
      ")
    }

    return variables.cipStaff
  }

  private query function getCostCentres() {
    if (!variables.keyExists('costCentres')) {
      variables.costCentres = queryExecute("
        SELECT CCNumber AS value, CONCAT(CCNumber, ': ', CCName) AS label
        FROM vsd.CostCentres ORDER BY CCNumber
      ")
    }

    return variables.costCentres
  }

  private query function getCostElements() {
    if (!variables.keyExists('costElements')) {
      variables.costElements = queryExecute("
        SELECT CENumber AS value, CONCAT(CENumber, ': ', CEName) AS label
        FROM vsd.CostElements ORDER BY CENumber
      ")
    }

    return variables.costElements
  }

  /** Return the next pay date on or after the specified date. */
  private date function nextPayDate(date currentDate = now()) {
  // Ensure date is set to a date object consistently
    currentDate = createDate(year(currentDate), month(currentDate), day(currentDate))

    // Next Pay day modulo calculation. Modulo flips after years where Saturday lands on the 53rd week.
    numeric function getModulo(required numeric year) {
      var modulo = 1
      for (var y = 2000; y < year; y++) {
        var dec31 = createDate(y, 12, 31) // Last day of the year
        var dec24 = createDate(y, 12, 24) // A week before the last day

        // Loop backward from the last day of the year to a week before
        for (var modDay = dec31; modDay >= dec24; modDay -= createTimeSpan(1, 0, 0, 0)) {
          // Checking for the 53rd week and Saturday
          if (week(modDay) == 53 && dayOfWeek(modDay) == 7) modulo = (modulo + 1) % 2
        }
      }

      return modulo
    }

    var modulo = getModulo(year(currentDate))
    for (var day = currentDate; day <= currentDate.add('d', 14); day = day.add('d', 1)) {
      if (year(day) != year(currentDate)) modulo = getModulo(year(day))
      if (week(day) % 2 == modulo && dayOfWeek(day) == 3) return day
    }

    throw('No pay date found within the next two weeks.')
  } // end nextPayDate()

  /** Render all the fields within a specified section of the form */
  void function renderSection(required numeric sectionID) {
    var sql = "
      SELECT f.*, t.*, (SELECT TOP 1 DestFieldID FROM vsd.FormsFieldsAutoFill WHERE FieldID = f.FieldID) AS DestFieldID
      FROM vsd.FormsFields f
      JOIN vsd.FormsFieldTypes t ON f.FieldTypeID = t.FieldTypeID
    "

    var queryParams = { sectionID: { value: sectionID, cfsqltype: 'CF_SQL_INTEGER' } }

    if (variables.formSubmissionID > 0) {
      sql &= "
        JOIN vsd.FormsSections sec ON sec.FSectID = f.FSectID
        JOIN vsd.FormsStages sta ON sta.FStageID = sec.FStageID
        JOIN vsd.Forms forms ON forms.FormID = sta.FormID
        JOIN vsd.FormsSubmissions s ON s.FormID = forms.FormID AND s.SubID = :subID
      "

      queryParams['subID'] = { value: variables.formSubmissionID, cfsqltype: 'CF_SQL_INTEGER' }
    }

    sql &= " WHERE f.FSectID = :sectionID ORDER BY f.Sequence ASC"

    var fields = queryExecute(sql, queryParams, { returnType: 'array' })

    var htmlOutput = ''

    for (var field in fields) variables.renderField(field)

    // Output the HTML or return it, depending on requirements
    writeOutput(htmlOutput)
  } // end renderSection()


  /** Given a field struct or query with field properties, render the field and output it. */
  void function renderField(required struct field) {
    var fieldId = field.FieldID
    var isBuilder = listLast(cgi.script_name, '/') == 'formBuilder.cfm'
    if (isBuilder) writeOutput('
      <div class="fieldDragContainer flex items-start" id="fieldDragContainer#fieldID#" data-field-id="#fieldID#">
    ')

    // Get the value of the field, if there's a submissionValuesMap, else default to the field's default value
    var value = variables.keyExists('submissionValuesMap') ? variables.submissionValuesMap[fieldId]
      : isNumeric(field?.DefaultData) ? defaultDataValues[field.DefaultData]
      : len(field?.DefaultValue) ? field.DefaultValue
      : ''

    writeOutput('<div id="form-item-#fieldId#" class="form-item">')

    // TODO: Ensure that files have requisite buttons to delete or download them
    // If a file has been entered before, put a link to the path of the existing file
    // if (field.FieldTypeID == 13 && variables.formSubmissionID > 0 && len(value)) {
    //   // TODO: Test that this button works for files
    //   writeOutput('
    //     <br />
    //     <button type="button"
    //       id="deleteFile#field.FieldID#"
    //       title="Remove this file from this form"
    //       class="delete btn-red deleteFile"
    //     ><i class="fas fa-times"></i></button>
    //     <a class="fileLink" id="fileLink#FieldID#" href="#value#">#reReplace(value, ".*/(.*)", "\1")#</a>
    //   ')
    // }

    // Assign options if this field uses any
    var options = isNumeric(field?.OptGroupID) ? queryExecute("
        SELECT OptionValue AS value, OptionDescription AS label, OptionToolTip
        FROM vsd.FormsOptGroupsOptions WHERE OptGroupID = :optGroupID
        ORDER BY Sequence, OptionDescription
      ",
      { optGroupID: { value: field?.OptGroupID, cfsqltype: 'CF_SQL_INTEGER' } },
      { returnType: 'array' }
    ) : []

    // TODO: All other field types
    // else if (field.FieldTypeID == 99999) renderCompletedStageDiv(field.FieldTypeID)
    // else if (field.FieldTypeID == 25) renderDisplayOrLabelOnly(field.FieldTypeID)
    // else if (field.FieldTypeID == 26) renderJSCalculatedField(field.FieldTypeID)
    // else if (field.FieldTypeID == 13) renderFileInput(field.FieldTypeID)
    // // Render a default input
    // else
    renderInput(field, value, options)

    writeOutput('</div>')

  } // end renderField()

  /**
   * Renders an input from the field data
   *
   * Select field types:
   * 5: Select
   * 6: SelectMulti
   * 14: StaffSelect
   * 15: StaffSelectMulti
   * 16: ManagerSelect
   * 17: ManagerSelectMulti
   * 18: ServicePointSelect
   * 19: ServicePointSelectMulti
   * 23: CostCentre Select
   * 24: CostElement Select
   * 30: CIP Staff Select
   * 31: StaffSelectWithInactive
   */
  void function renderInput(
    required struct field,
    string value = '',
    array options = [] // only used for 5 and 6
  ) {
    var fieldTypeId = field.FieldTypeId;
    var id = field.FieldID;

    var type = '5,6,14,15,16,17,18,19,23,24,30,31'.listFind(fieldTypeId) ? 'select'
      : '7,9'.listFind(fieldTypeId) ? 'checkbox' // multiple checkboxes and single checkbox
      : '11,12'.listFind(fieldTypeId) ? 'textarea'
      : fieldTypeID == 2  ? 'integer'
      : fieldTypeID == 3  ? 'email'
      : fieldTypeID == 4  ? 'tel'
      : fieldTypeID == 8  ? 'radio'
      : fieldTypeID == 10 ? 'date'
      : fieldTypeID == 13 ? 'file'      // TODO: Needs special handling
      : fieldTypeID == 22 ? 'decimal'
      : fieldTypeID == 25 ? 'display'
      : fieldTypeID == 26 ? 'jsCalc'    // TODO: Needs special handling
      : fieldTypeID == 27 ? 'markdown'
      : fieldTypeID == 28 ? 'postal'
      : fieldTypeID == 29 ? 'time'
      : 'text';

      // TODO: Add a 'datetime' type. Not needed now, but trivial to add

    // Set the options based on the fieldType
    options = '14,15'.listFind(fieldTypeId) ? getStaff()
      : fieldTypeId == 31 ? getStaffIncludingInactive()
      : '16,17'.listFind(fieldTypeId) ? getManagers()
      : '18,19'.listFind(fieldTypeId) ? application.offices
      : fieldTypeId == 23 ? getCostCentres()
      : fieldTypeId == 24 ? getCostElements()
      : fieldTypeId == 30 ? getCipStaff()
      : options;

    var label = field.Label
      & (field?.Required == 1 ? '<span class="ml-0.5 text-red-600 dark:text-red-500">*</span>' : '')
      & (len(field?.HelpText) ? '<span class="ml-2" data-tooltip="#field.HelpText#"><i class="link !no-underline fas fa-question-circle" id="help#id#"></i></span>' : '')

    var inputAttributes = {
      type: type,
      label: label,
      description: field?.FieldDesc,
      id: 'field' & id,
      name: 'field' & id,
      class: (type == 'select' ? 'chzn-select ' : '') & field?.HTMLClass,
      placeholder: len(field?.Placeholder) ? field.Placeholder
        : '6,15,17,19'.listFind(fieldTypeId) ? 'Select item(s)'
        : type == 'select' ? 'Select an item' : '',
      multiple: '6,15,17,19'.listFind(fieldTypeId) > 0,
      disabled: variables.formSubmissionID > 0 && field.SubStage > field.StageNumber,
      readonly: field?.ReadOnly == 1,
      options: options,
      value: value
    }

    if ('textarea,markdown'.listFindNoCase(type)) {
      inputAttributes.fullWidth = true
      inputAttributes.rows = 6
    }

    // If a custom error messages was specified, add it to the error attribute
    if (len(field?.Error)) inputAttributes.error = field.Error

    new AppInput(inputAttributes).writeOutput();

    // Add a list of the options when the chosen options are no longer present
    // TODO: This may only need to be displayed if a selected option is not present
    if (variables.formSubmissionID > 0 && len(arguments?.value)) {
      writeOutput('<input type="text" class="alternateInput" disabled value="#value#" />')
    }

    // Copy button for text fields
    if (variables.formSubmissionID > 0 && subStage > stageNumber) {
      writeOutput('
        <button type="button"
          class="copyButton btn-lime text-xs opacity-60 hover:opacity-100"
          >Copy <i class="fas fa-copy"></i></button>
      ')
    }

    // TODO: There's some logic around evaluating how defaults should be assigned for existing submissions.

  } // end renderSelect()


} // end component fbForm
</cfscript>