###


 File: superphy_genes.coffee
 Desc: Javascript functions for genes in the genes/search and strains/info pages
 Author: Matt Whiteside matthew.whiteside@phac-aspc.gc.ca & Akiff Manji akiff.manji@gmail.com
 Date: June 26th, 2014
 
 
###

root = exports ? this

class GenesList
  constructor: (@geneList, @geneType, @categories, @tableElem, @categoriesElem, @mTypes, @multi_select=false) ->
    throw new Error("Invalid gene type parameter: #{@geneType}.") unless @geneType is 'vf' or @geneType is 'amr'
   
    @sortField = 'name'
    @sortAsc = true
    @sortField = 'alleles' if 'alleles' in @mTypes
    @sortAsc = false if 'alleles' in @mTypes

    @filtered_category = null
    @filtered_subcategory = null

    @metaMap = {
      'name' : 'Gene Name'
      'uniquename': 'Unique Name'
      'alleles': 'Number of Alleles'
      'category': 'Category'
      'subcategory' : 'Sub Category'
    }

    for k,o of @geneList
      o.visible = true
      o.selected = false
      # Set up categories categories
      cats = []
      subcats = []
      catCount = 0
      for cat, subs of o.cats
        catCount++
        cats.push(" <span class='category-superscript  help-block'>[#{catCount}]</span> " + @_capitaliseFirstLetter(@categories[cat].parent_name) + "<br/>")
        subcats.push(@_capitaliseFirstLetter(@categories[cat].subcategories[k].category_name) + " <span class='category-superscript help-block'>[#{catCount}]</span><br/>") for k in Object.keys(subs.subcats)
        o.category = cats.join("")
        o.subcategory = subcats.join("")

    @filtered_geneList = @geneList
    
    @_appendGeneTable()
    @_appendCategories()

  # FUNC typeIsArray
  # A safer way to check if variable is array
  #
  # USAGE typeIsArray variable
  # 
  # RETURNS
  # boolean 
  #    
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  # FUNC _appendGeneTable
  # Appends genes to form. Only attaches
  # genes where object.visible = true
  #
  # RETURNS
  # boolean
  #    
  _appendGeneTable: () ->
    if @tableElem.length
      @tableElem.empty()

    table = @tableElem
    tableElem = jQuery("<table />").appendTo(table)

    style = 'select' if @multi_select
    style = 'redirect' unless @multi_select

    tableHtml = ''
    tableHtml += @_appendHeader()
    tableHtml += '<tbody>'
    tableHtml += @_appendGenes(@_sort(Object.keys(@geneList), @sortField, @sortAsc), @geneList, @geneType, style)
    tableHtml += '</tbody>'

    tableElem.append(tableHtml)
    @_actions(tableElem, style)

    true

  # FUNC _appendCategories
  # Appends categores to form.
  # 
  # RETURNS
  # boolean
  #
  _appendCategories: () ->
    categoryE = @categoriesElem
    introDiv = jQuery('<div class="gene-category-intro"></div>').appendTo(categoryE)
    introDiv.append('<span>Select category to refine list of genes:</span>')
    
    resetButt = jQuery("<button id='#{@geneType}-reset-category' class='btn btn-link'>Reset</button>").appendTo(introDiv)
    resetButt.click( (e) =>
      e.preventDefault()
      @_filterByCategory(-1,-1)
      @_resetNullCategories()
    )
    
    for k,o of @categories
      
      row1 = jQuery('<div class="row"></div>').appendTo(categoryE)
      cTitle = @_capitaliseFirstLetter(o.parent_name)
      titleDiv = jQuery("<div class='category-header col-xs-12'>#{cTitle}: </div>").appendTo(row1)
      
      if o.parent_definition?
        moreInfoId = 'category-info-'+k
        moreInfo = jQuery("<a id='#{moreInfoId}' href='#' data-toggle='tooltip' data-original-title='#{o.parent_definition}'><i class='fa fa-info-circle'></i></a>")
        titleDiv.append(moreInfo)
        moreInfo.tooltip({ placement: 'right' })
      
      row2 = jQuery('<div class="row"></div>').appendTo(categoryE)
      col2 = jQuery('<div class="col-xs-12"></div>').appendTo(row2)
      sel = jQuery("<select name='#{@geneType}-category' data-category-id='#{k}' class='form-control' placeholder='--Select a category--'></select>").appendTo(col2)

      options = []

      for s,t of o.subcategories
        def = ""
        def = t.category_definition if t.category_definition?
        name = @_capitaliseFirstLetter(t.category_name)
        id = "subcategory-id-#{s}"
        def.replace(/\.n/g, ". &#13;");
        options.push({id : "#{id}", value: "#{s}", title: "#{def}", name: "#{name}", parent: "#{k}"})

      sel.selectize(
        {
          searchField: ['name']
          options: options
          render: {
            option: (data, escape) =>
              return "<div class='option' title='#{data.title}'>#{data.name} <span class='badge'>#{@categories[data.parent].subcategories[data.value].gene_ids.length} genes</span></div>"
            item: (data, escape) =>
              return "<div class='item'>#{data.name}</div>"
          }
        }
      )
      
      that = @
      sel.change( ->
        selects = jQuery("select[name='#{that.geneType}-category']")
        obj = jQuery(@)
        catId = obj.data('category-id')
        subId = obj.val()
        
        if subId isnt "" or null  
          for sel in selects
            selectized = sel.selectize
            selectized.clear() if selectized.getValue() isnt subId
          
          @.selectize.getItem(subId)
          that._filterByCategory(catId, subId)

        if subId is "" or null
          that._filterByCategory(-1,-1)
      )
      
    true

  # FUNC _appendHeader
  # Helper method for _appendGeneTable method
  #
  _appendHeader: () ->
    table = '<thead><tr>'
    values = []
    i = -1

    if @sortField is 'name'
      sortIcon = 'fa-sort-asc'
      sortIcon = 'fa-sort-desc' unless @sortAsc
      values[++i] = {type:'name', name:'Gene Name', sortIcon:sortIcon}
    else
      values[++i] = {type:'name', name:'Gene Name', sortIcon:'fa-sort'}

    # Meta fields   
    for t in @mTypes
      tName = @metaMap[t]
      sortIcon = null
      
      if t is @sortField
        sortIcon = 'fa-sort-asc'
        sortIcon = 'fa-sort-desc' unless @sortAsc
        
      else
        sortIcon = 'fa-sort'
      
      values[++i] = { type: t, name: tName, sortIcon: sortIcon}

    table += @_template('th', v) for v in values

    table += '</thead></tr>'

    table

  # FUNC _appendGenes
  # Helper method for _appendGeneTable method
  #
  _appendGenes: (visibleG, genes, type, style) ->
    table = ''

    for gId in visibleG

      row = ''

      geneObj = genes[gId]

      name = geneObj.name

      continue unless geneObj.visible

      if style is 'redirect'
        #Links
        row += @_template('td1_redirect', {klass: 'gene_table_item', g: gId, name: name, type: type})

      else if style = "select"
        checked = ''
        checked = 'checked' if geneObj.selected
        row += @_template('td1_select', {klass: 'gene_table_item', g: gId, name: name, type: type, checked:checked})

      else
        return false

      # There are multiple categories present
      for d in @mTypes
        switch d
          when 'category' 
            if @filtered_category isnt null
              mData = @filtered_category
            else
              mData = geneObj[d]
          when 'subcategory'
            if @filtered_subcategory isnt null
              mData = @filtered_subcategory
            else
              mData = geneObj[d]
          else 
            mData = geneObj[d]
        
        row += @_template('td', {data: mData})

      table += @_template('tr', {row: row})

    table

  # FUNC _template
  # Helper method for _appendGeneTable method
  #
  _template: (tmpl, values) ->
    html = null
    if tmpl is 'tr'
      html = "<tr>#{values.row}</tr>"
      
    else if tmpl is 'th'
      html = "<th><a class='genome-table-sort' href='#' data-genomesort='#{values.type}'>#{values.name} <i class='fa #{values.sortIcon}'></i></a></th>"
    
    else if tmpl is 'td'
      html = "<td>#{values.data}</td>"
    
    else if tmpl is 'td1_redirect'
      html = "<td class='#{values.klass}'>#{values.name} <a class='gene-table-link' href='/superphy/genes/info?#{values.type}=#{values.g}' data-gene='#{values.g}' title='#{values.name} info'><i class='fa fa-search'></i></a></td>"
        
    else if tmpl is 'td1_select'
      html = "<td class='#{values.klass}'><div class='checkbox'><label><input class='checkbox gene-table-checkbox gene-search-select' type='checkbox' value='#{values.g}' #{values.checked} name='#{values.type}-gene'/> #{values.name}</label> <a class='gene-table-link' href='/superphy/genes/info?#{values.type}=#{values.g}' data-gene='#{values.g}' title='#{values.name} info'><i class='fa fa-search'></i></a></div></td>"
    
    else
      throw new SuperphyError "Unknown template type #{tmpl} in TableView method _template"
      
    html

  # FUNC _actions
  # Helper method for _appendGeneTable method
  #
  _actions: (tableEl, style) ->
    # Header sort
    that = @
    tableEl.find('.genome-table-sort').click (e) ->
      e.preventDefault()
      sortField = @.dataset.genomesort
      that._genesort(sortField)

  # FUNC _genesort
  # Private method to perform table sort on column
  #
  # PARAMS
  # field[str]: Sort column
  # 
  # RETURNS
  # boolean 
  #      
  _genesort: (field) ->
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

    #Update the table      
    @_appendGeneTable()     

  # FUNC _sort
  # Sort genes by meta-data 
  #
  # PARAMS
  # gids        - a list of gene ids
  # metaField   - a data field to sort on
  #
  # RETURNS
  # string
  #      
  _sort: (gids, metaField, asc) ->
    return gids unless gids.length
   
    that = @
    gids.sort (a,b) ->
      aObj = that.geneList[a]
      bObj = that.geneList[b]
    
      aField = aObj[metaField]
      aName = aObj.name.toString().toLowerCase()
      bField = bObj[metaField]
      bName = bObj.name.toString().toLowerCase()
      
      if aField? and bField?
        
        if typeIsArray aField
          aField = aField.join('').toLowerCase()
          bField = bField.join('').toLowerCase()
        else
          aField = aField.toString().toLowerCase()
          bField = bField.toString().toLowerCase()
          
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

  # FUNC _filterByCategory
  # Find genes belong to category and
  # append to list
  #
  # USAGE _filterByCategory int int
  # if catId == -1, reset of visible is performed
  # 
  # RETURNS
  # boolean
  #    
  _filterByCategory: (catId, subcatId) ->

    geneIds = []
    if catId is -1
      geneIds = Object.keys(@geneList)
      @filtered_category = null
      @filtered_subcategory = null
      @filtered_geneList = @geneList
      
    else
      @filtered_geneList = {}
      geneIds.push(id) for id in @categories[catId].subcategories[subcatId].gene_ids when @geneList[id]?
      throw new Error("Invalid category or subcategory ID: #{catId} / #{subcatId}.") unless geneIds? and typeIsArray geneIds
      o.visible = false for k,o of @geneList
      @filtered_category = @_capitaliseFirstLetter(@categories[catId].parent_name)
      @filtered_subcategory = @_capitaliseFirstLetter(@categories[catId].subcategories[subcatId].category_name)

    for g in geneIds
      o = @geneList[g]
      throw new Error("Invalid gene ID: #{g}.") unless o?
      o.visible = true
      @filtered_geneList[g] = o
      
    #Table
    @tableElem.empty()
    @_appendGeneTable()
    
    true

  # FUNC _resetNullCategories
  # Reset category drop downs back to null values. Triggered
  # when clicking reset button
  #
  # RETURNS
  # boolean
  #    
  _resetNullCategories: () ->
    el = @categoriesElem
    name = "#{@geneType}-category"
    select = el.find("select[name='#{name}']")
    sel.selectize.clear() for sel in select
    true
    
  # FUNC _capitaliseFirstLetter
  # Its obvious
  #
  # USAGE _capitaliseFirstLetter string
  # 
  # RETURNS
  # string
  # 
  _capitaliseFirstLetter: (str) -> 
    str[0].toUpperCase() + str[1..-1]

