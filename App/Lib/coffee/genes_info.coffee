###


 File: genes_info.coffee
 Desc: Javascript functions for the genes/info page
 Author: Matt Whiteside matthew.whiteside@phac-aspc.gc.ca
 Date: May 27th, 2013
 
 
###

root = exports ? this

# FUNC categoryView
# Creates category view for a single gene
#
# USAGE categories category_JSON, jQuery_DOM_element
# 
# RETURNS
# nothing
#    
categoryView = (categoryObj, el) ->

  html = '<div class="gene-info-category-wrapper">'
  
  topHtml = _categoryHtml(categoryObj.top, true)
  html += "<div class='top-category'>#{topHtml}</div>"
  midHtml = _categoryHtml(categoryObj.category)
  html += "<div class='middle-category'>#{midHtml}</div>"
  genHtml = _categoryHtml(categoryObj.gene)
  html += "<div class='gene-category'>#{genHtml}</div>"
    
  wrapEl = jQuery(html).appendTo(el)

unless root.categoryView
  root.categoryView = categoryView
  
_categoryHtml = (catObj, top=false) ->
  
  header = catObj.name[0].toUpperCase() + catObj.name[1..-1]
  
  html = "<h5><i class='fa fa-chevron-right'></i> #{header}</h5>"
    
  if catObj.definition
    html += "<p>#{catObj.definition}</p>"
    
  html
  

# FUNC retrieveGeneAlignment
# Ajax call to download gene alignment
# Creates views for MSA on success
#
# USAGE retrieveAlignment geneID, locusController
# 
# RETURNS
# boolean
#    
retrieveGeneAlignment = (geneID, locusData) ->

  # Kill ongoing AJAX request sent by this
  # method
  if alignmentRequest
    alignmentRequest.abort()
    
  # Prepare params
  serializedParams = {'gene': geneID}

  # Fire off the request
  console.log 'Sending gene alignment request'
  alignmentRequest = jQuery.ajax({
    url: "/superphy/genes/sequences"
    type: "post"
    data: serializedParams
  })
  

  # Callback handler that will be called on success
  alignmentRequest.done( (data, textStatus, jqXHR) -> 
    parentDiv = jQuery('#gene-info-msa')
    parentDiv.empty()
    
    viewController.createView('msa', parentDiv, data, locusData);
  )

  # Callback handler that will be called on failure
  alignmentRequest.fail( (jqXHR, textStatus, errorThrown) -> 
    console.error(
      "Error! AJAX retrieval of gene alignment failed: #{textStatus},  #{errorThrown}."
    )
    jQuery('#msa_download_inprogress').html('<div class="alert alert-danger">'+
      '<p style="text-align:center">Retrieval of gene alignment encountered error.</p>')
  )
  
  true
  
unless root.retrieveGeneAlignment
  root.retrieveGeneAlignment = retrieveGeneAlignment
  
# GLOBAL alignmentRequest
# jQuery object handler for Ajax call
#
# Prevents multiple requests being simultaneously sent
# from page

alignmentRequest = null

unless root.alignmentRequest
  root.alignmentRequest = alignmentRequest
    

  

  
