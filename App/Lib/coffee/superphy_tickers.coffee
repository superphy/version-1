###


 File: superphy_tickers.coffee
 Desc: Multiple Superphy Ticker Classes. Tickers are single line summaries of current genome data
 Author: Matt Whiteside matthew.whiteside@phac-aspc.gc.ca
 Date: April 16th, 2013
 
 
###

###
 MIXIN support
 
 The function adds instance properties to a class.

###
mixOf = (base, mixins...) ->
  class Mixed extends base
  for mixin in mixins by -1 #earlier mixins override later ones
    for name, method of mixin::
      Mixed::[name] = method
  Mixed

###
 CLASS TickerTemplate
 
 Template object for tickers. Defines required and
 common properties/methods. All ticker objects
 are descendants of the TickerTemplate.

###
class TickerTemplate
  constructor: (@parentElem, @elNum=1) ->
    @elID = @elName + @elNum
  
  elNum: 1
  elName: 'ticker'
  elID: undefined
  parentElem: undefined
  cssClass: undefined
  flavor: undefined
  
  update: (genomes) ->
    throw new SuperphyError "TickerTemplate method update() must be defined in child class (#{this.flavor})."
    false # return fail
 
###
 CLASS MetaTicker
  
 Counts number of a specified meta-data item

###

class MetaTicker extends TickerTemplate
  constructor: (@parentElem, @elNum, tickerArgs) ->
    
    super(@parentElem, @elNum)
    
    throw new SuperphyError 'Missing argument. MetaTicker constructor requires a string indicating meta-data type.' unless tickerArgs.length == 1
    
    @metaType = tickerArgs[0]
    
  
  elName: 'meta_ticker'
  cssClass: 'superphy_ticker_table'
  flavor: 'meta'
  noDataLabel: 'Not available'
  
  
  # FUNC update
  # Update Ticker
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  # 
  update: (genomes) ->
    
    # create or find MSA table
    tickerElem = jQuery("##{@elID}")
    if tickerElem.length
      tickerElem.empty()
    else      
      tickerElem = jQuery("<table id='#{@elID}' class='#{@cssClass}'></table>")
      jQuery(@parentElem).append(tickerElem)
   
    t1 = new Date()
    
    # Update totals
    countObj = {}
    @_updateCounts(countObj, genomes.pubVisible, genomes.public_genomes)
    @_updateCounts(countObj, genomes.pvtVisible, genomes.private_genomes)
    
    # Add to table
    headElem = jQuery('<thead><tr></tr></thead>').appendTo(tickerElem)
    bodyElem = jQuery('<tbody><tr></tr></tbody>').appendTo(tickerElem)
    headRow = jQuery('<tr></tr>').appendTo(headElem)
    bodyRow = jQuery('<tr></tr>').appendTo(bodyElem)
    
    ks = (k for k of countObj).sort(a, b) ->
      if a is @noDataLabel
        return 1
      if b is @noDataLabel
        return -1
      
      if a < b
        return -1
      else if a > b
        return 1
      else
        return 0
      
        
    for k in ks
      v = countObj[k]
      headRow.append("<th>#{k}</th>")
      bodyRow.append("<td>#{v}</td>") 
    
    t2 = new Date()
    
    ft = t2-t1
    console.log('MetaTicker update elapsed time: '+ft)
   
    true # return success
    

  _updateCounts: (counts, visibleG, genomes) ->
    
    meta = @metaType
    
    console.log('META'+meta)

    for g in visibleG
      
      if genomes[g][meta]?
        if counts[genomes[g][meta]]?
          counts[genomes[g][meta]]++
        else
          counts[genomes[g][meta]] = 1
      else
        if counts[@noDataLabel]?
          counts[@noDataLabel]++
        else
          counts[@noDataLabel] = 1
      
    true
    

###
 CLASS LocusTicker
  
 Counts number of a specified meta-data item

###

