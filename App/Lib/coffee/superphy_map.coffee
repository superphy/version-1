###

 File: superphy_map.coffee
 Desc: Objects & functions for managing geospatial views in Superphy
 Author: Akiff Manji akiff.manji@gmail.com
 Date: May 6, 2014

###

class MapView extends TableView
  constructor: (@parentElem, @style, @elNum, @genomeController, @mapArgs) ->
    # Call default constructor - creates unique element ID                  
    super(@parentElem, @style, @elNum)

    @sortField = 'isolation_country'
    @sortAsc = 'true'

    # Location Meta Types
    @locationMetaFields = {
      'isolation_country' : 'Country',
      'isolation_province_state' : 'Province/State',
      'isolation_city' : 'City'
    }

    mapSplitLayout = jQuery('<div class="map-split-layout row"></div>').appendTo(jQuery(@parentElem))
    
    ## Map and Search
    mapSearchEl = jQuery('<div class="map-search-wrapper col-md-6 span6"></div>').appendTo(mapSplitLayout)
    
    mapSearchRow = jQuery('<div class="geospatial-row row"></div>').appendTo(mapSearchEl)
    searchEl = jQuery('<div class="col-md-9 span9"></div>').appendTo(mapSearchRow)
    resetEl = jQuery('<div class="col-md-3 span3"></div>').appendTo(mapSearchRow)
    
    mapRow = jQuery('<div class="geospatial-row row"></div>').appendTo(mapSearchEl)
    map = jQuery('<div class="col-md-12 span12"></div>').appendTo(mapRow)
    mapCanvasEl = jQuery('<div class="map-canvas"></div>').appendTo(map)
    
    #Location search input
    inputGpEl = jQuery('<div class="input-group input-append"></div></div>').appendTo(searchEl)
    input = jQuery('<input type="text" class="form-control map-search-location input-xlarge" placeholder="Enter a search location">').appendTo(inputGpEl)
    buttonEl = jQuery('<span class="input-group-btn"><button class="btn btn-default map-search-button" type="button"><span class="fa fa-search"></span></button></span>').appendTo(inputGpEl)
    
    #Map reset link
    resetMapView = jQuery('<button id="reset-map-view" type="button" class="btn btn-link">Reset Map View</button>').appendTo(resetEl)

    ## Map menu and manifest
    mapManifestEl = jQuery('<div class="map-manifest-wrapper col-md-6 span6"></div>').appendTo(mapSplitLayout)
    menuRow = jQuery('<div class="row"></div>').appendTo(mapManifestEl)
    menu = jQuery('<div class="map-menu col-md-12 span12"></div>').appendTo(menuRow)

    manifestRow = jQuery('<div class="geospatial-row row"></div>').appendTo(mapManifestEl)
    mapManifest = jQuery('<div class="col-md-12 span12"></div>').appendTo(manifestRow)
    mapManifestEl = jQuery('<div class="map-manifest"></div>').appendTo(mapManifest)

    @locationController = @getLocationController(@mapArgs[0], @elNum)
    @mapController = @getCartographer(@mapArgs[0], @locationController)

    jQuery(@parentElem).data('views-index', @elNum)

    resetEl.click( (e) =>
      e.preventDefault()
      @mapController.resetMapView()
      )
    
  type: 'map'

  elName: 'genome_map'

  mapView: true

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
    
    tableElem = jQuery("##{@elID} table")
    if tableElem.length
      tableElem.empty()
    else
      divElem = jQuery("<div id='#{@elID}' class='superphy-table'/>")      
      tableElem = jQuery("<table />").appendTo(divElem)
      mapManifest = jQuery('.map-manifest').append(divElem)
      toggleUnknownLocations = jQuery('<div class="checkbox toggle-unknown-location" id="unknown-location"><label><input type="checkbox">Unknown Locations Off</label></div>').appendTo(jQuery('.map-menu'))

      that = @
      toggleUnknownLocations.change( () ->
        that.update(that.genomeController)
        )

    unknownsOff = jQuery('.toggle-unknown-location').find('input')[0].checked

    pubVis = []
    pvtVis = []

    if !@locationController?
      pubVis = genomes.pubVisible
      pvtVis = genomes.pvtVisible
    else
      #Load updated marker list
      @mapController.resetMarkers()

      pubVis.push i for i in @mapController.visibleLocations when i in genomes.pubVisible
      pvtVis.push i for i in @mapController.visibleLocations when i in genomes.pvtVisible      
      #Append genome list with no location
      pubVis.push i for i in @locationController.pubNoLocations when i in genomes.pubVisible unless unknownsOff
      pvtVis.push i for i in @locationController.pvtNoLocations when i in genomes.pvtVisible unless unknownsOff      
    
    #append genomes to list
    t1 = new Date()
    table = ''
    table += @_appendHeader(genomes)
    table += '<tbody>'
    table += @_appendGenomes(genomes.sort(pubVis, @sortField, @sortAsc), genomes.public_genomes, @style, false, true)
    table += @_appendGenomes(genomes.sort(pvtVis, @sortField, @sortAsc), genomes.private_genomes, @style, true, true)
    table += '</body>'
    tableElem.append(table)
    @_actions(tableElem, @style)
    t2 = new Date()
    ft = t2-t1
    console.log 'MapView update elapsed time: ' +ft
    
    true # return success

  # Message to appear in intro for genome map
  intro: ->
    mapIntro = []
    mapIntro.push({
      element: document.querySelector('.map-canvas')
      intro: "This map displays the location of genomes around the world."
      position: 'right'
      })
    mapIntro.push({
      element: document.querySelector('.map-search-location')
      intro: "Input a location here to see genomes found in that region."
      position: 'right'
      })
    mapIntro.push({
      element: document.querySelector('#genome_map3')
      intro: "The genomes corresponding to locations on the map are shown here.  Check the boxes to select each genome."
      position: 'left'
      })
    mapIntro.push({
      element: document.querySelector('#unknown-location')
      intro: "Check 'Unknown Locations Off' if you want to remove unknown locations from the list (these don't appear on the map)."
      position: 'left'
      })
    mapIntro.push({
      element: document.querySelector('#reset-map-view')
      intro: "Clicking this will reset the map view."
      position: 'bottom'
      })
    mapIntro


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

    # Location Meta fields
    for tk,tv of @locationMetaFields 
      sortIcon = null
      
      if tk is @sortField
        sortIcon = 'fa-sort-asc'
        sortIcon = 'fa-sort-desc' unless @sortAsc
        
      else
        sortIcon = 'fa-sort'
      
      values[++i] = { type: tk, name: tv, sortIcon: sortIcon}
      
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
        
        location = true if gObj.isolation_location?
        location = false unless gObj.isolation_location?

        if style == 'redirect'
          # Links
          
          # Genome name
          row += @_template('td1_redirect', {g: g, name: name, shortName: gObj.meta_array[0], klass: thiscls})
          # Genome location
          row += @_template('td1_location', {location: @mapController.allMarkers[g][k] ? 'NA'}) for k,v of @locationMetaFields when location
          row += @_template('td1_nolocation', {location: 'Unknown'}) for k,v of @locationMetaFields when !location
    
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
          # Genome location
          row += @_template('td1_location', {location: @mapController.allMarkers[g][k] ? 'NA'}) for k,v of @locationMetaFields when location
          row += @_template('td1_nolocation', {location: 'Unknown'}) for k,v of @locationMetaFields when !location


          # Other data
          for d in gObj.meta_array[1..-1]
            row += @_template('td', {data: d})
            
          table += @_template('tr', {row: row})       
     
        else
          return false
        
      table

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
      html = "<td class='#{values.klass}'><div class='checkbox'> <label><input class='checkbox genome-table-checkbox' type='checkbox' value='#{values.g}' #{values.checked}/> #{values.name}</label></div></td>"
      
    else if tmpl is 'td1_location'
      html = "<td>#{values.location}</td>"

    else if tmpl is 'td1_nolocation'
      html = "<td class='no-loc'>#{values.location}</td>"

    else if tmpl is 'spacer'
      html = "<tr class='genome-table-spacer'><td>---- USER-SUBMITTED GENOMES ----</td></tr>"
    
    else
      throw new SuperphyError "Unknown template type #{tmpl} in TableView method _template"
      
    html
    
  # FUNC dump
  # Generate CSV tab-delimited representation of all genomes with locations
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
    header = (genomes.metaMap[k] for k of fullMeta)
    header.unshift "Genome name"
    header.push "Location"
    output += "#" + header.join("\t") + "\n"
    
    # Output public set
    for id,g of genomes.public_genomes
      output += genomes.label(g,fullMeta,"\t") + "\t"
      output += if g.isolation_location then JSON.parse(g.isolation_location[0]).formatted_address else "N/A" 
      output += "\n"

    # Output private set
    for id,g of genomes.private_genomes
      output += genomes.label(g,fullMeta,"\t") + "\t"
      output += if g.isolation_location then JSON.parse(g.isolation_location[0]).formatted_address else "N/A" 
      output += "\n"

    return {
      ext: 'csv'
      type: 'text/plain'
      data: output
    }

  # FUNC getCartographer
  # creates a new cartographer object
  # reappends download-view div for better display
  #
  # PARAMS
  #
  # RETURNS
  # cartographer
  #
  getCartographer: (mapType, locationController) ->
    elem = @parentElem
    mapType = mapType ? 'base'
    cartographTypes = {
      'base': () =>
        new Cartographer(jQuery(elem), [locationController])
      'dot': () =>
        new DotCartographer(jQuery(elem), [locationController])
      'satellite': () =>
        new SatelliteCartographer(jQuery(elem), [locationController]) 
      'infoSatellite': () =>
        new InfoSatelliteCartographer(jQuery(elem), [locationController, @mapArgs[1]])
      'geophy': () =>
        new GeophyCartographer(jQuery(elem), [locationController, @mapArgs[1]])
    }
    cartographer = cartographTypes[mapType]()
    cartographer.cartograPhy()
    return cartographer

  # FUNC getLocationController
  # creates a new location controller object
  #
  # PARAMS
  #
  # RETURNS
  # location controller
  #
  getLocationController: (mapType, viewNum) ->
    cartographTypes = {
      'base': () => 
        null
      'dot': () => 
        null
      'satellite': () =>
        new LocationController(@genomeController, @parentElem, viewNum)
      'infoSatellite': () => 
        new LocationController(@genomeController, @parentElem, viewNum)
      'geophy': () => 
        new LocationController(@genomeController, @parentElem, viewNum)
    }
    controller = cartographTypes[mapType]()
    return controller

