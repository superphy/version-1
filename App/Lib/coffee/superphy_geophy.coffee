class GeoPhy
  constructor: (@publicGenomes, @privateGenomes, @viewController, @userGroups, @treeDiv, @mapDiv, @sumDiv, @tableDiv, @mapTableDiv) ->

  publicSubsetGenomes: {}
  privateSubsetGenomes: {}
  genomeController: null

  init: (boolShowall) ->
    if not @userGroups? or @userGroups? and boolShowall
      @_showall()
    else if @userGroups? and not boolShowall
      @_filter()
    @viewController.sideBar($('#search-utilities'))
    @viewController.createView('tree', @treeDiv, tree)
    #@_createSubmitForm(); 
    @viewController.createView('summary', @sumDiv)
    #$("#groups_table").appendTo(".map-manifest")
    @viewController.createView('table', @tableDiv)
    true

  _getPublicSubset: (public_genomes, selected_groups) ->
    public_subset_genomes = {}
    jQuery.each(selected_groups, (gp_num, gp) ->
      jQuery.each(gp, (i,v) ->
        if public_genomes[v]
          public_subset_genomes[v] = public_genomes[v]
          )
      )
    return public_subset_genomes

  _getPrivateSubset: (private_genomes, selected_groups) ->
    private_subset_genomes = {}
    jQuery.each(selected_groups, (gp_num, gp) ->
      jQuery.each(gp, (i,v) ->
        if private_genomes[v]
          private_subset_genomes[v] = private_genomes[v]
          )
      )
    return private_subset_genomes

  _appendLegend: (divEl, groups) ->
    
    blue = '#1f77b4';
    orange = '#ff7f0e';
    green = '#2ca02c';
    red = '#d62728';
    purple = '#9467bd';
    brown = '#8c564b';
    pink = '#e377c2';
    grey = '#7f7f7f';
    lime = '#bcbd22';
    aqua = '#17becf';

    colors = {
      'group1Color': blue;
      'group2Color': orange;
      'group3Color': green;
      'group4Color': red;
      'group5Color': purple;
      'group6Color': pink;
      'group7Color': brown;
      'group8Color': grey;
      'group9Color': aqua;
      'group10Color': lime;
    }

    legendEl = jQuery('<div class="col-md-12 panel panel-default"></div>')
    
    panelEl = jQuery('<div class="panel-body"></div>').appendTo(legendEl)

    rowEl = jQuery('<div class="row"></div>').appendTo(panelEl)

    divEl.prepend(legendEl)

    for gNum, gList of groups
      console.log gNum

      div = document.createElement('div')
      
      div.className = "col-md-1"

      svg = d3.select(div).append('svg')
        .attr('height', '20px')
        .attr('width', '100px')
      
      markerLegend = svg.append("g")
        .attr('transform', 'translate(0,0)')
      
      markerLegend.append("circle")
        .attr('cx', 10)
        .attr('cy', 10)
        .attr('r', '5px')
        .style({'fill': colors["group#{gNum}Color"], 'fill-opacity': '1.0'})

      markerLegend.append("text")
        .attr("class","legendlabel2")
        .attr("dx", 20)
        .attr("dy", 15)
        .attr("text-anchor", "start")
        .text("Group #{gNum}")

      rowEl.append(div)

    submitEl = jQuery("<div class='compare-genome-groups row'></div>").appendTo(panelEl)
    divEl = jQuery("<div class='col-md-12'></div>").appendTo(submitEl)
    clearFormEl = jQuery("<button class='btn btn-danger' onclick='location.reload()'><span class='fa fa-times'></span> Reset Form</button>").appendTo(divEl)
    buttonEl = jQuery("<button type='submit' class='btn btn-primary' value='Submit' form='groups-compare-form'><span class='fa fa-check'></span> Show All Groups</button>").appendTo(divEl)

    hiddenFormEl = jQuery('#groups-compare-form')

    buttonEl.click (e) =>
      e.preventDefault()
      
      jQuery("<input type='hidden' name='show-all' value='1'>").appendTo(hiddenFormEl)

      for i in [1..@viewController.groups.length] by 1
        groupGenomes = jQuery("#genome_group#{i} .genome_group_item")
        jQuery("<input type='hidden' name='group#{i}-genome' value='#{jQuery(genome).find('a').data('genome')}'>").appendTo(hiddenFormEl) for genome in groupGenomes
      
      jQuery("<input type='hidden' name='num-groups' value='#{@viewController.groups.length}'>").appendTo(hiddenFormEl)
      
      hiddenFormEl.submit()

    true

  _showall: () ->
    @_setViewController(@publicGenomes, @privateGenomes)
    gpColors = @_prepareGroups() if @userGroups?;
    ##### RESTORE
    @viewController.createView('map', @mapDiv, ['satellite'])
    ##### RESTORE
    true

  _filter: () ->
    @publicSubsetGenomes = @_getPublicSubset(@publicGenomes, @userGroups)
    @privateSubsetGenomes = @_getPrivateSubset(@privateGenomes, @userGroups)
    @_setViewController(@publicSubsetGenomes, @privateSubsetGenomes)
    jQuery('#groups-compare').hide();
    gpColors = @_prepareGroups();
    ##### RESTORE
    @viewController.createView('map', @mapDiv, ['geophy'], gpColors)
    ##### RESTORE
    @_appendLegend(jQuery('#groups-geophy'), @userGroups)
    true

  _setViewController: (pubList, pvtList) ->
    # TODO: Move this up to the init funciton and get rid of adding groups
    @viewController.init(pubList, pvtList, 'multi_select', '/superphy/groups/geophy')
    addMore = true
    submit = true
    filter = true
    #@viewController.createGroupsForm($('#geophy-control'), addMore, submit, filter)
    true

  # Deprecated: These functions are merged with the existing filtering functions.
  _createSubmitForm: () ->
    elem = jQuery('#geophy-control')
    parentTarget = 'geophy-control-panel-body'
    wrapper = jQuery('<div class="panel panel-default" id="geophy-control-panel"></div>')
    elem.append(wrapper)
    
    form = jQuery("<div class='panel-body' id='#{parentTarget}'></div>")
    wrapper.append(form)

    submitEl = jQuery('<div class="row"></div>')

    #TODO: Add buttons and actions
    submitButtonEl = jQuery('<div class="col-md-2 col-md-offset-4"><button id="group-browse-highlight" type="submit" value="Submit" form="geophy-form" class="btn btn-success"><span class="fa fa-exchange"></span> Highlight Genomes</button></div>').appendTo(submitEl)
    resetButtonEl = jQuery('<div class="col-md-2"><button id="group-browse-reset" type="button" form="geophy-form" class="btn btn-danger"><span class="fa fa-times"></span> Reset Views</button></div>').appendTo(submitEl)
    #hiddenFormEl = jQuery("<form class='form' id='geophy-form' method='post' action='#{@viewController.action}' enctype='application/x-www-form-urlencoded'></form>").appendTo(submitEl)

    submitButtonEl.click( (e) =>
      e.preventDefault()
      console.log "Button Clicked"
      @viewController.filterViews('selection')
      true
      )

    resetButtonEl.click( (e) =>
      e.preventDefault()
      @viewController.resetFilter()
      #TODO If this becomes active again, select takes list of genomes rather than iterating through lists calling function select
      # each time
      @viewController.select(g, false) for g in @viewController.genomeController.pubVisible
      @viewController.select(g, false) for g in @viewController.genomeController.pvtVisible
      jQuery('#reset-map-view').click()
      true
      ) 

    form.append(submitEl)

    true

  _prepareGroups: () ->
    genomeGroupColor = {}

    userMaxGroupNum = Math.max.apply(Math, Object.keys(@userGroups))

    while (userMaxGroupNum > @viewController.groups.length)
      @viewController.addGroupFormRow($("#group-form-block"))

    for gNum, gList of @userGroups
      for gId in gList
        @viewController.select(gId, true)
        genomeGroupColor[gId] = gNum
      @viewController.addToGroup(parseInt(gNum))

    return genomeGroupColor

  unless root.GeoPhy
    root.GeoPhy = GeoPhy
