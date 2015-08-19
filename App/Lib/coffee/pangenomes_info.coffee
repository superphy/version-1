###


 File: pangenomes_info.coffee
 Desc: Javascript functions for the genes/info page
 Author: Matt Whiteside matthew.whiteside@phac-aspc.gc.ca
 Date: Aug 8th, 2015
 
 
###

root = exports ? this

# FUNC retrievePgAlignment
# Ajax call to download pangenome alignment
# Creates views for MSA on success
#
# USAGE retrievePgAlignment regionID, locusController
# 
# RETURNS
# boolean
#    
retrievePgAlignment = (regionID, locusData) ->

  # Kill ongoing AJAX request sent by this
  # method
  if alignmentRequest
    alignmentRequest.abort()
    
  # Prepare params
  serializedParams = {'region': regionID}

  # Fire off the request
  console.log 'Sending gene alignment request'
  alignmentRequest = jQuery.ajax({
    url: "/superphy/pangenomes/sequences"
    type: "post"
    data: serializedParams
  })
  

  # Callback handler that will be called on success
  alignmentRequest.done( (data, textStatus, jqXHR) -> 
    parentDiv = jQuery('#pangenome-info-msa')
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
  
unless root.retrievePgAlignment
  root.retrievePgAlignment = retrievePgAlignment
  
# GLOBAL alignmentRequest
# jQuery object handler for Ajax call
#
# Prevents multiple requests being simultaneously sent
# from page

alignmentRequest = null

unless root.alignmentRequest
  root.alignmentRequest = alignmentRequest
    

  

  