###
  CLASS SelectionMapView
###

class SelectionMapView extends MapView
  constructor: (@selParentElem, @selStyle, @selElNum, @selGenomeController, @selMapArgs) ->
    super(@selParentElem, @selStyle, @selElNum, @selGenomeController, @selMapArgs)

  update: (genomes) ->
    super
    # TODO: 
    # /strains/info page:
    # If genome is a selected genome add an additional css class to higlight it
    selectedEl = jQuery('.genome_map_item a[data-genome="'+@mapController.selectedGenomeId+'"]')
    selectedElParent = selectedEl.parent()
    selectedElParent.prepend('<p style="padding:0px;margin:0px">Target genome: </p>')
    selectedElParent.css({"font-weight":"bold", "margin-bottom":"5px"})
    jQuery('.superphy-table table tbody').prepend('<tr>'+selectedElParent+'</tr>')
    selectedEl.remove()
    true

###
  CLASS Cartographer

  Handles map drawing and location searching

###
class Cartographer
  constructor: (@cartographDiv, @cartograhOpt) ->
    @defaultCenter = new google.maps.LatLng(-0.000, 0.000)
    @mapOptions = {
      center: @defaultCenter,
      zoom: 1,
      streetViewControl: false,
      mapTypeId: google.maps.MapTypeId.ROADMAP
      }
    @mapBounds
    @map = new google.maps.Map(jQuery(@cartographDiv).find('.map-canvas')[0], @mapOptions)
    jQuery('.map-search-button').bind('click', {context: @}, @pinPoint)


  # FUNC cartograPhy
  # initializes map in specified map div
  #
  # PARAMS
  #
  # RETURNS
  # google map object drawn into specified div
  #
  cartograPhy: () ->
    true

  # FUNC pinPoint
  # geocodes an address from the map search query
  # centers the map at specified area, and stores the latLng info in the database if it doesnt already exist
  #
  # PARAMS
  # address string
  # 
  # RETURNS
  #
  pinPoint: (e) =>
    e.preventDefault()
    queryLocation = jQuery('.map-search-location').val()
    jQuery.ajax({
      type: "POST",
      url: '/strains/geocode',
      data: {'address': queryLocation}
      }).done( (data) =>
        results = JSON.parse(data)
        @map.setCenter(results.geometry.location)
        # TODO: Change from bounds to viewport
        #northEast = new google.maps.LatLng(results.geometry.bounds.northeast.lat, results.geometry.bounds.northeast.lng)
        #southWest = new google.maps.LatLng(results.geometry.bounds.southwest.lat, results.geometry.bounds.southwest.lng)
        northEast = new google.maps.LatLng(results.geometry.viewport.northeast.lat, results.geometry.viewport.northeast.lng)
        southWest = new google.maps.LatLng(results.geometry.viewport.southwest.lat, results.geometry.viewport.southwest.lng)  
        bounds = new google.maps.LatLngBounds(southWest, northEast)
        @map.fitBounds(bounds)
        ).fail ( () ->
          alert "Could not get coordinates for: " +queryLocation+ ". Please enter in another search query"
          )
    true

  resetMapView: ->
    @map.setZoom(1)
    @map.setCenter(@defaultCenter)
    true

