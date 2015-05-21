###


 File: genes_search.coffee
 Desc: Javascript functions for the genes/search page
 Author: Matt Whiteside matthew.whiteside@phac-aspc.gc.ca
 Date: May 16th, 2013
 
 
###

root = exports ? this

# Globals
root.numVfSelected = 0
root.numAmrSelected = 0


# FUNC initGeneList
# initialises several variables for vf/amr object list
#
# USAGE initGeneList object_array
# 
# RETURNS
# Object containing jQuery DOM elements and data object array
#    
root.initGeneList = (gList, geneType, categories, tableElem, selElem, countElem, catElem, autocElem, multi_select=true) ->
  
  throw new Error("Invalid geneType parameter: #{geneType}.") unless geneType is 'vf' or geneType is 'amr'
  
  for k,o of gList
    o.visible = true
    o.selected = false
    
  dObj = {
    type: geneType
    genes: gList
    categories: categories
    num_selected: 0
    sortField: 'name'
    sortAsc: true
    element: {
      table: tableElem
      select: selElem
      count: countElem
      category: catElem
      autocomplete: autocElem
    }
    multi_select: multi_select
  }

# FUNC appendGeneTable
# Appends genes to form. Only attaches
# genes where object.visible = true
#
# USAGE appendGeneList data_object
#
# RETURNS
# boolean
#    
root.appendGeneTable = (d) ->
  table = d.element.table
  name = "#{d.type}-gene"
  tableElem = jQuery("<table />").appendTo(table)

  tableHtml = ''
  tableHtml += appendHeader(d)
  tableHtml += '<tbody>'
  tableHtml += appendGenes(d, sort(d.genes, d.sortField, d.sortAsc), d.genes, d.type, 'select')
  tableHtml += '</tbody>'

  tableElem.append(tableHtml)

  cboxes = table.find("input[name='#{name}']")
  cboxes.change( ->
    obj = $(@)
    geneId = obj.val()
    checked = obj.prop('checked')
    selectGene([geneId], checked, d)
  )
  
  updateCount(d)
  
  true

# FUNC sort
# Sort genomes by meta-data 
#
# PARAMS
# gids        - a list of genome labels ala: private_/public_123445
# metaField   - a data field to sort on
#
# RETURNS
# string
#      
sort = (gids, metaField, asc) ->
  #TODO: Get this working
  ###  return gids unless gids.length
 
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
    gids.reverse()###
    
  gids


template = (tmpl, values) ->
    
  html = null
  if tmpl is 'tr'
    html = "<tr>#{values.row}</tr>"
    
  else if tmpl is 'th'
    html = "<th><a class='genome-table-sort' href='#' data-genomesort='#{values.type}'>#{values.name} <i class='fa #{values.sortIcon}'></i></a></th>"
  
  else if tmpl is 'td'
    html = "<td>#{values.data}</td>"
  
  else if tmpl is 'td1_redirect'
    html = "<td class='#{values.klass}'>#{values.name} <a class='gene-table-link' href='/superphy/genes/info?#{values.type}=#{values.g}' data-gene='#{values.g}' title='#{values.name} info'><i class='fa fa-external-link'></i></a></td>"
      
  else if tmpl is 'td1_select'
    html = "<td class='#{values.klass}'><div class='checkbox'><label><input class='checkbox gene-table-checkbox gene-search-select' type='checkbox' value='#{values.g}' #{values.checked} name='#{values.type}-gene'/> #{values.name}</label> <a class='gene-table-link' href='/superphy/genes/info?#{values.type}=#{values.g}' data-gene='#{values.g}' title='#{values.name} info'><i class='fa fa-search'></i></a></div></td>"
  
  else
    throw new SuperphyError "Unknown template type #{tmpl} in TableView method _template"
    
  html


appendHeader = (d) ->  
  table = '<thead><tr>'
  values = []
  i = -1

  if d.sortField is 'name'
    sortIcon = 'fa-sort-asc'
    sortIcon = 'fa-sort-desc' unless d.sortAsc
    values[++i] = {type:'name', name:'Gene Name', sortIcon:sortIcon}
  else
    values[++i] = {type:'name', name:'Gene Name', sortIcon:'fa-sort'}

  values[++i] = {type:'uniquename', name:'Unique Name', sortIcon:'fa-sort'}

  table += template('th', v) for v in values

  table += '</thead></tr>'

  table

appendGenes = (d, visibleG, genes, type, style) ->

  table = ''

  for gId, gObj of visibleG

    row = ''

    geneObj = genes[gId]

    name = geneObj.name
    uniquename = geneObj.uniquename

    continue unless geneObj.visible

    if style is 'redirect'
      #Links
      row += template('td1_redirect', {klass: 'gene_table_item', name: name, type: type})

    else if style = "select"
      checked = ''
      checked = 'checked' if geneObj.selected
      row += template('td1_select', {klass: 'gene_table_item', g: gId, name: name, type: type, checked:checked})

    else
      return false

    row += template('td', {data: uniquename})
    table += template('tr', {row: row})

  table
      