class StxTicker extends TickerTemplate
  constructor: (@parentElem, @elNum, tickerArgs) ->
    
    super(@parentElem, @elNum, @elNum)
    
    throw new SuperphyError 'Missing argument. StxTicker constructor requires a LocusController object.' unless tickerArgs.length == 1
    
    @locusData = tickerArgs[0]
    
  
  elName: 'stx_ticker'
  cssClass: 'superphy_ticker_table'
  flavor: 'stx'
  noDataLabel: 'NA'
  
  
  # FUNC update
  # Update Ticker
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  # 
  update: (genomes) ->
    
    # create or find MSA table
    tickerElem = jQuery("##{@elID}")
    if tickerElem.length
      tickerElem.empty()
    else      
      tickerElem = jQuery("<table id='#{@elID}' class='#{@cssClass}'></table>")
      jQuery(@parentElem).append(tickerElem)
   
    t1 = new Date()
    
    # Update totals
    countObj = @locusData.count(genomes)
    
    # Add to table
    headElem = jQuery('<thead></thead>').appendTo(tickerElem)
    bodyElem = jQuery('<tbody></tbody>').appendTo(tickerElem)
    headRow = jQuery('<tr></tr>').appendTo(headElem)
    bodyRow = jQuery('<tr></tr>').appendTo(bodyElem)
    
    ks = (k for k of countObj)
    ks.sort (a, b) ->
      if a is @noDataLabel
        return 1
      if b is @noDataLabel
        return -1
      
      if a < b
        return -1
      else if a > b
        return 1
      else
        return 0
      
        
    for k in ks
      v = countObj[k]
      headRow.append("<th>#{k}</th>")
      bodyRow.append("<td>#{v}</td>") 
    
    t2 = new Date()
    
    ft = t2-t1
    console.log('StxTicker update elapsed time: '+ft)
   
    true # return success
    

###
 CLASS Histogram
  
 Histogram mixin

###
class Histogram
  
  # FUNC init
  # Initialise the histogram elements
  #
  # PARAMS
  # None
  # 
  # RETURNS
  # boolean 
  #       
  init: ->
    # Create empty histogram
    margin = {top: 40, right: 30, bottom: 40, left: 30}
    @width = 300 - margin.left - margin.right
    @height = 250 - margin.top - margin.bottom
    
    bins = [
      {'val': 0, 'key': '0'}
      {'val': 1, 'key': '1'}
      {'val': 2, 'key': '2'}
      {'val': 3, 'key': '3'}
      {'val': 4, 'key': '4'}
      {'val': 5, 'key': '>=5'}
    ]
    
    @x = d3.scale.ordinal()
      .domain(bins.map((d) -> d.val))
      .rangeRoundBands([0, @width], .05);
    
    @x2 = d3.scale.ordinal()
      .domain(bins.map((d) -> d.key))
      .rangeRoundBands([0, @width], .05);
     
    @xAxis = d3.svg.axis()
      .scale(@x2)
      .orient("bottom");
      
    @histogram = d3.layout.histogram()
      .bins([0,1,2,3,4,5,6])
      
    @parentElem.append("<div id='#{@elID}' class='#{@cssClass}'></div>")
      
    @canvas = d3.select("##{@elID}").append("svg")
        .attr("width", @width + margin.left + margin.right)
        .attr("height", @height + margin.top + margin.bottom)
    .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
      
    @formatCount = d3.format(",.0f");
    
    @canvas.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + @height + ")")
      .call(@xAxis)
      .append("text")
        .attr("dy", ".75em")
        .attr("y", 23)
        .attr("x", @width / 2)
        .attr("text-anchor", "middle")
        .text( 'Number of Alleles')
  
  # FUNC updateHistogram
  # Update/draw histogram bin
  #
  # PARAMS
  # List of numeric counts to bin
  # 
  # RETURNS
  # boolean 
  #       
  updateHistogram: (values) ->
    
    histData = @histogram(values)
    
    # Max y values are increased in discrete steps so that
    # scale is more consistent between updates
    steps = [10,50,100,200,500,800,1000,1200,1500,2000,5000,8000,10000,20000,50000,80000,100000]
    maxSteps = steps.length
    maxY = d3.max(histData, (d) -> d.y)
    yTop = NaN
    for i in [0..maxSteps] by 1
      if maxY < steps[i]
        yTop = steps[i]
        break
        
    @y = d3.scale.linear()
      .domain([0, yTop])
      .range([@height, 0])
    
    svgBars = @canvas.selectAll("g.histobar")
      .data(histData)
        
    # Update existing
    svgBars.attr("transform", (d) => "translate(" + @x(d.x) + "," + @y(d.y) + ")" )
    
    svgBars.select("rect")
        .attr("x", 0)
        .attr("width", @x.rangeBand())
        .attr("height", (d) => @height - @y(d.y) )
      
    svgBars.select("text")
      .attr("dy", ".75em")
      .attr("y", -14)
      .attr("x", @x.rangeBand() / 2)
      .attr("text-anchor", "middle")
      .text( (d) => 
        if d.y > 0
          @formatCount(d.y)
        else
          '' )
        
    # Remove old
    svgBars.exit().remove();
    
    # Insert new
    newBars = svgBars.enter().append("g")
      .attr("class", "histobar")
      .attr("transform", (d) => "translate(" + @x(d.x) + "," + @y(d.y) + ")" )
    
    newBars.append("rect")
      .attr("x", 0)
      .attr("width", @x.rangeBand())
      .attr("height", (d) => @height - @y(d.y) )
        
    newBars.append("text")
      .attr("dy", ".75em")
      .attr("y", -14)
      .attr("x", @x.rangeBand() / 2)
      .attr("text-anchor", "middle")
      .text( (d) => 
        if d.y > 0
          @formatCount(d.y)
        else
          '' )
          
    true