###
  CLASS DotCartographer

  Handles map drawing and location searching
  Allows for pinpointing locations

###
class DotCartographer extends Cartographer
  constructor: (@dotCartographDiv, @dotCartograhOpt) ->
    # Call default constructor
    super(@dotCartographDiv, @dotCartograhOpt)
  
  latLng: null
  marker: null

  # FUNC cartograPhy overrides Cartographer
  # initializes map in specified map div
  # binds click listener to map for dropping a map marker
  #
  # PARAMS
  #
  # RETURNS
  # google map object drawn into specified div
  #
  cartograPhy: () ->
    super
    google.maps.event.addListener(@map , 'click', (event) =>
      @plantFlag(event.latLng)
      )
    true

  # FUNC pinPoint overrides Cartographer
  # geocodes an address from the map search query
  # centers the map at specified area, and stores the latLng info in the database if it doesnt already exist
  # adds marker to center of map (i.e. queried location)
  #
  # PARAMS
  # address string
  # 
  # RETURNS
  #
  pinPoint: (e) =>
    e.preventDefault()
    queryLocation = jQuery('.map-search-location').val()
    jQuery.ajax({
      type: "POST",
      url: '/strains/geocode',
      data: {'address': queryLocation}
      }).done( (data) =>
        results = JSON.parse(data)
        @map.setCenter(results.geometry.location)
        # TODO: Change bounds to view port
        #northEast = new google.maps.LatLng(results.geometry.bounds.northeast.lat, results.geometry.bounds.northeast.lng)
        #southWest = new google.maps.LatLng(results.geometry.bounds.southwest.lat, results.geometry.bounds.southwest.lng)
        northEast = new google.maps.LatLng(results.geometry.viewport.northeast.lat, results.geometry.viewport.northeast.lng)
        southWest = new google.maps.LatLng(results.geometry.viewport.southwest.lat, results.geometry.viewport.southwest.lng)  
        bounds = new google.maps.LatLngBounds(southWest, northEast)
        @map.fitBounds(bounds)
        @latLng = results.geometry.location
        @plantFlag(@latLng, @map)
        ).fail ( () ->
          alert "Could not get coordinates for: " +queryLocation+ ". Please enter in another search query"
          )
    true

  # FUNC plantFlag
  # sets new marker on map on click event
  # removes old marker off of map if defined
  #
  # PARAMS
  # location latLng, map map
  #
  # RETURNS
  #
  plantFlag: (location) ->
    @marker.setMap(null) if @marker?
    @marker = new google.maps.Marker({
      position: location,
      map: @map
      });
    @marker.setTitle(@marker.getPosition().toString())
    @map.panTo(@marker.getPosition())
    true

  # FUNC resetMap
  # recenters the map in the map-canvas div when bootstrap map-tab and map-panel divs clicked
  # circumvents issues with rendering maps in bootstraps hidden tab and panel divs
  #
  # PARAMS
  #
  # RETURNS
  #
  resetMap: ()  =>
    x = @map.getZoom()
    c = @map.getCenter()
    google.maps.event.trigger(@map, 'resize')
    @map.setZoom(x)
    @map.setCenter(c)
    true