# FUNC filterGeneList
# Find genes that match filter and
# append to list
#
# USAGE appendGeneList data_object
# 
# RETURNS
# boolean
#    
root.filterGeneList = (d) ->
  #DONE
  searchTerm = d.element.autocomplete.val()
  
  matching(d.genes, searchTerm)
  
  #Table
  d.element.table.empty()

  appendGeneTable(d)
  
  true
        

# FUNC matching
# Find genes that match filter search word
#
# USAGE matching object_array, string
# 
# RETURNS
# boolean
#    
root.matching = (gList, searchTerm) ->
  #DONE
  regex = new RegExp escapeRegExp(searchTerm), "i"
  
  for k,g of gList
    
    val = g.name
    
    if regex.test val
      g.visible = true
      #console.log val+' passed'
      
    else
      g.visible = false
      #console.log val+' failed'
  
  true

# FUNC appendCategories
# Appends categores to form.
#
# USAGE appendGeneList data_object
# 
# RETURNS
# boolean
#
root.appendCategories = (d) ->
  #DONE
  categoryE = d.element.category
  introDiv = jQuery('<div class="gene-category-intro"></div>').appendTo(categoryE)
  introDiv.append('<span>Select category to refine list of genes:</span>')
  
  resetButt = jQuery("<button id='#{d.type}-reset-category' class='btn btn-link'>Reset</button>").appendTo(introDiv)
  resetButt.click( (e) ->
    e.preventDefault()
    filterByCategory(-1,-1,d)
    resetNullCategories(d)
  )
  
  for k,o of d.categories
    
    row1 = jQuery('<div class="row"></div>').appendTo(categoryE)
    cTitle = capitaliseFirstLetter(o.parent_name)
    titleDiv = jQuery("<div class='category-header col-xs-12'>#{cTitle}: </div>").appendTo(row1)
    
    if o.parent_definition?
      moreInfoId = 'category-info-'+k
      moreInfo = jQuery("<a id='#{moreInfoId}' href='#' data-toggle='tooltip' data-original-title='#{o.parent_definition}'><i class='fa fa-info-circle'></i></a>")
      titleDiv.append(moreInfo)
      moreInfo.tooltip({ placement: 'right' })
    
    row2 = jQuery('<div class="row"></div>').appendTo(categoryE)
    col2 = jQuery('<div class="col-xs-12"></div>').appendTo(row2)
    sel = jQuery("<select name='#{d.type}-category' data-category-id='#{k}' class='form-control'></select>").appendTo(col2)
    
    for s,t of o.subcategories
      def = ""
      def = t.category_definition if t.category_definition?
      name = capitaliseFirstLetter(t.category_name)
      id = "subcategory-id-#{s}"
      def.replace(/\.n/g, ". &#13;");
      sel.append("<option id='#{id}' value='#{s}' title='#{def}'>#{name}</option>")
      
    sel.append("<option value='null' selected><strong>--Select Category--</strong></option>")
    
    sel.change( ->
      obj = jQuery(@)
      catId = obj.data('category-id')
      subId = obj.val()
      
      if subId isnt 'null'
        jQuery("select[name='#{d.type}-category'][data-category-id!='#{catId}']").val('null')
        filterByCategory(catId, subId, d)
        
    )
    
  true
  
# FUNC filterByCategory
# Find genes belong to category and
# append to list
#
# USAGE filterByCategory int int data_object
# if catId == -1, reset of visible is performed
# 
# RETURNS
# boolean
#    
root.filterByCategory = (catId, subcatId, d) ->
  #DONE
  geneIds = []
  if catId is -1
    geneIds = Object.keys(d.genes)
    
  else
    geneIds = d.categories[catId].subcategories[subcatId].gene_ids
    throw new Error("Invalid category or subcategory ID: #{catId} / #{subcatId}.") unless geneIds? and typeIsArray geneIds
    o.visible = false for k,o of d.genes
  
  for g in geneIds
    o = d.genes[g]
    throw new Error("Invalid gene ID: #{g}.") unless o?
    o.visible = true
    
  #Table
  d.element.table.empty()
  console.log d
  appendGeneTable(d)
  
  true
  
# FUNC selectGene
# Update data object and elements for checked / unchecked genes\
#
# USAGE selectGene array, boolean, data_object
# 
# RETURNS
# boolean
#    
root.selectGene = (geneIds, checked, d) ->
  #DONE
  console.log geneIds
  console.log checked
  
  for g in geneIds
    d.genes[g].selected = checked
  
    if checked
      d.num_selected++
    else
      d.num_selected--
  
  updateCount(d)
   
  if checked
    addSelectedGenes(geneIds, d)
    
  else
    removeSelectedGenes(geneIds, d)
    
  true

