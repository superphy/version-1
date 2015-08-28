###

 File: superphy_summary.coffee
 Desc: Meta-data Summary class
 Author: Jason Masih jason.masih@phac-aspc.gc.ca
 Date: March 4th, 2015

###

###

 CLASS SummaryView

 Group/selection meta-data summary view 

 Creates stacked bar representation of meta-data for genome group/selection

###

class SummaryView extends ViewTemplate
  constructor: (@parentElem, @style, @elNum, @genomes, summaryArgs) ->
    widthToCalc = $('#selection-svg').width()-150
    @width = widthToCalc
    @height = 200
    @offset = 150
    @genomeCounter = "No genomes selected"
    @groupTracker = "No group selected"
    @selectionInfo = $("<p>" + @genomeCounter + "</p>").appendTo('#selection-info')
    @activeGroupInfo = $("<p>" + @groupTracker + "</p>").appendTo('#active-group-info')

    @svgSelection = d3.select('#selection-svg').append('svg').attr('class', 'summaryPanel').attr('width','101%').attr('height', @height)
    @svgActiveGroup = d3.select('#active-group-svg').append('svg').attr('class', 'summaryPanel').attr('width', '101%').attr('height', @height)
    
    @mtypesDisplayed = ['serotype','isolation_host','isolation_source','syndrome','stx1_subtype','stx2_subtype']
    @colours = {
      'serotype' : [
        '#236932',
        '#468554',
        '#6AA276',
        '#8DBE98',
        '#B0DABA',
        '#D4F7DC',
        '#e9fbed'
      ]
      'isolation_host' : [
        '#a70209',
        '#b3262c',
        '#c04a4f',
        '#cc6e72',
        '#d99295',
        '#e5b6b8',
        '#f2dadb'
      ]
      'isolation_source' : [
        '#3741ae',
        '#535cb9',
        '#7077c5',
        '#8c92d0',
        '#a9addc',
        '#c5c8e7',
        '#e2e3f3'
      ]
      'syndrome' : [
        '#962ba6',
        '#a549b2',
        '#b467bf',
        '#c385cc',
        '#d2a4d8',
        '#e1c2e5',
        '#f0e0f2'
      ]
      'stx1_subtype' : [
        '#F05C00',
        '#EF7123',
        '#EE8746',
        '#ED9D69',
        '#ECB28C',
        '#EBC8AF',
        '#EADED2'
      ]
      'stx2_subtype' : [
        '#35a6a7',
        '#51b2b3',
        '#6ebfc0',
        '#8bcccc',
        '#a8d8d9',
        '#c5e5e5',
        '#e2f2f2'
      ]
    }
    @resizing = false

    totalCount = {}
    for m in @mtypesDisplayed
      totalCount[m] = {}

    all_genomes = (Object.keys(@genomes.public_genomes)).concat(Object.keys(@genomes.private_genomes))
    
    # Saves total meta-data frequency to totalCount object
    for g in all_genomes
      @countMeta(totalCount, @genomes.genome(g), true)

    # @metaOntology object ensures the sub-bars of the meta-data summaries are in the order of the most frequent meta-data types (descending), according to the entire set of genomes
    # tt_mtitle sets meta-data category titles to have correct capitalization and spacing 
    @metaOntology = {}
    @tt_mtitle = {}
    for m in @mtypesDisplayed
      @selectionCount[m] = {}
      @metaOntology[m] = []
      @tt_mtitle[m] = new String()
      @metaOntology[m] = Object.keys(totalCount[m]).sort((a,b) -> totalCount[m][b] - totalCount[m][a])
      if m is "isolation_host" or m is "isolation_source"
        @tt_mtitle[m] = m.charAt(0).toUpperCase() + m.slice(1)
        @tt_mtitle[m] = @tt_mtitle[m].replace("_", " ")
        @tt_mtitle[m] = @tt_mtitle[m].slice(0,10) + @tt_mtitle[m].charAt(10).toUpperCase() + @tt_mtitle[m].slice(11)
      if m is "syndrome"
        @tt_mtitle[m] = "Symptoms/Diseases"
      if m is "stx1_subtype" or m is "stx2_subtype"
        @tt_mtitle[m] = m.charAt(0).toUpperCase() + m.slice(1)
        @tt_mtitle[m] = @tt_mtitle[m].replace("_", " ")
        @tt_mtitle[m] = @tt_mtitle[m].slice(0,5) + @tt_mtitle[m].charAt(5).toUpperCase() + @tt_mtitle[m].slice(6)
      if m is "serotype"
        @tt_mtitle[m] = m.charAt(0).toUpperCase() + m.slice(1)
    console.log("Test")
    super(@parentElem, @style, @elNum)

  selection: []
  selectionCount: {}
  activeGroup: []
  activeGroupCount: {}

  type: 'summary'
  
  elName: 'meta_summary'

  sumView: true

  # Empty to satisfy class requirements.  Should be changed.
  # FUNC update
  #
  # PARAMS
  # GenomeController object
  #
  # RETURNS
  # boolean
  #
  update: (genomes) ->

    true

  # FUNC updateActiveGroup
  # Update active group meta-data summary view
  #
  # PARAMS
  # GenomeController object, UserGroup object
  # 
  # RETURNS
  # boolean 
  # 
  updateActiveGroup: (usrGrp) ->


    if @resizing is false
      # Reset counts upon selecting a new group
      for m in @mtypesDisplayed
        @activeGroupCount[m] = {}
        @selectionCount[m] = {}

      tempActiveGroup = []

      # Get active group genome list
      @activeGroup = []
      @activeGroup = (usrGrp.active_group.public_list).concat(usrGrp.active_group.private_list)

      
      for g in @activeGroup
        if @genomes.genome(g).visible
          tempActiveGroup.push(g)

      @activeGroup = tempActiveGroup

      if @genomes.filterReset
        for g in @activeGroup
          @genomes.genome(g).isSelected = true

      # Copy @activeGroup into @selection for initial selection view
      @selection = []
      @selection = @selection.concat(@activeGroup)

      if @selection.length is 0 and @resizing is false
        @genomeCounter = 'No genomes selected'
        $('#selection-buttons').empty()
      if @selection.length is 1
        @genomeCounter = '1 genome selected'
        @groupEditForm('#selection-buttons', usrGrp) unless $('#selection-buttons').find('.form-group')[0]?
      if @selection.length > 1
        @genomeCounter = @selection.length + ' genomes selected'
        @groupEditForm('#selection-buttons', usrGrp) unless $('#selection-buttons').find('.form-group')[0]?
      $('#selection-info').html("<p>" + @genomeCounter + "</p>")

      if @activeGroup.length is 0 and @resizing is false
        @groupTracker = 'No group selected'
        $('#active-group-buttons').empty()
      if @activeGroup.length is 1 
        @groupTracker = "Active Group: " + usrGrp.active_group.group_name + " (" + @activeGroup.length + " genome)"
        @groupEditForm('#active-group-buttons', usrGrp) unless $('#active-group-buttons').find('.form-group')[0]?
      if @activeGroup.length > 1
        @groupTracker = "Active Group: " + usrGrp.active_group.group_name + " (" + @activeGroup.length + " genomes)"
        @groupEditForm('#active-group-buttons', usrGrp) unless $('#active-group-buttons').find('.form-group')[0]?
      $('#active-group-info').html("<p>" + @groupTracker + "</p>")
      
    
      for g in @activeGroup
        @countMeta(@activeGroupCount, @genomes.genome(g), true)
      for g in @selection
        @countMeta(@selectionCount, @genomes.genome(g), true)
      
      
    @createMeters(@activeGroupCount, @svgActiveGroup, @activeGroup)
    @createMeters(@selectionCount, @svgSelection, @selection)

    true

  # FUNC groupEditForm
  # Creates group edit (create, delete, update) form upon group or genome selection
  #
  # PARAMS
  # Button row ID, UserGroup object
  #
  # RETURNS
  # boolean
  #
  groupEditForm: (buttonsID, usrGrp) ->

    group_update = jQuery('<div class="form-group" style="margin-bottom:0px"></div>').appendTo(buttonsID)

    # If user isn't logged in
    unless usrGrp.username isnt ""

      custom_select = jQuery('<p>Please <a href="/superphy/user/login">sign in</a> to view your custom groups</p>')

      group_update_button_row1 = jQuery('<div class="row" style="margin-top:5px;padding:2px"></div>').appendTo(group_update)
      if buttonsID is '#selection-buttons'
        group_delete_button = jQuery('<div class="col-md-6"><button class="btn btn-sm" type="button">Clear selection</button></div></div>').appendTo(group_update_button_row1)
        group_update_input_row = jQuery('<div style="margin-top:5px"><p>Please <a href="/superphy/user/login">sign in</a> to create a group from your selection or update a group</p></div>').appendTo(group_update)
        group_update_input_row = jQuery('<div class="row" style="margin-top:5px;margin-left:8px"></div>').appendTo(group_update)
      if buttonsID is '#active-group-buttons'
        group_delete_button = jQuery('<div class="col-md-12"><button class="btn btn-sm" type="button">Clear active group</button></div>').appendTo(group_update_button_row1)
        group_update_input_row = jQuery('<div style="margin-top:5px"><p>Please <a href="/superphy/user/login">sign in</a> to view your custom groups</p></div>').appendTo(group_update)
        group_update_input_row = jQuery('<div class="row" style="margin-top:5px;margin-left:8px"></div>').appendTo(group_update)

      group_delete_button.click( (e) =>
        e.preventDefault()
        if buttonsID is '#selection-buttons'
          @clearSelection = true
          selection = []
          selection = selection.concat(@selection)
          for g in selection
            v.select(g, false) for v in viewController.views
            viewController.genomeController.genome(g).isSelected = false
          if viewController.views[2].constructor.name is 'SummaryView'
            summary = viewController.views[2]
            summary.afterSelect(@.checked)
          viewController.views[0].bonsaiActions(viewController.genomeController)
          @clearSelection = false
        if buttonsID is '#active-group-buttons'
          usrGrp._updateSelections({select_public_ids: [], select_private_ids: []}, "", "public")
        ) if group_delete_button?

    else
      custom_select = jQuery('<select id="custom_group_collections" class="form-control" placeholder="Select custom group(s)..."></select>')
      
      group_update_input_row = jQuery('<div class="row" style="margin-top:5px"></div>').appendTo(group_update)
      group_update_input = jQuery('<div class="col-xs-12">'+
        '<input class="form-control input-sm" type="text" id="create_group_name_input_summary" placeholder="Group Name">'+
        '<input style="margin-top:5px" class="form-control input-sm" type="text" id="create_collection_name_input_summary" placeholder="Collection Name">'+
        '<input style="margin-top:5px" class="form-control input-sm" type="text" id="create_description_input_summary" placeholder="Description">'+
          '</div>').appendTo(group_update_input_row) if buttonsID is '#selection-buttons'

      group_update_button_row1 = jQuery('<div class="row" style="margin-top:5px;padding:2px"></div>').appendTo(group_update)
      group_update_button_row2 = jQuery('<div class="row" style="padding-left:2px"></div>').appendTo(group_update)
      if buttonsID is '#selection-buttons'
        group_create_button = jQuery('<button class="btn btn-sm" type="button" style="margin-right:2pt; margin-top:2pt;">Create from selection</button>').appendTo(group_update_button_row1)
        group_update_button = jQuery('<button class="btn btn-sm" type="button" style="margin-right:2pt; margin-top:2pt;">Update with selection</button>').appendTo(group_update_button_row2)
        group_delete_button = jQuery('<button class="btn btn-sm" type="button" style="margin-right:2pt; margin-top:2pt;">Clear selection</button>').appendTo(group_update_button_row1)
      if buttonsID is '#active-group-buttons'
        group_delete_button = jQuery('<div class="col-md-12"><button class="btn btn-sm" type="button">Clear active group</button></div>').appendTo(group_update_button_row1)

      # Set up button click actions:
      group_create_button.click( (e) =>
        e.preventDefault()
        # Append hidden input to the form and submit
        data = []
        
        group_create_button.prepend(" <span class='fa fa-refresh spinning' style='margin-left:-3pt;'></span>")
        # data.push(encodeURIComponent($('#create_group_name_input').val()))
        # data.push(encodeURIComponent($('#create_collection_name_input').val()))
        # data.push(encodeURIComponent($('#create_description_input').val()))

        for g, g_obj of usrGrp.viewController.genomeController.public_genomes
          if g_obj.isSelected
            data.push('genome='+g)
            # data.push(encodeURIComponent('genome='+g))
 
        for g, g_obj of usrGrp.viewController.genomeController.private_genomes 
          if g_obj.isSelected
            data.push('genome='+g)
            # data.push(encodeURIComponent('genome='+g))

        data_str = data.join('&')

        jQuery.ajax({
          type: "GET",
          url: '/superphy/collections/create?'+data_str
          data: {
            'name': $('#create_group_name_input_summary').val(),
            'category' : $('#create_collection_name_input_summary').val(),
            'description' : $('#create_description_input_summary').val()
          }
          }).done( (data) =>
            console.log data
            #remove the spinner and resize the button
            group_create_button.find('span').remove()
            if data.success is 1
              if $('#create_group_name_input_error')
                $('#create_group_name_input_error').remove()
              for g, g_obj of usrGrp.viewController.genomeController.public_genomes
                if g_obj.isSelected
                  g_obj.groups.push(data.group_id) unless g_obj.groups.indexOf(data.group_id) > -1
              for g, g_obj of usrGrp.viewController.genomeController.private_genomes
                if g_obj.isSelected
                  g_obj.groups.push(data.group_id) unless g_obj.groups.indexOf(data.group_id) > -1
              $('#user-groups-selectize-form').remove()
              usrGrp.appendGroupForm(data.groups)
            else if data.success is 0
              if $('#create_group_name_input_error')
                $('#create_group_name_input_error').remove()
              $('#create_group_name_input_summary').before("<p id='create_group_name_input_error' style ='color:red;'>"+data.error+"</p>")
          ).fail ( (error) ->
            console.log error
          )
        ) if group_create_button?

      group_update_button.click( (e) =>

        
        group_update_button.prepend(" <span class='fa fa-refresh spinning' style='margin-right:5pt;'></span>")

        # Append hidden input to the form and submit
        data = []
        for g, g_obj of usrGrp.viewController.genomeController.public_genomes 
          if g_obj.isSelected
            data.push('genome='+g)
 
        for g, g_obj of usrGrp.viewController.genomeController.private_genomes 
          if g_obj.isSelected
            data.push('genome='+g)

        data_str = data.join('&')

        name =  $('#create_group_name_input_summary').val()
        group_id = usrGrp.user_custom_groups[name]
        console.log name
        console.log group_id

        #TODO:
        e.preventDefault()
        jQuery.ajax({
          type: "GET",
          url: '/superphy/collections/update?'+data_str,
          data: {
            'group_id' : group_id,
            'name': name,
            'category' : $('#create_collection_name_input_summary').val(),
            'description' : $('#create_description_input_summary').val()
          }
          }).done( (data) =>
            console.log data
            if $('#create_group_name_input_error')
                $('#create_group_name_input_error').remove()
            
            group_update_button.find('span').remove()

            if data.success is 1
              for g, g_obj of usrGrp.viewController.genomeController.public_genomes
                if g_obj.isSelected
                  g_obj.groups.push(data.group_id) unless g_obj.groups.indexOf(data.group_id) > -1
              for g, g_obj of usrGrp.viewController.genomeController.private_genomes
                if g_obj.isSelected
                  g_obj.groups.push(data.group_id) unless g_obj.groups.indexOf(data.group_id) > -1
              $('#user-groups-selectize-form').remove()
              usrGrp.appendGroupForm(data.groups)
            else if data.success is 0
              if $('#create_group_name_input_error')
                $('#create_group_name_input_error').remove()
              $('#create_group_name_input_summary').before("<p id='create_group_name_input_error' style ='color:red;'>"+data.error+"</p>")

          ).fail ( (error) ->
            console.log error
          )
        ) if group_update_button?

      group_delete_button.click( (e) =>
        e.preventDefault()
        if buttonsID is '#selection-buttons'
          @clearSelection = true
          selection = []
          selection = selection.concat(@selection)
          for g in selection
            v.select(g, false) for v in viewController.views
            viewController.genomeController.genome(g).isSelected = false
          if viewController.views[2].constructor.name is 'SummaryView'
            summary = viewController.views[2]
            summary.afterSelect(@.checked)
          viewController.views[0].bonsaiActions(viewController.genomeController)
          @clearSelection = false
        if buttonsID is '#active-group-buttons'
          usrGrp._updateSelections({select_public_ids: [], select_private_ids: []}, "", "public")
        ) if group_delete_button?

    #custom_select.appendTo(group_select)
      
    usrGrp._processGroups(usrGrp)


  # FUNC countMeta
  # Counts meta-data, for both selecting and unselecting
  #
  # PARAMS
  # Count object, genome object, isSelected boolean
  #
  # RETURNS
  # Count object
  #
  countMeta: (count, genome, isSelected) ->
    
    if isSelected
      # Increments count for selected genomes
      if count['serotype'][genome.serotype]?
        count['serotype'][genome.serotype] += 1
      else count['serotype'][genome.serotype] = 1
      if count['isolation_host'][genome.isolation_host]?  
        count['isolation_host'][genome.isolation_host] += 1
      else count['isolation_host'][genome.isolation_host] = 1
      if count['isolation_source'][genome.isolation_source]?
        count['isolation_source'][genome.isolation_source] += 1
      else count['isolation_source'][genome.isolation_source] = 1
      if count['syndrome'][genome.syndrome]?
        count['syndrome'][genome.syndrome] += 1
      else count['syndrome'][genome.syndrome] = 1
      if count['stx1_subtype'][genome.stx1_subtype]?
        count['stx1_subtype'][genome.stx1_subtype] += 1
      else count['stx1_subtype'][genome.stx1_subtype] = 1
      if count['stx2_subtype'][genome.stx2_subtype]?
        count['stx2_subtype'][genome.stx2_subtype] += 1
      else count['stx2_subtype'][genome.stx2_subtype] = 1
    else
      # Decrements count for unselected genomes
      if count['serotype'][genome.serotype] > 0
        count['serotype'][genome.serotype] -= 1
      else count['serotype'][genome.serotype] = 0
      if count['isolation_host'][genome.isolation_host] > 0
        count['isolation_host'][genome.isolation_host] -= 1
      else count['isolation_host'][genome.isolation_host] = 0
      if count['isolation_source'][genome.isolation_source] > 0
        count['isolation_source'][genome.isolation_source] -= 1
      else count['isolation_source'][genome.isolation_source] = 0
      if count['syndrome'][genome.syndrome] > 0
        count['syndrome'][genome.syndrome] -= 1
      else count['syndrome'][genome.syndrome] = 0
      if count['stx1_subtype'][genome.stx1_subtype] > 0
        count['stx1_subtype'][genome.stx1_subtype] -= 1
      else count['stx1_subtype'][genome.stx1_subtype] = 0
      if count['stx2_subtype'][genome.stx2_subtype] > 0
        count['stx2_subtype'][genome.stx2_subtype] -= 1
      else count['stx2_subtype'][genome.stx2_subtype] = 0

    count

  # FUNC select
  # Resets @selectionCount object and pushes selected genome to @selection
  #
  # PARAMS
  # Genome object from GenomeController list
  # Boolean indicating if selected/unselected 
  # 
  # RETURNS
  # boolean 
  #       
  select: (genome, isSelected) ->

    # Runs if a group has not been selected or a selection is being made after a group is selected; suppresses double run
    if user_groups_menu.runSelect or !user_groups_menu.groupSelected

      @selectionCount = {}
      for m in @mtypesDisplayed
        @selectionCount[m] = {}
      
      if isSelected
        @selection.push(genome) unless @selection.indexOf(genome) > -1
      else 
        @selection.splice(@selection.indexOf(genome), 1)

      true


  # FUNC intro
  # Sets intro.js content
  #
  # PARAMS
  # 
  # RETURNS
  # tableIntro array
  #
  intro: ->
    tableIntro = []
    tableIntro.push({
      element: document.querySelector('#groups_summary')
      intro: "This panel displays genome meta-data in a proportional bar representation. Each bar represents a meta-data category and each segment represents the frequency of each meta-data type.  Hovering over each segment will display more information.  
      Tabs allow for toggling between summaries for selected genomes and for the active group.  Groups can also be created/edited from selected genomes."
      position: 'bottom'
      })
    tableIntro
  
  # FUNC afterSelect
  # Runs after select for efficiency.  Tallies metadata in @selection and creates summary meters.  Also adds
  # group editing form
  #
  # PARAMS
  # Boolean indicating if selected/unselected 
  # 
  # RETURNS
  # boolean 
  # 
  afterSelect: () ->    
    
    
    #Run in viewController.select and on click for map list
    if @resizing == false
      for g in @selection
        @countMeta(@selectionCount, @genomes.genome(g), true)
    if @selection.length is 0 and @resizing == false
      @genomeCounter = 'No genomes selected'
      $('#selection-buttons').empty()
    if @selection.length is 1
      @genomeCounter = '1 genome selected'
      @groupEditForm('#selection-buttons', user_groups_menu) unless $('#selection-buttons').find('.form-group')[0]?
    if @selection.length > 1
      @genomeCounter = @selection.length + ' genomes selected'
      @groupEditForm('#selection-buttons', user_groups_menu) unless $('#selection-buttons').find('.form-group')[0]?
    $('#selection-info').html("<p>" + @genomeCounter + "</p>")    
    @createMeters(@selectionCount, @svgSelection, @selection)
    

    true

  # FUNC createMeters
  # Creates stacked bar representation of meta-data for summary count object
  #
  # PARAMS
  # summary count object, SVG view, count type array
  # 
  # RETURNS
  # boolean 
  # 
  
  createMeters: (sumCount, svgView, countType) ->
    
    #to calculate the required width for the svg, we need to get the information in the tab
    if $('#tabs').find('.active').find('a').attr('href') is '#selection-tab'
      @width = $('#selection-svg').width()-150
    else if $('#tabs').find('.active').find('a').attr('href') is '#active-group-tab'
      @width = $('#active-group-svg').width()-150
    if countType?
      totalSelected = countType.length
    else totalSelected = 0

    # Removes old summary meters
    svgView.selectAll('rect.summaryMeter').remove()
    
    # Creates HTML for popover tables
    tt_sub_table = {}
    tt_table_partial = {}
    tt_table = {}
    other_count = {}
    for m in @mtypesDisplayed
      tt_sub_table[m] = new String()
      tt_table_partial[m] = new String()
      tt_table[m] = new String()
      other_count[m] = 0
      i = 0
      while i < @metaOntology[m].length
        if i > 5 && sumCount[m][@metaOntology[m][i]]?
          other_count[m] += sumCount[m][@metaOntology[m][i]]
        tt_mtype = @metaOntology[m][i].charAt(0).toUpperCase() + @metaOntology[m][i].slice(1)
        if sumCount[m][@metaOntology[m][i]] > 0
          # If there is an "Other" case
          if i >= 6
            # Creates sub-table of all meta-data frequencies that are not within the top 6 overall 
            tt_sub_table[m] += ("<tr><td>" + tt_mtype + "</td><td style='text-align:right'>" + sumCount[m][@metaOntology[m][i]] + "</td></tr>")
            # Adds "Other" case to the whole table, including the expand/collapse functionality and the contents of tt_sub_table[m]
            tt_table[m] = tt_table_partial[m] + ("<tbody class='other-row' onclick=\"$('.after-other').slideToggle(100);\"><tr><td>[+] Other</td><td style='text-align:right'\">" + other_count[m] + "</td></tr></tbody><tbody class='after-other'>" + tt_sub_table[m] + "</tbody>")
          else
            # Assembles the rows of the table without the "Other" case
            tt_table_partial[m] += ("<tr><td>" + tt_mtype + "</td><td style='text-align:right'>" + sumCount[m][@metaOntology[m][i]] + "</td></tr>")
            # Copies last row for when there is no "Other" case
            tt_mtype_last = tt_mtype
            # In no "Other" case, copies over table contents into tt_table[m] for use in popovers
            tt_table[m] = tt_table_partial[m]
        i++
    
    # Adds rectangles to the tabbed window section for each type of meta-data summary
    y = 0
    for m in @mtypesDisplayed
      y += 30
      # Removes duplicate summary bar groups
      svgView.selectAll('g.sumBar_' + m).remove()
      # Groups summary meters into bars and adds meta-data category labels
      sumBar = svgView.append('g').attr('class', 'sumBar_' + m)
      sumBar.append('text').attr('y', y + 15).text(()->
        if m is "isolation_host" or m is "isolation_source"
          meta_label = m.charAt(0).toUpperCase() + m.slice(1)
          meta_label = meta_label.replace("_", " ")
          meta_label = meta_label.slice(0,10) + meta_label.charAt(10).toUpperCase() + meta_label.slice(11)
        if m is "syndrome"
          meta_label = "Symptoms/Diseases"
        if m is "stx1_subtype" or m is "stx2_subtype"
          meta_label = m.charAt(0).toUpperCase() + m.slice(1)
          meta_label = meta_label.replace("_", " ")
          meta_label = meta_label.slice(0,5) + meta_label.charAt(5).toUpperCase() + meta_label.slice(6)
        if m is "serotype"
          meta_label = m.charAt(0).toUpperCase() + m.slice(1)
        if totalSelected is 0
          meta_label = ''
        meta_label)
      width = []
      i = 0
      j = 0
      x = 0
      if @metaOntology[m].length < 7
        bar_count = @metaOntology[m].length
      else bar_count = 7
      while i < bar_count
        if i < 6 and sumCount[m][@metaOntology[m][i]]? and totalSelected > 0
          width[i] = @width * (sumCount[m][@metaOntology[m][i]] / totalSelected)
        else if i is 6 and totalSelected > 0 and @metaOntology[m][i]?
          width[i] = (@width - (width[0] + width[1] + width[2] + width[3] + width[4] + width[5]))
        else
          width[i] = 0
        length = 0
        pos = 0
        if @metaOntology[m][i]?
          pos = tt_table[m].indexOf(@metaOntology[m][i].charAt(0).toUpperCase() + @metaOntology[m][i].slice(1))
        if sumCount[m][@metaOntology[m][i]] > 0
          length = (@metaOntology[m][i] + "</td><td style='text-align:right'>" + sumCount[m][@metaOntology[m][i]]).length
          tt_data = tt_table[m].slice(0, pos - 8) + "<tr class='table-row-bold' style='color:" + @colours[m][3] + "'><td>" + tt_table[m].slice(pos, length + pos) + "</td></tr>" + tt_table[m].slice(length + pos)
        if i is 6
          if !sumCount[m][@metaOntology[m][5]]?
            if tt_table[m].indexOf("[+] Other")?
              pos = tt_table[m].indexOf("[+] Other")
            else pos = tt_table[m].indexOf(tt_mtype_last)
            tt_data = tt_table[m].slice(0, pos - 8) + "<tr class='table-row-bold' style='color:" + @colours[m][3] + "'><td>" + tt_table[m].slice(pos)
          else
            tt_data = tt_table[m].slice(0, tt_table[m].indexOf("[+] Other") - 8) + "<tr class='table-row-bold' style='color:" + @colours[m][3] + "'><td>" + tt_table[m].slice(tt_table[m].indexOf("[+] Other"))
        sumBar.append('rect')
          .attr('class', 'summaryMeter')
          .attr('id',
            if i is 6
              "Other"
            else @metaOntology[m][i])
          .attr('x', x + @offset unless isNaN(x))
          .attr('y', y)
          .attr('height', 20)
          .attr('width', Math.abs(width[i]) unless isNaN(width[i]))
          .attr('stroke', 'black')
          .attr('stroke-width', 1)
          .attr('fill', @colours[m][j++])
          .attr("data-toggle", "popover")
          .attr('data-content',
            if width[i] > 0
              "<table class='popover-table'><tr><th style='min-width:160px;max-width:160px;text-align:left'>" + @tt_mtitle[m] + "</th><th style='min-width:110px;max-width:110px;text-align:right'># of Genomes</th></tr>" + tt_data + "</table>")
        x += width[i]
        i++

    # Allows popovers to work in SVG
    svgView.selectAll('.summaryMeter')
      .each(()->
        $(this).popover({
          placement: 'bottom',
          html: 'true',
          trigger: 'hover',
          delay: {show:500, hide:500},
          animate: 'false',
          container: 'body',
          }))

    true