###
  CLASS SatelliteCartographer

  Handles map drawing and location searching
  Displays multiple markers on map
  Handles marker clustering
  Displays list of genomes 
  Alters genome list when map viewport changes

###
class SatelliteCartographer extends Cartographer
  constructor: (@satelliteCartographDiv, @satelliteCartograhOpt) ->
    # Call default constructor
    super(@satelliteCartographDiv, @satelliteCartograhOpt)
    @locationController = @satelliteCartograhOpt[0]
    @allMarkers = jQuery.extend(@locationController.pubMarkers, @locationController.pvtMarkers)
    @setMarkers(@allMarkers)

  # FUNC cartograPhy overrides Cartographer
  # initializes map in specified map div
  # initializs manifest list of genomes
  # displays genomes on map with known locations
  # clusters markers to reduces drawing overhead
  # binds listen-handlers to map to alter list with map view-port changes
  #
  # PARAMS
  # 
  # RETURNS
  # google map object drawn into specified div
  #
  cartograPhy: () ->
    super
    # Map viewport change event
    google.maps.event.addListener(@map, 'zoom_changed', () =>
      @markerClusterer.clearMarkers()
      )
    google.maps.event.addListener(@map, 'bounds_changed', () =>
      @markerClusterer.clearMarkers()
      )
    google.maps.event.addListener(@map, 'resize', () =>
      @markerClusterer.clearMarkers()
      )
    google.maps.event.addListener(@map, 'idle', () =>
      viewController.views[@locationController.viewNum-1].update(viewController.genomeController)
      )
    true

  # FUNC updateVisible
  # Initializes and sets lists of genomes with known locations
  # Initializes and sets lists of markers for google maps and marker clusterer
  # Resets lists to contain only those markers visible in the viewport of the map
  #
  # PARAMS
  # list of genomeController genomes, map 
  #
  # RETURNS
  #
  updateVisible: () ->
    # TODO:
    genomes = @locationController.genomeController
    @visibleLocations = []
    @clusteredMarkers = []

    for marker_id, marker of @allMarkers
      # Check if present on map
      # TODO: Check that this doesnt throw an error
      if @map.getBounds() != undefined && @map.getBounds().contains(marker.getPosition()) && (marker.feature_id in genomes.pubVisible || marker.feature_id in genomes.pvtVisible)
        @clusteredMarkers.push(marker)
        @visibleLocations.push(marker.feature_id)
    
    true

  # FUNC markerClusterer
  # creates a new marker clusterer object
  #
  # PARAMS
  # google maps map
  # 
  # RETURNS
  #
  setMarkers: (markerList) ->
    circleIcon = {
      path: google.maps.SymbolPath.CIRCLE
      fillColor: '#FF0000'
      fillOpacity: 0.8
      scale: 5
      strokeColor: '#FF0000'
      strokeWeight: 1
      }

    @clusteredMarkers = []

    for marker_id, marker of markerList
      marker.setMap(@map)
      marker.setIcon(circleIcon)
      @clusteredMarkers.push(marker)
    
    mcOptions = {gridSize: 50, maxZoom: 15}
    # Sets the markerClusterer object
    @markerClusterer = new MarkerClusterer(@map, @clusteredMarkers, mcOptions)
    true

  # FUNC resetMap
  # recenters the map in the map-canvas div when bootstrap map-tab and map-panel divs clicked
  # circumvents issues with rendering maps in bootstraps hidden tab and panel divs
  # resets and reinitlializes a new list of markers on the map
  #
  # PARAMS
  #
  # RETURNS
  #
  resetMap: ()  =>
    x = @map.getZoom()
    c = @map.getCenter()
    google.maps.event.trigger(@map, 'resize')
    @map.setZoom(x)
    @map.setCenter(c)
    @resetMarkers()
    true

  resetMarkers: () =>
    @updateVisible()
    @markerClusterer.clearMarkers()
    @markerClusterer.addMarkers(@clusteredMarkers)
    true