###
 CLASS MatrixTicker
  
 Histogram of allele frequency for multiple genes

###

class MatrixTicker extends mixOf TickerTemplate, Histogram
  constructor: (@parentElem, @elNum, genomes, tickerArgs) ->
    
    super(@parentElem, @elNum, @elNum)
    
    throw new SuperphyError 'Missing argument. MatrixTicker constructor requires GenomeController object.' unless genomes?
    throw new SuperphyError 'Missing argument. MatrixTicker constructor requires a JSON object containing: nodes, links object.' unless tickerArgs.length == 1
    
    tmp = tickerArgs[0]
    genes = tmp['nodes']
    alleles = tmp['links']
    @_doCounts(genomes, genes, alleles)
    
    @init()
    
  elName: 'matrix_ticker'
  cssClass: 'matrix_histogram'
  flavor: 'matrix'
  noDataLabel: 'NA'
  
  
  # FUNC update
  # Update Ticker
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  # 
  update: (genomes) ->
    
    t1 = new Date()
    
    # Update counts
    values = []
    for g in genomes.pubVisible.concat genomes.pvtVisible
      for n in @geneList
        throw new SuperphyError "Count not defined for genome #{g} and gene #{n}." unless @counts[g]? and @counts[g][n]?
        values.push @counts[g][n]
        
        
    # Redraw histogram
    @updateHistogram(values)

    t2 = new Date()
    
    ft = t2-t1
    console.log('MatrixTicker update elapsed time: '+ft)
   
    true # return success
    
    
  _doCounts: (genomes, genes, alleles) ->
    
    gList = Object.keys(genomes.public_genomes).concat Object.keys(genomes.private_genomes)
    @geneList = Object.keys(genes)
    
    @counts = {}
  
    for g in gList
      
      @counts[g] = {}
      
      for n in @geneList
         
        # Count alleles for genome/gene pair
        numAlleles = 0
        if alleles[g]? and alleles[g][n]?
          numAlleles = alleles[g][n].length
           
        @counts[g][n] = numAlleles
            
    true
   
    
###
 CLASS AlleleTicker
  
 Histogram of allele frequency for one gene

###

class AlleleTicker extends mixOf TickerTemplate, Histogram
  constructor: (@parentElem, @elNum, tickerArgs) ->
    
    super(@parentElem, @elNum, @elNum)
    
    throw new SuperphyError 'Missing argument. AlleleTicker constructor requires a LocusController object.' unless tickerArgs.length == 1
    
    @locusData = tickerArgs[0]
    
    @init()
    
  elName: 'allele_ticker'
  cssClass: 'allele_histogram'
  flavor: 'allele'
  noDataLabel: 'NA'
  
  
  # FUNC update
  # Update Ticker
  #
  # PARAMS
  # genomeController object
  # 
  # RETURNS
  # boolean 
  # 
  update: (genomes) ->
    
    t1 = new Date()
    
    # Update counts
    values = @locusData.count(genomes)
    
    # Redraw histogram
    @updateHistogram(values)

    t2 = new Date()
    
    ft = t2-t1
    console.log('AlleleTicker update elapsed time: '+ft)
   
    true # return success
    