# Return instance of GenesList
unless root.GenesList
  root.GenesList = GenesList

class GenesSearch extends GenesList
  constructor: (@geneList, @geneType, @categories, @tableElem, @selectedElem, @countElem, @categoriesElem, @autocompleteElem, @selectAllEl, @unselectAllEl, @mTypes, @multi_select=false) ->
    super(@geneList, @geneType, @categories, @tableElem, @categoriesElem, @mTypes, @multi_select)

    @num_selected = 0

    jQuery(@autocompleteElem).keyup( () => 
      @_filterGeneList() 
    )

    jQuery(@selectAllEl).click((e) => 
      e.preventDefault()
      @_selectAllGenes(true); 
    )

    jQuery(@unselectAllEl).click((e) => 
      e.preventDefault()
      @_selectAllGenes(false); 
    )
  
  # FUNC _appendGeneTable overrides GenesList
  #
  # PARAMS
  #
  # RETURNS
  # boolean
  #        
  _appendGeneTable: () ->
    super
    table = @tableElem
    name = "#{@geneType}-gene"

    cboxes = table.find("input[name='#{name}']")
    that = @
    cboxes.change( ->
      obj = $(@)
      geneId = obj.val()
      checked = obj.prop('checked')
      console.log checked
      that._selectGene([geneId], checked)
    )

    @_updateCount()
    true  

  # FUNC _filterGeneList
  # Find genes that match filter and
  # append to list
  # 
  # RETURNS
  # boolean
  #    
  _filterGeneList: () ->
    searchTerm = @autocompleteElem.val()
    
    @_matching(@geneList, searchTerm)
    
    #Table
    @tableElem.empty()

    @_appendGeneTable()
    
    true

  # FUNC _matching
  # Find genes that match filter search word
  #
  # USAGE _matching object_array, string
  # 
  # RETURNS
  # boolean
  #    
  _matching: (gList, searchTerm) ->
    regex = new RegExp @escapeRegExp(searchTerm), "i"
      
    for k,g of gList
      continue unless @filtered_geneList[k]
      val = g.name
      
      if regex.test val
        g.visible = true
        #console.log val+' passed'
        
      else
        g.visible = false

        #console.log val+' failed'
    
    true
  
  # FUNC _selectGene
  # Update data object and elements for checked / unchecked genes
  #
  # USAGE _selectGene array, boolean
  # 
  # RETURNS
  # boolean
  #    
  _selectGene: (geneIds, checked) ->
    console.log geneIds
    console.log checked
    
    for g in geneIds
      @geneList[g].selected = checked
    
      if checked
        @num_selected++
      else
        @num_selected--
    
    @_updateCount()
     
    if checked
      @_addSelectedGenes(geneIds)
      
    else
      @_removeSelectedGenes(geneIds)
      
    true

  # FUNC _updateCount
  # Update displayed # of genes selected
  #
  # RETURNS
  # boolean
  #    
  _updateCount: () ->
    # Stick in inner span
    innerElem = @countElem.find('span.selected-gene-count-text')
    unless innerElem.length
      innerElem = jQuery("<span class='selected-gene-count-text'></span>").appendTo(@countElem)
      
    if @geneType is 'vf'
      innerElem.text("#{@num_selected} virulence genes selected")
          
    if @geneType is 'amr'
      innerElem.text("#{@num_selected} AMR genes selected")
        
    true

  # FUNC _addSelectedGenes
  # Add genes to selected box element
  # 
  # USAGE _addSelectedGenes array
  #
  # RETURNS
  # boolean
  #    
  _addSelectedGenes: (geneIds) ->
    cls = 'selected-gene-item'
    for g in geneIds
      
      gObj = @geneList[g]
      
      listEl = jQuery("<li class='#{cls}'>"+gObj.name+' - '+gObj.uniquename+'</li>')
      actionEl = jQuery("<a href='#' data-gene='#{g}'> <i class='fa fa-times'></a>")
        
      # Set behaviour
      that = @
      actionEl.click (e) ->
        e.preventDefault()
        gid = @.dataset.gene
        that._selectGene([gid], false)
        $("input.gene-search-select[value='#{gid}']").prop('checked',false)
        
      # Append to list
      listEl.append(actionEl)
      @selectedElem.append(listEl)
    
    true

  # FUNC _removeSelectedGenes
  # Remove genes from selected box element
  # 
  # USAGE _removeSelectedGenes array
  #
  # RETURNS
  # boolean
  #    
  _removeSelectedGenes: (geneIds) ->
    
    for g in geneIds
      listEl = @selectedElem.find("li > a[data-gene='#{g}']")
      listEl.parent().remove()
      
    true
  
  # FUNC _selectAllGenes
  # Select all visible genes
  #
  # USAGE _selectAllGenes boolean
  #
  # if checked==true, 
  #   select all visible genes
  # if checked==false,
  #   unselect all genes 
  #
  # RETURNS
  # boolean
  #    
  _selectAllGenes: (checked) ->
    
    if checked
      visible = (k for k,g of @geneList when g.visible && !g.selected)
      @_selectGene(visible, true)
      $("input.gene-search-select[value='#{g}']").prop('checked',true) for g in visible
    else
      all = (k for k,g of @geneList when g.selected)
      @_selectGene(all, false)
      $("input.gene-search-select[value='#{g}']").prop('checked',false) for g in all
    
    true

  # FUNC prepareGenesQuery
  # (Public)
  # Prepares form for sumbission by
  # dynamically building form with hidden input params
  #
  # RETURNS
  # boolean
  #    
  prepareGenesQuery: (form) ->
    # Append genes
    for k,g of @geneList when g.selected
      input = jQuery('<input></input>')
      input.attr('type','hidden')
      input.attr('name', 'gene')
      input.val(k)
      form.append(input)
    true
    
  # FUNC escapeRegExp
  # Hides RegExp characters in a search string
  #
  # USAGE escapeRegExp str
  # 
  # RETURNS
  # string 
  #    
  escapeRegExp: (str) -> str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")

  _filterByCategory: (catId, subcatId) ->
    @autocompleteElem.val("")
    super

# Return instance of GenesSearch
unless root.GenesSearch
  root.GenesSearch = GenesSearch
