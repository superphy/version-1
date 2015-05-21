###


 File: superphy_matrix.coffee
 Desc: Genome x Gene table showing # of alleles
 Author: Matt Whiteside matthew.whiteside@phac-aspc.gc.ca
 Date: April 24th, 2013
 
 
###
 
###
 CLASS MatrixView
  
 Gene Allele Matrix view
 
 Always genome based
 Links to individual genes

###

class MatrixView extends ViewTemplate
  constructor: (@parentElem, @style, @elNum, genomes, matrixArgs) ->
    
    throw new SuperphyError 'Missing argument. MatrixView constructor requires GenomeController object.' unless genomes?
    throw new SuperphyError 'Missing argument. MatrixView constructor requires JSON object containing: nodes, links.' unless matrixArgs.length > 0
    
    tmp = matrixArgs[0]
    genes = tmp['nodes']
    alleles = tmp['links']
    gList = Object.keys(genomes.public_genomes).concat Object.keys(genomes.private_genomes)
    nList = Object.keys(genes)
    
    # Base maximum matrix size on input (no filtering)
    # Actual matrix may only fill part of the svg viewport
    @cellWidth = 20
    @margin = {top: 150, right: 0, bottom: 0, left: 250}
    @height = gList.length * @cellWidth
    @width = nList.length * @cellWidth
    @dim = {
      w: @width + @margin.right + @margin.left
      h: @height + @margin.top + @margin.bottom
    }
    
    # Call default constructor - creates unique element ID                  
    super(@parentElem, @style, @elNum)
    
    # Create matrix objects
    # Defines @matrix, @geneNodes, @genomeNodes
    @_computeMatrix(gList, genes, alleles)
    
    # Precompute ordering for genes which are stable
    # genomes can be removed through filtering
    @geneOrders = {
      name: d3.range(@nGenes).sort (a, b) =>
          d3.ascending(@geneNodes[a].name, @geneNodes[b].name)
        
      count: d3.range(@nGenes).sort (a, b) =>
          @geneNodes[b].count - @geneNodes[a].count
    }
    @geneOrders['group'] = @geneOrders['count']
    @orderType = 'name' # Start with alphabetical ordering
    
    # Set color opacity based on num of alleles
    # Above 4 alleles full saturation is reached
    @z = d3.scale.linear().domain([0, 4]).clamp(true)
    # Create gene mapping
    @x = d3.scale.ordinal().rangeBands([0, @width])
    
    @cssClass = 'superphy-matrix'
    @parentElem.append("<div id='#{@elID}' class='#{@cssClass}'></div>")
    
    # Create sort drop down
    ddDiv = jQuery('<div class="matrixSort"><span>Order:</span> </div>').appendTo("##{@elID}")
    dd = jQuery('<select name="matrix-sort">' +
        '<option value="name" selected="selected"> by Name</option>' +
        '<option value="count"> by Frequency</option>' +
        '<option value="group"> by Group</option>' +
        '</select>').appendTo(ddDiv)
    
    num = @elNum - 1     
    dd.change( ->
      sortType = @.value
      viewController.viewAction(num, 'matrix_sort', sortType) 
    )
    
    # Setup and attach SVG viewport
    @wrap = d3.select("##{@elID}")
      .append("div")
        .attr("class", "matrix-container")
      .append("svg")
        .attr("width", @dim.w)
        .attr("height", @dim.h)
    
    # Parent element for attaching matrix elements
    @canvas = @wrap.append("g")
      .attr("transform", "translate(" + @margin.left + "," + @margin.top + ")")
      
    # Background
    @canvas.append("rect")
      .attr("class", "matrixBackground")
      .attr("width", @width)
      .attr("height", @height)
      
    @formatCount = d3.format(",.0f")
    
    # Add jQuery dialog for clicked matrix elements
    dialog = jQuery('#dialog-matrix-row-select')
    unless dialog.length
     
      dialog = jQuery('<div id="dialog-matrix-row-select"></div>').appendTo('body')
      dialog
        .text( "Jump to genome information page?" )
        .dialog({
          title: 'Genome Information',
          autoOpen: false,
          resizable: false,
          height:160,
          modal: true,
          buttons: {
            Yes: ->
              id = jQuery( @ ).data("row-id")
              window.location.href = "/superphy/strains/info?genome=#{id}"
              jQuery( @ ).dialog( "close" )
            Cancel: ->
              jQuery( @ ).dialog( "close" )
          }
        })
        
    dialog2 = jQuery('#dialog-matrix-col-select')
    unless dialog2.length
     
      dialog2 = jQuery('<div id="dialog-matrix-col-select"></div>').appendTo('body')
      dialog2
        .text( "Jump to gene page?" )
        .dialog({
          title: 'Detailed Gene Information',
          autoOpen: false,
          resizable: false,
          height:160,
          modal: true,
          buttons: {
            Yes: ->
              id = jQuery( @ ).data("col-id")
              window.location.href = "/superphy/genes/info?gene=#{id}"
              jQuery( @ ).dialog( "close" )
            Cancel: ->
              jQuery( @ ).dialog( "close" )
          }
        })

    true
  
  type: 'matrix'
  
  elName: 'genome_matrix'
  
  duration: 500
   
  # FUNC _computeMatrix
  # build matrix data from input
  #
  # PARAMS
  # 1) List of genomeIDs
  # 2) Object of gene IDs => gene names
  # 3) Object of allele IDs for each genome and gene (e.g. genome => gene => array of allele IDs) 
  # 
  # RETURNS
  # boolean 
  #       
  _computeMatrix: (gList, genes, alleles) ->
     
    nList = Object.keys(genes)
    @nGenomes = gList.length
    @nGenes = nList.length
     
    # Genome nodes
    @genomeNodes = []
    @matrix = []
    i = 0
    for g in gList
      gObj = {
        id: i
        genome: g
        count: 0
      }
      @genomeNodes.push gObj
      @matrix[i] = d3.range(@nGenes).map (j) -> 
        {x: j, y: i, z: 0, i:null} 
      i++
      
    # Gene nodes
    @geneNodes = []
    
    i = 0
    for g in nList
      gObj = {
        id: i
        gene: g
        name: genes[g]
        count: 0
      }
      @geneNodes.push gObj
      i++
      
    # Cell values
    i = 0
    for g in @genomeNodes
      for n in @geneNodes
         
        # Count alleles for genome/gene pair
        numAlleles = 0
        if alleles[g.genome]? and alleles[g.genome][n.gene]?
          numAlleles = alleles[g.genome][n.gene].length
           
        g.count += numAlleles
        n.count += numAlleles
           
        @matrix[g.id][n.id].z = numAlleles
        @matrix[g.id][n.id].i = i
        
        i++
         
    true
         
     
    
  # FUNC update
  # Update genome tree view
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  #      
  update: (genomes) ->
    
    t1 = new Date()
    
    # Sync internal objects to current genome settings
    @_sync(genomes)
    
    # Recompute matrix dimensions
    @height = @cellWidth * @currN
    
    # Recompute domain
    @y = d3.scale.ordinal().rangeBands([0, @height])
    @y.domain(@genomeOrders[@orderType])
    @x.domain(@geneOrders[@orderType])
    
    # Shrink background
    @canvas.selectAll(".matrixBackground")
      .attr("height", @height);
      
    # Attach genome rows
    svgGenomes = @canvas.selectAll("g.matrixrow")
      .data(@currNodes, (d) -> d.id)
      
    # Update existing genome row's text, classes, style etc
    svgGenomes
        .attr("class", (d) => @_classList(d))
      .select("text.matrixlabel")
        .text((d) -> d.viewname )
      
    svgGenomes
      .selectAll("g.matrixcell title")
        .text((d) -> d.title )
      
    # Insert new rows at origin
    that = @
    newRows = svgGenomes.enter().append("g")
      .attr("class", (d) => @_classList(d))
      .attr("transform", (d, i) -> "translate(0,0)")
      .each((d) -> that._row(@, that.matrix[d.id], that.x, that.y, that.z))
    
    newRows.append("line")
      .attr("x2", @width)
      
    newRows.append("text")
      .attr("class","matrixlabel")
      .attr("x", -6)
      .attr("y", @y.rangeBand() / 2)
      .attr("dy", ".32em")
      .attr("text-anchor", "end")
      .text((d) -> d.viewname)
      .on("click", (d) ->
        jQuery('#dialog-matrix-row-select')
          .data('row-id', d.genome)
          .dialog('open')
      )   
      
    # Attach gene columns
    svgGenes = @canvas.selectAll("g.matrixcolumn")
      .data(@geneNodes, (d) -> d.id)
      
    # Shrink existing lines
    svgGenes.selectAll("line")
      .attr("x1", -@height)
      
    # Insert new columns at origin
    newCols = svgGenes.enter().append("g")
      .attr("class", "matrixcolumn")
      .attr("transform", (d, i) -> "translate(" + 0 + ")rotate(-90)" )

    newCols.append("line")
      .attr("x1", -@height)

    newCols.append("text")
      .attr("class","matrixlabel")
      .attr("x", 6)
      .attr("y", @y.rangeBand() / 2)
      .attr("dy", ".32em")
      .attr("text-anchor", "start")
      .text((d) -> d.name)
      .on("click", (d) ->
        jQuery('#dialog-matrix-col-select')
          .data('col-id', d.gene)
          .dialog('open')
      )   
      
    # Move new and existing rows to final position
    @_assumePositions()
    
    # Transition exiting rows to origin
    genomesExit = svgGenomes.exit().transition()
      .duration(@duration)
      .attr("transform", (d) -> "translate(0,0)")
      .remove()

    t2 = new Date()
    dt = new Date(t2-t1)
    console.log('MatrixView update elapsed time (s): '+dt.getMilliseconds())
    
    true # return success
    
 
  _sync: (genomes) ->
     
    # Compute current visible matrix columns
    @currNodes = []
    @currN = 0
    
    for n in @genomeNodes
      
      g = genomes.genome(n.genome)
      
      if g.visible
        # Record column object
        n.viewname = g.viewname
        n.selected = (g.isSelected? and g.isSelected)
        # Need default group assignment to compute order
        if g.assignedGroup?
          n.assignedGroup = g.assignedGroup
        else
          n.assignedGroup = 0
        
        n.index = @currN       
        @currNodes.push n
        @currN++
    
        # Update matrix cells
        i = 0
        for c in @matrix[n.id]
          c.title = "genome: #{n.viewname}, gene: #{@geneNodes[i].name}"
          i++
            
        
    # Compute new ordering
    @genomeOrders = {
      name: d3.range(@currN).sort (a, b) =>
        d3.ascending(@currNodes[a].viewname, @currNodes[b].viewname)
        
      count: d3.range(@currN).sort (a, b) =>
        @currNodes[b].count - @currNodes[a].count
          
      group: d3.range(@currN).sort (a, b) =>
        gdiff = @currNodes[b].assignedGroup - @currNodes[a].assignedGroup
        if gdiff == 0
          return @currNodes[b].count - @currNodes[a].count
        else
          return gdiff
    }
    
    true
    
  _row: (svgRow, rowData, x, y, z) ->
    
    # Grab row cells
    svgCells = d3.select(svgRow).selectAll(".matrixcell")
      .data(rowData, (d) -> d.i)
      
    # Insert new cells
    num = @elNum-1
    
    newCells = svgCells.enter().append("g")
      .attr("class", "matrixcell")
      .attr("transform", (d, i) =>
          "translate(" + @x(d.x) + ",0)")
      .on("mouseover", (p) => @_mouseover(p))
      .on("mouseout", @_mouseout)
        
    newCells.append("rect")
      .attr("x", 0)
      .attr("width", x.rangeBand())
      .attr("height", y.rangeBand())
      .style("fill-opacity", (d) -> z(d.z))
      
    newCells.append("text")
      .attr("dy", ".32em")
      .attr("y", x.rangeBand() / 2)
      .attr("x", x.rangeBand() / 2)
      .attr("text-anchor", "middle")
      .text( (d) => 
        if d.z > 0
          @formatCount(d.z)
        else
          '' 
      )
      
    newCells.append("title")
      .text( (d) -> d.title )
    
    true
    
  _assumePositions: ->
    
    that = @
    transit = @canvas.transition().duration(@duration)
    #transit = @canvas.transition().
    
    transit.selectAll(".matrixrow")
        #.delay((d, i) -> that.y(d.index) * 4)
        .attr("transform", (d, i) ->
          "translate(0," + that.y(d.index) + ")")
      .selectAll(".matrixcell")
        #.delay((d) -> that.x(d.x) * 4)
        .attr("x", (d) -> that.x(d.x))
        .attr("transform", (d, i) =>
          "translate(" + that.x(d.x) + ",0)")

    transit.selectAll(".matrixcolumn")
        #.delay((d, i) -> that.x(i) * 4)
        .attr("transform", (d, i) -> "translate(" + that.x(i) + ")rotate(-90)")
        
    true
    
  _mouseover: (p) ->
    d3.selectAll(".matrixrow text").classed("matrixActive", (d, i) -> d.index == p.y)
    d3.selectAll(".matrixcolumn text").classed("matrixActive", (d, i) -> i == p.x)
      
  
  _mouseout: ->
    d3.selectAll("text").classed("matrixActive", false)
    
  
  _classList: (d) ->
    clsList  = ['matrixrow'];
    clsList.push("selectedRow") if d.selected
    clsList.push("groupedRow#{d.assignedGroup}") if d.assignedGroup?
    
    clsList.join(' ')
    
  # FUNC viewAction
  # For top-level, global commands in TreeView that require
  # the genomeController as input the viewAction in viewController.
  # This method will call the desired method in the TreeView class
  #
  # PARAMS
  # event[string]: the type of event
  # eArgs[array]: argument array passed to event method
  # 
  # RETURNS
  # boolean 
  #      
  viewAction: (genomes, argArray) ->
    
    event = argArray.shift()
    
    if event is 'matrix_sort'
      @orderType = argArray[0];
      
      throw new SuperphyError "Unrecognized order type: #{@orderType} in MatrixView viewAction method." unless @orderType in Object.keys(@geneOrders)
      @update(genomes)
      
    else
      throw new SuperphyError "Unrecognized event type: #{event} in MatrixView viewAction method."
    
    true
    
  # FUNC dump
  # Generate a tab-delimited text table of gene counts
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
    
    rows = []
    
    # Print header
    row = []
    row.push "#"
    row.push n.name for n in @geneNodes
    rows.push row.join("\t")
    
    # Print rows
    for g in @currNodes
      row = []
      row.push g.viewname
      
      for n in @geneNodes 
        numAlleles = @matrix[g.id][n.id].z
        row.push numAlleles
      
      rows.push row.join("\t")
       
    return {
      ext: 'csv'
      type: 'text/plain'
      data: rows.join("\n") 
    }
  
  # FUNC updateCSS
  # Change CSS class for all genomes to match underlying genome properties
  #
  # PARAMS
  # simple hash object with private and public list of genome Ids to update
  # genomeController object
  # 
  # RETURNS
  # boolean 
  #      
  updateCSS: (gset, genomes) ->
  
    # Retrieve genome objects for each in gset
    genomeList = {}
    if gset.public?
      
      for g in gset.public
        genomeList[g] = genomes.public_genomes[g]
        
    if gset.private?
      
      for g in gset.private
        genomeList[g] = genomes.private_genomes[g]
        
        
    svgNodes = @canvas.selectAll("g.matrixrow")
    
    # Filter elements to those that are in set
    svgNodes.filter((d) -> genomeList[d.genome]?)
      .attr("class", (d) =>
        g = genomeList[d.genome]
        d.viewname = g.viewname
        d.selected = (g.isSelected? and g.isSelected)
        # Need default group assignment to compute order
        if g.assignedGroup?
          d.assignedGroup = g.assignedGroup
        else
          d.assignedGroup = 0
          
        # Set classes
        @_classList(d)
      )
      
      
  
    true
    
  # FUNC select
  # No function in a MSA, always returns true
  #
  # RETURNS
  # boolean 
  #        
  select: (genome, isSelected) ->
    
    true # success
    
 