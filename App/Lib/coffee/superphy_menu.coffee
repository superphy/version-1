###


 File: superphy_menu.coffee
 Desc: Objects & functions for managing navigation/icon menus in Superphy
 Author: Akiff Manji akiff.manji@gmail.com
 Date: July 24th, 2014
 
 
###

root = exports ? this

###
 CLASS SuperphyError
 
 Error object for this library
 
###
class SuperphyError extends Error
  constructor: (@message='', @name='Superphy Error') ->

class SuperphyMenu
  constructor: (@menuElem, @affix2Elem, @pageName, @menuName, @searchList, @viewList, @searchUrl, @redirectSearch=false) ->
    throw new SuperphyError 'SuperphyMenu requires menuElem parameter' unless @menuElem
    throw new SuperphyError 'SuperphyMenu requires affix2Elem parameter' unless @affix2Elem

    @iconLocation = '/App/Styling/superphy_icons/'

    @iconType = 'svg'

    @iconClasses = {
      'overview' : 'overview_icon_large'
      'stx': 'stx_icon_large'
      'phylogeny': 'phylogeny_icon_large'
      'geospatial': 'geospatial_icon_large'
      'vf': 'vf_icon_large'
      'amr': 'amr_icon_large'
      'download': 'download_icon_large'
      'genomelist': 'genomelist_icon_large'
      'alleles' : 'alleles_icon_large'
      'msa' : 'msa_icon_large'
    }

    @iconTitles = {
      'overview' : 'Overview'
      'stx' : "Stx Subtype"
      'phylogeny' : 'Phylogenetic Tree'
      'geospatial': 'Geospatial Info'
      'vf' : 'Virulence Factors'
      'amr': 'Antimicrobial Resistance'
      'download' : 'Download Genome'
      'genomelist' : 'Genome List'
      'alleles' : 'Alleles'
      'msa' : 'Multiple Sequence Alignment'
    }

    @createNavMenu();
    @appendList(@viewList, 'view', 'View', false) if @viewList?.length;
    @appendList(@searchList, 'search-by','Search By', @redirectSearch) if @searchList?.length;
    @setAffixActions();


  createNavMenu: () ->
    #Creates the shell menu element
    @menuRowEl = jQuery('<div class="row"></div>')
    @menuAppendToEl = jQuery('<div class="col-md-12 hidden-xs" id="superphy-icon-menu"></div>').appendTo(@menuRowEl)
    @menuAffixEl = jQuery("<nav id='#{@menuName}-menu-affix' class='menu-affix panel panel-default'></nav>").appendTo(@menuAppendToEl)
    @mainMenu = jQuery('<ul class="nav"></ul>').appendTo(@menuAffixEl)

    @menuRowEl.appendTo(@menuElem)

    true

  appendList: (list, klass, header, redirectSearch) ->
    # Set up the download link attr
    rowEl = jQuery('<div class="row"></div>')
    navEl = jQuery('<ul class="nav"></ul>').appendTo(rowEl)

    headerEl = jQuery('<div class="col-sm-12"></div>').appendTo(navEl)
    jQuery("<div class='panel-heading'><div class='panel-title'>#{header}:</div></div>").prependTo(headerEl)

    #Append new row for every 6 icons to keep things nice and clean
    count = if list.length % 6 != 0 then list.length + 6 - list.length % 6 else list.length

    for icon in list

      newLineEl = jQuery('<div class="col-sm-12"></div>').appendTo(navEl) if count % 6 == 0

      divEl = jQuery("<div class='col-xs-2 #{icon}-icon-wrapper'></div>")
      liEl = jQuery('<li class="superphy-icon-list"></li>').appendTo(divEl)

      redirectSearchUrl = if redirectSearch then "/#{@pageName}/search" else ""

      if icon is 'download'
        linkEl = jQuery("<a class='genome-dl-link'></a>") if icon is 'download'
      else
        linkEl = jQuery("<a href='#{redirectSearchUrl}##{icon}-panel-header'></a>")
        
        #@_setLinkAction(linkEl, icon) if klass is 'view'

      linkEl.appendTo(liEl)

      iconDivEl = jQuery("<div class='superphy-icon #{icon}-icon'></div>").appendTo(linkEl)
      iconEl = jQuery("<div class='superphy-icon-img #{icon}-icon-img' data-toggle='tooltip' title='#{@iconTitles[icon]}'></div>").appendTo(iconDivEl)
      captionEl = jQuery("<div class='caption'><small>#{@iconTitles[icon]}</small></div>").appendTo(iconDivEl)

      divEl.appendTo(newLineEl)

      count--
    
    rowEl.appendTo(@mainMenu)

    true

  _setLinkAction: (linkEl, icon) ->
    # TODO: Unused function for now. Candidate for deprecation
    linkEl.on('click', (e) ->
      if icon is 'stx'
        jQuery("#overview-panel").collapse('show') if jQuery("a[href='#overview-panel']").hasClass('collapsed')
      else
        jQuery("##{icon}-panel").collapse('show') if jQuery("a[href='##{icon}-panel']").hasClass('collapsed')
      )
    true

  setAffixActions: () ->

    menu_affix_height = jQuery(@menuAffixEl).height()

    menu_affix_offset = jQuery(@menuAffixEl).offset().top

    navbar_height = jQuery('.navbar').height()

    that = @

    @menuAffixEl.on('affix.bs.affix', () ->
      #jQuery('#accordian').css("margin-top", menu_affix_height + navbar_height)
      jQuery(@).prependTo(jQuery(that.affix2Elem)).hide().fadeIn('slow')
      jQuery('.superphy-icon').addClass('affix')
      )

    @menuAffixEl.on('affix-top.bs.affix', () ->
      #jQuery('#accordian').css("margin-top", "0px")
      jQuery(@).appendTo(jQuery(that.menuAppendToEl)).hide().fadeIn('slow')
      jQuery('.superphy-icon').removeClass('affix')
      )

    jQuery('[data-toggle="tooltip"]').tooltip({'placement': 'top'})

    jQuery(@menuAffixEl).affix({
      offset: {top: menu_affix_height + menu_affix_offset - navbar_height}
      })

    jQuery('body').scrollspy({ target: "##{@menuName}-menu-affix", offset: navbar_height + 20})

    # Set size classes on window load and resize
    jQuery(window).load( () ->
      if jQuery(@).width() < 1000
        jQuery(that.menuAffixEl).addClass('sm')
      else
        jQuery(that.menuAffixEl).removeClass('sm')
      )

    jQuery(window).resize( () ->
      if jQuery(@).width() < 1000
        jQuery(that.menuAffixEl).addClass('sm')
      else
        jQuery(that.menuAffixEl).removeClass('sm')
      )

    jQuery(@menuElem).height(menu_affix_height).css("margin-bottom", "30px")

    true

# Return instance of SuperphyMenu
unless root.SuperphyMenu
  root.SuperphyMenu = SuperphyMenu