class GeophyCartographer extends SatelliteCartographer
  # TODO: Requirements have changed for this class
  constructor: (@geophyCartographDiv, @geophyCartograhOpt) ->
    # Set Group Colors
    @genomeGroupColor = @geophyCartograhOpt[1]
    # Call default constructor
    super(@geophyCartographDiv, @geophyCartograhOpt)

  setMarkers: (markerList) ->
    blue = '#1f77b4';
    orange = '#ff7f0e';
    green = '#2ca02c';
    red = '#d62728';
    purple = '#9467bd';
    brown = '#8c564b';
    pink = '#e377c2';
    grey = '#7f7f7f';
    lime = '#bcbd22';
    aqua = '#17becf';

    colors = {
      'group1Color': blue;
      'group2Color': orange;
      'group3Color': green;
      'group4Color': red;
      'group5Color': purple;
      'group6Color': pink;
      'group7Color': brown;
      'group8Color': grey;
      'group9Color': aqua;
      'group10Color': lime;
    }


    for marker in markerList
      circleIcon = {
        path: google.maps.SymbolPath.CIRCLE
        fillColor: colors["group#{@genomeGroupColor[marker.feature_id]}Color"]
        fillOpacity: 0.8
        scale: 5
        strokeColor: colors["group#{@genomeGroupColor[marker.feature_id]}Color"]
        strokeWeight: 1
        }

      marker.setMap(@map)
      marker.setIcon(circleIcon)
    
    mcOptions = {gridSize: 50, maxZoom: 15}
    # Sets the markerClusterer object
    @markerClusterer = new MarkerClusterer(@map, markerList, mcOptions)
    true

