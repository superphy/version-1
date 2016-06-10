###


 File: superphy.coffee
 Desc: Objects & functions for managing views in Superphy
 Author: Matt Whiteside matthew.whiteside@phac-aspc.gc.ca
 Date: March 7th, 2013
 
 
###

# Set export object and namespace
root = exports ? this
#root.Superphy or= {}


###
 CLASS SuperphyError
 
 Error object for this library
 
###
class SuperphyError extends Error
  constructor: (@message='', @name='Superphy Error') ->


###
 CLASS ViewController
  
 Captures events. Updates data and views 
 
###
class ViewController
  constructor: ->
    throw new SuperphyError 'jQuery must be loaded before the SuperPhy library' unless jQuery?
    throw new SuperphyError 'SuperPhy library requires the URL library' unless URL?
    throw new SuperphyError 'SuperPhy library requires the Blob library' unless Blob?
    
    
  # Properties
  
  # View objects in window
  views: []
  groups: []
  tickers: []
  selectedBox: null 
  
  # Main action triggered by clicking on genome
  actionMode: false
  action: false
  
  maxGroups: 10
  
  genomeController: undefined

  defaultMetas: ['serotype','isolation_host','isolation_source']
  
  # Methods
  init: (publicGenomes, privateGenomes, @actionMode, @action, subset=null) ->
    unless @actionMode is 'single_select' or @actionMode is 'multi_select' or @actionMode is 'two_groups'
      throw new SuperphyError 'Unrecognized actionMode in ViewController init() method.'
    

    @genomeController = new GenomeController(publicGenomes, privateGenomes, subset, @defaultMetas)
    
    # Reset view and group lists
    @views = []
    @groups = []
    @tickers = []
 
 
  createView: (viewType, elem, viewArgs...) ->

    # Define style of view (select|redirect)
    # to match actionMode
    clickStyle = 'select'
    
    # Current view number
    vNum = @views.length + 1
        
    if @actionMode is 'single_select'
      # single_select behaviour: user clicks on single genome for more info
      clickStyle = 'redirect'
    
    try
      # Perform view creation in try/catch
      # to trap individual view errors

      if viewType is 'list'
        # New list view
        listView = new ListView(elem, clickStyle, vNum, viewArgs)
        listView.update(@genomeController)
        @views.push listView
        
      else if viewType is 'tree'
        # New tree view
        treeView = new TreeView(elem, clickStyle, vNum, @genomeController, viewArgs)
        treeView.update(@genomeController)
        @views.push treeView

      else if viewType is 'msa'
        # New multiple sequence alignment view
        msaView = new MsaView(elem, clickStyle, vNum, viewArgs)
        msaView.update(@genomeController)
        @views.push msaView
        
      else if viewType is 'matrix'
        # New matrix view
        # Genome list is needed to compute matrix size
        matView = new MatrixView(elem, clickStyle, vNum, @genomeController, viewArgs)
        matView.update(@genomeController)
        @views.push matView

      else if viewType is 'map'
        #New map view
        mapView = new MapView(elem, clickStyle, vNum, @genomeController, viewArgs)
        #mapView.update(@genomeController)
        @views.push mapView

      else if viewType is 'selmap'
        #New map view
        mapView = new SelectionMapView(elem, clickStyle, vNum, @genomeController, viewArgs)
        #mapView.update(@genomeController)
        @views.push mapView
        
      else if viewType is 'table'
        # New table view
        tableView = new TableView(elem, clickStyle, vNum, viewArgs)
        tableView.update(@genomeController)
        @views.push tableView

      else if viewType is 'summary'
        # New meta-data summary view
        sumView = new SummaryView(elem, clickStyle, vNum, @genomeController, viewArgs)
        sumView.update(@genomeController)
        @views.push sumView
        @summaryViewIndex = vNum-1;
        $(window).resize( (e) =>    
            window.viewController.views[window.viewController.summaryViewIndex].resizing= true
            if window.viewController.views[window.viewController.summaryViewIndex].activeGroup.length >0
              window.viewController.views[window.viewController.summaryViewIndex].updateActiveGroup(user_groups_menu)
            else
              window.viewController.views[window.viewController.summaryViewIndex].afterSelect(true)
            window.viewController.views[window.viewController.summaryViewIndex].resizing= false
          )

      else if viewType is 'jump2table'
        # TODO: Remove this, deprecated
        # New list view
        tableView = new TableView(elem, clickStyle, vNum, viewArgs)
        tableView.update(@genomeController)
        @views.push tableView
        return
        
      else
        throw new SuperphyError 'Unrecognized viewType <'+viewType+'> in ViewController createView() method.'
        return false

    
      # Create download link
      # Will be created by default unless a return statement is specified in the conditional clauses
      downloadElemDiv = jQuery("<div class='download-view'></div>")
      downloadElem = jQuery("<a class='download-view-link' href='#' data-genome-view='#{vNum}'>Download <i class='fa fa-download'></a>")
      downloadElem.click (e) ->
        viewNum = parseInt(@.dataset.genomeView)
        data = viewController.downloadViews(viewNum)
        @.href = data.href
        @.download = data.file
        true
      
      downloadElemDiv.append(downloadElem)
      downloadElemDiv.prependTo(elem)

    catch e
      @viewError(e, elem);
      return false # Return failure
      
    return true # return success

  # Append error message to view instead of rendering view
  viewError: (e, elem) ->
    elem.append("<div class='superphy-error'><p>Superphy Error! View failed to load.</p></div>")
    alert "Superphy error: #{e.message}\nLine: #{e.line}"

    return true;

    
  introOptions: ->
    intros = []

     # Meta-data and filter intro
    intros.push({
      element: document.querySelector('#meta-data-form')
      intro: "Any genome search can be further specified to include various meta-data by checking the corresponding boxes.  This will show more information for each genome on the list, tree, and map, but it will not affect the data."
      position: 'right'
      })
    intros.push({
      element: document.querySelector('#user-groups')
      intro: "Preset and user-defined groups can be loaded here as the active group.  Active group genomes will be highlighted in each view.  Use the 'Modify/Delete' tab to create and edit groups from your own selections.  These groups can be accessed from other SuperPhy pages."
      position: 'right'
      })
    intros.push({
      element: document.querySelector('#filter-form')
      intro: "Searches can also be filtered to limit the number of genomes displayed on the list, tree, map, and meta-data summary."
      position: 'right'
      })

    # Append intros for each view
    intros = intros.concat(v.intro()) for v in @views
    
    intros

  createGroup: (boxEl, buttonEl, clearButtonEl) ->
    
    # Current view number
    gNum = @groups.length + 1
    
    if gNum > @maxGroups
      return false
    
    # New list view
    grpView = new GroupView(boxEl, gNum)
    grpView.update(@genomeController)
    @groups.push grpView
    
    # Add response to button click
    buttonEl.click (e) ->
      e.preventDefault()
      viewController.addToGroup(gNum)

    # Add response to clear button click
    # TODO:
    clearButtonEl.click (e) ->
      e.preventDefault()
      viewController.clearFromGroup(gNum)

    return true # return success
    
  addToGroup: (grp) ->
    # Get all currently selected genomes
    selected = @genomeController.selected()
    
    # Change genome properties
    @genomeController.assignGroup(selected, grp)
    
    # Unselect this set now that its added to a group
    @genomeController.unselectAll()
    
    # Add to group box
    i = grp - 1
    @groups[i].add(selected, @genomeController)
    
    # Update views (class, checked, etc)
    v.update(@genomeController) for v in @views
    @selectedBox.update(@genomeController) if @selectedBox?

  createTicker: (tickerType, elem, tickerArgs...) ->
    
    # Current view number
    tNum = @tickers.length + 1
    
    if tickerType is 'meta'
      # New meta ticker
      metaTicker = new MetaTicker(elem, tNum, tickerArgs)
      metaTicker.update(@genomeController)
      @tickers.push metaTicker
      
    else if tickerType is 'stx'
      # New Stx ticker
      stxTicker = new StxTicker(elem, tNum, tickerArgs)
      stxTicker.update(@genomeController)
      @tickers.push stxTicker
      
    else if tickerType is 'matrix'
      # New Matrix ticker
      matTicker = new MatrixTicker(elem, tNum, @genomeController, tickerArgs)
      matTicker.update(@genomeController)
      @tickers.push matTicker
      
    else if tickerType is 'allele'
      # New allele ticker/histogram
      alTicker = new AlleleTicker(elem, tNum, tickerArgs)
      alTicker.update(@genomeController)
      @tickers.push alTicker
      
    else
      throw new SuperphyError 'Unrecognized tickerType in ViewController createTicker() method.'
      return false
      
    return true # return success
    
  select: (g, checked) ->

    if @actionMode is 'single_select'
      @redirect(g)
      
    else
      @genomeController.select(g, checked)
    
      v.select(g, checked) for v in @views
      
      # Needs to be called after select to add summary meters
      if @summaryViewIndex? && @summaryViewIndex > -1
        @views[@summaryViewIndex].afterSelect()

      @selectedBox.select(g, @genomeController, checked) if @selectedBox
 
    true
    
  redirect: (g) ->
    displayName = @.genomeController.private_genomes[g]?.displayname ? @.genomeController.public_genomes[g].displayname

    modalView = jQuery(
      '<div class="modal fade" id="view-redirect-modal" tabindex="-1" role="dialog" aria-labelledby="viewRedirectModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-sm">
          <div class="modal-content">
            <div class="modal-header">
              <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
              <h4 class="modal-title" id="viewRedirectModalLabel">Retrieve selected genome?</h4>
            </div>
            <div class="modal-body">
              Would you like to retrieve genome information for the selected genome: 
                <form id="view-redirect-form">
                  <div class="well well-sm">'+displayName+'</div>
                  <input type="hidden" name="genome" value="'+g+'"/>
                </form>
            </div>
            <div class="modal-footer">
            </div>
          </div>
        </div>
      </div>'
      )

    buttonCloseEl = jQuery('<button type="button" class="btn btn-danger" data-dismiss="modal" form="view-redirect-form" value="Cancel">Cancel</button>')
    buttonSubmitEl = jQuery(
      '<button 
      type="submit" 
      id="view-redirect-submit" 
      class="btn btn-success" 
      value="Submit" 
      form="view-redirect-form" 
      formmethod="post" 
      formaction="'+viewController.action+'">
        Submit
        </button>'
    )

    buttonSubmitEl.click(() ->
      modalView.find('.modal-body').append('
        <div class="alert alert-success">
          <p style="text-align:center">Retrieving genome</p>
          <div class="loader">
            <span></span>
          </div>
        </div>
          ')
      )

    modalView.find('.modal-footer').append(buttonCloseEl);
    modalView.find('.modal-footer').append(buttonSubmitEl);

    modalView.modal('show')

    true
    
  removeFromGroup: (genomeID, grp) ->
    # Remove single genome from list    
    # Change genome properties
    # Convert to Set format
    gset = @genomeController.genomeSet([genomeID])
    @genomeController.deleteGroup(gset)
    
    # Delete from list element
    i = grp - 1
    @groups[i].remove(genomeID)
    
    # Update style for genomes in views
    #v.updateCSS(gset, @genomeController) for v in @views
    v.update(@genomeController) for v in @views
    true

  clearFromGroup: (grp) ->
    # Remove all genomes from a group
    actionEl = jQuery("a[data-genome-group='#{grp}']")
    actionEl.click();
  
  groupForm: (elem, addMoreBool, submitBool, filterBool) ->
    #TODO: This has to be changed, need to be able to set up form for only 2 groups or more than 2 groups 

    # There can be only one
    blockEl = jQuery("<div id='group-form-block'></div>").appendTo(elem)
    @addGroupFormRow(blockEl)
    
    if addMoreBool
      addEl = jQuery("<div class='add-genome-groups row'></div>")
      divEl = jQuery("<div class='col-md-12'></div>").appendTo(addEl)
      buttEl = jQuery("<button class='btn' type='button'>More Genome Groups...</button>").appendTo(divEl)
      buttEl.click( (e) ->
        reachedMax = viewController.addGroupFormRow(jQuery("#group-form-block"))
        if !reachedMax
          jQuery(@).text('Max groups reached')
            .css('color','darkgrey')
          e.preventDefault()
      )
      elem.append(addEl)

    if submitBool
      #Create form submission function:
      submitEl = jQuery("<div class='compare-genome-groups row'></div>")
      divEl = jQuery("<div class='col-md-12'></div>").appendTo(submitEl)
      clearFormEl = jQuery("<button class='btn btn-danger' onclick='location.reload()'><span class='fa fa-times'></span> Reset Form</button>").appendTo(divEl)
      buttonEl = jQuery("<button type='submit' class='btn btn-primary' value='Submit' form='groups-compare-form'><span class='fa fa-check'></span> Filter Groups</button>").appendTo(divEl) if filterBool
      buttonEl = jQuery("<button type='submit' class='btn btn-primary' value='Submit' form='groups-compare-form'><span class='fa fa-check'></span> Analyze Groups</button>").appendTo(divEl) unless filterBool

      hiddenFormEl = jQuery("<form class='form' id='groups-compare-form' method='post' action='#{@action}' enctype='application/x-www-form-urlencoded'></form>").appendTo(divEl)
      # Prevent default click action to prepare the groups before submitting
      buttonEl.click( (e) =>
        e.preventDefault()
        alert = jQuery('<div class="alert alert-danger">
                        <button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>
                        You must have at least one genome in either of the groups to compare to.
                        </div>')
        unless jQuery('#genome_group1 li').length > 0 or jQuery('#genome_group2 li').length > 0
          blockEl.prepend(alert);
          return false

        #Prepare groups
        for i in [1..@groups.length] by 1
          groupGenomes = jQuery("#genome_group#{i} .genome_group_item")
          jQuery("<input type='hidden' name='group#{i}-genome' value='#{jQuery(genome).find('a').data('genome')}'>").appendTo(hiddenFormEl) for genome in groupGenomes
        
        jQuery("<input type='hidden' name='num-groups' value='#{@groups.length}'>").appendTo(hiddenFormEl)

        jQuery('#groups-compare-form').submit()
        )
        
      elem.append(submitEl)

    true
     
  addGroupFormRow: (elem) ->
    
    if typeof elem is 'string'
      elem = jQuery(elem)
    
    gNum = @groups.length + 1
    
    if gNum > @maxGroups
      return false
    
    # Create row
    rowEl = jQuery("<div class='group-form-row row'></div>").appendTo(elem)
    ok = true
      
    for i in [gNum, gNum+1]
      formEl = jQuery("<div id='genome-group-form#{i}' class='genome-group-form col-md-6'></div>")
      listEl = jQuery("<div id='genome-group-list#{i}' class='genome-group'></div>").appendTo(formEl)
      divEl = jQuery("<div class='genome-group-add-controller'></div>").appendTo(listEl)
      buttEl = jQuery("<button id='genome-group-add#{i}' class='btn btn-primary' type='button' title='Add genome(s) to Group #{i}'><span class='fa fa-plus'></span> <span class='input-lg' id='genome-group#{i}-heading'>Group #{i}</span></button>").appendTo(divEl)
      clearButtEl = jQuery("<button id='genome-group-clear#{i}' class='btn btn-primary pull-right' type='button' title='Clear all genome(s) from Group #{i}'><span class='fa fa-times'></span> <span class='input-lg' id='genome-group#{i}-heading'></span></button>").appendTo(divEl)
      rowEl.append(formEl)
      
      ok = @createGroup(listEl,buttEl,clearButtEl)
      
    ok  
            
    
  #submit:
  
  viewAction: (vNum, viewArgs...) ->
    @views[vNum].viewAction(this.genomeController, viewArgs)
    true
    
  getView: (vNum) ->
    @views[vNum]
  
  
  updateViews: (option, checked) ->

    console.log('test uv')
    
    @genomeController.updateMeta(option, checked)
    
    v.update(@genomeController) for v in @views
    v.update(@genomeController) for v in @groups
    t.update(@genomeController) for t in @tickers
    @selectedBox.update(@genomeController) if @selectedBox?
    
    true
    
  downloadViews: (viewNum) ->
    
    # External libraries needed to download files
    url = window.URL || window.webkitURL
    blob = window.Blob
    
    dump = @views[viewNum-1].dump(@genomeController)
    
    file = new blob([dump.data], {type: dump.type})
    href = url.createObjectURL(file);
    file = "superphy_download.#{dump.ext}"
    
    return {
      href: href
      file: file
    }
  
  # FUNC sideBar
  # Build and attach sideBar
  #
  # PARAMS
  # jQuery element object to pin bar to
  # 
  # RETURNS
  # boolean 
  #      
  sideBar: (elem) ->
    
    # Build & attach
    parentTarget = 'sidebar-group'
    wrapper = jQuery('<div class="panel-group" id="'+parentTarget+'"></div>')
    elem.append(wrapper)
      
    # Meta-data form
    form1 = jQuery('<div id="meta-data-form" class="panel panel-default"></div>')
    wrapper.append(form1)
    @metaForm(form1, parentTarget)

    # User groups form
    form3 = jQuery('<div id="user-groups" class="panel panel-default"></div>')
    wrapper.append(form3)
    @groupForm(form3, parentTarget)
    
    # Filter form
    form2 = jQuery('<div id="filter-form" class="panel panel-default"></div>')
    wrapper.append(form2)
    @filterForm(form2, parentTarget)
    true


  groupForm: (elem, parentStr) ->
    #group_menu = $('<div></div>')
    panel_header = $('<div class="panel-heading"></div>')
    panel_title = $('<div class="panel_title"> <a data-toggle="collapse" href="#group-form"> User Groups <span class="caret"></span></a></div>').appendTo(panel_header)
    
    panel_main = $('<div id="group-form" class="collapse in"></div>')
    panel_body = $('<div class="panel-body"></div>').appendTo(panel_main)
    group_form = $('<div class="user-groups-menu"></div>').appendTo(panel_body)

    elem.append(panel_header)
    elem.append(panel_main)

    true

  
  # Deprecated and set for deletion
  sideBarGroupManager: (elem) ->
    #Group form
    parentTarget = 'sidebar-accordion'
    wrapper = jQuery('#sidebar-accordion')

    form = jQuery('<div class="panel panel-default"></div>')
    wrapper.append(form)
    @groupsSideForm(form, parentTarget)
    true

  # Deprecated and set for deletion
  createGroupsForm: (elem, addMoreBool, submitBool, filterBool) ->
    parentTarget = 'groups-compare-panel-body'
    wrapper = jQuery('<div class="panel panel-default" id="groups-compare-panel"></div>')
    elem.append(wrapper)

    #Need to specify action mode so the page allows for more groups if needed
    form = jQuery('<div class="panel-body" id="'+parentTarget+'"></div>')
    wrapper.append(form)
    @groupForm(form, addMoreBool, submitBool, filterBool);
    true
      
  metaForm: (elem, parentStr) ->
    
    # Build & attach form
    form = 
    '<div class="panel-heading">'+
    '<div class="panel-title">'+
    '<a data-toggle="collapse" href="#meta-form"><i class="fa fa-eye"></i> Meta-data '+
    '<span class="caret"></span></a>'+
    '</div></div>'+
    '<div id="meta-form" class="collapse in">'+
    '<div class="panel-body">'+
    '<p>Select meta-data displayed:</p>'+
    '<form class="form-inline">'+
    '<fieldset>'+
    '<div class="checkbox col-md-12"><label><input class="meta-option checkbox" type="checkbox" name="meta-option" value="accession"> Accession # </label></div>'+
    '<div class="checkbox col-md-12"><label><input class="meta-option checkbox" type="checkbox" name="meta-option" value="strain"> Strain </label></div>'+
    '<div class="checkbox col-md-12"><label><input class="meta-option checkbox" type="checkbox" name="meta-option" value="serotype"> Serotype </label><div id="meta-option_serotype" style="display:none;width:12px;height:12px;background:#004D11;border:1px solid #000;position:relative;bottom:15px;left:200px;"></div></div>'+
    '<div class="checkbox col-md-12"><label><input class="meta-option checkbox" type="checkbox" name="meta-option" value="isolation_host"> Isolation Host </label><div id="meta-option_isolation_host" style="display:none;width:12px;height:12px;background:#9E0015;border:1px solid #000;position:relative;bottom:15px;left:200px;"></div></div>'+
    '<div class="checkbox col-md-12"><label><input class="meta-option checkbox" type="checkbox" name="meta-option" value="isolation_source"> Isolation Source </label><div id="meta-option_isolation_source" style="display:none;width:12px;height:12px;background:#000752;border:1px solid #000;position:relative;bottom:15px;left:200px;"></div></div>'+
    '<div class="checkbox col-md-12"><label><input class="meta-option checkbox" type="checkbox" name="meta-option" value="isolation_date"> Isolation Date </label></div>'+
    '<div class="checkbox col-md-12"><label><input class="meta-option checkbox" type="checkbox" name="meta-option" value="syndrome"> Symptoms / Diseases </label><div id="meta-option_syndrome" style="display:none;width:12px;height:12px;background:#520042;border:1px solid #000;position:relative;bottom:15px;left:200px;"></div></div>'+
    '<div class="checkbox col-md-12"><label><input class="meta-option checkbox" type="checkbox" name="meta-option" value="stx1_subtype"> Stx1 Subtype </label><div id="meta-option_stx1_subtype" style="display:none;width:12px;height:12px;background:#F05C00;border:1px solid #000;position:relative;bottom:15px;left:200px;"></div></div>'+
    '<div class="checkbox col-md-12"><label><input class="meta-option checkbox" type="checkbox" name="meta-option" value="stx2_subtype"> Stx2 Subtype </label><div id="meta-option_stx2_subtype" style="display:none;width:12px;height:12px;background:#006B5C;border:1px solid #000;position:relative;bottom:15px;left:200px;"></div></div>'+                                                   
    '</fieldset>'+
    '</form>'+
    '</div></div>'
    
    elem.append(form)
    
    # Set response
    jQuery('input[name="meta-option"]').change ->
      # alert(@.value, @.checked)
      id = '#'+@.name + '_' + @.value

      if @.checked
        jQuery(id).show()

      else
        jQuery(id).hide()

      viewController.updateViews(@.value, @.checked)


    @_checkDefaultMeta(@defaultMetas)
      
    true
    
  # FUNC filterViews
  # Identify genomes that match query and update
  # views with the new visible genome lists. Submitting empty form
  # or clicking clear button remove any filter
  #
  # PARAMS
  # string indicating if the 'fast' or 'advanced' form was submitted
  # 
  # RETURNS
  # boolean 
  #      
  filterViews: (filterForm) ->
    
    if filterForm is 'selection'
      # Update filter settings to so only selected genomes are visible
      @genomeController.filterBySelection()
      
    else
      # Form based search
      searchTerms = null
      
      # Parse input
      if filterForm is 'fast'
        # Fast form - basic filtering of name
        
        # retrieve search term
        term = jQuery("#fast-filter > input").val().toLowerCase()
        
        if term? and term.length
          searchTerms = []
          #searchTerms.push { searchTerm: term, dataField: 'displayname', negate: false }
          searchTerms.push { searchTerm: term, dataField: 'viewname', negate: false }
          
      else
        # Advanced form - specified fields, terms
        searchTerms = @_parseFilterForm()
        return false unless searchTerms?
          
      
      # Perform search
      @genomeController.filter(searchTerms)
      
    # Update Views 
    @_toggleFilterStatus(true)

    groupedNodes = @views[1].findGroupedChildren(@views[1].activeGroup)
    selectedNodes = @views[1].findGroupedChildren(@genomeController.selected().public.concat(@genomeController.selected().private))

    if @views[1].activeGroup.length > 0
      for g in groupedNodes
        @views[1]._percolateSelected(g.parent, true)

    for g in selectedNodes
      console.log(selectedNodes)
      @views[1]._percolateSelected(g.parent, true)

    v.update(@genomeController) for v in @views
    t.update(@genomeController) for t in @tickers
    
    true
    
  # FUNC resetFilter
  # Removes any filter applied, displaying all genomes
  #
  # RETURNS
  # boolean 
  #      
  resetFilter: ->
    @genomeController.filterReset = true
    @genomeController.filter()
    @_toggleFilterStatus()
    @_clearFilterForm()
    # Updates active group to reflect entire database
    if user_groups_menu? and @views[2].activeGroup.length > 0
      @views[2].updateActiveGroup(user_groups_menu)
    v.update(@genomeController) for v in @views
    t.update(@genomeController) for t in @tickers
    
  # FUNC filterForm
  # Build and attach form used to filter genome by name/property
  #
  # PARAMS
  # jQuery element object to pin form to
  # 
  # RETURNS
  # boolean 
  #      
  filterForm: (elem, parentStr) ->
    
    # Header
    header = jQuery(
      '<div class="panel-heading">'+
      '<div class="panel-title">'+
      '<a data-toggle="collapse" href="#filter-form"><i class="fa fa-filter"></i> Filter '+
      '<span class="caret"></span></a>'+
      '</div></div>'
    ).appendTo(elem)
      
    container = jQuery('<div id="filter-form" class="panel-collapse collapse in"></div>')
    
    # Add filter status bar
    numVisible = @genomeController.filtered
    filterStatus = jQuery('<div id="filter-status"></div>')
    filterOn = jQuery("<div id='filter-on'><div id='filter-on-text' class='alert alert-warning'>Filter active. #{numVisible} genomes visible.</div></div>")
    filterOff = jQuery('<div id="filter-off"></div>')
    
    delButton = jQuery('<button id="remove-filter" type="button" class="btn btn-sm">Clear</button>')
    delButton.click (e) ->
      e.preventDefault()
      viewController.resetFilter()  
      
    delButton.appendTo(filterOn)
    
    if numVisible > 0
      filterOn.show()
      filterOff.hide()
    else 
      filterOn.hide()
      filterOff.show()
      
    filterStatus.append(filterOn)
    filterStatus.append(filterOff)
    container.append(filterStatus)
    
    # Desc
    container.append('<p>Limit genomes displayed in views by:</p>')
    
    # Add form selector
    filtType = jQuery('<form id="select-filter-form" class="form-horizontal"></form>')
    
    fastGroup = jQuery('<div class="form-group"></div>')
    fastDiv = jQuery('<div class="col-xs-1"></div>').appendTo(fastGroup)
    fastRadio = jQuery('<input id="fast" type="radio" name="filter-form-type" value="fast" checked>').appendTo(fastDiv)
    fastLab = jQuery('<label class="col-xs-10" for="fast">Basic</label>').appendTo(fastGroup)
    
    fastRadio.change (e) ->
      if @checked?
        jQuery("#fast-filter").show()
        jQuery("#adv-filter").hide()
        jQuery("#selection-filter").hide()
        jQuery("#group-filter").hide()

      true

    filtType.append(fastGroup)
    
    
    advGroup = jQuery('<div class="form-group"></div>')
    advDiv = jQuery('<div class="col-xs-1"></div>').appendTo(advGroup)
    advRadio = jQuery('<input type="radio" id="adv" name="filter-form-type" value="advanced">').appendTo(advDiv)
    advLab = jQuery('<label class="col-xs-10" for="adv">Advanced</label>').appendTo(advGroup)
    
    advRadio.change (e) ->
      if this.checked?
        jQuery("#fast-filter").hide()
        jQuery("#adv-filter").show()
        jQuery("#selection-filter").hide()
        jQuery("#group-filter").hide()

      true
    
    filtType.append(advGroup)
    
    selGroup = jQuery('<div class="form-group"></div>')
    selDiv = jQuery('<div class="col-xs-1"></div>').appendTo(selGroup)
    selRadio = jQuery('<input id="sel" type="radio" name="filter-form-type" value="selection">').appendTo(selDiv)
    selLab = jQuery('<label class="col-xs-10" for="sel">By Selection</label>').appendTo(selGroup)    
    
    selRadio.change (e) ->
      if this.checked?
        jQuery("#fast-filter").hide()
        jQuery("#adv-filter").hide()
        jQuery("#selection-filter").show()
        jQuery("#group-filter").hide()
      true

    filtType.append(selGroup)
    

    # Select by group.  Commented out to reduce confusion regarding group filtering.  Filter by selection only now.
    # ugpGroup = jQuery('<div class="form-group"></div>')
    # ugpDiv = jQuery('<div class="col-xs-1"></div>').appendTo(ugpGroup)
    # ugpRadio = jQuery('<input id="ugp" type="radio" name="filter-form-type" value="selection">').appendTo(ugpDiv)
    # ugpLab = jQuery('<label class="col-xs-10" for="ugp">By Group</label>').appendTo(ugpGroup)    
    
    # ugpRadio.change (e) ->
    #   if this.checked?
    #     jQuery("#fast-filter").hide()
    #     jQuery("#adv-filter").hide()
    #     jQuery("#selection-filter").hide()
    #     jQuery("#group-filter").show()
    #   true

    # filtType.append(ugpGroup)
    
    container.append(filtType)
    
    # Build & attach simple fast form
    sf = jQuery("<div id='fast-filter'></div>")
    @addFastFilter(sf)
    container.append(sf)
    
    # Build & attach advanced form
    advForm = jQuery("<div id='adv-filter'></div>")
    @addAdvancedFilter(advForm)
    advForm.hide()
    container.append(advForm)
    
    # Add filter by selection button
    fbs = jQuery("<div id='selection-filter'>"+
      "<p>A selection in one of the views (i.e. genomes selected in a clade or map region)</p>"+
      "</div>")
    filtButton = jQuery('<button id="filter-selection-button" type="button" class="btn btn-sm">Filter by selection</button>')
    filtButton.click (e) ->
      e.preventDefault()
      viewController.filterViews('selection')
    fbs.append(filtButton)
    fbs.hide()
    container.append(fbs)


    # Build select by group form
    # TODO: Style properly with css
    fbg = jQuery("<div class='row' id='group-filter'>"+
      "<p>A group in one of the views</p>"+
      "</div>")
    findButton = jQuery('<div class="col-xs-3"><button id="user-groups-submit" class="btn btn btn-sm" type="button">Select</button></div>')
    fbg.append(findButton)
    filtButton = jQuery('<div class="col-xs-3"><button id="filter-group-button" type="button" class="btn btn-sm">Filter</button></div>')
    filtButton.click (e) ->
      e.preventDefault()
      viewController.filterViews('selection')
    fbg.append(filtButton)
    fbg.hide()
    container.append(fbg)
    
    container.appendTo(elem)
    
    true
      
  _toggleFilterStatus: (attempt=false) ->
    
    numVisible = @genomeController.filtered
    filterOn = jQuery('#filter-on')
    filterOff = jQuery('#filter-off')
    
    if numVisible > 0
      filterOn.find('#filter-on-text').text("Filter active. #{numVisible} genomes visible.")
      filterOn.show()
      filterOff.hide()
      
    else if numVisible is 0 and attempt
      filterOn.find('#filter-on-text').text("No genomes match search criteria.")
      filterOn.show()
      filterOff.hide()
      
    else 
      filterOn.hide()
      filterOff.show()
   
    true

  _toggleSelectAll: (switchOn, hardLimit) ->
    # TODO: Handle the different form types
    numVisible = @genomeController.filtered

    selectAllRow = jQuery('.select-all-genomes-row')

    selectAllRow.empty()

    divEl = jQuery('<div class="col-md-6"></div>')
    buttonGp = jQuery('<div class="btn-group"></div>').appendTo(divEl)

    selectAllButt = jQuery('<button id="table-select-all" class="btn btn-link">Select All</button>').appendTo(buttonGp)
    unSelectAllButt = jQuery('<button id="table-unselect-all" class="btn btn-link">Unselect All</button>').appendTo(buttonGp)

    selectAllButt.click( (e) =>
      e.preventDefault()
      @select(g, true) for g in @genomeController.pubVisible
      @select(g, true) for g in @genomeController.pvtVisible
      )

    unSelectAllButt.click( (e) =>
      e.preventDefault()
      @select(g, false) for g in @genomeController.pubVisible
      @select(g, false) for g in @genomeController.pvtVisible
      )
    
    if switchOn and numVisible <= hardLimit
      selectAllRow.append(divEl)
    else
    
    true
    
  _clearFilterForm: ->
    
    # Remove, build & attach simple fast form
    sf = jQuery("#fast-filter")
    sf.empty()
    @addFastFilter(sf)
    
    # Remove, build & attach advanced form
    advForm = jQuery("#adv-filter")
    advForm.empty()
    @addAdvancedFilter(advForm)
      
    true
    
  addAdvancedFilter: (elem) ->
    
    elem.append("<p>Boolean keyword search of specified meta-data fields</p>")
    
    advRows = jQuery("<div id='adv-filter-rows'></div>")
    elem.append(advRows)
    @addFilterRow(advRows, 1)
    
    # Create execution button
    advButton = jQuery('<button id="adv-filter-submit" type="button" class="btn btn-sm">Filter</button>')
    elem.append(advButton)
    advButton.click (e) ->
      e.preventDefault
      viewController.filterViews('advanced')
    
    # Add term button
    addRow = jQuery('<a href="#" class="adv-filter-addition">Add term</a>')
    
    addRow.click (e) -> 
      e.preventDefault()
      rows = jQuery('.adv-filter-row')
      rowI = rows.length + 1
      viewController.addFilterRow(jQuery('#adv-filter-rows'), rowI)
     
    elem.append(addRow)
      
    true
    
  ###  
  # FUNC addFilterRow
  # Adds additional search term row to advanced filter form.
  # Multiple search terms are joined using boolean operators.
  #
  # PARAMS
  # elem - jQuery element object of rows
  # rowNum - sequential number for new row
  # 
  # RETURNS
  # boolean 
  #       
  addFilterRow: (elem, rowNum) ->
    
    # Row wrapper
    row = jQuery('<div class="adv-filter-row" data-filter-row="' + rowNum + '"></div>').appendTo(elem)
    
    # Term join operation
    if rowNum isnt 1
      jQuery('<select name="adv-filter-op" data-filter-row="' + rowNum + '">' +
        '<option value="and" selected="selected">AND</option>' +
        '<option value="or">OR</option>' +
        '<option value="not">NOT</option>' +
        '</select>').appendTo(row)
    
    # Field type
    dropDown = jQuery('<select name="adv-filter-field" data-filter-row="' + rowNum + '"></select>').appendTo(row)
    for k,v of @genomeController.metaMap
        dropDown.append('<option value="' + k + '">' + v + '</option>')
    
    dropDown.append('<option value="displayname" selected="selected">Genome name</option>')
    
    # Change type of search term box depending on field type
    dropDown.change ->
      thisRow = this.dataset.filterRow
      if @.value is 'isolation_date'
        jQuery('.adv-filter-keyword[data-filter-row="' + thisRow + '"]').hide()
        jQuery('.adv-filter-date[data-filter-row="' + thisRow + '"]').show()
      else
        jQuery('.adv-filter-keyword[data-filter-row="' + thisRow + '"]').show()
        jQuery('.adv-filter-date[data-filter-row="' + thisRow + '"]').hide()
      true
    
    # Keyword-based search wrapper
    keyw = jQuery('<div class="adv-filter-keyword" data-filter-row="' + rowNum + '"></div>)')
    
    # Search term box
    jQuery('<input type="text" name="adv-filter-term" data-filter-row="' + rowNum + '" placeholder="Keyword"></input>').appendTo(keyw)
    keyw.appendTo(row)
    
    # Predefined search term dropdowns
    # Host
    
    

    # Date-based search wrapper
    dt = jQuery('<div class="adv-filter-date" data-filter-row="' + rowNum + '"></div>)')
    dt.append('<select name="adv-filter-before" data-filter-row="' + rowNum + '">' +
      '<option value="before" selected="selected">before</option>' +
      '<option value="after">after</option>' +
      '</select>')
    dt.append('<input type="text" name="adv-filter-year" data-filter-row="' + rowNum + '" placeholder="YYYY"></input>')
    dt.append('<input type="text" name="adv-filter-mon" data-filter-row="' + rowNum + '" placeholder="MM"></input>')
    dt.append('<input type="text" name="adv-filter-day" data-filter-row="' + rowNum + '" placeholder="DD"></input>')
    dt.hide()
    dt.appendTo(row)
    
    # Delete button
    if rowNum isnt 1
      delRow = jQuery('<a href="#" class="adv-filter-subtraction" data-filter-row="' + rowNum + '">Remove term</a>')
      delRow.appendTo(row)

      # Delete row wrapper
      delRow.click (e) ->
        e.preventDefault()
        thisRow = this.dataset.filterRow
        jQuery('.adv-filter-row[data-filter-row="' + thisRow + '"]').remove()
  
    true
    
  ###
    
  # FUNC addFilterRow
  # Adds additional search term row to advanced filter form.
  # Multiple search terms are joined using boolean operators.
  #
  # PARAMS
  # elem - jQuery element object of rows
  # rowNum - sequential number for new row
  # 
  # RETURNS
  # boolean 
  #       
  addFilterRow: (elem, rowNum) ->
    
    # Row wrapper
    row = '<div class="adv-filter-row" data-filter-row="' + rowNum + '">';
    
    # Term join operation
    row += '<div class="adv-filter-header">'
    if rowNum isnt 1
      row += '<select name="adv-filter-op" data-filter-row="' + rowNum + '">' +
        '<option value="and" selected="selected">AND</option>' +
        '<option value="or">OR</option>' +
        '<option value="not">NOT</option>' +
        '</select>'
    
    # Field type
    dropDown = '<select name="adv-filter-field" data-filter-row="' + rowNum + '">'
    for k,v of @genomeController.metaMap
        dropDown += '<option value="' + k + '">' + v + '</option>'
   
    dropDown += '<option value="displayname" selected="selected">Genome name</option></select>'
    row += dropDown
    
    row += '</div><div class="adv-filter-body">'
    
    # Keyword-based search wrapper
    keyw = '<div class="adv-filter-keyword" data-filter-row="' + rowNum + '">'
      
    # Search term box
    keyw += '<input type="text" name="adv-filter-term" data-filter-row="' + rowNum + '" placeholder="Keyword"></input>'
    keyw += '</div>'
    row += keyw
    
    # Predefined search term dropdowns
    # Host
    hosts =  '<div class="adv-filter-host-terms" data-filter-row="' + rowNum + '">'
    hosts +='<select name="adv-filter-hosts" data-filter-row="' + rowNum + '">'
    hosts += '<option value="">--Select Host--</option>'
    for v in superphyMetaOntology["hosts"]
      hosts += '<option value="'+v+'">'+v+'</option>'
    hosts += '<option value="other">Other (fill in field below)</option></select>'
    hosts += '<input type="text" name="adv-filter-host-other" data-filter-row="' + rowNum + '" placeholder="Other" disabled></input>'
    hosts += '</div>'
    row += hosts
    
    # Source
    sources =  '<div class="adv-filter-source-terms" data-filter-row="' + rowNum + '">'
    sources +='<select name="adv-filter-sources" data-filter-row="' + rowNum + '">'
    sources += '<option value="">--Select Source--</option>'
    for v in superphyMetaOntology["sources"]
      sources += '<option value="'+v+'">'+v+'</option>'
    sources += '<option value="other">Other (fill in field below)</option></select>'
    sources += '<input type="text" name="adv-filter-source-other" data-filter-row="' + rowNum + '" placeholder="Other" disabled></input>'
    sources += '</div>'
    row += sources
    
    # Syndrome
    syndromes =  '<div class="adv-filter-syndrome-terms" data-filter-row="' + rowNum + '">'
    syndromes +='<select name="adv-filter-syndromes" data-filter-row="' + rowNum + '">'
    syndromes += '<option value="">--Select Syndrome--</option>'
    for v in superphyMetaOntology["syndromes"]
      syndromes += '<option value="'+v+'">'+v+'</option>'
    syndromes += '<option value="other">Other (fill in field below)</option></select>'
    syndromes += '<input type="text" name="adv-filter-syndrome-other" data-filter-row="' + rowNum + '" placeholder="Other" disabled></input>'
    syndromes += '</div>'
    row += syndromes
      

    # Date-based search wrapper
    dt = '<div class="adv-filter-date" data-filter-row="' + rowNum + '">'
    dt +='<select name="adv-filter-before" data-filter-row="' + rowNum + '">' +
      '<option value="before" selected="selected">before</option>' +
      '<option value="after">after</option>' +
      '</select>'
    dt += '<input type="text" name="adv-filter-year" data-filter-row="' + rowNum + '" placeholder="YYYY"></input>'
    dt += '<input type="text" name="adv-filter-mon" data-filter-row="' + rowNum + '" placeholder="MM"></input>'
    dt += '<input type="text" name="adv-filter-day" data-filter-row="' + rowNum + '" placeholder="DD"></input>'
    dt += '</div>'
    row += dt
    
    if rowNum isnt 1
      delRow = '<a href="#" class="adv-filter-subtraction" data-filter-row="' + rowNum + '">Remove term</a>'
      row += delRow
    
    row += '</div>'
    
    rowObj = jQuery(row)
    
    # Actions
   
    # Change type of search term box depending on field type
    ff = rowObj.find('[name="adv-filter-field"][data-filter-row="'+rowNum+'"]')
    ff.change ->
      thisRow = this.dataset.filterRow
      if @.value is 'isolation_date'
        jQuery('.adv-filter-keyword[data-filter-row="' + thisRow + '"]').hide()
        jQuery('.adv-filter-date[data-filter-row="' + thisRow + '"]').show()
        jQuery('.adv-filter-host-terms[data-filter-row="'+rowNum+'"]').hide()
        jQuery('.adv-filter-source-terms[data-filter-row="'+rowNum+'"]').hide()
        jQuery('.adv-filter-syndrome-terms[data-filter-row="'+rowNum+'"]').hide()
      else if @.value is 'isolation_host'
        jQuery('.adv-filter-keyword[data-filter-row="' + thisRow + '"]').hide()
        jQuery('.adv-filter-date[data-filter-row="' + thisRow + '"]').hide()
        jQuery('.adv-filter-host-terms[data-filter-row="'+rowNum+'"]').show()
        jQuery('.adv-filter-source-terms[data-filter-row="'+rowNum+'"]').hide()
        jQuery('.adv-filter-syndrome-terms[data-filter-row="'+rowNum+'"]').hide()
      else if @.value is 'isolation_source'
        jQuery('.adv-filter-keyword[data-filter-row="' + thisRow + '"]').hide()
        jQuery('.adv-filter-date[data-filter-row="' + thisRow + '"]').hide()
        jQuery('.adv-filter-host-terms[data-filter-row="'+rowNum+'"]').hide()
        jQuery('.adv-filter-source-terms[data-filter-row="'+rowNum+'"]').show()
        jQuery('.adv-filter-syndrome-terms[data-filter-row="'+rowNum+'"]').hide()
      else if @.value is 'syndrome'
        jQuery('.adv-filter-keyword[data-filter-row="' + thisRow + '"]').hide()
        jQuery('.adv-filter-date[data-filter-row="' + thisRow + '"]').hide()
        jQuery('.adv-filter-host-terms[data-filter-row="'+rowNum+'"]').hide()
        jQuery('.adv-filter-source-terms[data-filter-row="'+rowNum+'"]').hide()
        jQuery('.adv-filter-syndrome-terms[data-filter-row="'+rowNum+'"]').show()
      else
        jQuery('.adv-filter-keyword[data-filter-row="' + thisRow + '"]').show()
        jQuery('.adv-filter-date[data-filter-row="' + thisRow + '"]').hide()
        jQuery('.adv-filter-host-terms[data-filter-row="'+rowNum+'"]').hide()
        jQuery('.adv-filter-source-terms[data-filter-row="'+rowNum+'"]').hide()
        jQuery('.adv-filter-syndrome-terms[data-filter-row="'+rowNum+'"]').hide()
      true
      
    # Hosts
    fht = rowObj.find('.adv-filter-host-terms[data-filter-row="'+rowNum+'"]')
    fh = fht.find('[name="adv-filter-hosts"]')
    fh.change ->
      thisRow = this.dataset.filterRow
      if @.value is 'other'
        jQuery('[name="adv-filter-host-other"][data-filter-row="'+rowNum+'"]').prop("disabled",false)
      else
        jQuery('[name="adv-filter-host-other"][data-filter-row="'+rowNum+'"]').prop("disabled",true)
       
    fht.hide()
    
    # Sources
    fst = rowObj.find('.adv-filter-source-terms[data-filter-row="'+rowNum+'"]')
    fs = fst.find('[name="adv-filter-sources"]')
    fs.change ->
      thisRow = this.dataset.filterRow
      if @.value is 'other'
        jQuery('[name="adv-filter-source-other"][data-filter-row="'+rowNum+'"]').prop("disabled",false)
      else
        jQuery('[name="adv-filter-source-other"][data-filter-row="'+rowNum+'"]').prop("disabled",true)
        
    fst.hide()
    
    # Syndrome
    fdt = rowObj.find('.adv-filter-syndrome-terms[data-filter-row="'+rowNum+'"]')
    fd = fdt.find('[name="adv-filter-syndromes"]')
    fd.change ->
      thisRow = this.dataset.filterRow
      if @.value is 'other'
        jQuery('[name="adv-filter-syndrome-other"][data-filter-row="'+rowNum+'"]').prop("disabled",false)
      else
        jQuery('[name="adv-filter-syndrome-other"][data-filter-row="'+rowNum+'"]').prop("disabled",true)
        
    fdt.hide()    
    
    
    # Hide date
    fd = rowObj.find('.adv-filter-date[data-filter-row="'+rowNum+'"]')
    fd.hide()
    
    # Delete button
    if rowNum isnt 1

      # Delete row wrapper
      db = rowObj.find('.adv-filter-subtraction[data-filter-row="'+rowNum+'"]')
      db.click (e) ->
        e.preventDefault()
        thisRow = this.dataset.filterRow
        console.log('del'+thisRow)
        jQuery('.adv-filter-row[data-filter-row="'+thisRow+'"]').remove()
        
  
    elem.append(rowObj)
    true
   
    
  # FUNC addSimpleFilter
  # Perform 'as-you-type' filter based on displayed name.
  #
  # PARAMS
  # elem - jQuery element object for simple form wrapper
  #
  # 
  # RETURNS
  # boolean 
  #       
  addFastFilter: (elem) ->
    
    # Desc
    elem.append("<p>Basic genome name filter</p>");
    
    # Search term box
    tBox = jQuery('<input type="text" name="fast-filter-term" placeholder="Filter by..."></input>')
    
    # Filter after keyup
    #tBox.keyup (e) ->
    #  viewController.filterViews('fast')
      
    # Create execution button
    fastButton = jQuery('<button id="fast-filter-submit" type="button" class="btn btn-sm">Filter</button>')
    fastButton.click (e) ->
      e.preventDefault
      viewController.filterViews('fast')
      
    # Attach elements
    tBox.appendTo(elem)
    fastButton.appendTo(elem)
    
    true
    
  # FUNC _parseFilterForm
  # Retrieves the input from the advanced filter form and
  # generates a searchTerms array
  #
  # RETURNS
  # array of searchTerms objects (see _runFilter method)
  # or null if form is missing data
  #
  _parseFilterForm:  ->
    
    rows = jQuery('.adv-filter-row')
    searchTerms = []
    
    for row in rows
      t = {}
      rowNum = parseInt(row.dataset.filterRow)
      
      # Retrieve dataField
      df = jQuery("[name='adv-filter-field'][data-filter-row='#{rowNum}']").val()
      t.dataField = df
      
      isDate = false
      isDate = true if df is 'isolation_date'
      
      if !isDate
        
        if df is 'isolation_host'
          # Retrieve host
          term = jQuery("[name='adv-filter-hosts'][data-filter-row='#{rowNum}']").val()
          
          if term is 'other'
            term = jQuery("[name='adv-filter-host-other'][data-filter-row='#{rowNum}']").val()
            term = trimInput term, 'keyword'
            
          unless term? and term isnt ""
            alert('Error: empty field.')
            return null 
          
          t.searchTerm = term
          
        else if df is 'isolation_source'
          # Retrieve source
          term = jQuery("[name='adv-filter-sources'][data-filter-row='#{rowNum}']").val()
          
          if term is 'other'
            term = jQuery("[name='adv-filter-source-other'][data-filter-row='#{rowNum}']").val()
            term = trimInput term, 'keyword'
            
          unless term? and term isnt ""
            alert('Error: empty field.')
            return null 
          
          t.searchTerm = term
          
        else if df is 'syndrome'
          # Retrieve syndrome
          term = jQuery("[name='adv-filter-syndromes'][data-filter-row='#{rowNum}']").val()
          
          if term is 'other'
            term = jQuery("[name='adv-filter-syndrome-other'][data-filter-row='#{rowNum}']").val()
            term = trimInput term, 'keyword'
            
          unless term? and term isnt ""
            alert('Error: empty field.')
            return null 
          
          t.searchTerm = term  
        
        else
          # Retrieve keyword
          term = jQuery("[name='adv-filter-term'][data-filter-row='#{rowNum}']").val()
          
          term = trimInput term, 'keyword'
          unless term? and term isnt ""
            alert('Error: empty field.')
            return null 
          
          t.searchTerm = term
        
      else
        # Retrieve date
        bef = jQuery("[name='adv-filter-before'][data-filter-row='#{rowNum}']").val()
        unless bef is 'before' or bef is 'after'
          throw new SuperphyError('Invalid input in advanced filter form. Element "adv-filter-before" must contain strings "before","after".')
        isBefore = true
        isBefore = false if bef is 'after'
        
        # Year
        yr = jQuery("[name='adv-filter-year'][data-filter-row='#{rowNum}']").val()
        
        yr = trimInput yr, 'Year'
        return null unless yr?
        
        unless /^[1-9][0-9]{3}$/.test(yr)
          alert('Error: invalid Year.')
          return null
       
        # Month
        # Ignore empty month field, use january as default
        mn = jQuery("[name='adv-filter-mon'][data-filter-row='#{rowNum}']").val()
        mn = jQuery.trim(mn) if mn?
        
        if mn? and mn.length
          unless /^[0-9]{1,2}$/.test(mn)
            alert('Error: invalid Month.')
            return null
          
        else
          mn = '01'
          
        # Day
        # Ignore empty day field, use 1st default
        dy = jQuery("[name='adv-filter-day'][data-filter-row='#{rowNum}']").val()
        dy = jQuery.trim(dy) if dy?
        
        if dy? and dy.length
          unless /^[0-9]{1,2}$/.test(dy)
            alert('Error: invalid Day.')
            return null
          
        else
          dy = '01'
        
        date = Date.parse("#{yr}-#{mn}-#{dy}")
        if isNaN date
          alert('Error: invalid date.')
          return null
        
        t.date = date
        t.before = isBefore
        
        
      unless rowNum == 1
        # Subsequent terms have join operators
        op = jQuery("[name='adv-filter-op'][data-filter-row='#{rowNum}']").val()
        negate = false
        
        unless op is 'or' or op is 'and' or op is 'not'
          throw new SuperphyError('Invalid input in advanced filter form. Element "adv-filter-op" must contain strings "and","or","not".')
        
        if op is 'not'
          op = 'and'
          negate = true
          
        t.op = op
        t.negate = negate
        
        searchTerms.push t
        
      else
        # Currently, the first term cannot be negated
        t.negate = false
        searchTerms.unshift t
        
    searchTerms
  
  # FUNC createSelectionView
  # Creates a unique view-type object that tracks currently selected
  # genomes
  #
  # RETURNS
  # boolean
  # 
  createSelectionView: (boxEl, countEl=null) ->
    
    # Existing selection window?
    throw new SuperphyError 'Existing SelectionView. Cannot create multiple views of this type.' if @selectedBox?
    
    # New list view
    selView = new SelectionView(boxEl, countEl)
    selView.update(@genomeController)
    @selectedBox = selView
      
    return true # return success
    
    
  # FUNC submitGenomes
  # To do a form submission, selected or grouped
  # genomes are added as hidden parameters to a form
  #
  # USAGE submitGenomes jQuery_element string
  # if paramType = 'selected'
  #   all selected genomes will be added as genome=public_12344
  # if paramType = 'grouped'
  #   all grouped genomes will be added as group1=public_12344
  # RETURNS
  # boolean
  # 
  submitGenomes: (formEl, paramType='selected') ->
    
    if paramType is 'selected'
      
      gset = @genomeController.selected()
      genomes = gset.public.concat gset.private
      
      for g in genomes
        input = jQuery('<input></input>')
        input.attr('type','hidden')
        input.attr('name', 'genome')
        input.val(g)
        formEl.append(input)
          
    else if paramType is 'grouped'
      
      for k,v of @genomeController.public_genomes when v.assignedGroup?
        input = jQuery('<input></input>')
        input.attr('type', 'hidden')
        input.attr('name', "group#{v.assignedGroup}")
        input.val(g)
        formEl.append(input)
     
      for k,v of @genomeController.private_genomes when v.assignedGroup?
        input = jQuery('<input></input>')
        input.attr('type', 'hidden')
        input.attr('name', "group#{v.assignedGroup}")
        input.val(g)
        formEl.append(input)
      
    else
      throw new SuperphyError "Unknown paramType parameter: #{paramType}"

  # FUNC highlightInView
  # Identify genomes that match query and update
  # selected view so that genome(s) are highlighted
  #
  # PARAMS
  # string for search query
  # int indicating view number
  # 
  # RETURNS
  # boolean 
  #      
  highlightInView: (searchStr, vNum) ->
    
    unless searchStr and searchStr.length
      return false
      
    targetList = @genomeController.find(searchStr)
    
    if targetList and targetList.length
      @views[vNum].highlightGenomes(@genomeController, targetList)
      
    else
      superphyAlert "Search string #{searchStr} matches no currently visible genomes.", "None Found"
      
    true
    

  # FUNC checkDefaultMeta
  # Helper function that checks off default meta-options
  #
  # PARAMS
  # defaults: array of metadata type strings
  # 
  # RETURNS
  # boolean 
  #      
  _checkDefaultMeta: (defaults) ->

    for m in defaults
      jQuery('input[name="meta-option"][value="'+m+'"]').prop('checked', true)
      jQuery('#meta-option_'+m).show()

    true
    

# Return instance of a ViewController
unless root.ViewController
  root.viewController = new ViewController


###
 CLASS ViewTemplate
 
 Template object for views. Defines required and
 common properties/methods. All view objects
 are descendants of the ViewTemplate.

###
class ViewTemplate
  constructor: (@parentElem, @style='select', @elNum=1) ->
    @elID = @elName + @elNum
  
  type: undefined
  
  elNum: 1
  elName: 'view'
  elID: undefined
  parentElem: undefined
  
  # Default is 'select' where elements styled for on/off checkbox behaviour.
  # Other option is 'redirect', elements styled for clicking on genome to go to page
  style: 'select'
  
  update: (genomes) ->
    throw new SuperphyError "ViewTemplate method update() must be defined in child class (#{this.type})."
    false # return fail
    
  updateCSS: (gset, genomes) ->
    throw new SuperphyError "ViewTemplate method updateCSS() must be defined in child class (#{this.type})."
    false # return fail
    
  select: (genome, isSelected) ->
    throw new SuperphyError "ViewTemplate method select() must be defined in child class (#{this.type})."
    false # return fail
  
  dump: (genomes) ->
    throw new SuperphyError "ViewTemplate method dump() must be defined in child class (#{this.type})."
    false # return fail
    
  viewAction: (genomes, args...) ->
    throw new SuperphyError "viewAction method has not been defined in child class (#{this.type})."
    false # return fail
    
  highlightGenomes: (genomes, targetList, args...) ->
    throw new SuperphyError "highlightGenomes method has not been defined in child class (#{this.type})."
    false # return fail
    
  cssClass: ->
    # For each list element
    @elName + '_item'
    
    
      

###
 CLASS ListView
 
 Genome list
 
 Always genome-based
 Returns genome ID to redirect/select when genome list item is clicked

###
class ListView extends ViewTemplate
  constructor: (@parentElem, @style, @elNum, listArgs) ->
    
    # Additional data to append to node names
    # Keys are genome IDs
    if listArgs? and listArgs[0]?
      @locusData = listArgs[0]
      
    # Call default constructor - creates unique element ID                  
    super(@parentElem, @style, @elNum)
  
  type: 'list'
  
  elName: 'genome_list'
  
  locusData: null
  
  # FUNC update
  # Update genome list view
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  #      
  update: (genomes) ->
    
    # create or find list element
    listElem = jQuery("##{@elID}")
    if listElem.length
      listElem.empty()
    else      
      listElem = jQuery("<ul id='#{@elID}'/>")
      jQuery(@parentElem).append(listElem)
   
    # append genomes to list
    t1 = new Date()
    @_appendGenomes(listElem, genomes.pubVisible, genomes.public_genomes, @style, false)
    @_appendGenomes(listElem, genomes.pvtVisible, genomes.private_genomes, @style, true)
    t2 = new Date()
    
    ft = t2-t1
    console.log('ListView update elapsed time: '+ft)
    
    true # return success
  
  _appendGenomes: (el, visibleG, genomes, style, priv) ->
    
    # View class
    cls = @cssClass()
        
    if priv && visibleG.length
      el.append("<li class='genome_list_spacer'>---- USER-SUBMITTED GENOMES ----</li>")
      
    for g in visibleG
      
      thiscls = cls
      thiscls = cls+' '+genomes[g].cssClass if genomes[g].cssClass?
      
      name = genomes[g].viewname
      if @locusData?
        name += @locusData.genomeString(g)
      
      if style == 'redirect'
        # Links
        
        # Create elements
        listEl = jQuery("<li class='#{thiscls}'>#{name}</li>")
        actionEl = jQuery("<a href='#' data-genome='#{g}'> <span class='fa fa-search'></span>info</a>")
        
        # Set behaviour
        actionEl.click (e) ->
          e.preventDefault()
          gid = @.dataset.genome
          viewController.select(gid, true)
        
        # Append to list
        listEl.append(actionEl)
        el.append(listEl)
        
      else if style == 'select'
        # Checkboxes
        
        # Create elements
        checked = ''
        checked = 'checked' if genomes[g].isSelected
        listEl = jQuery("<li class='#{thiscls}'></li>")
        labEl = jQuery("<label class='checkbox'>#{name}</label>")
        actionEl = jQuery("<input class='checkbox' type='checkbox' value='#{g}' #{checked}/>")
        
        # Set behaviour
        actionEl.change (e) ->
          e.preventDefault()
          viewController.select(@.value, @.checked)
        
        # Append to list
        labEl.append(actionEl)
        listEl.append(labEl)
        el.append(listEl)
        
      else
        return false
      
    true
    
  # FUNC updateCSS
  # Change CSS class for selected genomes to match underlying genome properties
  #
  # PARAMS
  # simple hash object with private and public list of genome Ids to update
  # genomeController object
  # 
  # RETURNS
  # boolean 
  #      
  updateCSS: (gset, genomes) ->
    
    # Retrieve list DOM element    
    listEl = jQuery("##{@elID}")
    throw new SuperphyError "DOM element for list view #{@elID} not found. Cannot call ListView method updateCSS()." unless listEl? and listEl.length
    
    # append genomes to list
    @_updateGenomeCSS(listEl, gset.public, genomes.public_genomes) if gset.public?
    
    @_updateGenomeCSS(listEl, gset.private, genomes.private_genomes) if gset.private?
    
    true # return success
    
  
  _updateGenomeCSS: (el, changedG, genomes) ->
    
    # View class
    cls = @cssClass()
    
    for g in changedG
      
      thiscls = cls
      thiscls = cls+' '+ genomes[g].cssClass if genomes[g].cssClass?
      liEl = null
      
     if @style == 'redirect'
        # Link style
        
        # Find element
        descriptor = "td > a[data-genome='#{g}']"
        itemEl = el.find(descriptor)
        
        unless itemEl? and itemEl.length
          throw new SuperphyError "List element for genome #{g} not found in ListView #{@elID}"
          return false
          
        liEl = itemEl.parent()
       
      else if @style == 'select'
        # Checkbox style
        
        # Find element
        descriptor = "td input[value='#{g}']"
        itemEl = el.find(descriptor)
        
        unless itemEl? and itemEl.length
          throw new SuperphyError "List element for genome #{g} not found in ListView #{@elID}"
          return false
          
        liEl = itemEl.parents().eq(1)
   
      else
        return false
      
      liEl.attr('class', thiscls)
        
        
    true # success
  
  # FUNC select
  # Change style to indicate its selection status
  #
  # PARAMS
  # genome object from GenomeController list or array of such objects
  # boolean indicating if selected/unselected
  # 
  # RETURNS
  # boolean 
  #       
  select: (genomes, isSelected) ->

    genomelist = genomes
    unless typeIsArray(genomes)
      genomelist = [genomes]

    for genome in genomelist
  
      itemEl = null
      
      if @style == 'select'
        # Checkbox style, othe styles do not have 'select' behavior
        
        # Find element
        descriptor = "li input[value='#{genome}']"
        itemEl = jQuery(descriptor)
   
      else
        return false
      
      unless itemEl? and itemEl.length
        throw new SuperphyError "List element for genome #{genome} not found in ListView #{@elID}"
        return false
          
      itemEl.prop('checked', isSelected);
    
    true # success
  
  # FUNC dump
  # Generate CSV tab-delimited representation of all genomes and meta-data
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # object containing:
  #   ext[string] - a suitable file extension (e.g. csv)
  #   type[string] - a MIME type
  #   data[string] - a string containing data in final format
  #      
  dump: (genomes) ->
    
    # Create complete list of meta-types
    # make all visible
    fullMeta = {}
    fullMeta[k] = true for k of genomes.visibleMeta
    
    output = ''
    # Output header
    header = (genomes.metaMap[k] for k in genomes.mtypes)
    header.unshift "Genome name"
    output += "#" + header.join("\t") + "\n"
    
    # Output public set
    for id,g of genomes.public_genomes
      output += genomes.label(g,fullMeta,"\t") + "\n"
      
    # Output private set
    for id,g of genomes.private_genomes
      output += genomes.label(g,fullMeta,"\t") + "\n"
      
    return {
      ext: 'csv'
      type: 'text/plain'
      data: output 
    }
    
 
###
 CLASS GroupView
 
 A special type of genome list that is used to temporarily store the user's
 selected genomes.
 
 Only one 'style' which provides a remove button to remove group from group.
 Will be updated by changes to the meta-display options but not by filtering.

###
class GroupView
  constructor: (@parentElem, @elNum=1) ->
    @elID = @elName + @elNum
  
  
  type: 'group'
  elNum: 1
  elName: 'genome_group'
  elID: undefined
  
  # FUNC update
  # Update genome list view
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  #      
  update: (genomes) ->
    # create or find list element
    listElem = jQuery("##{@elID}")
    if listElem.length
      listElem.empty()
    else      
      listElem = jQuery("<ul id='#{@elID}' class='genome-group-list'/>")
      jQuery(@parentElem).append(listElem)
   
    # append group genomes to list
    # TODO:
    ingrp = genomes.grouped(@elNum)

    @_appendGenomes(listElem, ingrp.public, genomes.public_genomes)
    @_appendGenomes(listElem, ingrp.private, genomes.private_genomes)
    
    true # return success
  
  # FUNC add
  # Add single genome to list view
  # Should be faster than calling update (which will reinsert all genomes)
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  #      
  add: (genomeSet, genomes) ->
    # create or find list element
    listElem = jQuery("##{@elID}")
    if not listElem.length    
      listElem = jQuery("<ul id='#{@elID}' class='genome-group-list'/>")
      jQuery(@parentElem).append(listElem)
    
    if genomeSet.public?
      @_appendGenomes(listElem, genomeSet.public, genomes.public_genomes)
        
    if genomeSet.private?
      @_appendGenomes(listElem, genomeSet.private, genomes.private_genomes)
      
  _appendGenomes: (el, visibleG, genomes) ->
    
    # View class
    cls = @cssClass()
    
    for g in visibleG
      # Includes remove links

      # Create elements
      listEl = jQuery("<li class='#{cls}'>"+genomes[g].viewname+'</li>')
      actionEl = jQuery("<a href='#' data-genome='#{g}' data-genome-group='#{@elNum}'> <i class='fa fa-times'></a>")
      
      # Set behaviour
      actionEl.click (e) ->
        e.preventDefault()
        gid = @.dataset.genome
        grp = @.dataset.genomeGroup
        console.log('clicked remove on '+gid)
        viewController.removeFromGroup(gid, grp)
      
      # Append to list
      listEl.append(actionEl)
      el.append(listEl)
      
    true
    
  remove: (gid) ->

    # Retrieve list DOM element    
    listEl = jQuery("##{@elID}")
    throw new SuperphyError "DOM element for group view #{@elID} not found. Cannot call GroupView method remove()." unless listEl? and listEl.length
    
    # Find genome DOM element
    descriptor = "li > a[data-genome='#{gid}']"
    linkEl = listEl.find(descriptor)

    
    unless linkEl? and linkEl.length
      throw new SuperphyError "List item element for genome #{gid} not found in GroupView #{@elID}"
      return false
      
    # Remove list item element from selected list
    linkEl.parent('li').remove()
      
    true
    
  cssClass: ->
    # For each list element
    @elName + '_item'
    

###
 CLASS GenomeController
 
 Manages private/public genome list 

###
class GenomeController
  constructor: (@public_genomes, @private_genomes, subset=null, defaultMetas=[]) ->
    
    if subset?
      # Only a subset of all genomes are in use
      # Probably should be managed on server-side
      # but this is easier
      newPub = {}
      newPri = {}
      
      for i in subset
        
        if @public_genomes[i]?
          newPub[i] = @public_genomes[i]
        else if @private_genomes[i]?
          newPri[i] = @private_genomes[i]
          
      @public_genomes = newPub
      @private_genomes = newPri


    for m in defaultMetas
      @visibleMeta[m] = true
 
    @update() # Initialize the viewname field
    @filter() # Initialize the visible genomes
  
    
    # Track changes in the set of visible genomes through
    # incremental ID
    @genomeSetId = 0
    
  pubVisible: []
  
  pvtVisible: []

  filterReset: false
  
  visibleMeta: 
    strain: false
    serotype: false
    isolation_host: false
    isolation_source: false
    isolation_date: false
    accession: false
    syndrome: false
    stx1_subtype: false
    stx2_subtype: false
    
  metaMap:
    'strain': 'Strain',
    'serotype': 'Serotype',
    'isolation_host': 'Host',
    'isolation_source': 'Source',
    'isolation_date': 'Date of isolation',
    'accession': 'Accession ID'
    'syndrome': 'Symptom / Disease',
    'stx1_subtype': 'Stx1 Subtype',
    'stx2_subtype': 'Stx2 Subtype'
    
  mtypes: [
    'strain'
    'serotype'
    'isolation_host'
    'isolation_source'
    'isolation_date'
    'syndrome'
    'stx1_subtype'
    'stx2_subtype'
    'accession'
  ]
    
  publicRegexp: new RegExp('^public_')
  privateRegexp: new RegExp('^private_')

  filtered: 0

  mtypesDisplayed: ['serotype','isolation_host','isolation_source','isolation_date','syndrome','stx1_subtype','stx2_subtype']

  mtypesCounted: ['serotype','isolation_host','isolation_source','syndrome','stx1_subtype','stx2_subtype']



  # FUNC update
  # Update genome names displayed to user
  #
  # PARAMS
  # none (object variable visibleMeta is used to determine which fields are displayed)
  # 
  # RETURNS
  # boolean 
  #      
  update: ->
    
    # Update public set
    for id,g of @public_genomes
      ma = @label(g,@visibleMeta,null)
      g.viewname = ma.join('|')
      g.meta_array = ma
      
    # Update private set
    for id,g of @private_genomes
      ma = @label(g,@visibleMeta,null)
      g.viewname = ma.join('|')
      g.meta_array = ma
      
    true
    
  
  # FUNC filter
  # Updates the pubVisable and pvtVisable id lists with the genome
  # Ids that passed filter in sorted order
  #
  # PARAMS
  # searchTerms - an array of objects containing the following properties:
  #   searchTerm[string]: match string or date 
  #   dataField[string]: genome attribute to use in search (e.g. isolation_date)
  #   negate[boolean]: return genomes that do not pass filter
  #   op[string,optional] - and,or logical operators used to join multiple queries. First term should not have an operator
  # -OR-
  #   dataField[string]: 'isolation_date'
  #   date[string]: a date string YYYY-MM-DD
  #   before[boolean]: indicates before/after date
  #   op[string,optional] - see above
  # 
  # RETURNS
  # boolean
  #
  filter: (searchTerms = null) ->
    
    pubGenomeIds = []
    pvtGenomeIds = []

    if searchTerms?     
      results = @_runFilter(searchTerms);
      
      pubGenomeIds = results.public;
      pvtGenomeIds = results.private;
      
      @filtered = pubGenomeIds.length + pvtGenomeIds.length
      
      if @filtered != 0
        # Reset visible variable for all genomes
        g.visible = false for i,g of @public_genomes
        g.visible = false for i,g of @private_genomes
        
        # Set visible variable for genomes that passed filter
        @public_genomes[g].visible = true for g in pubGenomeIds
        @private_genomes[g].visible = true for g in pvtGenomeIds
        
        @pubVisible = pubGenomeIds.sort (a, b) => cmp(@public_genomes[a].viewname, @public_genomes[b].viewname)
        @pvtVisible = pvtGenomeIds.sort (a, b) => cmp(@private_genomes[a].viewname, @private_genomes[b].viewname)
        
    else
      pubGenomeIds = Object.keys(@public_genomes)
      pvtGenomeIds = Object.keys(@private_genomes)
      
      @filtered = 0
      
      # Reset visible variable for all genomes
      g.visible = true for i,g of @public_genomes
      g.visible = true for i,g of @private_genomes
    
      @pubVisible = pubGenomeIds.sort (a, b) => cmp(@public_genomes[a].viewname, @public_genomes[b].viewname)
      @pvtVisible = pvtGenomeIds.sort (a, b) => cmp(@private_genomes[a].viewname, @private_genomes[b].viewname)
    
    # Changed the visible genomes, so views need to reset to default starting view
    @genomeSetId++
    
    true


  # FUNC countMeta
  # Update count object with genome totals
  #
  # PARAMS
  # genome
  # count 
  # 
  # RETURNS
  # count dictionary
  #
  countMeta: (genome, count = null, count_unassigned = true) ->

    count = {} if !count?

    for t in @mtypesCounted

      if !count[t]?
        count[t] = {}
      
      arr = genome[t]
      
      if arr?
        for v in arr
          # Could be multiple values for metadata type
      
          if !count[t]?
            count[t] = {}

          if count[t][v]?
            count[t][v]++
          else count[t][v] = 1

      else if count_unassigned

        if count[t]['Unassigned']?
          count[t]['Unassigned']++
        else
          count[t]['Unassigned'] = 1
    

    count

  # FUNC metaOrder
  # Count all values for each metadata type.
  # Determine the X most frequent values.
  #
  # PARAMS
  # None
  # 
  # RETURNS
  # count dictionary, count list
  #
  metaOrder: (bins = 6)->

    # Do total metadata counts once for displayed metadata
    # This is used to establish bar orders in views
    # It doesnt change irregardless if filter/update applied
    metaBins = {}
    metaOrder = {}
    count = {}
    for id,g of @public_genomes
      count = @countMeta(g, count) 

    for id,g of @private_genomes
      count = @countMeta(g, count)

    for m in @mtypesCounted

      if count[m]?
        valueList = Object.keys(count[m]).sort((a,b) -> count[m][b] - count[m][a])

        trackedValues = []
        if valueList.length > bins
          trackedValues = valueList.slice(0,bins)
          trackedValues.push('other')
        else
          trackedValues = valueList

        metaBins[m] = {}
        metaOrder[m] = trackedValues
        i = 0
        for v in trackedValues
          metaBins[m][v] = i

          i++


    [metaBins, metaOrder]

  

    
  # FUNC filterBySelection
  # Updates the pubVisable and pvtVisable id lists to match currently selected genomes
  # If no genomes are selected, resets filter to show all genomes
  #
  # PARAMS
  # none
  # 
  # RETURNS
  # boolean
  #
  filterBySelection: ->
    
    gset = @selected()
    
    pubGenomeIds = gset.public;
    pvtGenomeIds = gset.private;
    
    @filtered = pubGenomeIds.length + pvtGenomeIds.length
    
    if @filtered == 0
      # No genomes selected, reset filter
      @filter()
    else
      # Filter based on selection
      
      # Reset visible variable for all genomes
      g.visible = false for i,g of @public_genomes
      g.visible = false for i,g of @private_genomes
      
      # Set visible variable for genomes that are selected
      # "Also unselect at this point" was commented out for clarification that the filtered genomes are still selected
      for g in pubGenomeIds
        @public_genomes[g].visible = true 
        #@public_genomes[g].isSelected = false
        
      for g in pvtGenomeIds
        @private_genomes[g].visible = true
        #@private_genomes[g].isSelected = false
      
      # Sort
      @pubVisible = pubGenomeIds.sort (a, b) => cmp(@public_genomes[a].viewname, @public_genomes[b].viewname)
      @pvtVisible = pvtGenomeIds.sort (a, b) => cmp(@private_genomes[a].viewname, @private_genomes[b].viewname)

      # Workaround fix for incorrect positioning and metadata bars on tree
      viewController.viewAction(1, 'reset_window')

    true
  
  # FUNC _runFilter
  # Calls match function for each search term and combines results for multi-term queries
  #
  # PARAMS
  # An array of searchTerm objects defined as:
  # searchTerm - search string (any portion is matched, no 'exact'/global matching) 
  # dataField  - a meta-data key name to do the search on
  # negate     - a boolean indicating is user wants to do a NOT search
  # op         - a string containing 'and/or'. The first term must not contain an op property.
  #              Subsequent terms must contain the op property.
  #
  #   -OR-, when dataField = 'isolation_date'
  #
  # dataField  - must be 'isolation_date'
  # date       - a date string in the format YYYY-MM-DD
  # before     - a boolean indicated 'before/after'
  # op         - see above
  #
  # RETURNS
  # two arrays
  #
  _runFilter: (searchTerms) ->
    
    unless typeIsArray searchTerms
      throw new SuperphyError('Invalid argument. GenomeController method _runFilter() requires array of search term objects as input.');
    
    # Start with entire set
    pubGenomeIds = Object.keys(@public_genomes)
    pvtGenomeIds = Object.keys(@private_genomes)
    firstTerm = true
    
    for t in searchTerms
      
      if firstTerm
        # Validate the first term just to do a quick check that input type is correct
        throw new SuperphyError("Invalid filter input. First search term object cannot contain an operator property 'op'.") if t.op?
        
        unless t.dataField is 'isolation_date'
          # Non-date form
          throw new SuperphyError("Invalid filter input. Search term objects must contain a 'searchTerm' property.") unless t.searchTerm?
          throw new SuperphyError("Invalid filter input. Search term objects must contain a 'dataField' property.") unless t.dataField?
          throw new SuperphyError("Invalid filter input. Search term objects must contain a 'negate' property.") unless t.negate?
        else
          # Date form
          throw new SuperphyError("Invalid filter input. Date objects must contain a 'searchTerm' property.") unless t.dataField?
          throw new SuperphyError("Invalid filter input. Date objects must contain a 'date' property.") unless t.date?
          throw new SuperphyError("Invalid filter input. Date objects must contain a 'before' property.") unless t.before?
          
        firstTerm = false

      else
         throw new SuperphyError("Invalid filter input. Subsequent search term objects must contain an operator property 'op'.") unless t.op?
 
      if t.op? and t.op is 'or'
        # Union operation runs on whole set
        
        pubSet = []
        pubSet = []
      
        if t.dataField is 'isolation_date'
          # Date comparison
          pubSet = (id for id in Object.keys(@public_genomes) when @passDate(@public_genomes[id], t.before, t.date))
          pvtSet = (id for id in Object.keys(@private_genomes) when @passDate(@private_genomes[id], t.before, t.date))
        else
          # String matching
          regex = new RegExp escapeRegExp(t.searchTerm), "i"
          pubSet = (id for id in Object.keys(@public_genomes) when @match(@public_genomes[id], t.dataField, regex, t.negate))
          pvtSet = (id for id in Object.keys(@private_genomes) when @match(@private_genomes[id], t.dataField, regex, t.negate))
          
        # Union with previous results
        pubGenomeIds = @union(pubGenomeIds, pubSet)
        pvtGenomeIds = @union(pvtGenomeIds, pvtSet)
          
      else
        # Intersection operation runs on current matched subset
        
        if t.dataField is 'isolation_date'
          # Date comparison
          pubSet = (id for id in pubGenomeIds when @passDate(@public_genomes[id], t.before, t.date))
          pvtSet = (id for id in pvtGenomeIds when @passDate(@private_genomes[id], t.before, t.date))
          pubGenomeIds = pubSet
          pvtGenomeIds = pvtSet
        else
          # String matching
          regex = new RegExp escapeRegExp(t.searchTerm), "i"
          pubSet = (id for id in pubGenomeIds when @match(@public_genomes[id], t.dataField, regex, t.negate))
          pvtSet = (id for id in pvtGenomeIds when @match(@private_genomes[id], t.dataField, regex, t.negate))
          pubGenomeIds = pubSet
          pvtGenomeIds = pvtSet
        
    return { public: pubGenomeIds, private: pvtGenomeIds }
  
  # FUNC match
  # Determines if genome passes filter conditions
  #
  # PARAMS
  # genome - a single genome object from the private_/public_genomes
  # key    - a data field name in the genome object
  # regex  - a js RegExp object representing search string
  # negate - a boolean indicating whether to do NOT search
  # 
  # RETURNS
  # boolean 
  #      
  match: (genome, key, regex, negate) ->
    
    unless genome[key]?
      return false
    
    # change array into suitable string
    val = genome[key]
    val = genome[key].toString() if typeIsArray genome[key]
    
    # check if any part of string matches
    if regex.test val
      if !negate
        #console.log('passed'+val)
        return true
      else
        return false
    else
      if negate
        return true
      else
        #console.log('failed'+val)
        return false
  
  # FUNC passDate
  # Determines if genome passes date conditions
  #
  # PARAMS
  # genome - a single genome object from the private_/public_genomes
  # before - a boolean indicating criteria 'before/after'
  # date   - a Date object
  # 
  # RETURNS
  # boolean 
  #      
  passDate: (genome, before, date) ->
    
    unless genome['isolation_date']?
      return false
    
    # Parse date
    # There should only be one date assigned
    val = genome['isolation_date'][0]
    d2 = Date.parse(val);
    
    # Compae dates
    if before
      if d2 < date
        return true
      else
        return false
    else
      if d2 > date
        return true
      else
        return false  
  
  # FUNC union
  # Returns the union of two arrays
  #
  # PARAMS
  # arr1
  # arr2
  # 
  # RETURNS
  # array 
  #      
  union: (arr1, arr2) ->
    
    arr = []
    
    for i in arr1.concat(arr2)
      unless i in arr
        arr.push i
        
    arr
      
  # FUNC label
  # Genome names displayed to user, may include meta-data appended to end
  #
  # PARAMS
  # genome      - a single genome object from the private_/public_genomes
  # visibleMeta - a data field name in the genome object
  # joinStr     - a string or null (in which case, no join is performed)
  #
  # RETURNS
  # string
  #      
  label: (genome, visibleMeta, joinStr) ->
    na = 'NA'
    lab = [genome.displayname]
    
    # Add visible meta-data to label is specific order
    # Array values
    for t in @mtypes when t isnt 'accession'
      lab.push (genome[t] ? [na]).join(' ') if visibleMeta[t]
    
    # Scalar values
    lab.push genome.primary_dbxref ? na if visibleMeta.accession
    
    # Return string or array
    if joinStr?
      return lab.join(joinStr)
    else
      return lab
   
 
  updateMeta: (option, checked) ->

    unless @visibleMeta[option]?
      throw new SuperphyError 'unrecognized option in GenomeController method updateMeta()'
      return false
      
    unless checked is true or checked is false
      throw new SuperphyError 'invalid checked argument in GenomeController method updateMeta()'
      return false
    
    # toggle value
    @visibleMeta[option] = checked
    
    @update()
    
    true
    
  select: (genomes, checked) ->

    genomelist = genomes
    unless typeIsArray(genomes)
      genomelist = [genomes]

    for g in genomelist
    
      if @publicRegexp.test(g)
        @public_genomes[g].isSelected = checked 
        #alert('selected public: '+g+' value:'+checked)
      else
        @private_genomes[g].isSelected = checked
        #alert('selected private: '+g+' value:'+checked)
    
    true
    
  selected: ->
    pub = []
    pvt = []
    pub = (k for k,v of @public_genomes when v.isSelected? and v.isSelected is true)
    pvt = (k for k,v of @private_genomes when v.isSelected? and v.isSelected is true)
    
    return { public: pub, private: pvt }
    
  unselectAll: ->
    for k,v of @public_genomes
      v.isSelected = false if v.isSelected?
      
    for k,v of @private_genomes
      v.isSelected = false if v.isSelected?
      
  
  assignGroup: (gset, grpNum) ->
    if gset.public? and typeof gset.public isnt 'undefined'
      for g in gset.public
        @public_genomes[g].assignedGroup = grpNum
        cls = 'genome_group'+grpNum
        @public_genomes[g].cssClass = cls
        
    if gset.private? and typeof gset.private isnt 'undefined'
      for g in gset.private
        @private_genomes[g].assignedGroup = grpNum
        cls = 'genome_group'+grpNum
        @private_genomes[g].cssClass = cls
    
    true
    
  deleteGroup: (gset) ->
    if gset.public? and typeof gset.public isnt 'undefined'
      for g in gset.public
        @public_genomes[g].assignedGroup = null
        @public_genomes[g].cssClass = null
        
    if gset.private? and typeof gset.public isnt 'undefined'
      for g in gset.private
        @private_genomes[g].assignedGroup = null
        @private_genomes[g].cssClass = null
    
    true
      
  grouped: (grpNum) ->
    pub = []
    pvt = []
    pub = (k for k,v of @public_genomes when v.assignedGroup? and v.assignedGroup is grpNum)
    pvt = (k for k,v of @private_genomes when v.assignedGroup? and v.assignedGroup is grpNum)

    return { public: pub, private: pvt }
    
  genomeSet: (gids) ->
    pub = []
    pvt = []
    pub = (g for g in gids when @publicRegexp.test(g))
    pvt = (g for g in gids when @privateRegexp.test(g))
    
    return { public: pub, private: pvt }
    
  genome: (gid) ->
    if @publicRegexp.test(gid)
      return @public_genomes[gid]
    else
      return @private_genomes[gid]
      
  # FUNC sort
  # Sort genomes by meta-data 
  #
  # PARAMS
  # gids        - a list of genome labels ala: private_/public_123445
  # metaField   - a data field to sort on
  # asc         - a boolean indicating sort order
  #
  # RETURNS
  # list
  #      
  sort: (gids, metaField, asc) ->
    
    return gids unless gids.length
   
    that = @
    gids.sort (a,b) ->
      aObj = that.genome(a)
      bObj = that.genome(b)
      
      aField = aObj[metaField]
      aName = aObj.displayname.toLowerCase()
      bField = bObj[metaField]
      bName = bObj.displayname.toLowerCase()
      
      if aField? and bField?
        
        if typeIsArray aField
          aField = aField.join('').toLowerCase()
          bField = bField.join('').toLowerCase()
        else
          aField = aField.toLowerCase()
          bField = bField.toLowerCase()
          
        if aField < bField
          return -1
        else if aField > bField
          return 1
        else
          if aName < bName
            return -1
          else if aName > bName
            return 1
          else
            return 0
            
      else
        if aField? and not bField?
          return -1
        else if bField? and not aField?
          return 1
        else
          if aName < bName
            return -1
          else if aName > bName
            return 1
          else
            return 0

    if not asc
      gids.reverse()
      
    gids
          
          
  # FUNC find
  # Returns list of visible public and private genome IDs \
  # that have matching names
  #
  # PARAMS
  # searchStr - a string to use in genome name search
  # 
  # RETURNS
  # array of matching genome labels
  #
  find: (searchStr) ->
    
    regex = new RegExp escapeRegExp(searchStr), "i"
    pubSet = (id for id in @pubVisible when @match(@public_genomes[id], 'displayname', regex, false))
    pvtSet = (id for id in @pvtVisible when @match(@private_genomes[id], 'displayname', regex, false))
    
 
    genomes = pubSet.concat pvtSet
    
    console.log genomes
    
    genomes
        
  
###
 CLASS LocusController
 
 Manages Locus/Gene allele data 

###
class LocusController
  constructor: (@locusData) ->
    
 
  emptyString: "<span class='locus_group0'>No alleles detected</span>"

  zeroString: "<span class='locus_group0'>0</span>"
 
  # FUNC locusString
  # return string for single allele/locus 
  #
  # PARAMS
  # Either
  # 1. single argument with ID format: genomeID|locusID
  #   -or-
  # 2. two arguments: genomeID, locusID
  #   -where-
  # genomeID = public_1234
  # locusID = 1234
  # 
  # RETURNS
  # string
  #      
  locusString: (id, locusID=null) ->
    
    genomeID
    if locusID?
      genomeID = id
    else
      res = parseHeader(id)
      genomeID = res[1]
      locusID = res[2]
      throw new SuperphyError "Invalid locus ID format: #{id}." unless genomeID? and locusID?
      
    g = @locusData[genomeID]
    throw new SuperphyError "Unknown genome: #{genomeID}." unless g?
    
    l = g[locusID]
    throw new SuperphyError "Unknown locus: #{locusID} for genome #{genomeID}." unless l?
    
    str = ''
    if l.copy > 1
      str = " (#{l.copy} copy)"
 
    str
    
  # FUNC locusNode
  # return text/class associated with locus 
  #
  # PARAMS
  # Either
  # 1. single argument with ID format: genomeID|locusID
  #   -or-
  # 2. two arguments: genomeID, locusID
  #   -where-
  # genomeID = public_1234
  # locusID = 1234
  # 
  # RETURNS
  # string, group
  #      
  locusNode: (id, locusID=null) ->
    
    genomeID
    if locusID?
      genomeID = id
    else
      res = parseHeader(id)
      genomeID = res[1]
      locusID = res[2]
      throw new SuperphyError "Invalid locus ID format: #{id}." unless genomeID? and locusID?
      
    g = @locusData[genomeID]
    throw new SuperphyError "Unknown genome: #{genomeID}." unless g?
    
    l = g[locusID]
    throw new SuperphyError "Unknown locus: #{locusID} for genome #{genomeID}." unless l?
    
    str
    if l.copy > 1
      str = " (#{l.copy} copy)"
    else 
      str = ''
    
    return [str, null]
    

  # FUNC genomeString
  # return string for genome (merging multiple loci/allele 
  # data strings for genome) 
  #
  # PARAMS
  # genomeID with format: public_1234
  #
  # RETURNS
  # string
  #      
  genomeString: (genomeID) ->
    
    str = ' - '
    g = @locusData[genomeID]
    
    if g? and g.num_copies > 0
      str += "<span class='locus_group1'>#{g.num_copies} allele(s)</span>"
      
    else
      str += @emptyString
    
    str


  # FUNC countString
  # return string representing allele count for genome (merging multiple loci/allele 
  # data strings for genome) 
  #
  # PARAMS
  # genomeID with format: public_1234
  #
  # RETURNS
  # string
  #      
  countString: (genomeID) ->
    
    str = ''
    g = @locusData[genomeID]
    
    if g? and g.num_copies > 0
      str = "<span class='locus_group1'>#{g.num_copies}</span>"
      
    else
      str = @zeroString
    
    str
    
    
  # FUNC count
  # Counts unique locus data copies for a set of genomes
  #
  # PARAMS
  # genomeController object
  #
  # RETURNS
  # string
  #      
  count: (genomes) ->
    
    counts_list = []
    
    @_count(genomes.pubVisible, counts_list)
    @_count(genomes.pvtVisible, counts_list)
    
    counts_list
    
  _count: (genomeList, counts_list) ->
    
    for gID in genomeList
      c = @genome_copies(gID)
      counts_list.push c
        
    true

  # FUNC genome_copies
  # Returns the number of copies for genome ID
  # in the locusData object. If genome ID not
  # found in locusData, returns 0.
  #
  # PARAMS
  # genome_id string
  #
  # RETURNS
  # integer
  #
  genome_copies: (gID) ->
    g = @locusData[gID]
    if g?
      return g.num_copies
    
    0

  # FUNC sort
  # Sort genomes by allele count
  #
  # PARAMS
  # genomeList  - a list of genome labels ala: private_/public_123445
  # asc         - a boolean indicating sort order
  # genomesC    - pointer to genomeController object
  #
  # RETURNS
  # list
  #      
  sort: (genomeList, asc, genomesC) ->
    
    return genomeList unless genomeList.length
   
    that = @
    genomeList.sort (a,b) ->
      anum = that.genome_copies(a)
      bnum = that.genome_copies(b)
      
      if anum < bnum
        return -1
      else if anum > bnum
        return 1
      else
        aObj = genomesC.genome(a)
        bObj = genomesC.genome(b)
      
        aName = aObj.displayname.toLowerCase()
        bName = bObj.displayname.toLowerCase()

        if aName < bName
          return -1
        else if aName > bName
          return 1
        else
          return 0
            
    if not asc
      genomeList.reverse()
      
    genomeList

    
# Return instance of a LocusController
unless root.LocusController
  root.LocusController = LocusController
  
###
 CLASS StxController
 
 Manages Stx data 

###
class StxController
  constructor: (@locusData) ->
 
    @dataValues = {}
    @format() # Initialise the dataString field
    
    
  emptyString: "<span class='locus_group0'>NA</span>"
  
 
  # FUNC format
  # Format the locus data HTML strings
  # Record unique data values
  #
  # PARAMS
  # none
  # 
  # RETURNS
  # boolean 
  #      
  format: ->
    
    for g of @locusData
      for k,o of @locusData[g]
      
        val = o.data
        
        dataGroup = 0
        if @dataValues[val]?
          dataGroup = @dataValues[val]
          
        else
          grpNum = Object.keys(@dataValues).length
          grpNum++
          @dataValues[val] = grpNum
          dataGroup = grpNum
         
        o.cls = "locus_group#{dataGroup}"
        o.group = dataGroup
        o.dataString = "<span class='#{o.cls}'>#{val}</span>"
        
    true
    
  # FUNC locusString
  # return string for single allele/locus 
  #
  # PARAMS
  # Either
  # 1. single argument with ID format: genomeID|locusID
  #   -or-
  # 2. two arguments: genomeID, locusID
  #   -where-
  # genomeID = public_1234
  # locusID = 1234
  # 
  # RETURNS
  # string
  #      
  locusString: (id, locusID=null) ->
    
    genomeID
    if locusID?
      genomeID = id
    else
      res = parseHeader(id)
      genomeID = res[1]
      locusID = res[2]
      throw new SuperphyError "Invalid locus ID format: #{id}." unless genomeID? and locusID?
      
    g = @locusData[genomeID]
    throw new SuperphyError "Unknown genome: #{genomeID}." unless g?
    
    l = g[locusID]
    throw new SuperphyError "Unknown locus: #{locusID} for genome #{genomeID}." unless l?
    
    str
    if l.copy > 1
      str = " (#{l.copy} copy) -  #{l.dataString}"
    else 
      str = ' - ' + l.dataString
    
    str
    
  # FUNC locusNode
  # return text/class associated with locus 
  #
  # PARAMS
  # Either
  # 1. single argument with ID format: genomeID|locusID
  #   -or-
  # 2. two arguments: genomeID, locusID
  #   -where-
  # genomeID = public_1234
  # locusID = 1234
  # 
  # RETURNS
  # string
  #      
  locusNode: (id, locusID=null) ->
    
    genomeID
    if locusID?
      genomeID = id
    else
      res = parseHeader(id)
      genomeID = res[1]
      locusID = res[2]
      throw new SuperphyError "Invalid locus ID format: #{id}." unless genomeID? and locusID?
      
    g = @locusData[genomeID]
    throw new SuperphyError "Unknown genome: #{genomeID}." unless g?
    
    l = g[locusID]
    throw new SuperphyError "Unknown locus: #{locusID} for genome #{genomeID}." unless l?
    
    str
    if l.copy > 1
      str = " (#{l.copy} copy) -  #{l.data}"
    else 
      str = ' - ' + l.data
    
    return [str, l.group]
    

  # FUNC genomeString
  # return string for genome (merging multiple loci/allele 
  # data strings for genome) 
  #
  # PARAMS
  # genomeID with format: public_1234
  #
  # RETURNS
  # string
  #      
  genomeString: (genomeID) ->
    
    str = ' - '
    g = @locusData[genomeID]
    
    if g?
      ds = (v.dataString for k,v of g)
      str += ds.join(',')
      
    else
      str += @emptyString
    
    str
    
    
  # FUNC count
  # Counts unique locus data values for a set of genomes
  #
  # PARAMS
  # genomeController object
  #
  # RETURNS
  # string
  #      
  count: (genomes) ->
    
    uniqueValues = {'NA': 0}
    
    @_count(genomes.pubVisible, uniqueValues)
    @_count(genomes.pvtVisible, uniqueValues)
    
    uniqueValues
    
  _count: (genomeList, uniqueValues) ->
    
    for gID in genomeList
      g = @locusData[gID]
      if g?
        for k,v of g
          if uniqueValues[v.data]?
            uniqueValues[v.data]++
          else
            uniqueValues[v.data] = 1
      else
        uniqueValues['NA']++
    
# Return instance of a LocusController
unless root.StxController
  root.StxController = StxController
  

###
 CLASS SelectionView
 
 A special type of genome list that is used to temporarily store the user's
 selected genomes.
 
 Only one 'style' which provides a remove button to remove group from group.
 Will be updated by changes to the meta-display options but not by filtering.

###
class SelectionView
  constructor: (@parentElem, @countElem=null, @elNum=1) ->
    @elID = @elName + @elNum
    @count = 0
  
  
  type: 'selected'
  elNum: 1
  elName: 'selected_genomes'
  elID: undefined
  
  
  # FUNC update
  # Update genome list view
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  #      
  update: (genomes) ->
    
    # create or find list element
    listElem = jQuery("##{@elID}")
    if listElem.length
      listElem.empty()
    else      
      listElem = jQuery("<ul id='#{@elID}' class='selected-group-list'/>")
      jQuery(@parentElem).append(listElem)
   
    # append selected genomes to list
    ingrp = genomes.selected()
    @_appendGenomes(listElem, ingrp.public, genomes.public_genomes)
    @_appendGenomes(listElem, ingrp.private, genomes.private_genomes)
    
    @count = ingrp.public.length
    @count += ingrp.private.length
    @_updateCount()
    
          
    true # return success
  
  _appendGenomes: (el, visibleG, genomes) ->
    
    # View class
    cls = @cssClass()

    console.log(visibleG)
    
    for g in visibleG
      # Includes remove links
      
      # Create elements
      listEl = jQuery("<li class='#{cls}'>"+genomes[g].viewname+'</li>')
      actionEl = jQuery("<a href='#' data-genome='#{g}'> <i class='fa fa-times'></a>")
      
      # Set behaviour
      actionEl.click (e) ->
        e.preventDefault()
        gid = @.dataset.genome
        console.log('clicked unselect on '+gid)
        viewController.select(gid, false)
        # TODO: map should follow the ViewTemplate and then this fragile
        # code wouldn't be necessary
        viewController.views[2].matchSelected($("input[value='#{gid}']")[0])
      
      # Append to list
      listEl.append(actionEl)
      el.append(listEl)
      
    true
    
  # FUNC select
  # Add/remove selected/unselected genomes
  # to list
  #
  # PARAMS
  # genomeID
  # genomeController object
  # boolean indicating if selected/unselected
  #
  # RETURNS
  # boolean 
  #      
  select: (genomeIDs, genomes, checked) ->

    genomeIDlist = genomeIDs
    unless typeIsArray(genomeIDs)
      genomeIDlist = [genomeIDs]
    
    if checked
      gset = genomes.genomeSet(genomeIDlist)
      @add(gset, genomes)
    else
      @remove(genomeIDlist)
      
    true




  # FUNC add
  # Add single genome to list view
  # Should be faster than calling update (which will reinsert all genomes)
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  #      
  add: (genomeSet, genomes) ->
    
    # create or find list element
    listElem = jQuery("##{@elID}")
    if not listElem.length    
      listElem = jQuery("<ul id='#{@elID}' class='selected-group-list'/>")
      jQuery(@parentElem).append(listElem)
    
    if genomeSet.public?
      @_appendGenomes(listElem, genomeSet.public, genomes.public_genomes)
        
    if genomeSet.private?
      @_appendGenomes(listElem, genomeSet.private, genomes.private_genomes)
      
    @count += genomeSet.public.length
    @count += genomeSet.private.length
    @_updateCount()
  
  
  # FUNC remove
  # Remove genome from selected list
  # Should be faster than calling update (which will reinsert all genomes)
  #
  # PARAMS
  # genomeController object or array of such objects
  # 
  # RETURNS
  # boolean 
  #        
  remove: (gids) ->

    genomeIDlist = gids
    unless typeIsArray(gids)
      genomeIDlist = [gids]


    for gid in genomeIDlist

      # Retrieve list DOM element    
      listEl = jQuery("##{@elID}")
      throw new SuperphyError "DOM element for group view #{@elID} not found. Cannot call SelectionView method remove()." unless listEl? and listEl.length
      
      # Find genome DOM element
      descriptor = "li > a[data-genome='#{gid}']"
      linkEl = listEl.find(descriptor)
      
      # Commented out to suppress exception when selecting groups on VF/AMR page
      # unless linkEl? and linkEl.length
      #   throw new SuperphyError "List item element for genome #{gid} not found in SelectionView"
      #   return false
        
      # Remove list item element from selected list
      if linkEl? and linkEl.length
        linkEl.parent('li').remove()
      
      @count--

    @_updateCount()
      
    true
    
  cssClass: ->
    # For each list element
    @elName + '_item'
    
  # FUNC _updateCount
  # update the count element with the current # of selected
  #
  # PARAMS
  # genome object set with public/private t
  # 
  # RETURNS
  # boolean 
  #      
  _updateCount: ->
    
    # Update count element
    if @countElem?
      # Stick in inner span
      innerElem = @countElem.find('span.selected_genome_count_text')
      unless innerElem.length
        innerElem = jQuery("<span class='selected_genome_count_text'></span>").appendTo(@countElem)
      
      innerElem.text("#{@count} genomes selected")
      
    true 

 

###

  HELPER FUNCTIONS
  
###

parseHeader = (str) ->
  match = /^((?:public|private)_\d+)\|(\d+)/.exec(str)
  
  match
  

# FUNC typeIsArray
# A safer way to check if variable is array
#
# USAGE typeIsArray variable
# 
# RETURNS
# boolean 
#    
typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

# FUNC escapeRegExp
# Hides RegExp characters in a search string
#
# USAGE escapeRegExp str
# 
# RETURNS
# string 
#    
escapeRegExp = (str) -> str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")

# FUNC cmp
# performs alphabetical comparison, case sensitive
#
# USAGE cmp is called in array.sort
# 
# RETURNS
# -1,0,1 if lower, equal or greater in alpha order 
#    
cmp = (a, b) -> if a > b then 1 else if a < b then -1 else 0

# FUNC trimInput
# Trims leading/trailing ws.
# Sends alert if input is empty (using field in warning message)
#
# USAGE trimInput string, string
# 
# RETURNS
# string or null
#    
trimInput = (str, field) ->
  if str?
    term = jQuery.trim(str)
    if term.length
      return term
    else 
      alert("Error: #{field} is empty.")
      return null
  else
    alert("Error: #{field} is empty.")
    return null

# FUNC superphyAlert
# JQuery UI dialog to use as alert replacement
#
# USAGE superphyAlert string, string
# 
# RETURNS
# Boolean
#      
superphyAlert = (output_msg='No Message to Display.', title_msg='Alert') ->
  
  jQuery("<div></div>")
    .html(output_msg)
    .dialog({
      title: title_msg,
      resizable: false,
      modal: true,
      buttons: {
        "Ok": -> jQuery( this ).dialog( "close" );
      }
    })

# OBJECT superphyMetaOntology
# Standardized terms for host, source and syndrome
#
# To update this list (sync with DB host, source, syndrome tables)
# copy and paste text from url: .../upload/meta_ontology below
#
superphyMetaOntology = {
   "syndromes" : [
      "Bacteriuria",
      "Bloody diarrhea",
      "Crohn's Disease",
      "Diarrhea",
      "Gastroenteritis",
      "Hemolytic-uremic syndrome",
      "Hemorrhagic colitis",
      "Mastitis",
      "Meningitis",
      "Peritonitis",
      "Pneumonia",
      "Pyelonephritis",
      "Septicaemia",
      "Ulcerateive colitis",
      "Urinary tract infection (cystitis)"
   ],
   "hosts" : [
      "Bos taurus (cow)",
      "Canis lupus familiaris (dog)",
      "Environmental source",
      "Felis catus (cat)",
      "Gallus gallus (chicken)",
      "Homo sapiens (human)",
      "Mus musculus (mouse)",
      "Oryctolagus cuniculus (rabbit)",
      "Ovis aries (sheep)",
      "Sus scrofa (pig)"
   ],
   "sources" : [
      "Blood",
      "Cecum",
      "Colon",
      "Feces",
      "Ileum",
      "Intestine",
      "Liver",
      "Meat",
      "Meat-based food",
      "Stool",
      "Urine",
      "Vegetable-based food",
      "Water",
      "Yolk",
      "cerebrospinal_fluid"
   ]
}


