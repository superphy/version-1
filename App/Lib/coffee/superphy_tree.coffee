###


 File: superphy_tree.coffee
 Desc: Phylogenetic Tree View Class
 Author: Matt Whiteside matthew.whiteside@phac-aspc.gc.ca
 Date: March 20th, 2013
 
 
###
 
# Add D3 method to move node to top
d3.selection.prototype.moveToFront = ->
  @.each( -> @.parentNode.appendChild(@) )

###
 CLASS TreeView
  
 Phylogenetic tree view
 
 Can be genome- or locus-based
 Returns genome ID to redirect/select if leaf node is clicked
 
###

class TreeView extends ViewTemplate
  constructor: (@parentElem, @style, @elNum, @genomes, treeArgs) ->
    
    throw new SuperphyError 'Missing argument. TreeView constructor requires JSON tree object.' unless treeArgs.length > 0
    @root = @trueRoot = treeArgs[0]
    
    # Tracks changes in underlying visible genome set
    @currentGenomeSet = -1;
    
    @dim={w: 700, h: 800}
    @margin={top: 20, right: 180, bottom: 20, left: 20}
    @locusData = treeArgs[1] if treeArgs[1]?
    @dim = treeArgs[2] if treeArgs[2]?
    @margin = treeArgs[3] if treeArgs[3]?
                  
    # Call default constructor - creates unique element ID                  
    super(@parentElem, @style, @elNum)
    
    # Setup and attach SVG viewport
    
    # Dimensions
    @width = @dim.w - @margin.right - @margin.left
    @height = @dim.h - @margin.top - @margin.bottom
    @xzoom = d3.scale.linear().domain([0, @width]).range([0, @width])
    @yzoom = d3.scale.linear().domain([0, @height]).range([0, @height])

    @leafCounter = 0

    # Tree layout rendering object
    @cluster = d3.layout.cluster()
      .size([@width, @height])
      .sort(null)
      .value((d) -> Number(d.length) )
      .separation((a, b) =>
        @leafCounter += 1
        a_height = 1
        b_height = 1
        if a._children? && visible_bars > 1
          a_height = visible_bars
        else a_height = 2
        if b._children? && visible_bars > 1
          b_height = visible_bars
        else b_height = 2
        a_height + b_height)

    # Append tree commands
    legendID = "tree_legend#{@elNum}"
    @_treeOps(@parentElem, legendID)
    
    # SVG layer
    jQuery("<div id='#{@elID}' class='#{@cssClass()}'></div>").appendTo(@parentElem)
    @wrap = d3.select("##{@elID}").append("svg")
      .attr("width", @dim.w)
      .attr("height", @dim.h)
      .style("-webkit-backface-visibility", "hidden")
    
    # Scale bar
    @scalePos = {x: 10, y: 10}
    @scaleBar = @wrap.append("g")
      .attr("transform", "translate("+@scalePos.x+","+@scalePos.y+")")
      .attr("class", "scalebar")
    
    # Parent element for attaching tree elements
    @canvas = @wrap.append("g")
      .attr("transform", "translate(" + @margin.left + "," + @margin.top + ")")

    @windowX = @margin.top

    @windowY = @margin.left

    # Build viewport
    num = @elNum - 1;
    @zoom = d3.behavior.zoom()
        .x(@xzoom)
        .y(@yzoom)
        .scaleExtent([1,8]).on("zoom", -> viewController.getView(num).zoomed())
        
    @wrap.call(
      @zoom
    )
    
    # Scale bar
    @scaleBar.append('line')
      .attr('x1',0)
      .attr('y1',0)
      .attr('x2',1)
      .attr('y2',0)
      
    @scaleBar.append('text')
      .attr("dx", "0")
      .attr("dy", "1em")
      .attr("text-anchor", "start")

    
    # Legend SVG
    
    jQuery("<div id='#{legendID}' class='genome_tree_legend'></div>").appendTo(@parentElem)
    @wrap2 = d3.select("##{legendID}").append("svg")
      .attr("width", @dim.w)
      .attr("height", 120)
      .style("-webkit-backface-visibility", "hidden")
    
    @legend = @wrap2.append("g")
      .attr("transform", "translate(" + 5 + "," + 5 + ")")
    
    @_legend(@legend)  
    
    # Attach a clade dialog
    if @style is 'select'
      dialog = jQuery('#dialog-clade-select')
      unless dialog.length
        dialog = jQuery('<div id="dialog-clade-select"></div>').appendTo('body')
        dialog
          .text("Select/unselect genomes in clade:")
          .dialog({
            #title: 'Select clade',
            dialogClass: 'noTitleStuff',
            autoOpen: false,
            resizable: false,
            height: 120,
            modal: true,
            buttons: {
              Select: ->
                node = jQuery( @ ).data("clade-node")
                viewController.getView(num).selectClade(node, true)
                if viewController.views[2].constructor.name is 'SummaryView'
                  summary = viewController.views[2]
                  summary.afterSelect(true)
                jQuery( @ ).dialog( "close" )
              Unselect: ->
                node = jQuery( @ ).data("clade-node")
                viewController.getView(num).selectClade(node, false)
                if viewController.views[2].constructor.name is 'SummaryView'
                  summary = viewController.views[2]
                  summary.afterSelect(false)
                jQuery( @ ).dialog( "close" )
              Cancel: ->
                jQuery( @ ).dialog( "close" )
            }
          })

   
    # Keep track of metadata currently visible in tree
    # So we don't need to do work when meta-data doesn't change
    @treeMeta = {}
    for t in @genomes.mtypesDisplayed
      @treeMeta[t] = @genomes.visibleMeta[t]

    # Determine value order for each meta-data type
    @metaBins = @genomes.metaOrder()

    @allGenomes = (Object.keys(@genomes.public_genomes)).concat(Object.keys(@genomes.private_genomes))
    @nodes = @cluster.nodes(@root)

    # Objects for popover tables
    # for n in @nodes
    #   n.tt_table_last = new String()
    #   n.tt_table = {}
    #   n.tt_table_partial = {}
    #   n.tt_sub_table = {}
    #   n.other_count = {}
    #   for m in @mtypesDisplayed
    #     n.tt_table_partial[m] = new String()
    #     n.tt_sub_table[m] = new String()
    #     n.tt_table[m] = new String()
    #     n.other_count[m] = 0

    # Add properties to tree nodes
    @_prepTree()

    true

  activeGroup: []

  rectBlock: ''
    
  type: 'tree'
  
  elName: 'genome_tree'
  
  nodeId: 0

  expandTracker: 0

  depths: []

  separationChange: true

  xStretcher: 1

  xStretch: false

  yStretcher: 1

  yStretch: false
  
  duration: 1000
  
  expandDepth: 9

  visible_bars = 0

  total_height = 0

  levelTracker: 0

  firstRun: true
  
  x_factor: 1.5
  y_factor: 5000

  colours = {
      'serotype' : [
        '#236932',
        '#468554',
        '#6AA276',
        '#8DBE98',
        '#B0DABA',
        '#D4F7DC',
        '#e9fbed'
      ]
      'isolation_host' : [
        '#a70209',
        '#b3262c',
        '#c04a4f',
        '#cc6e72',
        '#d99295',
        '#e5b6b8',
        '#f2dadb'
      ]
      'isolation_source' : [
        '#3741ae',
        '#535cb9',
        '#7077c5',
        '#8c92d0',
        '#a9addc',
        '#c5c8e7',
        '#e2e3f3'
      ]
      'syndrome' : [
        '#962ba6',
        '#a549b2',
        '#b467bf',
        '#c385cc',
        '#d2a4d8',
        '#e1c2e5',
        '#f0e0f2'
      ]
      'stx1_subtype' : [
        '#F05C00',
        '#EF7123',
        '#EE8746',
        '#ED9D69',
        '#ECB28C',
        '#EBC8AF',
        '#EADED2'
      ]
      'stx2_subtype' : [
        '#35a6a7',
        '#51b2b3',
        '#6ebfc0',
        '#8bcccc',
        '#a8d8d9',
        '#c5e5e5',
        '#e2f2f2'
      ]
    }

  # FUNC update
  # Update genome tree view
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  #      
  update: (genomes, sourceNode=null) ->

    # Runs only once.  Pre-selects "Isolation Host", "Serotype", and "Isolation Source" meta-data categories to appear in table and on tree.
    # Also relies on genome.visibleMeta object (changes in genomes.update())
    if @firstRun
      $('input[value="serotype"]').prop('checked', true)
      $('input[value="isolation_host"]').prop('checked', true)
      $('input[value="isolation_source"]').prop('checked', true)
      # @mtypesSelected.push('serotype') unless @mtypesSelected.indexOf('serotype') > -1
      # @mtypesSelected.push('isolation_host') unless @mtypesSelected.indexOf('isolation_host') > -1
      # @mtypesSelected.push('isolation_source') unless @mtypesSelected.indexOf('isolation_source') > -1
      
    @firstRun = false

    @leafCounter = 0

    # Does this update trigger a change in the metadata displayed?
    [meta_change, visible_bars] = @metaChange()

    t1 = new Date()
   
    # save old root, might require updating
    oldRoot = @root

    # for g in (genomes.pubVisible).concat(genomes.pvtVisible)
    #   genomes.genome(g).isSelected = false
    # for g in (genomes.selected().public).concat(genomes.selected().private)
    #   genomes.genome(g).isSelected = true

    # filter visible, set selected, set class, set viewname
    # changes @root object
    @_sync(genomes)

    @nodes = @cluster.nodes(@root)

    # find starting point to launch new nodes/links
    sourceNode = @root unless sourceNode?
    @launchPt = {x: sourceNode.x, y: sourceNode.y, x0: sourceNode.x0, y0: sourceNode.y0, oldX: sourceNode.oldX, oldY: sourceNode.oldY}
    
    # Needs to compute some starting values for the tree view
    # any time tree genome subset changes or is reset
    if @reformat
      @_scale()
      
      # Update scale bar
      targetLen = 30
      unit = targetLen / @branch_scale_factor_y
      unit = Math.round(unit * 10000) / 10000
      @scaleLength = unit * @branch_scale_factor_y
      @scaleBar.select('line')
        .attr('x1', 0)
        .attr('x2', @scaleLength)
        .attr('y1', 0)
        .attr('y2', 0)
      @scaleBar.select('text')
        .text("#{unit} branch length units")
        
      # Reset zoom if 'Reset' or 'Fit to window' tree ops are used
      @zoom.translate([0,0]).scale(1) if @reset or @fitToWindow
      @scaleBar.select("line")
        .attr('transform','scale(1,1)')
      @reformat = false

    # visible_bars multiplier allows for separation
    # @leafCounter keeps track of how many leaves there are on the tree
    # @separationChange is true when tree height is not to be fixed, false for "Fit to window" button
    for n in @nodes
      n.y = n.sum_length * @branch_scale_factor_y
      if @separationChange

        if visible_bars <= 1
          n.x = n.x * @branch_scale_factor_x * @leafCounter / 24
        if visible_bars > 1
          n.x = n.x * @branch_scale_factor_x * @leafCounter / 24 * ((visible_bars * 0.3) + 1)
          n.oldX = n.oldX * @branch_scale_factor_x * @leafCounter / 24 * ((visible_bars * 0.3) + 1)
      else
        n.x = n.x * @branch_scale_factor_x
      # For "X-stretch" and "Y-stretch" tree buttons (reversed)
      n.y = n.y * @xStretcher if @xStretch
      n.x = n.x * @yStretcher if @yStretch
      n.width = []
      n.xpos = 0

    # If tree clade expanded / collapsed
    # shift tree automatically to accommodate new values
    if @expansionContraction
      yedge = @width - 30 # subtract buffer
      ypos = @edgeNode.y
      if ypos > yedge
        yshift = ypos-yedge
        for n in @nodes
          n.y = n.y - yshift
          n.oldY = n.oldY - yshift
        
      @expansionContraction = false
      
    # Collect existing nodes and create needed new nodes
    svgNodes = @canvas.selectAll("g.treenode")
      .data(@nodes, (d) -> d.id )
 
    # Compute connector layout
    svgLinks = @canvas.selectAll("path.treelink")
      .data(@cluster.links(@nodes), (d) -> d.target.id )
      
    # Insert new connectors
    linksEnter = svgLinks.enter()
      .insert("path")
      .attr("class", "treelink")
      .attr("d", (d) =>
        p = {x: @launchPt.x0, y: @launchPt.y0, oldX: @launchPt.oldX, oldY: @launchPt.oldY}
        @_step({source: p, target: p})
      )
    
    # Ensures tree links translate correctly when preserving coordinates of nodes
    @canvas.selectAll("path.treelink").transition()
      .duration(@duration)
      .attr("d", (d) => @_zTranslate(d, @xzoom, @yzoom))

    # Transition exiting connectors to the parent nodes new position.
    svgLinks.exit().transition()
      .duration(@duration)
        .attr("d", (d) =>
          o = {x: @launchPt.x, y: @launchPt.y, oldX: @launchPt.oldX, oldY: @launchPt.oldY}
          @_step({source: o, target: o})
        )
        .remove()
        
    # Update existing node's text, classes, style and events
    # Only leaf nodes will change
    currLeaves = svgNodes.filter((d) -> d.leaf)
      .attr("class", (d) => @_classList(d))
      .on("click", (d) ->
        unless d.assignedGroup?
          viewController.select(d.genome, !d.selected)

          ## WHAT THE FUCK IS THIS
          if viewController.views[2].constructor.name is 'SummaryView'
            summary = viewController.views[2]
            summary.afterSelect(!d.selected)
          ##
        else
          null
      )
          
    currLeaves.select("circle")
      .style("fill", (d) => 
        if d.selected
          "lightsteelblue"
        else
          "#fff")
    
    # Update text if meta-labels
    # or filter changed them
    svgNodes.select("text")
      .text((d) ->
        if d.leaf
          d.viewname
        else
          d.label
      )
    
    # Hide text for internal nodes with expanded clades 
    svgNodes.filter((d) -> d.children && !d.leaf )
        .select("text")
          .transition()
          .duration(@duration)
          .style("fill-opacity", 1e-6)

    # Update meta bars

    # Insert nodes
    # Enter any new nodes at the parent's previous position.
    nodesEnter = svgNodes.enter()
      .append("g")
      .attr("class", (d) =>
        @_classList(d))
      .attr("id", (d) -> "treenode"+d.id )
      .attr("transform", (d) =>
        "translate(" + @launchPt.y0 + "," + @launchPt.x0 + ")")
      
    leaves = nodesEnter.filter( (d) -> d.leaf )

    leaves.append("rect")
      .attr('width', 11)
      .attr('height', 11)
      .attr('x', -5.5)
      .attr('y', -5.5)
      .style('opacity', (d) =>
        if @activeGroup.indexOf(d.name) > -1
          1
        else 0)
      .style('fill', (d) =>
        if @activeGroup.indexOf(d.name) > -1
          'steelblue'
        else '#fff')

    leaves.append("circle")
      .attr("r", 1e-6)
      .style("fill", (d) =>
        if d.selected
          "lightsteelblue"
        else
          "#fff")

    if @style is 'select'
      leaves.on("click", (d) ->
        unless d.assignedGroup?
          viewController.select(d.genome, !d.selected)
          ## AGAIN WHAT IS GOING ON HERE
          if viewController.views[2].constructor.name is 'SummaryView'
            summary = viewController.views[2]
            summary.afterSelect(!d.selected)
          ##
        else
          null
      )
    else
      leaves.on("click", (d) ->
        viewController.redirect(d.genome)
      )
    
    # # Adjusts tree label according to width of genomeMeter
    # nodesEnter
    #   .append("text")
    #   .attr("class","treelabel")
    #   .attr("x", (n) ->
    #     if n._children?
    #       (10 * (Math.log(n.num_leaves)) + Math.pow(Math.log(n.num_leaves), 2.5) + 10)
    #     else
    #       "0.6em")
    #   .attr("dy", ".4em")
    #   .attr("text-anchor", "start")
    #   .text((d) ->
    #     if d.leaf
    #       d.viewname
    #     else
    #       d.label
    #   )
    #   .style("fill-opacity", 1e-6)
  
    # Append command elements to new internal nodes
    iNodes = nodesEnter.filter((n) -> !n.leaf && !n.root )
    num = @elNum-1

    # # Removes duplicate groups and bars
    # svgNodes.select('g').remove()
    # svgNodes.select('rect.genomeMeter').remove()

    # @rectBlock = svgNodes.append('g')

    # # Appends genomeMeter.  Size of bar reflects number of genomes.
    # svgNodes
    #   .append('rect')
    #   .style("fill", "red")
    #   .style("stroke-width", 0.5)
    #   .style("stroke", "black")
    #   .attr("class", "genomeMeter")
    #   .attr("width", (n) ->
    #     if n._children? and !($(@).hasClass('genomeMeter'))
    #       (10 * (Math.log(n.num_leaves)) + Math.pow(Math.log(n.num_leaves), 2.5))
    #     else 0)
    #   .attr("height", 7)
    #   .attr("y", -3)
    #   .attr("x", 4)

    # # Adds colour boxes to metadata sidebar
    # $(document).ready ->
    #   $('input[name="meta-option"]').each (obj) ->
    #     $('#'+this.name+'_'+this.value).hide()
    #     if this.checked
    #       $('#'+this.name+'_'+this.value).show()

    # # Creates popover HTML content for a selected meta-category.
    # for m in @mtypesSelected
    #   @updatePopovers(m)

    # # Generates meta-data bars for each collapsed leaf
    # y = -5
    # centred = -1.5
    # for m in @mtypesDisplayed
    #   if genomes.visibleMeta[m]
    #     j = 0
    #     i = 0
    #     y += 7
    #     centred += -3.5
    #     if @metaOntology[m].length < 7
    #       bar_count = @metaOntology[m].length
    #     else bar_count = 7
    #     while i < bar_count
    #       @rectBlock
    #         .append("rect")
    #         .style("fill", colours[m][j++])
    #         .style("stroke-width", 0.5)
    #         .style("stroke", "black")
    #         .attr("class", (n) -> 
    #           if n._children?
    #             "metaMeter")
    #         .attr("id", (n) =>
    #           if n._children?
    #             if i == 6
    #               "Other"
    #             else @metaOntology[m][i])
    #         .attr("width", (n) =>
    #           if n._children?
    #             if n.metaCount[m][@metaOntology[m][i]]? && i < 6 && @metaOntology[m][i]?
    #               n.width[i] = ((10*(Math.log(n.num_leaves)) + Math.pow(Math.log(n.num_leaves), 2.5)) * (n.metaCount[m][@metaOntology[m][i]]) / n.num_leaves)
    #             else if i is 6 && @metaOntology[m][i]?
    #               n.width[i] = ((10*(Math.log(n.num_leaves)) + Math.pow(Math.log(n.num_leaves), 2.5)) - (n.width[0] + n.width[1] + n.width[2] + n.width[3] + n.width[4] + n.width[5]))
    #             else
    #               n.width[i] = 0
    #           if n.width[i] > 0
    #             n.width[i])
    #         .attr("height", (n) -> 
    #           if n._children?
    #             7)
    #         .attr("y", (n) -> 
    #           if n._children?
    #             y)
    #         .attr("x", (n) ->
    #           if n._children?
    #             if n.width[i-1]? && i > 0
    #               n.xpos += n.width[i-1]
    #             else n.xpos = 0
    #           n.xpos + 4)
    #         .attr("data-toggle", (n) -> 
    #           if n._children?
    #             "popover")
    #         .attr("data-content", (n) =>
    #           if n._children?
    #             length = 0
    #             pos = 0
    #             if @metaOntology[m][i]?
    #               pos = n.tt_table[m].indexOf(@metaOntology[m][i].charAt(0).toUpperCase() + @metaOntology[m][i].slice(1))
    #             if n.metaCount[m][@metaOntology[m][i]] > 0
    #               length = (@metaOntology[m][i] + "</td><td style='text-align:right'>" + n.metaCount[m][@metaOntology[m][i]]).length
    #               tt_data = n.tt_table[m].slice(0, pos - 8) + "<tr class='table-row-bold' style='color:" + colours[m][3] + "'><td>" + n.tt_table[m].slice(pos, length + pos) + "</td></tr>" + n.tt_table[m].slice(length + pos)
    #             if i is 6
    #               if n.width[i-1] is 0
    #                 if n.tt_table[m].indexOf("[+] Other")?
    #                   pos = n.tt_table[m].indexOf("[+] Other")
    #                 else pos = n.tt_table[m].indexOf(n.tt_table_last)
    #                 tt_data = n.tt_table[m].slice(0, pos - 8) + "<tr class='table-row-bold' style='color:" + colours[m][3] + "'><td>" + n.tt_table[m].slice(pos)
    #               else
    #                 tt_data = n.tt_table[m].slice(0, n.tt_table[m].indexOf("[+] Other") - 8) + "<tr class='table-row-bold' style='color:" + colours[m][3] + "'><td>" + n.tt_table[m].slice(n.tt_table[m].indexOf("[+] Other"))
    #           if n.width[i] > 0
    #             "<table class='popover-table'><tr><th style='min-width:160px;max-width:160px;text-align:left'>" + @tt_mtitle[m] + "</th><th style='min-width:110px;max-width:110px;text-align:right'># of Genomes</th></tr>" + tt_data + "</table>")
    #       i++

    # # Dismisses popover when mouse leaves both the metaMeter and the popover itself
    # (($) ->
    #   oldHide = $.fn.popover.Constructor::hide

    #   $.fn.popover.Constructor::hide = ->
    #     if @options.trigger == 'hover' and @tip().is(':hover')
    #       that = this
    #       setTimeout (->
    #         that.hide.call that, arguments
    #       ), that.options.delay.hide
    #       return
    #     oldHide.call this, arguments
    #     return

    #   return
    # ) jQuery

    # # Allows popovers to work in SVG
    # @rectBlock.selectAll('.metaMeter')
    #   .each(()->
    #     $(this).popover({
    #       placement: 'bottom',
    #       html: 'true',
    #       trigger: 'hover',
    #       delay: {show:500, hide:500},
    #       animate: 'false',
    #       container: 'body',
    #       }))

    # # Dismisses popovers on next click unless a new popover is opened
    # $('body').on('click', (e)->
    #   if ($(e.target).data('toggle') isnt 'popover' && $(e.target).parents('.popover.in').length is 0)
    #       $('[data-toggle="popover"]').popover('hide'))
    
    # # Removes duplicate bar groups
    # if ($('#treenode:has(g.v' + visible_bars + ')'))
    #   svgNodes.select('.v' + visible_bars).remove()

    # # Groups meta-bars in v + visible_bars class
    # @rectBlock.attr("class", 'v' + visible_bars) if visible_bars > 0
    
    # # Removes old meta-data bar groups after new ones are created
    # if visible_bars > 0
    #   if ($('.v' + (visible_bars - 1))[0])
    #     svgNodes.select('.v' + (visible_bars - 1)).remove()
    #   if ($('.v' + (visible_bars + 1))[0])
    #     svgNodes.select('.v' + (visible_bars + 1)).remove()
    #   svgNodes.selectAll('.v0').remove()
    # else svgNodes.selectAll('.v1').remove()

    # # Removes genome bars when meta-data is applied
    # svgNodes.selectAll('.genomeMeter').remove() if visible_bars > 0

    cmdBox = iNodes
      .append('text')
      .attr("class","treeicon expandcollapse")
      .attr("text-anchor", 'middle')
      .attr("y", 4)
      .attr("x", -8)
      .text((d) -> "\uf0fe")
  
    cmdBox.on("click", (d) -> 
      viewController.viewAction(num, 'expand_collapse', d, @.parentNode)
    )

    # # select/unselect clade
    # if @style is 'select'
      # # select
      # cladeIcons = iNodes
        # .append('text')
        # .attr("class","treeicon selectclade")
        # .attr("text-anchor", 'middle')
        # .attr("y", 4)
        # .attr("x", -20)
        # .text((d) -> "\uf058")