###
  CLASS InfoSatelliteCartographer

  Handles map drawing and location searching
  Displays multiple markers on map
  Handles marker clustering
  Displays list of genomes 
  Alters genome list when map viewport changes
  Highlights selected genome on map from search query

###
class InfoSatelliteCartographer extends SatelliteCartographer
  constructor: (@infoSatelliteCartographDiv, @infoSatelliteCartograhOpt) ->
    # Call default constructor
    super(@infoSatelliteCartographDiv, @infoSatelliteCartograhOpt)
    @selectedGenomeId = @infoSatelliteCartograhOpt[1]
    @selectedGenome = window.viewController.genomeController.private_genomes[@selectedGenomeId] ? window.viewController.genomeController.public_genomes[@selectedGenomeId]
    @selectedGenomeLocation = @locationController._parseLocation(@selectedGenome)

  cartograPhy: () ->
    super
    @showSelectedGenome(@selectedGenomeLocation ,@map)
    @showLegend()

  showSelectedGenome: (location, map) ->
    unless location?
      throw new SuperphyError('Location cannot be determined or location is undefined (not specified)!')
      return 0
    maxZndex = google.maps.Marker.MAX_ZINDEX
    zInd = maxZndex + 1
    markerLatLng = new google.maps.LatLng(location.centerLatLng)
    overlay = new CartographerOverlay(map, location.centerLatLng, location.locationFormattedAddress)

  showLegend: ()  ->
    jQuery('.map-search-table').append('
      <tr>
      <td>
      <div class="map-legend">
        <div class="col-md-3">
          <div class="row">
            <div class="col-xs-3">
              <img class="map-legend-marker-img" src="/App/Pictures/marker_icon_green.png">
            </div>
            <div class="col-xs-9">
             <p class="legendlabel1">Target genome</p>
            </div>
          </div>
        </div>
      </div>
      </td>
      </tr>
      ')

class CartographerOverlay
  constructor: (@map, @latLng, @title) ->
    @setMap(@map)
    @div = null;
    
  CartographerOverlay:: = new google.maps.OverlayView()

  onAdd: () ->
    div = document.createElement('div')
    div.id = "selectedGenome"
    div.style.borderStyle = 'none'
    div.style.borderWidth = '0px'
    div.style.position = 'absolute'
    #div.style.width = '22px'
    #div.style.height = '40px'
    div.style.width = '15px'
    div.style.height = '15px'  
    div.style.cursor = 'pointer'

    # We initially created an svg circle marker but it didnt look very good on the map so were using the default image
    # TODO:
    svg = d3.select(div).append('svg')
      .attr('height', '15px')
      .attr('width', '15px')
    
    selectedMarker = svg.append("g")
      .attr('transform', 'translate(0,0)')
    
    selectedMarker.append("circle")
      .attr('cx', 7.5)
      .attr('cy', 7.5)
      .attr('r', '5px')
      .style({'fill': '#ffc966', 'stroke': '#ffa500', 'stroke-width': '3px', 'fill-opacity': '0.5'})

    selectedMarker.append("title")
      .text(@title)

    # TODO:
    #img = document.createElement('img')
    #img.src = '/App/Pictures/marker_icon_green.png'
    #img.style.width = '100%'
    #img.style.height = '100%'
    #img.style.position = 'absolute'
    #img.id = "selectedGenomeMarker"
    #img.title = @title
    #div.appendChild(img)

    @div = div

    panes = @getPanes()
    panes.floatPane.appendChild(div)

  onRemove: () ->
    @div.parentNode.removeChild(@div)
    @div = null

  draw: () ->
    overlayProjection = @getProjection()
    location = overlayProjection.fromLatLngToDivPixel(@latLng)
    
    div = @div

    #div.style.left = location.x + 'px'
    #div.style.top = location.y + 'px'

    div.style.left = (location.x - 7.5) + 'px'
    div.style.top = (location.y - 7.5) + 'px'


# New class to handle the genome locations and the list
class LocationController
  constructor: (@genomeController, @parentElem, @viewNum) ->
    @_populateLocations(@genomeController)
    #Handle error messages here

  # Genomes with locations
  pubLocations: null
  pvtLocations: null

  # Genomes without locations
  pubNoLocations: null
  pvtNoLocations: null

  # Created Markers
  pubMarkers: null
  pvtMarkers: null

  _populateLocations: (genomes) ->
    @pubLocations = []
    @pvtLocations = []
    @pubNoLocations = []
    @pvtNoLocations = []
    @pubMarkers = {}
    @pvtMarkers = {}

    for pubGenomeId, public_genome of genomes.public_genomes
      unless public_genome.isolation_location? && public_genome.isolation_location != ""
        @pubNoLocations.push(pubGenomeId)
      else
        pubMarkerObj = @_parseLocation(public_genome)
        @pubLocations.push(pubGenomeId)

        public_genome.isolation_country = pubMarkerObj['locationCountry']
        public_genome.isolation_province_state = pubMarkerObj['locationProvinceState']
        public_genome.isolation_city = pubMarkerObj['locationCity']

        pubMarker = new google.maps.Marker({
          position: pubMarkerObj['centerLatLng']
          title: public_genome.uniquename
          feature_id: pubGenomeId
          uniquename: public_genome.uniquename
          location: pubMarkerObj['locationFormattedAddress']
          isolation_country: pubMarkerObj['locationCountry']
          isolation_province_state: pubMarkerObj['locationProvinceState']
          isolation_city: pubMarkerObj['locationCity']
          privacy: 'public'
          })

        @pubMarkers[pubGenomeId] = pubMarker

    for pvtGenomeId, private_genome of genomes.private_genomes
      unless private_genome.isolation_location? && private_genome.isolation_location != ""
        @pvtNoLocations.push(pvtGenomeId)
      else
        pvtMarkerObj = @_parseLocation(private_genome)
        @pvtLocations.push(pvtGenomeId)

        private_genome.isolation_country = pvtMarkerObj['locationCountry']
        private_genome.isolation_province_state = pvtMarkerObj['locationProvinceState']
        private_genome.isolation_city = pvtMarkerObj['locationCity']

        pvtMarker = new google.maps.Marker({
          position: pvtMarkerObj['centerLatLng']
          title: private_genome.uniquename
          feature_id: pvtGenomeId
          uniquename: private_genome.uniquename
          location: pvtMarkerObj['locationFormattedAddress']
          isolation_country: pvtMarkerObj['locationCountry']
          isolation_province_state: pvtMarkerObj['locationProvinceState']
          isolation_city: pvtMarkerObj['locationCity']
          privacy: 'private'
          })            

        @pvtMarkers[pvtGenomeId] = pvtMarker

    true

  # FUNC parseLocation
  # parses the location out from a genome object
  # parses location name, center latLng point, SW and NE boundary latLng points
  #
  # PARAMS
  # genomeController genome
  #
  # RETURNS
  # marker object
  #
  _parseLocation: (genome) ->
    # TODO: Change bounds to viewPort
    genomeLocation = JSON.parse(genome.isolation_location[0])
    # Get location from genome
    locationFormattedAddress = genomeLocation.formatted_address
    # Get location coordinates
    locationCoordinates = genomeLocation.geometry
    # Get location center
    locationCenter = locationCoordinates.location
    # Get center lat
    locationCenterLat = locationCenter.lat
    # Get center Lng
    locationCenterLng = locationCenter.lng
    # Get location SW boundary
    #locationViewPortSW = locationCoordinates.bounds.southwest
    locationViewPortSW = locationCoordinates.viewport.southwest
    # Get SW boundary lat
    locationViewPortSWLat = locationViewPortSW.lat
    # Get SW boundary Lng
    locationViewPortSWLng = locationViewPortSW.lng
    # Get location NE boundary
    #locationViewPortNE = locationCoordinates.bounds.northeast
    locationViewPortNE = locationCoordinates.viewport.northeast
    # Get NE boundary lat
    locationViewPortNELat = locationViewPortNE.lat
    # Get NE boundary lng
    locationViewPortNELng = locationViewPortNE.lng
    
    # Format the address into its components
    locationAddressComponents = {
      'country' :  undefined,
      'administrative_area_level_1' : undefined,
      'locality' : undefined}
    
    locationAddressComponents[add_cmp.types[0]] = add_cmp.long_name for add_cmp in genomeLocation.address_components when add_cmp.types[0] in Object.keys(locationAddressComponents)

    centerLatLng = new google.maps.LatLng(locationCenterLat, locationCenterLng)
    swLatLng = new google.maps.LatLng(locationViewPortSWLat, locationViewPortSWLng)
    neLatLng = new google.maps.LatLng(locationViewPortNELat, locationViewPortNELng)
    markerBounds = new google.maps.LatLngBounds(swLatLng, neLatLng)

    markerObj = {}
    markerObj['locationFormattedAddress'] = locationFormattedAddress
    markerObj['locationCountry'] = locationAddressComponents['country']
    markerObj['locationProvinceState'] = locationAddressComponents['administrative_area_level_1']
    markerObj['locationCity'] = locationAddressComponents['locality']
    markerObj['centerLatLng'] = centerLatLng
    markerObj['markerBounds'] = markerBounds

    return markerObj