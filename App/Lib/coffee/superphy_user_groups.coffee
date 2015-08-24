###


File: superphy_user_groups.coffee
Desc: Objects & functions for managing user created groups in Superphy
Author: Akiff Manji akiff.manji@gmail.com
Date: Sept 8th, 2014


###

root = exports ? this

###
CLASS SuperphyError

Error object for this library

###
class SuperphyError extends Error
  constructor: (@message='', @name='Superphy Error') ->

class UserGroups
  constructor: (@userGroupsObj, @username, @parentElem, @viewController, @public_genomes, @private_genomes) ->
    throw new SuperphyError 'User groups object cannot be empty/null.' unless @userGroupsObj
    throw new SuperphyError 'Parent div not specified.' unless @parentElem
    throw new SuperphyError 'ViewController object is required' unless @viewController

    @user_custom_collections = {}
    @user_custom_groups = {}

    @runSelect = false
    @groupSelected = false

    @active_group = {
      group_id : '',
      public_list : [],
      private_list : [],
      group_name : ''
    }

    @appendGroupForm(@userGroupsObj)
  
  initialBonsaiState = {};

    #Separate out appending the user groups div and processing the actual groups
  appendGroupForm: (uGpObj) =>

      container = jQuery('<div id="user-groups-selectize-form"></div>').appendTo(@parentElem)
    
      tabUl = jQuery('<ul class="nav nav-tabs"></ul>').appendTo(container)
      loadGroupsTab = jQuery('<li role="presentation" class="active"><a href="#load-groups" role="tab" data-toggle="tab">Load</a></li>').appendTo(tabUl)
      createGroupsTab = jQuery('<li role="presentation"><a href="#create-groups" role="tab" data-toggle="tab">Modify/Delete</a></li>').appendTo(tabUl)

      tabPanes = jQuery('<div class="tab-content"></div>').appendTo(container)

      # Tab pane for loading groups
      loadGroupPane = jQuery('<div role="tabpanel" class="tab-pane active" id="load-groups"></div>').appendTo(tabPanes)
      load_groups_form = jQuery('<form class="form"></form>').appendTo(loadGroupPane)
      
      # Group Selections - TODO: Change to tree structure
      group_select = jQuery('<div class="control-group" style="margin-top:5px"></div>').appendTo(load_groups_form)
      

      if window.Worker 
        myWorker = new Worker("../App/Lib/js/worker/group_builder.js");

        myWorker.postMessage(JSON.stringify(uGpObj));
        myWorker.onmessage = (e) =>
          standard_select = jQuery(e.data).prependTo(group_select)
          bonsai = $('.group-list').bonsai({createInputs: 'radio',checkboxes: true})
          bonsai = $('.group-list').data('bonsai')
          @_removeCategoryRadio();
          initialBonsaiState = bonsai.serialize();
          return 1
      else
        standard_select = jQuery(this.bonsaiUserGroupList(uGpObj)).appendTo(group_select);
      
      
      
      #standard_select = jQuery('').appendTo(group_select)

      group_query_input = jQuery('<input id="group-query-input" type="hidden" data-group="" data-genome_list="">').appendTo(group_select)

      load_group = jQuery('<div class="form-group" style="margin-bottom:0px"></div>').appendTo(load_groups_form)
      load_group_row = jQuery('<div class="row"></div>').appendTo(load_group)
      load_groups_button = jQuery('button#user-groups-submit')
      load_groups_button2 = $('<div class="col-md-3"><button class="btn btn-sm" type="button">Load</button></div>').appendTo(load_group_row)

      load_groups_button.click( (e) => 
        e.preventDefault()
        data = $('#group-query-input').data()
        group_number = $('input[name=undefined]:checked', '.group-list').val()
        data = $("li[id=bonsai"+group_number+"]", '.group-list')
        select_ids = @_getGroupGenomes(group_number, @public_genomes, @private_genomes)
        @_updateSelections(select_ids, group_number, data.genome_list)

        #@standardSelectizeControl.clear()
        @customSelectizeControl.clear()
        )

      load_groups_button2.click( (e) => 
        e.preventDefault()
        data = $('#group-query-input').data()
        group_number = $('input[name=undefined]:checked', '.group-list').val()
        data = $("li[id=bonsai"+group_number+"]", '.group-list')
        select_ids = @_getGroupGenomes(group_number, @public_genomes, @private_genomes)
        @_updateSelections(select_ids, group_number, data.genome_list)

        #@standardSelectizeControl.clear()
        @customSelectizeControl.clear()
        )
      


      # Tab pane for creating groups
      createGroupPane = jQuery('<div role="tabpanel" class="tab-pane" id="create-groups"></div>').appendTo(tabPanes)
      create_group_form = jQuery('<form class="form"></form>').appendTo(createGroupPane)
      group_update = jQuery('<div class="form-group"></div>').appendTo(create_group_form)

      


      # If user logged in
      unless @username isnt ""
        custom_select = jQuery('<p>Please <a href="/superphy/user/login">sign in</a> to view your custom groups</p>')
        group_update_input_row = jQuery('<div style="margin-top:5px"><p>Please <a href="/superphy/user/login">sign in</a> to create, update and delete groups</p></div>').appendTo(group_update)
      else
        custom_select = jQuery('<select id="custom_group_collections" class="form-control" placeholder="Select custom group(s)..."></select>')
        
        group_update_input_row = jQuery('<div class="row" style="margin-top:5px"></div>').appendTo(group_update)
        group_update_input = jQuery('<div class="col-xs-12">'+
          '<input class="form-control input-sm" type="text" id="create_group_name_input" placeholder="Group Name">'+
          '<input style="margin-top:5px" class="form-control input-sm" type="text" id="create_collection_name_input" placeholder="Collection Name">'+
          '<input style="margin-top:5px" class="form-control input-sm" type="text" id="create_description_input" placeholder="Description">'+
            '</div>').appendTo(group_update_input_row)

        group_update_button_row = jQuery('<div class="row" style="margin-top:5px"></div>').appendTo(group_update)
        group_create_button = jQuery('<div class="col-xs-3"><button class="btn btn-sm" type="button">Create</button></div>').appendTo(group_update_button_row)
        group_update_button = jQuery('<div class="col-xs-3"><button class="btn btn-sm" type="button">Update</button></div>').appendTo(group_update_button_row)
        group_delete_button = jQuery('<div class="col-xs-3"><button class="btn btn-sm" type="button">Delete</button></div>').appendTo(group_update_button_row)

        # Set up button click actions:
        group_create_button.click( (e) =>
          e.preventDefault()
          # Append hidden input to the form and submit
          data = []
          for g, g_obj of @viewController.genomeController.public_genomes 
            if g_obj.isSelected
              data.push('genome='+g)
   
          for g, g_obj of @viewController.genomeController.private_genomes 
            if g_obj.isSelected
              data.push('genome='+g)

          data_str = data.join('&')

          jQuery.ajax({
            type: "GET",
            url: '/superphy/collections/create?'+data_str,
            data: {
              'name': $('#create_group_name_input').val(),
              'category' : $('#create_collection_name_input').val(),
              'description' : $('#create_description_input').val()
            }
            }).done( (data) =>
              console.log data
              if data.success is 1
                for g, g_obj of usrGrp.viewController.genomeController.public_genomes
                  if g_obj.isSelected
                    g_obj.groups.push(data.group_id) unless g_obj.groups.indexOf(data.group_id) > -1
                for g, g_obj of usrGrp.viewController.genomeController.private_genomes
                  if g_obj.isSelected
                    g_obj.groups.push(data.group_id) unless g_obj.groups.indexOf(data.group_id) > -1
                $('#user-groups-selectize-form').remove()
                @appendGroupForm(data.groups)
            ).fail ( (error) ->
              console.log error
            )
          )

        group_update_button.click( (e) =>
          # Append hidden input to the form and submit
          data = []
          for g, g_obj of @viewController.genomeController.public_genomes 
            if g_obj.isSelected
              data.push('genome='+g)
   
          for g, g_obj of @viewController.genomeController.private_genomes 
            if g_obj.isSelected
              data.push('genome='+g)

          data_str = data.join('&')

          name =  $('#create_group_name_input').val()
          group_id = @user_custom_groups[name]
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
              'category' : $('#create_collection_name_input').val(),
              'description' : $('#create_description_input').val()
            }
            }).done( (data) =>
              console.log data
              if data.success is 1
                for g, g_obj of usrGrp.viewController.genomeController.public_genomes
                  if g_obj.isSelected
                    g_obj.groups.push(data.group_id) unless g_obj.groups.indexOf(data.group_id) > -1
                for g, g_obj of usrGrp.viewController.genomeController.private_genomes
                  if g_obj.isSelected
                    g_obj.groups.push(data.group_id) unless g_obj.groups.indexOf(data.group_id) > -1
                $('#user-groups-selectize-form').remove()
                @appendGroupForm(data.groups)
            ).fail ( (error) ->
              console.log error
            )
          )

        group_delete_button.click( (e) =>
          e.preventDefault()
          name =  $('#create_group_name_input').val()
          group_id = @user_custom_groups[name]
          jQuery.ajax({
            type: "GET",
            url: '/superphy/collections/delete',
            data : {
              'group_id' : group_id
            }
            }).done( (data) =>
              if data.success is 1
                for g, g_obj of usrGrp.viewController.genomeController.public_genomes
                  if g_obj.isSelected
                    g_obj.groups.push(data.group_id)
                for g, g_obj of usrGrp.viewController.genomeController.private_genomes
                  if g_obj.isSelected
                    g_obj.groups.push(data.group_id)
                $('#user-groups-selectize-form').remove()
                @appendGroupForm(data.groups)
              $('#user-groups-selectize-form').remove()
              @appendGroupForm(data.groups)
              console.log data
            ).fail ( (error) ->
              console.log error
            )
          )

      # create or find list element


      custom_select.appendTo(group_select)
      
      


      @_processGroups(uGpObj)

      # Commented out to remove box appearing on Group Browse
      # Process notification-box area:
      # elem = jQuery('#geophy-control')
      # parentTarget = 'geophy-control-panel-body'
      # wrapper = jQuery('<div class="panel panel-default" id="geophy-control-panel"></div>')
      # elem.append(wrapper)

      # notification_box = jQuery("<div class='panel-body' id='#{parentTarget}'></div>")
      # wrapper.append(notification_box)

      true

  _processGroups: (uGpObj) =>
    

    return unless @username isnt ""

    # Process custom groups
    custom_groups_select_optgroups = []
    custom_groups_select_options = []
    for group_collection, group_collection_index of uGpObj.custom

      custom_groups_select_optgroups.push({value: group_collection_index.name, label: group_collection_index.name, count: group_collection_index.children.length})
      custom_groups_select_options.push({class: group_collection_index.name, value: group.id, name: group.name}) for group in group_collection_index.children

      @user_custom_groups[group.name] = group.id for group in group_collection_index.children

    $selectized_custom_group_select = $('#custom_group_collections').selectize({
      delimiter: ',',
      persist: false,
      options: custom_groups_select_options,
      optgroups: custom_groups_select_optgroups,
      optgroupField: 'class',
      labelField: 'name',
      searchField: ['name'],
      render: {
        optgroup_header: (data, escape) =>
          return "<div class='optgroup-header'>#{data.label} - <span>#{data.count}</span></div> "
        option: (data, escape) =>
          return "<div data-collection_name='#{data.class}' data-group_name='#{data.name}'>#{data.name}</div>"
        item: (data, escape) =>
          return "<div>#{data.name}</div>"
        },
      create: true
      })
    
    @customSelectizeControl = $selectized_custom_group_select[0].selectize

    @customSelectizeControl.on('change', () ->
      $('#group-query-input').data('group', @getValue()).data('genome_list', 'private')
      )

  # FUNC bonsaiUserGroupList
  # Creates bonsai object and generates a jquery nested list
  # From Jason's bonsaiMapList function in the superphy_map.coffee file
  #
  # PARAMS
  # GenomeController object
  # 
  # RETURNS
  # HTML table 
  # 
  bonsaiUserGroupList: (uGpObj) ->
    
    groupHash = {}
    for group_collection, group_collection_index of uGpObj.standard
      groupHash[group_collection_index.name] = {}
      for group in group_collection_index.children
        groupHash[group_collection_index.name][group.name]={}
        if group.type is "collection"
          groupHash[group_collection_index.name][group.name]['type'] = 'collection'
          for level1 in group.children
            groupHash[group_collection_index.name][group.name][level1.name]= {}
            if level1.type is "collection"
              groupHash[group_collection_index.name][group.name][level1.name]['type'] = 'collection'
              for level2 in level1.children
                groupHash[group_collection_index.name][group.name][level1.name][level2.name] = {}
                if level2.type is "group"
                  groupHash[group_collection_index.name][group.name][level1.name][level2.name] = {}
                  groupHash[group_collection_index.name][group.name][level1.name][level2.name]['id'] = level2.id
                  groupHash[group_collection_index.name][group.name][level1.name][level2.name]['type'] = level2.type
            if level1.type is "group"
              groupHash[group_collection_index.name][group.name][level1.name]['id'] = level1.id
              groupHash[group_collection_index.name][group.name][level1.name]['type'] = level1.type
        if group.type is "group"
          groupHash[group_collection_index.name][group.name] = {}
          groupHash[group_collection_index.name][group.name]['id'] = group.id
          groupHash[group_collection_index.name][group.name]['type'] = group.type
           
    console.log(groupHash)

    table = "<ol class='group-list' genome_list='public'>" 

    #looping throught the main categories, ex: serotypes, host, syndrome ...
    for level0Key in Object.keys(groupHash).sort()
      table += "<li id=#{level0Key} data-value='false'><label style='font-weight:normal;margin-top:2px;margin-left:5px;'>#{level0Key}</label>"
      table += "<ol>"

      #looping throught the level1, ex: Homo Sapiens, 1c
      for level1key in Object.keys(groupHash[level0Key]).sort()
        level1 = groupHash[level0Key][level1key]
        if level1['type'] is 'collection'
          table += "<li id=#{level1key} data-value='false'><label style='font-weight:normal;margin-top:2px;margin-left:5px;'>#{level1key}</label>"
          table += "<ol>" 

          #loop through categories inside, here this is to show the serotype collections
          for level2key in Object.keys(groupHash[level0Key][level1key]).sort()
            level2 = groupHash[level0Key][level1key][level2key]
            if level2['type'] is "collection"
              table += "<li id=#{level2key} data-value='false'><label style='font-weight:normal;margin-top:2px;margin-left:5px;'>#{level2key}</label>"
              table += "<ol>"

              #list through the serotype collections
              for level3key in Object.keys(groupHash[level0Key][level1key][level2key]).sort()
                level3 = groupHash[level0Key][level1key][level2key][level3key]
                if level3['type'] is "group"
                  table += "<li id=\"bonsai#{level2['id']}\"  data-value=#{level3['id']} data-collection_name=#{level2key} data-group_name=#{level3key}><label style='font-weight:normal;line-height:100%;'>#{level3key}</label></li>"
              table += "</ol></li>"
            if level2['type'] is "group"
              table += "<li id=\"bonsai#{level2['id']}\"  data-value=#{level2['id']} data-collection_name=#{level1key} data-group_name=#{level2key}><label style='font-weight:normal;line-height:100%;'>#{level2key}</label></li>"
          table += "</ol></li>"
        if level1['type'] is "group"
          #console.log "Add group level group"+group.name+" under "+group_collection_index.name
          table += "<li id=\"bonsai#{level1['id']}\"  data-value=#{level1['id']} data-collection_name=#{level0Key} data-group_name=#{level1key}><label style='font-weight:normal;line-height:100%;'>#{level1key}</label></li>"
      table += "</ol></li>"
    table = table + "</ol>"
    return table

  _getGroupGenomes: (group_id, public_genomes, private_genomes) =>

    option = $("li[id=bonsai"+group_id+"]", ".group-list")
    collection_name = $(option).data("collection_name")
    group_name = $(option).data("group_name")

    #TODO: If user is not logged in genomes don't have groups

    # Added checks for duplicate genomes in groups
    select_public_ids =  (genome_id for genome_id, genome_obj of public_genomes when parseInt(group_id) in genome_obj.groups) unless select_public_ids.indexOf(genome_id) > -1
    select_private_ids =  (genome_id for genome_id, genome_obj of private_genomes when parseInt(group_id) in genome_obj.groups) unless select_private_ids.indexOf(genome_id) > -1

    return {'select_public_ids' : select_public_ids, 'select_private_ids' : select_private_ids}

  # FUNC removeCategoryRadio
  #
  # Quick hack to remove the radio buttons where there are no group number associated with the element
  # in the Bonzai tree
  # 
  _removeCategoryRadio:() =>
    $('.group-list').find("input").each(()->
      if @.value is 'false'
        @.remove()
      else
        $("#"+@.id).css({'position':'absolute', 'height':'100%', 'margin-top': '0px'})
        $("label[for="+@.id+"]", '.group-list').css({'width':'80%','margin-bottom':'0px','margin-left':'12%'})
      )
        
        
    #change the label width to have it cover 90% of the space, this should solve the radio button beign over the title

  _updateSelections: (select_ids, group_id, genome_list) =>
    @groupSelected = true
    @runSelect = false
    public_selected = []
    private_selected = []
    notification_box = $('#geophy-control-panel-body')
    notification_box.empty()
    # Uncheck all selected genomes
    @viewController.select(genome_id, false) for genome_id in Object.keys(viewController.genomeController.public_genomes)
    @viewController.select(genome_id, false) for genome_id in Object.keys(viewController.genomeController.private_genomes)
    if not select_ids.select_public_ids.length and not select_ids.select_private_ids.length
      # Updates selections for when groups are cleared
      @active_group.group_id = ''
      @active_group.public_list = []
      @active_group.private_list = []
      @active_group.group_name = ''
      @groupSelected = false
      # Summary panel
      @viewController.views[3].updateActiveGroup(@) if @viewController.views[3]?
      # Table
      @viewController.views[2].updateActiveGroup(@)
      # Tree
      @viewController.views[1].updateActiveGroup(@)
      # Map
      @viewController.views[0].updateActiveGroup(@)
      
      bonsai = $('.group-list').data('bonsai')
      bonsai.restore(initialBonsaiState)

      return
    # First check if custom user groups
    else
      for genome_id in select_ids.select_public_ids
        public_selected.push(genome_id)
        if genome_id in viewController.genomeController.pubVisible
           @viewController.select(genome_id, true)

      for genome_id in select_ids.select_private_ids
        private_selected.push(genome_id)
        if genome_id in viewController.genomeController.pvtVisible
          @viewController.select(genome_id, true)

    @runSelect = true
    
    # Append info to notification:
    # Get group and collection names and counts
    #option = @standardSelectizeControl.getOption(group_id)[0] if genome_list is "public"
    option = @customSelectizeControl.getOption(group_id)[0] if genome_list is "private"
    option = $("li[id=bonsai"+group_id+"]", '.group-list') if $("li[id=bonsai"+group_id+"]", '.group-list')
    
    collection_name = $(option).data("collection_name")
    group_name = $(option).data("group_name")

    @active_group.group_id = group_id
    @active_group.public_list = public_selected
    @active_group.private_list = private_selected
    @active_group.group_name = group_name

    notification_alert = $("<div class='alert alert-info' role='alert'>Current group loaded: #{group_name}</div><br>")
    $("<span clasfgroups='help-block'>#{public_selected.length} genomes from #{collection_name} collection</span>").appendTo(notification_alert)
    notification_alert.appendTo(notification_box)

    # Summary panel
    @viewController.views[3].updateActiveGroup(@) if @viewController.views[3]?
    # Table
    @viewController.views[2].updateActiveGroup(@)
    # Tree
    @viewController.views[1].updateActiveGroup(@)
    # Map
    @viewController.views[0].updateActiveGroup(@)

    return true;

    true

  # Return instance of UserGroups
unless root.UserGroups
  root.UserGroups = UserGroups
