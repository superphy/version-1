###


 File: superphy_table.coffee
 Desc: Attribute Table View Class
 Author: Matt Whiteside matthew.whiteside@phac-aspc.gc.ca
 Date: May 27th, 2013
 
 
###
 
###
 CLASS TableView
  
 Attribute Table view
 
 Always genome-based
 Returns genome ID to redirect/select when genome list item is clicked

###

class TableView extends ViewTemplate
  constructor: (@parentElem, @style, @elNum, tableArgs) ->
    
    # Additional data to append to node names
    # Keys are genome IDs
    if tableArgs? and tableArgs[0]?
      @locusData = tableArgs[0]
      
    # Call default constructor - creates unique element ID                  
    super(@parentElem, @style, @elNum)

    # Sort selection
    @sortField = 'displayname'
    @sortAsc = true

  type: 'table'
  
  elName: 'genome_table'
  
  locusData: null

  
  # FUNC update
  # Update genome table view
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  #
  update: (genomes) ->
    
    # create or find list element
    tableElem = jQuery("##{@elID} table")
    if tableElem.length
      tableElem.empty()
    else
      divElem = jQuery("<div id='#{@elID}' class='superphy-table'/>")      
      tableElem = jQuery("<table />").appendTo(divElem)
      jQuery(@parentElem).append(divElem)

    # Append genomes to table
    t1 = new Date()
    table = ''
    table += @_appendHeader(genomes)
    table += '<tbody>'
    table += @_appendGenomes(genomes.sort(genomes.pubVisible, @sortField, @sortAsc), genomes.public_genomes, @style, false)
    table += @_appendGenomes(genomes.sort(genomes.pvtVisible, @sortField, @sortAsc), genomes.private_genomes, @style, true)
    table += '</tbody>'

    tableElem.append(table)
    @_actions(tableElem, @style)

    t2 = new Date()
    
    ft = t2-t1
    console.log('TableView update elapsed time: '+ft)
    
    true # return success
  
  # Message to appear in intro for genome table
  intro: ->
    tableIntro = []
    tableIntro.push({
      element: document.querySelector('#genome_table1')
      intro: "These are the names of the genomes in the database.  Check the boxes to select each genome."
      position: 'right'
      })
    tableIntro

  _template: (tmpl, values) ->
    
    html = null
    if tmpl is 'tr'
      html = "<tr>#{values.row}</tr>"
      
    else if tmpl is 'th'
      html = "<th><a class='genome-table-sort' href='#' data-genomesort='#{values.type}'>#{values.name} <i class='fa #{values.sortIcon}'></i></a></th>"
    
    else if tmpl is 'td'
      html = "<td>#{values.data}</td>"
    
    else if tmpl is 'td1_redirect'
      html = "<td class='#{values.klass}'>#{values.name} <a class='genome-table-link' href='#' data-genome='#{values.g}' title='Genome #{values.shortName} info'><i class='fa fa-search'></i></a></td>"
        
    else if tmpl is 'td1_select'
      html = "<td class='#{values.klass}'><div class='checkbox'><label><input class='checkbox genome-table-checkbox' type='checkbox' value='#{values.g}' #{values.checked}/> #{values.name}</label></div></td>"
      
    else if tmpl is 'spacer'
      html = "<tr class='genome-table-spacer'><td>---- USER-SUBMITTED GENOMES ----</td></tr>"
    
    else
      throw new SuperphyError "Unknown template type #{tmpl} in TableView method _template"
      
    html
    
 
  _appendHeader: (genomes) ->
    
    table = '<thead><tr>'
    values = []
    i = -1
    
    # Genome
    if @sortField is 'displayname'
      sortIcon = 'fa-sort-asc'
      sortIcon = 'fa-sort-desc' unless @sortAsc
      values[++i] = { type: 'displayname', name: 'Genome', sortIcon: sortIcon}
    else
      values[++i] = { type: 'displayname', name: 'Genome', sortIcon: 'fa-sort'}
    
    # Meta fields   
    for t in genomes.mtypes when genomes.visibleMeta[t]
      tName = genomes.metaMap[t]
      sortIcon = null
      
      if t is @sortField
        sortIcon = 'fa-sort-asc'
        sortIcon = 'fa-sort-desc' unless @sortAsc
        
      else
        sortIcon = 'fa-sort'
      
      values[++i] = { type: t, name: tName, sortIcon: sortIcon}
      
    
    table += @_template('th',v) for v in values
    
    table += '</tr></thead>'
      
    table
        
  
  _appendGenomes: (visibleG, genomes, style, priv) ->
    
    cls = @cssClass()
    table = ''
    
    # Spacer    
    if priv && visibleG.length
      table += @_template('spacer',null)
        
    for g in visibleG
      
      row = ''
      
      gObj = genomes[g]
      thiscls = cls
      thiscls = cls+' '+gObj.cssClass if gObj.cssClass?
      
      name = gObj.meta_array[0]
      if @locusData?
        name += @locusData.genomeString(g)

      if style == 'redirect'
        # Links
        
        # Genome name
        row += @_template('td1_redirect', {g: g, name: name, shortName: gObj.meta_array[0], klass: thiscls})
  
        # Other data
        for d in gObj.meta_array[1..-1]
          row += @_template('td', {data: d})
          
        table += @_template('tr', {row: row})       
       
      else if style == 'select'
        # Checkboxes
        
        # Genome name
        checked = ''
        checked = 'checked' if gObj.isSelected
        row += @_template('td1_select', {g: g, name: name, klass: thiscls, checked: checked})
  
        # Other data
        for d in gObj.meta_array[1..-1]
          row += @_template('td', {data: d})
          
        table += @_template('tr', {row: row})       
   
      else
        return false
      
    table
    
    
  _actions: (tableEl, style) ->
    
    num = @elNum - 1
    
    # Header sort
    tableEl.find('.genome-table-sort').click (e) ->
      e.preventDefault()
      sortField = @.dataset.genomesort
      viewController.viewAction(num, 'sort', sortField)
    
    if style == 'select' 
      # Cell checkbox
      tableEl.find('.genome-table-checkbox').click (e) ->
        #e.preventDefault()
        viewController.select(@.value, @.checked)
      
    if style == 'redirect'
      # Cell link
      tableEl.find('.genome-table-link').click (e) ->
        e.preventDefault()
        gid = @.dataset.genome
        viewController.select(gid, true)
      
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
    tableEl = jQuery("##{@elID}")
    throw new SuperphyError "DOM element for list view #{@elID} not found. Cannot call TableView method updateCSS()." unless tableEl? and tableEl.length
    
    # append genomes to list
    @_updateGenomeCSS(tableEl, gset.public, genomes.public_genomes) if gset.public?
    
    @_updateGenomeCSS(tableEl, gset.private, genomes.private_genomes) if gset.private?
    
    true # return success
    
  
  _updateGenomeCSS: (el, changedG, genomes) ->
    #TODO: If the user tries to delete a genome from a group that has been filtered out, they will get an error
    #Might need to overrride this for the mapViews

    # View class
    cls = @cssClass()
    
    for g in changedG
      
      thiscls = cls
      thiscls = cls+' '+ genomes[g].cssClass if genomes[g].cssClass?
      dataEl = null
      
      if @style == 'redirect'
        # Link style
        
        # Find element
        descriptor = "td > a[data-genome='#{g}']"
        itemEl = el.find(descriptor)

        unless itemEl? and itemEl.length and genomes[g].visible is true
          continue
          #throw new SuperphyError "Table element for genome #{g} not found in TableView #{@elID}"
          #return false
          
        dataEl = itemEl.parent()
       
      else if @style == 'select'
        # Checkbox style
        
        # Find element
        descriptor = "td input[value='#{g}']"
        itemEl = el.find(descriptor)
        
        unless itemEl? and itemEl.length and genomes[g].visible is true
          continue
          #throw new SuperphyError "Table element for genome #{g} not found in TableView #{@elID}"
          #return false
          
        dataEl = itemEl.parents().eq(1)
   
      else
        return false
      
      dataEl.attr('class', thiscls)
        
        
    true # success
  
  # FUNC select
  # Change style to indicate its selection status
  #
  # PARAMS
  # genome object from GenomeController list
  # boolean indicating if selected/unselected
  # 
  # RETURNS
  # boolean 
  #       
  select: (genome, isSelected) ->
    
    itemEl = null
    
    if @style == 'select'
      # Checkbox style, othe styles do not have 'select' behavior
      
      # Find element
      descriptor = "td input[value='#{genome}']"
      itemEl = jQuery(descriptor)
 
    else
      return false
    
    #unless itemEl? and itemEl.length
      #throw new SuperphyError "Table element for genome #{genome} not found in TableView #{@elID}"
      #return false
        
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
    header.unshift "Superphy ID", "Genome name"
    output += "#" + header.join("\t") + "\n"
    
    # Output public set
    for id,g of genomes.public_genomes
      output += id + "\t" + genomes.label(g,fullMeta,"\t") + "\n"
      
    # Output private set
    for id,g of genomes.private_genomes
      output += id + "\t" + genomes.label(g,fullMeta,"\t") + "\n"
      
    return {
      ext: 'csv'
      type: 'text/plain'
      data: output 
    }
    
  # FUNC viewAction
  # For top-level, global commands in TableView that require
  # the genomeController as input use the viewAction in viewController.
  # This method will call the desired method in the TableView class
  #
  # PARAMS
  # genomes[obj]: GenomeContoller instance
  # argArry[array]: argument array passed to event method, first element is the event name
  # 
  # RETURNS
  # boolean 
  #      
  viewAction: (genomes, argArray) ->
    
    event = argArray.shift()
    
    if event is 'sort'
      @_sort(genomes, argArray[0])
    else
      throw new SuperphyError "Unrecognized event type: #{event} in TableView viewAction method."
    
    true
    
  # FUNC _sort
  # Private method to perform table sort on column
  #
  # PARAMS
  # genomes[obj]: GenomeContoller instance
  # field[str]: Sort column
  # 
  # RETURNS
  # boolean 
  #      
  _sort: (genomes, field) ->
    
    if field is @sortField
      # If the same field is clicked again, reverse sort order
      if @sortAsc
        @sortAsc = false
      else
        @sortAsc = true
      
    else
      @sortField = field
      @sortAsc = true
      
    console.log [field, @sortField, @sortAsc].join(', ')
      
    @update(genomes)
    