# FUNC updateCount
# Update displayed # of genes selected
# 
# USAGE updateCount data_object
#
# RETURNS
# boolean
#    
root.updateCount = (d) ->
  #DONE
  # Stick in inner span
  innerElem = d.element.count.find('span.selected-gene-count-text')
  unless innerElem.length
    innerElem = jQuery("<span class='selected-gene-count-text'></span>").appendTo(d.element.count)
    
  if d.type is 'vf'
    innerElem.text("#{d.num_selected} virulence genes selected")
        
  if d.type is 'amr'
    innerElem.text("#{d.num_selected} AMR genes selected")
      
  true

# FUNC addSelectedGenes
# Add genes to selected box element
# 
# USAGE addSelectedGenes array data_object
#
# RETURNS
# boolean
#    
root.addSelectedGenes = (geneIds, d) ->
  #DONE
  cls = 'selected-gene-item'
  for g in geneIds
    
    gObj = d.genes[g]
    
    listEl = jQuery("<li class='#{cls}'>"+gObj.name+' - '+gObj.uniquename+'</li>')
    actionEl = jQuery("<a href='#' data-gene='#{g}'> <i class='fa fa-times'></a>")
      
    # Set behaviour
    actionEl.click (e) ->
      e.preventDefault()
      gid = @.dataset.gene
      selectGene([gid], false, d)
      $("input.gene-search-select[value='#{gid}']").prop('checked',false)
      
    # Append to list
    listEl.append(actionEl)
    d.element.select.append(listEl)
  
      
  true 

# FUNC removeSelectedGenes
# Remove genes from selected box element
# 
# USAGE removeSelectedGenes array data_object
#
# RETURNS
# boolean
#    
root.removeSelectedGenes = (geneIds, d) ->
  
  for g in geneIds
    listEl = d.element.select.find("li > a[data-gene='#{g}']")
    listEl.parent().remove()
    
  true
  
# FUNC selectAllGenes
# Select all visible genes
#
# USAGE selectAllGenes boolean, d
#
# if checked==true, 
#   select all visible genes
# if checked==false,
#   unselect all genes 
#
# RETURNS
# boolean
#    
root.selectAllGenes = (checked, d) ->
  
  if checked
    visible = (k for k,g of d.genes when g.visible && !g.selected)
    selectGene(visible, true, d)
    $("input.gene-search-select[value='#{g}']").prop('checked',true) for g in visible
  else
    all = (k for k,g of d.genes when g.selected)
    selectGene(all, false, d)
    $("input.gene-search-select[value='#{g}']").prop('checked',false) for g in all
  
  true
  
# FUNC submitGeneQuery
# Submit by dynamically building form with hidden
# input params
# 
# USAGE submitGeneQuery data_object data_object viewController
#
# RETURNS
# boolean
#    
root.submitGeneQuery = (vfData, amrData, viewController) ->
  
  form = jQuery('<form></form')
  form.attr('method', 'POST')
  form.attr('action', viewController.action)
  
  # Append genome params
  viewController.submitGenomes(form, 'selected')
  
  # Append VF genes
  for k,g of vfData.genes when g.selected
    input = jQuery('<input></input>')
    input.attr('type','hidden')
    input.attr('name', 'gene')
    input.val(k)
    form.append(input)
      
  for k,g of amrData.genes when g.selected
    input = jQuery('<input></input>')
    input.attr('type','hidden')
    input.attr('name', 'gene')
    input.val(k)
    form.append(input)
      
  jQuery('body').append(form)
  form.submit()
      
  true
  
# FUNC resetNullCategories
# Reset category drop downs back to null values. Triggered
# when clicking reset button
# 
# USAGE resetNullCategories data_object
#
# RETURNS
# boolean
#    
root.resetNullCategories = (d) ->
  el = d.element.category
  name = "#{d.type}-category"
  el.find("select[name='#{name}']").val('null')
  
  true
  
  
# FUNC capitaliseFirstLetter
# Its obvious <- haha
#
# USAGE capitaliseFirstLetter string
# 
# RETURNS
# string
# 
root.capitaliseFirstLetter = (str) -> 
  str[0].toUpperCase() + str[1..-1]
  
  
# FUNC escapeRegExp
# Hides RegExp characters in a search string
#
# USAGE escapeRegExp str
# 
# RETURNS
# string 
#    
root.escapeRegExp = (str) -> str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")

# FUNC typeIsArray
# A safer way to check if variable is array
#
# USAGE typeIsArray variable
# 
# RETURNS
# boolean 
#    
root.typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'



      
