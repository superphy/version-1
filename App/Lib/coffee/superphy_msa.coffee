###


 File: superphy_msa.coffee
 Desc: Multiple Sequence Alignment View Class
 Author: Matt Whiteside matthew.whiteside@phac-aspc.gc.ca
 Date: April 9th, 2013
 
 
###
 
###
 CLASS MsaView
  
 Multiple Sequence Alignment view
 
 Always locus-based
 Returns nothing to redirect/select (no click behavior defined)

###

class MsaView extends ViewTemplate
  constructor: (@parentElem, @style, @elNum, msaArgs) ->
    
    throw new SuperphyError 'Missing argument. MsaView constructor requires JSON alignment object.' unless msaArgs.length > 0
    
    alignmentJSON = msaArgs[0]
    
    # Additional data to append to node names
    # Keys are genome|locus IDs
    @locusData = null
    if msaArgs[1]?
      @locusData = msaArgs[1]
      
    # Call default constructor - creates unique element ID                  
    super(@parentElem, @style, @elNum)
    
    # Format alignment object into rows of even length
    @_formatAlignment(alignmentJSON)
  
  type: 'msa'
  
  elName: 'genome_msa'
  
  blockLen: 70
  
  nameLen: 25
  
  consLine: 'conservation_line'
  
  posLine: 'position_line'
  
  nuclClasses: { 'A': 'nuclA', 'G': 'nuclG', 'C': 'nuclC', 'T':'nuclT', '*': 'consM', ' ':'consMM', '-':'nuclGAP'}
  
  cssClass: 'msa_row_name'
  
  maxRows: 26
  minRows: 0

  hasLocation: true


  # FUNC _formatAlignment
  # Splits alignment strings into even-length
  # rows. Called once in constructor since
  # alignments do not change during lifetime of
  # of view. Stores final alignment in @alignment
  #
  # PARAMS
  # none
  # 
  # RETURNS
  # boolean 
  #      
  _formatAlignment: (alignmentJSON) ->
 
    # Loci in alignment
    @rowIDs = (g for g of alignmentJSON)
   
    if alignmentJSON[@rowIDs[0]].hasOwnProperty('contig_name')
      @hasLocation = true
    else 
      @hasLocation = false
   
    # Initialise the alignment data
    seqLen = alignmentJSON[@rowIDs[0]]['seq'].length
    @alignment = {};
    for n in @rowIDs
      
      @alignment[n] = {
        'alignment': [],
        'seq': alignmentJSON[n]['seq']
        'genome': alignmentJSON[n]['genome']
        'locus': alignmentJSON[n]['locus'],
        'location': false
      }

      if @hasLocation
        loc = alignmentJSON[n]['start_pos'] + ".." + alignmentJSON[n]['end_pos']
        if alignmentJSON[n]['strand'] == -1
          loc = "complement(#{loc})"
        loc = alignmentJSON[n]['contig_name'] + "[#{loc}]"
        @alignment[n]['location'] = loc

      
    @alignment[@consLine] = { 'alignment': [] }
    @alignment[@posLine] = { 'alignment': [] }
    
    @numBlock = 0
    for j in [0..seqLen] by @blockLen
      @numBlock++
      for n in @rowIDs
        seq = alignmentJSON[n]['seq']
        @alignment[n]['alignment'].push(@_formatBlock(seq.substr(j,@blockLen)))
     
      # Position Line
      pos = j+1
      posElem = "<td class='msaPosition'>#{pos}</td>"
      @alignment[@posLine]['alignment'].push(posElem)
       
    true
    
  _formatBlock: (seq) ->
    html = '';
    seq.toUpperCase()
    
    for c in [0..seq.length-1]
      chr = seq.charAt(c)
      cls = @nuclClasses[chr]
      html += "<td class='#{cls}'>#{chr}</td>"
    
    html
  
  # FUNC update
  # Update MSA view
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  # 
  
  update: (genomes) ->
    
    # create or find MSA table
    msaElem = jQuery("##{@elID}")
    if msaElem.length
      msaElem.empty()
      msaElem.append('<tbody></tbody>')
    else      
      msaElem = jQuery("<table id='#{@elID}'><tbody></tbody></table>")
      jQuery(@parentElem).append(msaElem)
   
    # append alignment rows to table
    t1 = new Date()
    
    # obtain current names and sort
    @_appendRows(msaElem, genomes)
    
    t2 = new Date()
    
    ft = t2-t1
    console.log('MsaView update elapsed time: '+ft)
   
    true # return success
    

  _appendRows: (el, genomes) ->
    
    genomeElem = {}
    visibleRows = []
    tmp = {}
    newLine = '&#013;'
    
    # Find number of active rows
    # Compute current genome name
    for i in @rowIDs
      a = @alignment[i]
      genomeID = a['genome']
      g = genomes.genome(genomeID)
      
      if g.visible
        
        visibleRows.push i
        
        # MSA row name
        name = g.viewname
        
        # Append locus data
        if @locusData?
          name += @locusData.locusString(i)
          
        tmp[i] = name
        
        # Class data for row name
        thiscls = @cssClass
        thiscls = @cssClass+' '+g.cssClass if g.cssClass?
        
        nameCell = "<td class='#{thiscls}' data-genome='#{genomeID}' "
        if @hasLocation
          loc = a['location']
          nameCell += " data-location='#{loc}'" 
        nameCell += ">#{name}</td>";
        
        genomeElem[i] = nameCell
    
    n = visibleRows.length
    if n >= @maxRows
      el.html("<tr class='msa-info'><td>Multiple sequence alignment is displayed when number of visible rows is below #{@maxRows}.</td></tr>"+
        "<tr class='msa-info'><td>Current number of rows: #{n}</td></tr>"+
        "<tr class='msa-info'><td>To view, either download alignment or use the filter to reduce visible genomes.</td></tr>"
      )
      
    else if n <= @minRows
      el.html("<tr class='msa-info'><td>Multiple sequence alignment is displayed when number of visible rows is above #{@minRows}.</td></tr>"+
        "<tr class='msa-info'><td>Current number of rows: #{n}</td></tr>"
      )
    
    else
      # Build and Attach MSA
        
      # Sort alphabetically
      visibleRows.sort (a,b) ->
        aname = tmp[a]
        bname = tmp[b]
        if aname > bname then 1 else if aname < bname then -1 else 0
      
      # Compute conservation line for this set
      matches = @cigarLine(visibleRows)
      
      # Spit out each block row
      rows = ''
      for j in [0...@numBlock]
        
        consArray = @alignment[visibleRows[0]]['alignment'][j].split('')
        console.log consArray.length
        
        for i in visibleRows
          row = '<tr>'
          row += genomeElem[i] + @alignment[i]['alignment'][j]
          row += '</tr>'
          rows += row
          
        # Add conservation row and position row
        row = '<tr>'
        row +='<td></td>'+matches[j]
        row += '</tr>'
        rows += row
       
        # Add position row
        row = '<tr>'
        row += @alignment[@posLine]['alignment'][j]
        row += '</tr>'
        rows += row
      
      el.append(rows)

      jQuery("td.#{thiscls}").tooltip({
        'placement': 'top'
        'title': ()->
          elem = jQuery(this)

          popup = elem.text();
          popup += "\n\nlocation: " + elem.attr('data-location') if elem.attr('data-location')?

          return popup
      })
        
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
    msaEl = jQuery("##{@elID}")
    throw new SuperphyError "DOM element for Msa view #{@elID} not found. Cannot call MsaView method updateCSS()." unless msaEl? and msaEl.length
    
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
     
      # Find element
      descriptor = "td[data-genome='#{g}']"
      itemEl = el.find(descriptor)
      
      unless itemEl? and itemEl.length
        throw new SuperphyError "Msa element for genome #{g} not found in MsaView #{@elID}"
        return false
      
      console.log("Updating class to #{thiscls}")
      liEl = itemEl.parents().eq(1)
      liEl.attr('class', thiscls)
     
    true # success
  
  # FUNC select
  # No function in a MSA, always returns true
  #
  # RETURNS
  # boolean 
  #        
  select: (genome, isSelected) ->
    
    true # success
  
  # FUNC dump
  # Generate fasta file of visible sequences in MSA
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
    
    # Get the sequences and headers
    output = ''
    
    for i in @rowIDs
      a = @alignment[i]
      genomeID = a['genome']
      g = genomes.genome(genomeID)
      
      if g.visible
        
        # Fasta header
        name = g.viewname
        
        if @locusData? && @locusData[i]?
          name += @locusData[i]

        # Location
        name += ' location='+a['location'] if @hasLocation;
          
        # Fasta sequence
        seq = a['seq']
        output += ">#{name}\n#{seq}\n"
        
        
    return {
      ext: 'fasta'
      type: 'text/plain'
      data: output 
    }
    
  # FUNC cigarLine
  # Generate a basic cigar line for current visible alignment
  #
  #   Format: match -> '*' and mismatch -> ' '.
  #
  # PARAMS
  #   visibleRows: array of visible row IDs
  #
  # RETURNS
  #   array-ref containing array of block-length strings
  #   representing html-formatted cigar line
  #      
  cigarLine: (visibleRows)->
  
    # Find mismatches
    consL = @alignment[visibleRows[0]]["seq"].split('')
    l = consL.length - 1
    
    for r in visibleRows.slice(1)
      seq = @alignment[r]["seq"]
      for i in [0..l]
        c = consL[i]
        if c != '$'
          consL[i] = '$' if c != seq[i]
          
    # Change symbols
    final = ''
    for c in consL
      if c == '$'
        final += ' '
      else
        final += '*'
      
    # Chop into blocks and add html
    consArray = []
    for j in [0..l] by @blockLen
      consArray.push(@_formatBlock(final.substr(j,@blockLen)))
     
    consArray
   
  
    
  
    
  
      
  
  
    
    
  