#         
      # cladeIcons.on("click", (d) ->
        # jQuery('#dialog-clade-select')
          # .data('clade-node', d)
          # .dialog('open')
      # )
 
     # select/unselect clade
    if @style is 'select'
      # select
      cladeSelect = iNodes
        .append('rect')
        .attr("class","selectClade")
        .attr("width", 8)
        .attr("height", 8)
        .attr("y", -4)
        .attr("x", -25)
        
      cladeSelect.on("click", (d) ->
        jQuery('#dialog-clade-select')
          .data('clade-node', d)
          .dialog('open')
      )
  
    # Transition out new nodes
    nodesUpdate = svgNodes.transition()
      .duration(@duration)
      .attr("transform", (d) =>
        if !isNaN(d.oldX) and !isNaN(d.oldY)
          "translate(" + d.oldY + "," + d.oldX + ")"
        else if @launchPt.oldX? and @launchPt.oldY?
          "translate(" + (@launchPt.oldY + (d.y - @launchPt.y0)) + "," + (@launchPt.oldX + (d.x - @launchPt.x0)) + ")"
        else
          "translate(" + d.y + "," + d.x + ")")

  
    nodesUpdate.select("circle")
      .attr("r", 4)

    nodesUpdate.selectAll("rect.genomeMeter")
      .attr("width", (n) ->
        if n._children?
          (10 * (Math.log(n.num_leaves)) + Math.pow(Math.log(n.num_leaves), 2.5))
        else 
          0)

    nodesUpdate.selectAll(".treelabel")
      .attr("x", (n) ->
        if n._children?
          (10 * (Math.log(n.num_leaves)) + Math.pow(Math.log(n.num_leaves), 2.5) + 10)
        else
          "0.6em")
      .attr("dy", ".4em")
      .attr("text-anchor", "start")
      .text((d) ->
        if d.leaf
          d.viewname
        else
          d.label
      )
      .style("fill-opacity", 1e-6)

    m = 1
    # while m < visible_bars + 1
    #   svgNodes.selectAll('.v' + m)
    #     .attr("transform", "translate(" + 0 + "," + centred + ")" )
    #   m++

    nodesUpdate.filter((d) -> !d.children )
      .select("text")
        .style("fill-opacity", 1)
    
    nodesUpdate.select(".expandcollapse")
      .text((d) ->
        if d._children? 
          "\uf0fe"
        else
          "\uf146"
      )

    # Ensures tree nodes translate correctly when preserving node coordinates
    @canvas.selectAll("g.treenode").transition()
      .duration(@duration)
      .attr("transform", (d) => @_zTransform(d, @xzoom, @yzoom))
    
    # Transition exiting nodes to the parent's new position.
    nodesExit = svgNodes.exit().transition()
      .duration(@duration)
      .attr("transform", (d) =>
        "translate(" + @launchPt.y + "," + @launchPt.x + ")")
      .remove()

    nodesExit.select("circle")
      .attr("r", 1e-6)
    
    nodesExit.select("text")
      .style("fill-opacity", 1e-6)
    
    nodesExit.select("rect")
      .attr("width", 1e-6)
      .attr("height",1e-6)

    # Reinsert previous root on top 
    # (when filter is applied the viewable tree can
    # have a root that does not match global tree root. 
    # When restoring the tree, the previous root 
    # has to be re-inserted after the branches, so it 
    # appears on top of branches
    if !oldRoot.root and @root != oldRoot
      # Need to redraw the command features
      id = oldRoot.id
      elID = "treenode#{id}"
      svgNode = @canvas.select("##{elID}")
      svgNode.moveToFront()
      
    
    # Stash old positions for transitions
    for n in @nodes
      n.x0 = n.x
      n.y0 = n.y
    
    t2 = new Date()
    dt = new Date(t2-t1)
    console.log('TreeView update elapsed time (sec): '+dt.getSeconds())

    @expandCollapse = false
    @reset = false
    @fitToWindow = false

    # groupedNodes = @findGroupedChildren(@activeGroup)
    # selectedNodes = @findGroupedChildren(genomes.selected().public.concat(genomes.selected().private))

    # if @activeGroup.length > 0
    #   for g in groupedNodes
    #     @_percolateSelected(g.parent, true)

    # for g in selectedNodes
    #   @_percolateSelected(g.parent, true)

    true # return success


  # FUNC metaChange
  # Determines if displayed metadata changed in this
  # update call. Updates treeMeta object to match 
  # current state.
  #
  # PARAMS
  # none
  # 
  # RETURNS
  # tuple:
  #   [0]: boolean indicating if metadata changed
  #   [1]: int number of metadata types
  # 
  metaChange: ->

    change = false
    sum = 0
    for m of @treeMeta
      
      if @treeMeta[m] != @genomes.visibleMeta[m]
        change = true
        @treeMeta[m] = @genomes.visibleMeta[m]

      if @treeMeta[m]
        sum++


    return [change, sum]


  # FUNC findGroupedChildren
  # Finds all grouped genome nodes
  #
  # PARAMS
  # groupList array
  # 
  # RETURNS
  # groupedNodes array 
  # 
  findGroupedChildren: (groupList) ->

    groupedNodes = []
    for g in groupList
      n = @_findLeaf(g)
      groupedNodes.push n
          
    groupedNodes

  # FUNC resetInternalNodes
  # Sets num_selected and internal_node_selected properties of all nodes to 0.
  #
  # PARAMS
  # Node object
  # 
  # RETURNS
  # boolean 
  # 
  resetInternalNodes: (node) ->

    return true unless node?

    node.num_selected = 0
    node.internal_node_selected = 0

    @resetInternalNodes(node.parent)

    true

  # FUNC updateActiveGroup
  # Update active group for highlighting on tree
  #
  # PARAMS
  # UserGroup object
  # 
  # RETURNS
  # boolean 
  # 
  updateActiveGroup: (usrGrp) ->

    @groupInstance = true

    # List of names of active group genomes
    @activeGroup = (usrGrp.active_group.public_list).concat(usrGrp.active_group.private_list)

    svgNodes = @canvas.selectAll("g.treenode")

    leafNodes = svgNodes.filter((d) -> d.leaf)

    for g in @allGenomes
      n = @_findLeaf(g)
      @resetInternalNodes(n)
      if @activeGroup.indexOf(g) > -1
        n.activeGroup = true
        n.selected = true
      else
        n.activeGroup = false
        n.selected = false

    # List of active group genome nodes
    groupedNodes = @findGroupedChildren(@activeGroup)

    for g in groupedNodes
      @_percolateSelected(g.parent, true)

    svgNodes.attr("class", (d) =>
      @_classList(d))

    # Adds rectangle around node circle (group symbol)
    leafNodes.select("rect")
      .attr('width', 11)
      .attr('height', 11)
      .attr('x', -5.5)
      .attr('y', -5.5)
      .style('stroke', '#fff')
      .style('opacity', (d) =>
        if d.activeGroup
          1
        else 0)
      .style('fill', (d) =>
        if d.activeGroup
          'steelblue'
        else '#fff')

    # Changes colour of circle according to selection
    svgNodes.select("circle")
      .style("fill", (d) => 
        if d.selected
          "lightsteelblue"
        else
          "#fff")

    true

  # FUNC updatePopovers
  # Updates tree meta-data bars popover HTML content
  #
  # PARAMS
  # Meta-data option
  #
  # RETURNS
  # Boolean
  #
  updatePopovers: (option) ->

    # Creates n.tt_table_partial[m] which holds popover table html content as a string for metadata summary
    if @mtypesDisplayed.indexOf(option) > -1
      i = 0
      while i < @metaOntology[option].length
        @rectBlock.text((n)=>
          if n._children?
            if n.metaCount[option][@metaOntology[option][i]]? && i < 6 && @metaOntology[option][i]?
              n.width[i] = ((10*(Math.log(n.num_leaves)) + Math.pow(Math.log(n.num_leaves), 2.5)) * (n.metaCount[option][@metaOntology[option][i]]) / n.num_leaves)
            else if i is 6 && @metaOntology[option][i]?
              n.width[i] = ((10*(Math.log(n.num_leaves)) + Math.pow(Math.log(n.num_leaves), 2.5)) - (n.width[0] + n.width[1] + n.width[2] + n.width[3] + n.width[4] + n.width[5]))
            else
              n.width[i] = 0
            if n.metaCount[option][@metaOntology[option][i]]? && i > 5
              n.other_count[option] += n.metaCount[option][@metaOntology[option][i]]
            tt_mtype = @metaOntology[option][i].charAt(0).toUpperCase() + @metaOntology[option][i].slice(1)
            if n.metaCount[option][@metaOntology[option][i]] > 0
              other_width = Math.round(n.num_leaves*n.width[6] / (10*(Math.log(n.num_leaves)) + Math.pow(Math.log(n.num_leaves), 2.5)))
              if i >= 6
                n.tt_sub_table[option] += ("<tr><td>" + tt_mtype + "</td><td style='text-align:right'>" + n.metaCount[option][@metaOntology[option][i]] + "</td></tr>") unless n.tt_sub_table[option].indexOf("<tr><td>" + tt_mtype + "</td><td style='text-align:right'>" + n.metaCount[option][@metaOntology[option][i]] + "</td></tr>") > -1
                n.tt_table[option] = n.tt_table_partial[option] + ("<tbody class='other-row' onclick=\"$('.after-other').slideToggle(100);\"><tr><td>[+] Other</td><td style='text-align:right'\">" + other_width + "</td></tr></tbody><tbody class='after-other'>" + n.tt_sub_table[option] + "</tbody>") unless n.tt_table[option].indexOf(n.tt_table_partial[option] + ("<tbody class='other-row' onclick=\"$('.after-other').slideToggle(100);\"><tr><td>[+] Other</td><td style='text-align:right'\">" + other_width + "</td></tr></tbody><tbody class='after-other'>" + n.tt_sub_table[option] + "</tbody>")) > -1
              else
                n.tt_table_partial[option] += ("<tr><td>" + tt_mtype + "</td><td style='text-align:right'>" + n.metaCount[option][@metaOntology[option][i]] + "</td></tr>") unless n.tt_table_partial[option].indexOf("<tr><td>" + tt_mtype + "</td><td style='text-align:right'>" + n.metaCount[option][@metaOntology[option][i]] + "</td></tr>") > -1
                n.tt_table_last = tt_mtype
                n.tt_table[option] = n.tt_table_partial[option]
              n.tt_table_partial[option])
        i++

    true


  # FUNC intro
  # Message to appear in intro for genome tree
  #
  # PARAMS
  # 
  # RETURNS
  # treeIntro array 
  #
  intro: ->
    treeIntro = []

    treeIntro.push({
      element: document.querySelector('#tree_find_input2')
      intro: "Use this search bar to search for a specific genome.  The genome will be indicated by a yellow circle on the tree, which shows its phylogenetic relationships with other genomes."
      position: 'left'
      })
    treeIntro.push({
      element: document.querySelector('#tree-controls')
      intro: "Use these buttons to have the tree fit within the window, to reset the tree, to expand/collapse one level, and to stretch the tree."
      position: 'bottom'
      })
    treeIntro.push({
      element: document.querySelector('#genome_tree2')
      intro: "Genomes can be selected by clicking the blue circles.  Clades can be selected by clicking the red boxes.  Pan by clicking and dragging.  Clicking on the '+' and '-' symbols will expand or collapse each clade.  Use the clickwheel on your mouse to zoom.
      Single red bars represent the number of genomes in each clade.  Stacked bars represent the proportion of each type of meta-data in the clade.  Further information is displayed by hovering over each segment of the bar."
      position: 'left'
      })
    treeIntro.push({
      element: document.querySelector('#tree_legend2')
      intro: "Use this legend to help you."
      position: 'left'
      })
    treeIntro


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
        
    svgNodes = @canvas.selectAll("g.treenode")
    
    # Filter elements to those that are in set
    updateNodes = svgNodes.filter((d) -> genomeList[d.genome]?)
      .attr("class", (d) =>
        g = genomeList[d.genome]
        d.selected = (g.isSelected? and g.isSelected)
        d.assignedGroup = g.assignedGroup
        @_classList(d)
      )
      
    updateNodes.on("click", (d) ->
      unless d.assignedGroup?
        viewController.select(d.genome, !d.selected)
        if viewController.views[2].constructor.name is 'SummaryView'
          summary = viewController.views[2]
          summary.afterSelect(!d.selected)
      else
        null
    )
      
  
    true
    
  
  # FUNC viewAction
  # For top-level, global commands in TreeView that require
  # the genomeController as input use the viewAction in viewController.
  # This method will call the desired method in the TreeView class
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
    
    if event is 'expand_collapse'
      @_expandCollapse(genomes, argArray[0], argArray[1])
    else if event is 'fit_window'
      @xStretcher = 1
      @yStretcher = 1
      @fitToWindow = true
      @separationChange = false
      @reformat = true
      @update(genomes)
    else if event is 'reset_window'
      @xStretcher = 1
      @yStretcher = 1
      @xStretch = false
      @yStretch = false
      @separationChange = true
      @reset = true
      @resetWindow = true
      @highlightGenomes(genomes, null)
      @update(genomes)
    else if event is 'expand_tree'
      @expandTracker++
      @separationChange = true
      @expandTree(genomes)
    else if event is 'collapse_tree'
      @expandTracker--
      @separationChange = true
      @collapseTree(genomes)
    else if event is 'xstretch'
      @xStretch = true
      @xStretcher = @xStretcher * 2
      @reformat = true
      @update(genomes)
    else if event is 'ystretch'
      @yStretch = true
      @yStretcher = @yStretcher * 1.5
      @reformat = true
      @update(genomes)
    
    else
      throw new SuperphyError "Unrecognized event type: #{event} in TreeView viewAction method."
    
    true
    
  # FUNC selectClade
  # Call select on every leaf node in clade
  #
  # PARAMS
  # Data object representing node
  # boolean indicating select/unselect
  # 
  # RETURNS
  # boolean 
  #        
  selectClade: (node, checked) ->
    
    if node.leaf
      if checked
        # Select leaf
        unless node.selected
          viewController.select(node.genome, checked)
          if viewController.views[2].constructor.name is 'SummaryView'
            summary = viewController.views[2]
            summary.afterSelect(@.checked)
      else
        # Unselect leaf if it is currently selected
        if node.selected
          viewController.select(node.genome, checked)
          if viewController.views[2].constructor.name is 'SummaryView'
            summary = viewController.views[2]
            summary.afterSelect(@.checked)
     
    else
      if node.children
        @selectClade(c, checked) for c in node.children
      
      else if node._children
        @selectClade(c, checked) for c in node._children
        
    true
    
  # FUNC select
  # Changes css classes for selected genome in tree
  # Also updates coloring of selectClade command icons
  # to indicate presence of selected genome
  #
  # PARAMS
  # Data object representing node
  # boolean indicating select/unselect
  # 
  # RETURNS
  # boolean 
  #              
  select: (genome, isSelected) ->

    if user_groups_menu.runSelect or !user_groups_menu.groupSelected
    
      d = @_findLeaf(genome)
      
      svgNodes = @canvas.selectAll("g.treenode")
     
      updateNode = svgNodes.filter((d) -> d.genome is genome)
      
      if updateNode
        updateNode.attr("class", (d) =>
            d.selected = isSelected
            @_classList(d)
          )
          
        updateNode.select("circle")
          .style("fill", (d) => 
            if d.selected
              "lightsteelblue"
            else
              "#fff")
        
        # Push selection up tree
        @_percolateSelected(d.parent, isSelected)
        
        # update classes
        svgNodes.filter((d) -> !d.leaf)
          .attr("class", (d) =>
            @_classList(d)
          )
      
    true
    
    
  # FUNC _percolateSelected
  # Updates internal nodes up the tree
  # changing classes based on if 
  #
  # PARAMS
  # Data object representing node
  # boolean indicating select/unselect
  # 
  # RETURNS
  # boolean 
  #
  _percolateSelected: (node, checked) ->

    return true unless node?

    if checked
      node.num_selected++
    else
      node.num_selected--

    if node.num_selected == node.num_leaves
      node.internal_node_selected = 2
    else if node.num_selected > 0
      node.internal_node_selected = 1
    else
      node.internal_node_selected = 0
       
    @_percolateSelected(node.parent, checked)
    
    true
    
    
  # FUNC dump
  # Generate a Newick formatted tree of all genomes (ignores any filters)
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
    
    tokens = []
    
    @_printNode(genomes, @root, tokens)
    
    output = tokens.join('')
    
    return {
      ext: 'newick'
      type: 'text/plain'
      data: output 
    }
    
  _printNode: (genomes, node, tokens) ->
    
    if node.leaf
      # Genome node
      g = genomes.genome(node.genome)
      lab = genomes.label(g, genomes.visibleMeta)
      
      tokens.push("\"#{lab}\"",':',node.length)
    
    else
      # Internal node
      
      # Add all children
      children = node.children
      children = node._children if node._children?
      
      tokens.push('(')
        
      for c in children
        @_printNode(genomes, c, tokens)
        tokens.push(',')
          
      tokens[tokens.length-1] = ')' # replace last comma with closing bracket
      
      tokens.push("\"#{node.name}\"",':',node.length)
    
    true
    
    
  # Build right-angle branch connectors
  _step: (d) ->

    if !isNaN(d.source.oldX) and !isNaN(d.source.oldY) and !isNaN(d.target.oldX) and !isNaN(d.target.oldY)
      "M" + d.source.oldY + "," + d.source.oldX +
      "L" + d.source.oldY + "," + d.target.oldX +
      "L" + d.target.oldY + "," + d.target.oldX
    else
      "M" + d.source.y + "," + d.source.x +
      "L" + d.source.y + "," + d.target.x +
      "L" + d.target.y + "," + d.target.x
    
  _prepTree: ->
    
    # Set starting position of root
    @trueRoot.root = true
    @trueRoot.x0 = @height / 2
    @trueRoot.y0 = 0
    
    gPattern = /^((?:public_|private_)\d+)\|/
    
    # Save pointer to leaves
    @leaves = []
    @_assignKeys(@trueRoot, 0, gPattern)
  

  _assignKeys: (n, i, gPattern) ->
    
    n.id = i
    n.storage = n.length*1 # save original value
    i++
    
    if n.children?
      n.num_selected = 0
      
      # Save original children.widthay
      n.daycare = n.children.slice() # clone array
      
      for m in n.children
        i = @_assignKeys(m, i, gPattern)
        
    else if n._children?
      n.num_selected = 0
    
      # Save original children.widthay
      n.daycare = n._children.slice() # clone array
      
      for m in n._children
        i = @_assignKeys(m, i, gPattern)
    
    # Keep record of all leaf nodes
    # for faster genome searching
    if n.leaf? and n.leaf is "true"
      if @locusData?
        # Nodes are keyed: genome|locus
        res = gPattern.exec(n.name)
        throw new SuperphyError "Invalid tree node key. Expecting: genome|locus. Recieved: #{n.name}" unless res?
        n.genome = res[1]
      else
        # Nodes are keyed: genome
        n.genome = n.name
      
      # Save pointer to this leaf node
      @leaves.push n
    
    i
  
  # FUNC _sync
  # Creates up-to-date root object with matched the genome data properties 
  # (i.e. filtered nodes remvoed from children.widthay and added to hiddenChildren.widthay, 
  # group classes, genome names etc)
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  #      
  _sync: (genomes) ->

    # Need to keep handle on the true root
    @root = @_syncNode(@trueRoot, genomes, 0)

    # Check if genome set has changed
    if (genomes.genomeSetId != @currentGenomeSet) || @resetWindow
      # Need to set starting expansion layout
      @_expansionLayout()
      @currentGenomeSet = genomes.genomeSetId
      @resetWindow = false
      @reformat = true

   
    true
    
  _syncNode: (node, genomes, sumLengths) ->

    # Restore to original branch length
    # Compute cumulative branch length
    node.length = node.storage*1

    node.sum_length = sumLengths + node.length

    if node.leaf? and node.leaf is "true"

      # Genome leaf node
      g = genomes.genome(node.genome)

      # Genome can be missing if a subset of genomes was used
      # Or if it was filtered     
      if g? and g.visible
        # Update node with sync'd genome properties
        
        node.viewname = g.viewname
        node.selected = (g.isSelected? and g.isSelected)
        node.assignedGroup = g.assignedGroup
        node.hidden   = false
        node.activeGroup = false

        # Append locus data
        # This will overwrite assignedGroup
        if @locusData?
          ld = @locusData.locusNode(node.name)
          node.viewname += ld[0]
          node.assignedGroup = ld[1] if ld[1]?

      else
        # Mask filtered node
        node.hidden = true

      unless node.metaCount? && !g?
        node.metaCount = genomes.countMeta(g)

    else

      # Internal node
      isExpanded = true
      isExpanded = false if node._children?

      node.metaCount = {}

      # Iterate through the original children array
      children = []
      for c in node.daycare
        u = @_syncNode(c, genomes, node.sum_length)
        
        unless u.hidden
          children.push(u)

          

      if children.length == 0
        node.hidden = true
        
      else if children.length == 1
        # Child replaces this node
        node.hidden = true
        child = children[0]
        child.length += node.length
        
        return child
        
      else
        node.hidden = false
        if isExpanded
          node.children = children
        else
          node._children = children

    node  
  
  # FUNC _cloneNode
  # Creates copy of node object by copying properties
  # 
  # DOES NOT COPY children/_children because 
  # that will copy the child objects by reference and
  # not actual cloning
  #
  # PARAMS
  # javascript object representing tree node
  # 
  # RETURNS
  # JS object
  #
  _cloneNode: (node) ->
    
    copy = {}
    
    for k,v of node
      unless k is 'children' or k is '_children'
        copy[k] = v
    
    copy
    
  
  # FUNC _expansionLayout
  # Set internal node names, set initial expanded
  # nodes 
  # 
  # PARAMS
  # javascript object representing tree node
  # 
  # RETURNS
  # boolean
  #  
  _expansionLayout: ->
    
    @_formatNode(@root, 0)
    
    @root.x0 = @height / 2
    @root.y0 = 0
    @root.root = true
    
    true
  
  # FUNC _formatNode
  # Recursive function that sets expand / collapse setting 
  # based on level and if on path to focus node.
  # Also sets interactive internal node names and counts.
  #
  # This only gets called when the genome set changes.
  # 
  # PARAMS
  # javascript object representing tree node
  # Int for tree level
  # Reference to parent node
  # String indicating 
  # 
  # RETURNS
  # JS object
  #  
  _formatNode: (node, depth, parentNode=null) ->
    
    # There shouldn't be any hidden nodes in the
    # traversal
    return null if node.hidden
    
    current_depth = depth+1
    record = {}
    node.parent = parentNode
    node.root = false
    
    if node.leaf? and node.leaf is "true"
      # Genome leaf node
      
      record['num_leaves'] = 1
      record['outgroup'] = node.label
      record['depth'] = current_depth
      record['length'] = node.length
      record['num_selected'] = (node.selected ? 1 : 0)

      g = @genomes.genome(node.genome)
      counts = @genomes.countMeta(g);
      # Only keep track of values meta bins
      trackedMeta = {}
      for m,cobj of counts

        for v of cobj
          # Could be multiple values for a type
          num = cobj[v]

          if !@metaBins[m][v]?
            # This is not a tracked value
            # Falls into 'other'
            v = 'other'

          trackedMeta[m] = {} unless trackedMeta[m]?
          if trackedMeta[m][v]?
            trackedMeta[m][v] += num
          else 
            trackedMeta[m][v] = num

      record['metaCount'] = trackedMeta
      
      return record
       
    else
      # Internal node
      
      # Set expand / collapse setting
      isExpanded = true
      children = node.children
      if node._children?
        isExpanded = false
        children = node._children
        
      if current_depth < @expandDepth
        # Expand upper level
        node.children = children
        node._children = null
      else if isExpanded
        # Collapse lower levels
        node._children = children
        node.children = null
      else
        # Maintain existing setting
        node._children = children
        node.children = null
      
      # Iterate through the children
      record = {
        num_leaves: 0
        num_selected: 0
        outgroup: ''
        depth: 1e6
        length: 0
        metaCount: {}
      }

      for c in children
        r = @_formatNode(c, current_depth, node)
        
        record['num_leaves'] += r['num_leaves']
        # Prevents doubling num_leaves count when a filter is applied

        ## WHAT IS GOING ON HERE??
        record['num_selected'] += r['num_selected'] unless @genomes.filtered > 0 or @genomes.filterReset is true
        ##

        # Compare to existing outgroup
        if (record['depth'] > r['depth']) || (record['depth'] == r['depth'] && record['length'] < r['length']) 
          # new outgroup found
          record['depth'] = r['depth']
          record['length'] = r['length']
          record['outgroup'] = r['outgroup']

        
        # Sum metadata values
        for m,vobj of r.metaCount
          record.metaCount[m] = {} unless record.metaCount[m]?
          for v,num of vobj
            if record.metaCount[m][v]?
              record.metaCount[m][v] += num
            else 
              record.metaCount[m][v] = num

          
      # Assign internal node values
      node.label = "#{record['num_leaves']} genomes (outgroup: #{record['outgroup']})";
      node.num_leaves = record['num_leaves']
      node.num_selected = record['num_selected']
      node.metaCount = record.metaCount
      
      if node.num_selected == node.num_leaves
        node.internal_node_selected = 2
      else if node.num_selected > 0
        node.internal_node_selected = 1
      else
        node.internal_node_selected = 0

           
    record


  # FUNC _scale
  # Sets branch x and y scale factors. Needs to
  # be called after tree rendered. Called after
  # major changes to genomes (filter, reset view)
  # Stretches tree so that it covers X% of view
  # area. The X% is determined by the number of
  # leaves in tree up to a max of 80%
  # 
  # PARAMS
  # Nothing
  # 
  # RETURNS
  # Boolean
  #
  _scale: ->
    
    # Scale branch lengths based on number of leaves
    farthest = d3.max(@nodes, (d) -> d.sum_length * 1)
    lowest = d3.max(@nodes, (d) -> d.x )
    percCovered = 0.10 * @root.num_leaves
    percCovered = 0.90 if percCovered > 0.90
    padding = 20
    yedge = (@width - padding) * percCovered 
    xedge = (@height - padding) * percCovered
    
    @branch_scale_factor_y = yedge/farthest
    @branch_scale_factor_x = xedge/lowest
      
    true
             
  _expandCollapse: (genomes, d, el) ->
    
    svgNode = d3.select(el)
    @edgeNode = null # Record right-most node
    maxy = 0
   
    if d.children?
      @expand = false
      # Collapse all child nodes into parent
      d._children = d.children
      d.children = null
      @edgeNode = d
      
    else
      @expand = true
      # Expand 3-levels
      d.children = d._children
      d._children = null
      
      # Expand child nodes
      for c in d.children
        if c._children?
          c.children = c._children
          c._children = null
            
        # Expand grandchild nodes
        if c.children?
          for c2 in c.children
            if c2._children?
              c2.children = c2._children
              c2._children = null
                
            if c2.children?
              for c3 in c2.children
                if c3.sum_length > maxy
                  maxy = c3.sum_length
                  @edgeNode = c3
                  
            if c2.sum_length > maxy
              maxy = c2.sum_length
              @edgeNode = c2
              
        if c.sum_length > maxy
          maxy = c.sum_length
          @edgeNode = c
                
    @expansionContraction = true # adjust right shift
            
    @update(genomes, d)
    
    true
    
  zoomed: ->
    
    @canvas.selectAll("g.treenode")
      .attr("transform", (d) => @_zTransform(d, @xzoom, @yzoom))
    
    @canvas.selectAll("path.treelink")
      .attr("d", (d) => @_zTranslate(d, @xzoom, @yzoom))
      
    #@scaleBar.attr("transform", "translate(" + @xzoom(@scalePos.x) + "," + @yzoom(@scalePos.y) + ")")
    
    @scaleBar.select("line")
      .attr('transform','scale('+d3.event.scale+',1)')
      
    true
      
  # Build right-angle connectors stretched for zoom
  _zTranslate: (d, xzoom, yzoom) ->  
    sourceX = xzoom(d.source.y)
    sourceY = yzoom(d.source.x)
    targetX = xzoom(d.target.y)
    targetY = yzoom(d.target.x)
  
    "M" + sourceX + "," + sourceY +
    "L" + sourceX + "," + targetY + 
    "L" + targetX + "," + targetY
  
  # Position nodes stretched for zoom
  _zTransform: (d, xzoom, yzoom) ->
    d.oldX = yzoom(d.x)
    d.oldY = xzoom(d.y)
    "translate(" + xzoom(d.y) + "," + yzoom(d.x) + ")"

  _classList: (d) ->
    
    clsList  = ['treenode'];
    clsList.push("selectedNode") if d.selected
    clsList.push("focusNode") if d.focus
    clsList.push("groupedNode#{d.assignedGroup}") if d.assignedGroup?
    clsList.push("activeGroupNode") if d.activeGroup
    
    if d.internal_node_selected?
      if d.internal_node_selected == 2
        clsList.push("internalSNodeFull")
      else if d.internal_node_selected == 1
        clsList.push("internalSNodePart")
  
    clsList.join(' ')
    
  # FUNC _findLeaf
  # Return data object matching genome ID
  # 
  # PARAMS
  # string for genome ID
  # 
  # RETURNS
  # Genome node object
  #  
  _findLeaf: (genome) ->
    
    # Find data object
    n = null
    found = @leaves.some( (el, i) ->
      if el.genome is genome
        n = el
        return true
      else
        return false
    )
    
    unless found
      throw new SuperphyError "No leaf node matching #{genome} found."
      return null
      
    # The svg element may not exist if it is in collapsed tree clade
    return n
    
 
  # FUNC _legend
  # Attach legend for tree manipulations
  # 
  # PARAMS
  # D3 svg element to attach legend elements to
  # 
  # RETURNS
  # boolean
  #   
  _legend: (el) ->
    
    lineh = 25
    lineh2 = 40
    lineh3 = 55
    lineh4 = 70
    lineh5 = 85
    lineh6 = 100
    textdx = ".6em"
    textdx2= "2.5em"
    textdy = ".4em"
    pzdx   = "3.2em"
    pzdx2  = "3.7em"
    pzdy   = ".5em"
    indent = 8
    colw = 245
    colw2 = 480
    
    if @style is 'select'
      
      # Genome select column
      gsColumn = el.append("g")
        .attr("transform", "translate(5,"+lineh+")" )
        
      genomeSelect = gsColumn.append("g")
        .attr("class", 'treenode')
        
      genomeSelect.append("circle")
        .attr("r", 4)
        .attr("cx", 0)
        .attr("cy", 0)
        .style("fill", "#fff")
        
      genomeSelect.append("text")
        .attr("class","legendlabel1")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Click to select / unselect genome')

      genomeSelect = gsColumn.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate("+indent+","+lineh+")" )
        
      genomeSelect.append("circle")
        .attr("r", 4)
        .attr("cx", 0)
        .attr("cy", 0)
        .style("fill", "#fff")
        
      genomeSelect.append("text")
        .attr("class","legendlabel2")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Unselected genome')
        
      genomeSelect = gsColumn.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate("+indent+","+lineh2+")" )
        
      genomeSelect.append("circle")
        .attr("r", 4)
        .attr("cx", 0)
        .attr("cy", 0)
        .style("fill", "lightsteelblue")
        
      genomeSelect.append("text")
        .attr("class","legendlabel2")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Selected genome')

      genomeSelect = gsColumn.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate("+indent+","+lineh3+")" )

      genomeSelect.append('rect')
        .attr('width', 11)
        .attr('height', 11)
        .attr('x', -5.5)
        .attr('y', -5.5)
        .style('fill', 'steelblue')
        
      genomeSelect.append("circle")
        .attr("r", 4)
        .attr("cx", 0)
        .attr("cy", 0)
        .style("fill", "#fff")
        
      genomeSelect.append("text")
        .attr("class","legendlabel2")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Active group genome')

      genomeSelect = gsColumn.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate("+indent+","+lineh4+")" )
        
      genomeSelect.append("circle")
        .attr("r", 4)
        .attr("cx", 0)
        .attr("cy", 0)
        .style("stroke", "#ffa500")
        .style("stroke-width", "3px")
        
      genomeSelect.append("text")
        .attr("class","legendlabel2")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Searched genome')
        
      # Clade select column
      csColumn = el.append("g")
        .attr("transform", "translate("+colw+","+lineh+")" )
        
      cladeSelect = csColumn.append("g")
        .attr("class", 'treenode')
        
      cladeSelect.append('rect')
        .attr("class","selectClade")
        .attr("width", 8)
        .attr("height", 8)
        .attr("y", -4)
        .attr("x", -4)
        
      cladeSelect.append("text")
        .attr("class","legendlabel1")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Click to select / unselect clade')
        
      cladeSelect = csColumn.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate("+indent+","+lineh+")" )
        
      cladeSelect.append('rect')
        .attr("class","selectClade")
        .attr("width", 8)
        .attr("height", 8)
        .attr("y", -4)
        .attr("x", -4)
        
      cladeSelect.append("text")
        .attr("class","legendlabel2")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('No genomes selected in clade')
        
      cladeSelect = csColumn.append("g")
        .attr("class", 'treenode internalSNodePart')
        .attr("transform", "translate("+indent+","+lineh2+")" )
        
      cladeSelect.append('rect')
        .attr("class","selectClade")
        .attr("width", 8)
        .attr("height", 8)
        .attr("y", -4)
        .attr("x", -4)
        
      cladeSelect.append("text")
        .attr("class","legendlabel2")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Some genomes selected in clade')
        
      cladeSelect = csColumn.append("g")
        .attr("class", 'treenode internalSNodeFull')
        .attr("transform", "translate("+indent+","+lineh3+")" )
        
      cladeSelect.append('rect')
        .attr("class","selectClade")
        .attr("width", 8)
        .attr("height", 8)
        .attr("y", -4)
        .attr("x", -4)
        
      cladeSelect.append("text")
        .attr("class","legendlabel2")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('All genomes selected in clade')
      
      # clade expand/collapse  
      ecColumn = el.append("g")
        .attr("transform", "translate("+colw2+","+lineh+")" )
        
      expandCollapse = ecColumn.append("g")
        .attr("class", 'treenode')
          
      expandCollapse.append('text')
        .attr("class","treeicon expandcollapse")
        .attr("text-anchor", 'middle')
        .attr("dy", 4)
        .attr("dx", -1)
        .text((d) -> "\uf0fe")
        
      expandCollapse.append("text")
        .attr("class","legendlabel1")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Click to collapse / expand clade')
        
      expandCollapse = ecColumn.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate("+indent+","+lineh+")" )
        
      expandCollapse.append('text')
        .attr("class","treeicon expandcollapse")
        .attr("text-anchor", 'middle')
        .attr("dy", 4)
        .attr("dx", -1)
        .text((d) -> "\uf146")
        
      expandCollapse.append("text")
        .attr("class","legendlabel2")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Expanded clade')
        
      expandCollapse = ecColumn.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate("+indent+","+lineh2+")" )
        
      expandCollapse.append('text')
        .attr("class","treeicon expandcollapse")
        .attr("text-anchor", 'middle')
        .attr("dy", 4)
        .attr("dx", -1)
        .text((d) -> "\uf0fe")
        
      expandCollapse.append("text")
        .attr("class","legendlabel2")
        .attr("dx", textdx)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Collapsed clade')
        
      # Pan / zoom
      pzRow = el.append("g")
        .attr("transform", "translate(0,0)" )
      
      panZoom = pzRow.append("g") 
        .attr("class", 'treenode')
        
      panZoom.append("text")
        .attr("class","slash")
        .attr("dx", 0)
        .attr("dy", ".5em")
        .attr("text-anchor", "start")
        .text('Pan')
        
      panZoom.append("text")
        .attr("class","legendlabel1")
        .attr("dx", pzdx)
        .attr("dy", pzdy)
        .attr("text-anchor", "start")
        .text('Click & Drag')
        
      panZoom = pzRow.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate("+colw+",0)" )
        
      panZoom.append("text")
        .attr("class","slash")
        .attr("dx", "-.4em")
        .attr("dy", ".5em")
        .attr("text-anchor", "start")
        .text('Zoom')
        
      panZoom.append("text")
        .attr("class","legendlabel1")
        .attr("dx", pzdx)
        .attr("dy", pzdy)
        .attr("text-anchor", "start")
        .text('Scroll')
        
    else
      # Redirect
    
      # Genome select
      genomeSelect = el.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate(5,0)" )
        
      genomeSelect.append("circle")
        .attr("r", 4)
        .attr("cx", 8)
        .attr("cy", 0)
        .style("fill", "#fff")
        
      genomeSelect.append("text")
        .attr("class","legendlabel1")
        .attr("dx", textdx2)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Select genome')
        
      # Clade expand
      cladeExpand = el.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate(5, "+lineh+")" )
      
      cladeExpand.append('text')
        .attr("class","treeicon expandcollapse")
        .attr("text-anchor", 'middle')
        .attr("y", 4)
        .attr("x", -1)
        .text((d) -> "\uf0fe")
        
      cladeExpand.append("text")
        .attr("class","slash")
        .attr("dx", ".5em")
        .attr("dy", ".5em")
        .attr("text-anchor", "start")
        .text('/')
        
      cladeExpand.append('text')
        .attr("class","treeicon expandcollapse")
        .attr("text-anchor", 'middle')
        .attr("y", 8)
        .attr("x", 17)
        .text((d) -> "\uf146")
        
      cladeExpand.append("text")
        .attr("class","legendlabel1")
        .attr("dx", textdx2)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Expand / Collapse clade')
        
      # Pan / zoom
      panZoom = el.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate("+colw+",0)" )
        
      panZoom.append("text")
        .attr("class","slash")
        .attr("dx", 0)
        .attr("dy", ".5em")
        .attr("text-anchor", "start")
        .text('Pan ')
        
      panZoom.append("text")
        .attr("class","legendlabel1")
        .attr("dx", pzdx2)
        .attr("dy", pzdy)
        .attr("text-anchor", "start")
        .text('Click & Drag')
        
      panZoom = el.append("g")
        .attr("class", 'treenode')
        .attr("transform", "translate("+colw+","+lineh+")" )
        
      panZoom.append("text")
        .attr("class","slash")
        .attr("dx", 0)
        .attr("dy", ".5em")
        .attr("text-anchor", "start")
        .text('Zoom')
        
      panZoom.append("text")
        .attr("class","legendlabel1")
        .attr("dx", pzdx2)
        .attr("dy", pzdy)
        .attr("text-anchor", "start")
        .text('Scroll')
        
        
      # Focus node
      focusNode = el.append("g")
        .attr("class", 'treenode focusNode')
        .attr("transform", "translate("+colw2+",0)" )
        
      focusNode.append("circle")
        .attr("r", 4)
        .attr("cx", 8)
        .attr("cy", 2)
        #.style("fill", "#fff")
        
      focusNode.append("text")
        .attr("class","legendlabel1")
        .attr("dx", textdx2)
        .attr("dy", textdy)
        .attr("text-anchor", "start")
        .text('Target genome')
        

  # FUNC _treeOps
  # Attach buttons for tree manipulations
  # 
  # PARAMS
  # JQuery element to attach legend elements to
  # 
  # RETURNS
  # boolean
  #   
  _treeOps: (el, legendID) ->
      
    # Additional tree ops (buttons)
    opsHtml = ''
    
    # control form
    controls = '<div class="row">'
      
    controls += "<div class='col-sm-9 span9'><div class='btn-group' id='tree-controls'>"
    
    # Fit to window
    fitButtonID = "tree_fit_button#{@elNum}"
    controls += "<button id='#{fitButtonID}' type='button' class='btn btn-default btn-sm'>Fit to window</button>"
      
    # Reset to original view
    resetButtonID = "tree_reset_button#{@elNum}"
    controls += "<button id='#{resetButtonID}' type='button' class='btn btn-default btn-sm'>Reset</button>"
    
    # Expand next level
    expButtonID = "tree_expand_button#{@elNum}"
    controls += "<button id='#{expButtonID}' type='button' class='btn btn-default btn-sm'>Expand</button>"

    # Collapse next level
    colButtonID = "tree_collapse_button#{@elNum}"
    controls += "<button id='#{colButtonID}' type='button' class='btn btn-default btn-sm'>Collapse</button>"

    # Horizontal expansion
    xStretchButtonID = "tree_xstretch_button#{@elNum}"
    controls += "<button id='#{xStretchButtonID}' type='button' class='btn btn-default btn-sm'>X-stretch</button>"

    # Horizontal contraction
    # xShrinkButtonID = "tree_xshrink_button#{@elNum}"
    # controls += "<button id='#{xShrinkButtonID}' type='button' class='btn btn-default btn-sm'>X-shrink</button>"

    # Vertical expansion
    yStretchButtonID = "tree_ystretch_button#{@elNum}"
    controls += "<button id='#{yStretchButtonID}' type='button' class='btn btn-default btn-sm'>Y-stretch</button>"

    # Vertical contraction
    # yShrinkButtonID = "tree_yshrink_button#{@elNum}"
    # controls += "<button id='#{yShrinkButtonID}' type='button' class='btn btn-default btn-sm'>Y-shrink</button>"
      
    controls += "</div></div>" # End button group, 6-col
    
    # Find genome
    findButtonID = "tree_find_button#{@elNum}"
    findInputID = "tree_find_input#{@elNum}"
    controls += "<div class='col-sm-3 span3'><div class='input-group input-prepend input-group-sm'>"
    controls += "<span class='input-group-btn'> <button id='#{findButtonID}' class='btn btn-default btn-sm' type='button'>Search</button></span>"
    controls += "<input id='#{findInputID}' type='text' class='form-control input-small'></div></div>"
      
    controls += "</div>" # End row
      
    opsHtml += "#{controls}"
   
    jQuery("<div class='tree_operations'>#{opsHtml}</div>").appendTo(el)
      
    # Actions
    num = @elNum-1
    
    
    # Find genome
    jQuery("##{findButtonID}").click (e) ->
      e.preventDefault()
      searchString = jQuery("##{findInputID}").val()
      viewController.highlightInView(searchString, num)
    
    # Fit window
    jQuery("##{fitButtonID}").click (e) ->
      e.preventDefault()
      viewController.viewAction(num, 'fit_window')
      
    # Reset window
    jQuery("##{resetButtonID}").click (e) ->
      e.preventDefault()
      viewController.viewAction(num, 'reset_window')
      
    # Expand one level of tree
    jQuery("##{expButtonID}").click (e) ->
      e.preventDefault()
      viewController.viewAction(num, 'expand_tree')

    # Collapse one level of tree
    jQuery("##{colButtonID}").click (e) ->
      e.preventDefault()
      viewController.viewAction(num, 'collapse_tree')

    # Horizontal expansion of tree
    jQuery("##{xStretchButtonID}").click (e) ->
      e.preventDefault()
      viewController.viewAction(num, 'xstretch')

    # Vertical expansion of tree
    jQuery("##{yStretchButtonID}").click (e) ->
      e.preventDefault()
      viewController.viewAction(num, 'ystretch')
    
    
    true
  
  # FUNC highlightNode
  # Find and set focusNode in tree, expanding
  # internal nodes on path to focusNode
  # 
  # PARAMS
  # GenomeController object
  # array of genome ID strings
  # If array empty, resets focus nodes
  # 
  # RETURNS
  # boolean
  #   
  highlightGenomes: (genomes, targetList) ->

    # Reset all genomes
    for l in @leaves
      l.focus = false
      
    if targetList? and targetList.length
      
      targetNodes = @_blowUpPath(targetList)
      
      if targetNodes.length
        maxy = 0
        @edgeNode = null
        for n in targetNodes
          if n.sum_length > maxy
            maxy = n.sum_length
            @edgeNode = n

          
        @expansionContraction = true
        num = @elNum-1
        @update(genomes)
        #@canvas.attr("transform", "translate(" + -(@edgeNode.y - 300) + "," + -(@edgeNode.x - 300) + ")")
        viewController.viewAction(num, 'fit_window')
        
      else
        gs = targetList.join(', ')
        throw new SuperphyError "TreeView method highlightGenome error. Genome(s) #{gs} not found."
      
    
  # FUNC _blowUpPath
  # Scans tree for matching genomes. 
  # When genome found expands all 
  # internal nodes in path.
  # 
  # PARAMS
  # array of genome ID strings
  # 
  # RETURNS
  # boolean
  #     
  _blowUpPath: (targetList) ->
    
    targetNodes = []
    for g in targetList
      n = @_findLeaf(g)
      n.focus = true
      targetNodes.push n
      
      # expand path to root
      curr = n.parent
      while curr
        if curr._children?
          curr.children = curr._children
          curr._children = null
          
        curr = curr.parent
          
    targetNodes
    
    
  # FUNC expandTree
  # Expands all internal nodes in tree
  # 
  # PARAMS
  # genomeController object
  #
  # RETURNS
  # boolean
  #       
  expandTree: (genomes) ->
    
    @_expandOneLevel(@root)
    
    @reformat = true
    @update(genomes)
    
    true

  # FUNC expandTree
  # Expands all internal nodes in tree
  # 
  # PARAMS
  # genomeController object
  #
  # RETURNS
  # boolean
  #       
  collapseTree: (genomes) ->

    @levelTracker = 0

    @depths = []

    for n in @nodes
      if n.leaf or n._children?
        @depths.push(n.depth)
        @levelTracker = Math.max.apply(Math, @depths)
    
    @_collapseOneLevel(@root)
    
    @reformat = true
    @update(genomes)
    
    true

  # FUNC _collapseOneLevel
  # Collapses one level of internal nodes in tree
  # 
  # PARAMS
  # Node object
  # 
  # RETURNS
  # boolean
  #     
  _collapseOneLevel: (n) ->

    if n.children?
      for c in n.children
        @_collapseOneLevel(c)

    # Collapse
    if n._children? or n.leaf
      if n.depth is @levelTracker
        if (n.parent).children isnt null
          (n.parent)._children = (n.parent).children
          (n.parent).children = null
        
    true
  
  # Changed from _blowUpAll as function now expands next level instead of all 
  # FUNC _expandOneLevel
  # Expands next level of internal nodes in tree
  # 
  # PARAMS
  # Node object
  # 
  # RETURNS
  # boolean
  #     
  _expandOneLevel: (n) ->

    # In cases where an expanded node has children that have children, provides node.oldX and node.oldY values
    if !n.oldX? and @launchPt.oldX?
      n.oldX = @launchPt.oldX + (n.x - @launchPt.x0)
    if !n.oldY? and @launchPt.oldY?
      n.oldY = @launchPt.oldY + (n.y - @launchPt.y0)

    if n.children?
      for c in n.children
        @_expandOneLevel(c)
    
    # Expand
    if n._children?
      n.children = n._children
      n._children = null
        
    true
    
    
